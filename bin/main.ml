open Pcl_compiler

(* ── Phase 1: Parser ─────────────────────────────────────────────── *)
let run_parser lexbuf =
  try
    Parser.program
      Lexer.token
      lexbuf
  with
  | Lexer.LexicalError message ->
      Printf.eprintf "Lexical error: %s\n" message; 
      exit 1
  | _error ->
      Printf.eprintf "Syntax error\n"; 
      exit 1

(* ── Phase 3: Semantic analysis – TODO ─────────────────────────── *)
(* let run_semantic _ast = () *)

(* ── Phase 4: Code generation – TODO ───────────────────────────── *)
(* let run_codegen _ast = () *)

(* ── Entry point ─────────────────────────────────────────────────── *)
let () =
  let filename =
    if Array.length Sys.argv > 1 then 
      Sys.argv.(1)
    else begin
      Printf.eprintf "Usage: pcl-compiler <file.pcl>\n"; 
      exit 1
    end
  in

  let channel = open_in filename in
  let lexbuf = Lexing.from_channel channel in
  let _ast = run_parser lexbuf in
  
  close_in channel;
  Printf.printf "Parsing OK\n"
