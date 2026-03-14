{
  open Tokens

  (* exception for strings not understood (ie. @#$) *)
  exception LexicalError of string

  (* Buffer for building string literals *)
  let string_buf = Buffer.create 64

  (* returns "line X, col Y" for the current lexbuf position *)
  let lexer_pos lexbuf =
    let pos = Lexing.lexeme_start_p lexbuf in
    Printf.sprintf "line %d, col %d" pos.pos_lnum (pos.pos_cnum - pos.pos_bol)

  (* function that inputs c and returns the correct character *)
  (* escape sequences *)
  let decode_escape lexbuf c = match c with
    | 'n'  -> '\n'
    | 't'  -> '\t'
    | 'r'  -> '\r'
    | '0'  -> '\000' (* Ocaml null = \000 (octal) or \x00 (hex) *)
    | '\\' -> '\\'  (* stays the same: \ char = \\  in Ocaml *)
    | '\'' -> '\''  (* stays the same: ' char = \' in Ocaml *)
    | '"'  -> '"'   (* pcl source = \" but in Ocaml is '"' no backspace needed *)
    (* _ = else *)
    | _    -> raise (LexicalError (lexer_pos lexbuf ^ Printf.sprintf ": Unknown escape sequence: \\%c" c))
}

(* ── Named character classes ─────────────────────────────────────── *)
let letter     = ['a'-'z' 'A'-'Z']
let digit      = ['0'-'9']
let id_char    = letter | digit | '_'
let whitespace = [' ' '\t' '\r' '\n']

(* ── Numeric patterns ─────────────────────────────────────────────── *)
let integer    = digit+
let real       = digit+ '.' digit+ (['e' 'E'] ['+' '-']? digit+)?

(* ── Printable characters allowed inside char/string literals ──────
   Any printable ASCII except single-quote, double-quote and backslash *)
let common_char = [^ '\'' '"' '\\' '\x00'-'\x1f' '\x7f']

(* ── Main tokenizer ──────────────────────────────────────────────── *)
rule token = parse
  (* Whitespace – skip silently *)
  | whitespace+   { token lexbuf }

  (* Block comments  (* ... *)  – not nested *)
  | "(*"          { comment lexbuf }

  (* ── Keywords (must come before the identifier rule so that the
       longest-match / first-rule tie-break picks the keyword when the
       input is exactly the keyword word) ── *)
  | "and"         { T_and }
  | "array"       { T_array }
  | "begin"       { T_begin }
  | "boolean"     { T_boolean }
  | "char"        { T_char }
  | "dispose"     { T_dispose }
  | "div"         { T_div }
  | "do"          { T_do }
  | "else"        { T_else }
  | "end"         { T_end }
  | "false"       { T_false }
  | "forward"     { T_forward }
  | "function"    { T_function }
  | "goto"        { T_goto }
  | "if"          { T_if }
  | "integer"     { T_integer }
  | "label"       { T_label }
  | "mod"         { T_mod }
  | "new"         { T_new }
  | "nil"         { T_nil }
  | "not"         { T_not }
  | "of"          { T_of }
  | "or"          { T_or }
  | "procedure"   { T_procedure }
  | "program"     { T_program }
  | "real"        { T_real }
  | "result"      { T_result }
  | "return"      { T_return }
  | "then"        { T_then }
  | "true"        { T_true }
  | "var"         { T_var }
  | "while"       { T_while }

  (* ── Identifiers ── *)
  | letter id_char*  { T_id (Lexing.lexeme lexbuf) }

  (* ── Real literals (must come before integer so "42.0" isn't split) ── *)
  | real             { T_real_const (float_of_string (Lexing.lexeme lexbuf)) }

  (* ── Integer literals ── *)
  | integer          { T_int_const (int_of_string (Lexing.lexeme lexbuf)) }

  (* ── Character literals  'x'  or  '\n' ── *)
  | '\'' (common_char as c) '\''
      { T_char_const c }
  | '\'' '\\' (['n' 't' 'r' '0' '\\' '\'' '"'] as c) '\''
      { T_char_const (decode_escape lexbuf c) }

  (* ── String literals  "..." ── *)
  | '"'
      { Buffer.clear string_buf;
        string_lit lexbuf }

  (* ── Two-character operators (must come before single-char ones) ── *)
  | ":="  { T_assign }
  | "<>"  { T_ne }
  | ">="  { T_ge }
  | "<="  { T_le }

  (* ── Single-character operators ── *)
  | '='   { T_eq }
  | '<'   { T_lt }
  | '>'   { T_gt }
  | '+'   { T_plus }
  | '-'   { T_minus }
  | '*'   { T_times }
  | '/'   { T_fdiv }
  | '^'   { T_caret }
  | '@'   { T_at }

  (* ── Punctuation ── *)
  | ';'   { T_semicolon }
  | '.'   { T_dot }
  | '('   { T_lparen }
  | ')'   { T_rparen }
  | ':'   { T_colon }
  | ','   { T_comma }
  | '['   { T_lbracket }
  | ']'   { T_rbracket }

  | eof   { T_eof }

  | _ as c
      { raise (LexicalError
          (Printf.sprintf "Unexpected character: '%c' (ASCII %d)"
             c (Char.code c))) }

(* ── Block-comment consumer ─────────────────────────────────────── *)
and comment = parse
  | "*)"  { token lexbuf }
  | eof   { raise (LexicalError (lexer_pos lexbuf ^ ": Unterminated comment")) }
  | _     { comment lexbuf }

(* ── String-literal consumer ────────────────────────────────────── *)
and string_lit = parse
  | '"'
      { T_string_const (Buffer.contents string_buf) }
  | '\\' (['n' 't' 'r' '0' '\\' '\'' '"'] as c)
      { Buffer.add_char string_buf (decode_escape lexbuf c);
        string_lit lexbuf }
  | '\n'
      { raise (LexicalError (lexer_pos lexbuf ^ ": Unterminated string literal (newline inside string)")) }
  | eof
      { raise (LexicalError (lexer_pos lexbuf ^ ": Unterminated string literal")) }
  | common_char+ as s
      { Buffer.add_string string_buf s;
        string_lit lexbuf }
  | _ as c
      { raise (LexicalError (lexer_pos lexbuf ^ Printf.sprintf ": Invalid character in string: '%c'" c)) }
