open Pcl_compiler.Parser
open Pcl_compiler.Lexer

(* ── Pretty-print a token (used for --dump-tokens debug mode) ──── *)
let string_of_token = function
  | T_and       -> "T_and"
  | T_array     -> "T_array"
  | T_begin     -> "T_begin"
  | T_boolean   -> "T_boolean"
  | T_char      -> "T_char"
  | T_dispose   -> "T_dispose"
  | T_div       -> "T_div"
  | T_do        -> "T_do"
  | T_else      -> "T_else"
  | T_end       -> "T_end"
  | T_false     -> "T_false"
  | T_forward   -> "T_forward"
  | T_function  -> "T_function"
  | T_goto      -> "T_goto"
  | T_if        -> "T_if"
  | T_integer   -> "T_integer"
  | T_label     -> "T_label"
  | T_mod       -> "T_mod"
  | T_new       -> "T_new"
  | T_nil       -> "T_nil"
  | T_not       -> "T_not"
  | T_of        -> "T_of"
  | T_or        -> "T_or"
  | T_procedure -> "T_procedure"
  | T_program   -> "T_program"
  | T_real      -> "T_real"
  | T_result    -> "T_result"
  | T_return    -> "T_return"
  | T_then      -> "T_then"
  | T_true      -> "T_true"
  | T_var       -> "T_var"
  | T_while     -> "T_while"
  | T_id s             -> Printf.sprintf "T_id(%s)" s
  | T_int_const n      -> Printf.sprintf "T_int_const(%d)" n
  | T_real_const f     -> Printf.sprintf "T_real_const(%g)" f
  | T_char_const c     -> Printf.sprintf "T_char_const(%C)" c
  | T_string_const s   -> Printf.sprintf "T_string_const(%S)" s
  | T_assign    -> "T_assign(:=)"
  | T_eq        -> "T_eq(=)"
  | T_ne        -> "T_ne(<>)"
  | T_lt        -> "T_lt(<)"
  | T_gt        -> "T_gt(>)"
  | T_le        -> "T_le(<=)"
  | T_ge        -> "T_ge(>=)"
  | T_plus      -> "T_plus(+)"
  | T_minus     -> "T_minus(-)"
  | T_times     -> "T_times(*)"
  | T_fdiv      -> "T_fdiv(/)"
  | T_caret     -> "T_caret(^)"
  | T_at        -> "T_at(@)"
  | T_semicolon -> "T_semicolon(;)"
  | T_dot       -> "T_dot(.)"
  | T_lparen    -> "T_lparen"
  | T_rparen    -> "T_rparen"
  | T_colon     -> "T_colon(:)"
  | T_comma     -> "T_comma(,)"
  | T_lbracket  -> "T_lbracket([)"
  | T_rbracket  -> "T_rbracket(])"
  | T_eof       -> "T_eof"

(* ── Phase 1: Lex – dump all tokens ─────────────────────────────── *)
let run_lexer lexbuf =
  try
    let rec loop () =
      let tok = token lexbuf in
      Printf.printf "%s\n" (string_of_token tok);
      if tok <> T_eof then loop ()
    in
    loop ()
  with LexicalError msg ->
    Printf.eprintf "Lexical error: %s\n" msg;
    exit 1

(* ── Phase 2: Parse ─────────────────────────────────────────────── *)
let run_parser lexbuf =
  try
    let ast = Pcl_compiler.Parser.program Pcl_compiler.Lexer.token lexbuf in
    Printf.printf "Parsing OK\n";
    Pcl_compiler.Ast_printer.print_program ast
  with
  | Pcl_compiler.Lexer.LexicalError msg ->
      Printf.eprintf "Lexical error: %s\n" msg; exit 1
  | _e ->
      Printf.eprintf "Syntax error\n"; exit 1

(* ── Phase 3: Semantic analysis – TODO ─────────────────────────── *)
(* let run_semantic _ast = () *)

(* ── Phase 4: Code generation – TODO ───────────────────────────── *)
(* let run_codegen _ast = () *)

(* ── Entry point ─────────────────────────────────────────────────── *)
let () =
  let filename =
    if Array.length Sys.argv > 1 then Sys.argv.(1)
    else (Printf.eprintf "Usage: pcl-compiler <file.pcl>\n"; exit 1)
  in
  let ic = open_in filename in
  let lexbuf = Lexing.from_channel ic in
  run_lexer lexbuf;
  let ic2 = open_in filename in
  let lexbuf2 = Lexing.from_channel ic2 in
  run_parser lexbuf2;
  close_in ic;
  close_in ic2
