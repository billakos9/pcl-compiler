open Pcl_compiler


let parse_file filename =
  let channel = open_in filename in
  let lexbuf = Lexing.from_channel channel in

  try
    let ast = Parser.program Lexer.token lexbuf in
    close_in channel;
    ast
  with error ->
    close_in_noerr channel;
    raise error


(* entry point *)
let () =
  if Array.length Sys.argv <> 2 then
    begin
      Printf.eprintf "Usage: semantic_inspect <file.pcl>\n";
      exit 1
    end;

    let filename = Sys.argv.(1) in

    try
      let ast = parse_file filename in
      Semantic.check_program ast;
      Printf.printf "Semantic Analysis OK\n"
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
    | Sys_error message ->
      Printf.eprintf "File error: %s\n" message;
      exit 1
      
