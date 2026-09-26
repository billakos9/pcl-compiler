open Pcl_compiler

let parse_file filename =
  let channel = open_in filename in
  Fun.protect
    ~finally:(fun () -> close_in_noerr channel)
    (fun () ->
      let lexbuf = Lexing.from_channel channel in
      lexbuf.lex_curr_p <-
        { lexbuf.lex_curr_p with pos_fname = filename };
      Parser.program Lexer.token lexbuf)


let compile_file filename =
  let ast = parse_file filename in
  let typed_program = Semantic.analyze_program ast in
  Codegen.generate_program typed_program


let write_output output_filename llvm_ir =
  match output_filename with
  | None ->
      print_string llvm_ir

  | Some filename ->
      let channel = open_out filename in
      Fun.protect
        ~finally:(fun () -> close_out_noerr channel)
        (fun () -> output_string channel llvm_ir)


let () =
  let input_filename = ref None in
  let output_filename = ref None in
  let set_input filename =
    match !input_filename with
    | None -> input_filename := Some filename
    | Some _ -> raise (Arg.Bad "only one input file may be specified")
  in
  let options =
    [
      ("-o", Arg.String (fun filename -> output_filename := Some filename),
       "<file.ll> write LLVM IR to this file");
    ]
  in
  let usage = "Usage: pcl-compiler [-o output.ll] <file.pcl>" in
  Arg.parse options set_input usage;

  let filename =
    match !input_filename with
    | Some filename -> filename
    | None ->
        Arg.usage options usage;
        exit 1
  in

  try
    compile_file filename
    |> write_output !output_filename
  with
  | Lexer.LexicalError message ->
      Printf.eprintf "Lexical error: %s\n" message;
      exit 1
  | Parser.Error ->
      Printf.eprintf "Syntax error\n";
      exit 1
  | Semantic.TypeError message ->
      Printf.eprintf "Semantic error: %s\n" message;
      exit 1
  | Codegen.CodegenError message ->
      Printf.eprintf "Code generation error: %s\n" message;
      exit 1
  | Sys_error message ->
      Printf.eprintf "File error: %s\n" message;
      exit 1
