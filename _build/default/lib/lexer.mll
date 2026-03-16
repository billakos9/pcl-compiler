(* Header Block *)
{
  open Parser

  (* exception for strings not understood (ie. @#$) *)
  exception LexicalError of string

  (* Buffer for building string literals *)
  let string_buf = Buffer.create 64

  (*    lexer_pos returns "line X, col Y" for the current lexbuf position.
        
        lexeme_start_p returns a Lexing.position record for the start of
        the current lexeme; 
        
        pos_lnum is the current line number (1-based),
        
        pos_cnum is the absolute character offset from the start of the input
        
        pos_bol is the offset of the beginning of the current line
    *)

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
let id_char    = letter | digit | '_'   (* Characters allowed inside an identifier *)
let whitespace = [' ' '\t' '\r' '\n']   (* Empty characters (space , tab, move to start of the line, newline) *)

(* ── Numeric patterns ─────────────────────────────────────────────── *)
let integer    = digit+
(* ? = the previous block is either 0 or 1 (optional)*)
let real       = digit+ '.' digit+ (['e' 'E'] ['+' '-']? digit+)?

(* ── Printable characters allowed inside char/string literals
  Any printable ASCII ( except = ^ ) single-quote, double-quote and backslash *)
let common_char = [^ '\'' '"' '\\' '\x00'-'\x1f' '\x7f']

(* ── Main tokenizer ──────────────────────────────────────────────── *)
(*  First pattern wins in Ocamllex (ie. begine is T_begin and note T_id "begin") *)
rule token = parse
  (* Whitespace – skip silently *)
  | whitespace+   { token lexbuf }    (* Recursive call of the function *)

  (* Block comments  (* ... *)  – not nested *)
  | "(*"          { comment lexbuf }  (* Jump to comment function *)

  (* Keywords *)
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
  (* id_char starts with a letter *)
  | letter id_char*  { T_id (Lexing.lexeme lexbuf) } (* returns the string just read from lexer *)

  (* ── Real literals (must come before integer so "42.0" isn't split) ── *)
  | real             { T_real_const (float_of_string (Lexing.lexeme lexbuf)) }    (* conversion to real *)

  (* ── Integer literals ── *)
  | integer          { T_int_const (int_of_string (Lexing.lexeme lexbuf)) }   (* conversion to string *)

  (* ── Character literals  'x'  or  '\n' ── *)
  | '\'' (common_char as c) '\''
      { T_char_const c }
  (* escape char literal *)
  | '\'' '\\' (['n' 't' 'r' '0' '\\' '\'' '"'] as c) '\''
      { T_char_const (decode_escape lexbuf c) }

  (* ── String literals  "..." ── *)
  | '"'
      { Buffer.clear string_buf;    (* clean buffer from previous reads *)
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

(* cont. of token rule *)
(* ── String-literal consumer ────────────────────────────────────── *)
and string_lit = parse
  (* string ended *)
  | '"'
      { T_string_const (Buffer.contents string_buf) }
  (* decode escape and add to buffer *)
  | '\\' (['n' 't' 'r' '0' '\\' '\'' '"'] as c)
      { Buffer.add_char string_buf (decode_escape lexbuf c);
        string_lit lexbuf }
  (* error if string never ended with '"' *)
  | '\n'
      { raise (LexicalError (lexer_pos lexbuf ^ ": Unterminated string literal (newline inside string)")) }
  | eof
      { raise (LexicalError (lexer_pos lexbuf ^ ": Unterminated string literal")) }
  (* many chars together -> add them (better efficiency) *)
  | common_char+ as s
      { Buffer.add_string string_buf s;
        string_lit lexbuf }
  (* fallback *)
  | _ as c
      { raise (LexicalError (lexer_pos lexbuf ^ Printf.sprintf ": Invalid character in string: '%c'" c)) }
