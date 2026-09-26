open Pcl_compiler

exception SyntaxError of string
exception DriverError of string

type output_mode =
  | BuildExecutable
  | EmitIntermediate
  | EmitFinal


let lexer_position lexbuf =
  let position = lexbuf.Lexing.lex_curr_p in
  let column = position.pos_cnum - position.pos_bol + 1 in
  Printf.sprintf
    "%s:%d:%d"
    position.pos_fname
    position.pos_lnum
    column


let parse_channel source_name channel =
  let lexbuf = Lexing.from_channel channel in
  lexbuf.lex_curr_p <-
    { lexbuf.lex_curr_p with pos_fname = source_name };

  try
    Parser.program Lexer.token lexbuf
  with Parser.Error ->
    raise (SyntaxError (lexer_position lexbuf))


let compile_channel ~optimize source_name channel =
  let ast = parse_channel source_name channel in
  let typed_program = Semantic.analyze_program ast in
  let optimized_program =
    if optimize then
      Optimizer.optimize_program typed_program
    else
      typed_program
  in
  Codegen.generate_program optimized_program


let compile_file ~optimize filename =
  let channel = open_in filename in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () -> compile_channel ~optimize filename channel)


let write_file filename contents =
  let channel = open_out filename in
  Fun.protect
    ~finally:(fun () -> close_out_noerr channel)
    (fun () -> output_string channel contents)


let remove_if_present filename =
  try Sys.remove filename with Sys_error _ -> ()


let with_temporary_llvm llvm_ir action =
  let filename = Filename.temp_file "pclc-" ".imm" in
  Fun.protect
    ~finally:(fun () -> remove_if_present filename)
    (fun () ->
      write_file filename llvm_ir;
      action filename)


let absolute_path path =
  if Filename.is_relative path then
    Filename.concat (Sys.getcwd ()) path
  else
    path


let rec find_upwards directory relative_path =
  let candidate = Filename.concat directory relative_path in
  if Sys.file_exists candidate then
    Some candidate
  else
    let parent = Filename.dirname directory in
    if parent = directory then
      None
    else
      find_upwards parent relative_path


let find_runtime () =
  match Sys.getenv_opt "PCL_RUNTIME" with
  | Some filename when Sys.file_exists filename ->
      filename

  | Some filename ->
      raise
        (DriverError
           ("PCL_RUNTIME does not exist: " ^ filename))

  | None ->
      let executable_directory =
        Sys.executable_name
        |> absolute_path
        |> Filename.dirname
      in
      let search_roots =
        [Sys.getcwd (); executable_directory]
      in
      let rec search = function
        | [] ->
            raise
              (DriverError
                 "cannot locate runtime/pcl_runtime.c; set PCL_RUNTIME")

        | directory :: rest ->
            (match find_upwards directory "runtime/pcl_runtime.c" with
            | Some filename -> filename
            | None -> search rest)
      in
      search search_roots


let clang_program () =
  match Sys.getenv_opt "PCL_CLANG" with
  | Some command -> command
  | None -> "clang"


let process_status = function
  | Unix.WEXITED code ->
      Printf.sprintf "exited with status %d" code
  | Unix.WSIGNALED signal ->
      Printf.sprintf "was killed by signal %d" signal
  | Unix.WSTOPPED signal ->
      Printf.sprintf "was stopped by signal %d" signal


let run_process stage arguments =
  let argv = Array.of_list arguments in
  try
    let process =
      Unix.create_process
        argv.(0)
        argv
        Unix.stdin
        Unix.stdout
        Unix.stderr
    in
    let _, status = Unix.waitpid [] process in
    match status with
    | Unix.WEXITED 0 -> ()
    | _ ->
        raise
          (DriverError
             (stage ^ " failed: " ^ process_status status))
  with
  | Unix.Unix_error (error, function_name, argument) ->
      raise
        (DriverError
           (Printf.sprintf
              "%s failed in %s(%s): %s"
              stage
              function_name
              argument
              (Unix.error_message error)))


let optimization_arguments optimize =
  if optimize then ["-O2"] else []


let llvm_input_arguments =
  ["-Wno-override-module"; "-x"; "ir"]


let generate_assembly ~optimize ~llvm_filename ~assembly_filename =
  let clang = clang_program () in
  run_process
    "assembly generation"
    ([clang]
     @ optimization_arguments optimize
     @ ["-S"]
     @ llvm_input_arguments
     @ [llvm_filename; "-o"; assembly_filename])


