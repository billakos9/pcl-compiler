open Pcl_compiler
open Parser

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

let dump_tokens filename =
  let channel = open_in filename in
(* create the buffer *)
  let lexbuf = Lexing.from_channel channel in

  let rec loop () =
    (* consume until eof *)
    let token = Lexer.token lexbuf in
    Printf.printf "%s\n" (string_of_token token);

    if token <> T_eof then
      loop ()
  in
(* close even if lexer fails *)
  try
    loop ();
    close_in channel
  with error ->
    close_in_noerr channel;
    raise error

let () =
  if Array.length Sys.argv <> 2 then begin
    Printf.eprintf "Usage: lexer_inspect <file.pcl>\n";
    exit 1
  end;
  
  let filename = Sys.argv.(1) in

(* error handling, 
1 - file not in pcl, 
2 - file does not open *)
  try
    dump_tokens filename
  with
  | Lexer.LexicalError message ->
      Printf.eprintf "Lexical error: %s\n" message;
      exit 1
  | Sys_error message ->
      Printf.eprintf "File error: %s\n" message;
      exit 1