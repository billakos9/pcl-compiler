
module MenhirBasics = struct
  
  exception Error
  
  let _eRR =
    fun _s ->
      raise Error
  
  type token = 
    | T_while
    | T_var
    | T_true
    | T_times
    | T_then
    | T_string_const of 
# 17 "lib/parser.mly"
       (string)
# 20 "lib/parser.ml"
  
    | T_semicolon
    | T_rparen
    | T_return
    | T_result
    | T_real_const of 
# 15 "lib/parser.mly"
       (float)
# 29 "lib/parser.ml"
  
    | T_real
    | T_rbracket
    | T_program
    | T_procedure
    | T_plus
    | T_or
    | T_of
    | T_not
    | T_nil
    | T_new
    | T_ne
    | T_mod
    | T_minus
    | T_lt
    | T_lparen
    | T_le
    | T_lbracket
    | T_label
    | T_integer
    | T_int_const of 
# 14 "lib/parser.mly"
       (int)
# 53 "lib/parser.ml"
  
    | T_if
    | T_id of 
# 13 "lib/parser.mly"
       (string)
# 59 "lib/parser.ml"
  
    | T_gt
    | T_goto
    | T_ge
    | T_function
    | T_forward
    | T_fdiv
    | T_false
    | T_eq
    | T_eof
    | T_end
    | T_else
    | T_dot
    | T_do
    | T_div
    | T_dispose
    | T_comma
    | T_colon
    | T_char_const of 
# 16 "lib/parser.mly"
       (char)
# 81 "lib/parser.ml"
  
    | T_char
    | T_caret
    | T_boolean
    | T_begin
    | T_at
    | T_assign
    | T_array
    | T_and
  
end

include MenhirBasics

# 1 "lib/parser.mly"
  
  (* =========================================================
     parser.mly  –  Menhir parser for PCL
     Filled in during Phase 2.
     ========================================================= *)

# 103 "lib/parser.ml"

type ('s, 'r) _menhir_state

and _menhir_box_program = 
  | MenhirBox_program of (unit) [@@unboxed]

let _menhir_action_1 =
  fun () ->
    (
# 29 "lib/parser.mly"
          ( () )
# 115 "lib/parser.ml"
     : (unit))

let _menhir_print_token : token -> string =
  fun _tok ->
    match _tok with
    | T_while ->
        "T_while"
    | T_var ->
        "T_var"
    | T_true ->
        "T_true"
    | T_times ->
        "T_times"
    | T_then ->
        "T_then"
    | T_string_const _ ->
        "T_string_const"
    | T_semicolon ->
        "T_semicolon"
    | T_rparen ->
        "T_rparen"
    | T_return ->
        "T_return"
    | T_result ->
        "T_result"
    | T_real_const _ ->
        "T_real_const"
    | T_real ->
        "T_real"
    | T_rbracket ->
        "T_rbracket"
    | T_program ->
        "T_program"
    | T_procedure ->
        "T_procedure"
    | T_plus ->
        "T_plus"
    | T_or ->
        "T_or"
    | T_of ->
        "T_of"
    | T_not ->
        "T_not"
    | T_nil ->
        "T_nil"
    | T_new ->
        "T_new"
    | T_ne ->
        "T_ne"
    | T_mod ->
        "T_mod"
    | T_minus ->
        "T_minus"
    | T_lt ->
        "T_lt"
    | T_lparen ->
        "T_lparen"
    | T_le ->
        "T_le"
    | T_lbracket ->
        "T_lbracket"
    | T_label ->
        "T_label"
    | T_integer ->
        "T_integer"
    | T_int_const _ ->
        "T_int_const"
    | T_if ->
        "T_if"
    | T_id _ ->
        "T_id"
    | T_gt ->
        "T_gt"
    | T_goto ->
        "T_goto"
    | T_ge ->
        "T_ge"
    | T_function ->
        "T_function"
    | T_forward ->
        "T_forward"
    | T_fdiv ->
        "T_fdiv"
    | T_false ->
        "T_false"
    | T_eq ->
        "T_eq"
    | T_eof ->
        "T_eof"
    | T_end ->
        "T_end"
    | T_else ->
        "T_else"
    | T_dot ->
        "T_dot"
    | T_do ->
        "T_do"
    | T_div ->
        "T_div"
    | T_dispose ->
        "T_dispose"
    | T_comma ->
        "T_comma"
    | T_colon ->
        "T_colon"
    | T_char_const _ ->
        "T_char_const"
    | T_char ->
        "T_char"
    | T_caret ->
        "T_caret"
    | T_boolean ->
        "T_boolean"
    | T_begin ->
        "T_begin"
    | T_at ->
        "T_at"
    | T_assign ->
        "T_assign"
    | T_array ->
        "T_array"
    | T_and ->
        "T_and"

let _menhir_fail : unit -> 'a =
  fun () ->
    Printf.eprintf "Internal failure -- please contact the parser generator's developers.\n%!";
    assert false

include struct
  
  [@@@ocaml.warning "-4-37"]
  
  let _menhir_run_0 : type  ttv_stack. ttv_stack -> _ -> _ -> _menhir_box_program =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer ->
      let _tok = _menhir_lexer _menhir_lexbuf in
      match (_tok : MenhirBasics.token) with
      | T_eof ->
          let _v = _menhir_action_1 () in
          MenhirBox_program _v
      | _ ->
          _eRR ()
  
end

let program =
  fun _menhir_lexer _menhir_lexbuf ->
    let _menhir_stack = () in
    let MenhirBox_program v = _menhir_run_0 _menhir_stack _menhir_lexbuf _menhir_lexer in
    v