let link_executable ~assembly_filename ~output_filename =
  let clang = clang_program () in
  let runtime = find_runtime () in
  run_process
    "linking"
    [ clang;
      "-x"; "assembler"; assembly_filename;
      "-x"; "c"; runtime;
      "-lm";
      "-o"; output_filename ]


let source_stem filename =
  if Filename.extension filename = "" then
    filename
  else
    Filename.chop_extension filename


let build_executable ~optimize ~output_filename source_filename =
  let llvm_ir = compile_file ~optimize source_filename in
  let stem = source_stem source_filename in
  let llvm_filename = stem ^ ".imm" in
  let assembly_filename = stem ^ ".asm" in
  write_file llvm_filename llvm_ir;
  generate_assembly ~optimize ~llvm_filename ~assembly_filename;
  link_executable ~assembly_filename ~output_filename


let emit_intermediate ~optimize llvm_ir =
  if not optimize then
    print_string llvm_ir
  else
    with_temporary_llvm llvm_ir (fun llvm_filename ->
      let clang = clang_program () in
      run_process
        "intermediate optimization"
        ([clang; "-S"; "-emit-llvm"; "-O2"]
         @ llvm_input_arguments
         @ [llvm_filename; "-o"; "-"]))


let emit_final ~optimize llvm_ir =
  with_temporary_llvm llvm_ir (fun llvm_filename ->
    generate_assembly
      ~optimize
      ~llvm_filename
      ~assembly_filename:"-")


let run () =
  let mode = ref BuildExecutable in
  let mode_was_set = ref false in
  let input_filename = ref None in
  let output_filename = ref None in
  let optimize = ref false in

  let set_mode requested_mode =
    if !mode_was_set then
      raise (Arg.Bad "-i and -f are mutually exclusive");
    mode := requested_mode;
    mode_was_set := true
  in

  let set_input filename =
    match !input_filename with
    | None -> input_filename := Some filename
    | Some _ -> raise (Arg.Bad "only one input file may be specified")
  in

  let options =
    [ ("-i", Arg.Unit (fun () -> set_mode EmitIntermediate),
       "read PCL from stdin and write LLVM IR to stdout");
      ("-f", Arg.Unit (fun () -> set_mode EmitFinal),
       "read PCL from stdin and write assembly to stdout");
      ("-o", Arg.String (fun filename -> output_filename := Some filename),
       "<file> set the generated executable path");
      ("-O", Arg.Set optimize,
       "enable LLVM optimization") ]
  in

  let usage =
    "Usage: pcl-compiler [-O] [-o executable] <source>\n\
     \       pcl-compiler [-O] (-i | -f)"
  in
  Arg.parse options set_input usage;

  match !mode with
  | BuildExecutable ->
      let source_filename =
        match !input_filename with
        | Some filename -> filename
        | None -> raise (DriverError "no input file specified")
      in
      let executable =
        match !output_filename with
        | Some filename -> filename
        | None -> "a.out"
      in
      build_executable
        ~optimize:!optimize
        ~output_filename:executable
        source_filename

  | EmitIntermediate
  | EmitFinal as selected_mode ->
      if !input_filename <> None then
        raise (DriverError "-i and -f read source from standard input");
      if !output_filename <> None then
        raise (DriverError "-o cannot be combined with -i or -f");

      let llvm_ir = compile_channel ~optimize:!optimize "<stdin>" stdin in
      (match selected_mode with
      | EmitIntermediate -> emit_intermediate ~optimize:!optimize llvm_ir
      | EmitFinal -> emit_final ~optimize:!optimize llvm_ir
      | BuildExecutable -> assert false)


let () =
  try
    run ()
  with
  | Lexer.LexicalError message ->
      Printf.eprintf "Lexical error: %s\n" message;
      exit 1
  | SyntaxError position ->
      Printf.eprintf "Syntax error at %s\n" position;
      exit 1
  | Semantic.TypeError message ->
      Printf.eprintf "Semantic error: %s\n" message;
      exit 1
  | Codegen.CodegenError message ->
      Printf.eprintf "Code generation error: %s\n" message;
      exit 1
  | DriverError message ->
      Printf.eprintf "Compiler driver error: %s\n" message;
      exit 1
  | Sys_error message ->
      Printf.eprintf "File error: %s\n" message;
      exit 1
