
module MenhirBasics = struct
  
  exception Error
  
  let _eRR =
    fun _s ->
      raise Error
  
  type token = 
    | T_eof
  
end

include MenhirBasics

# 1 "lib/parser.mly"
  
  (* =========================================================
     parser.mly  –  Menhir parser for PCL
     Filled in during Phase 2.
     ========================================================= *)

# 25 "lib/parser.ml"

type ('s, 'r) _menhir_state

and _menhir_box_program = 
  | MenhirBox_program of (unit) [@@unboxed]

let _menhir_action_1 =
  fun () ->
    (
# 12 "lib/parser.mly"
               ( () )
# 37 "lib/parser.ml"
     : (unit))

let _menhir_print_token : token -> string =
  fun _tok ->
    match _tok with
    | T_eof ->
        "T_eof"

let _menhir_fail : unit -> 'a =
  fun () ->
    Printf.eprintf "Internal failure -- please contact the parser generator's developers.\n%!";
    assert false

include struct
  
  [@@@ocaml.warning "-4-37"]
  
  let _menhir_run_0 : type  ttv_stack. ttv_stack -> _ -> _ -> _menhir_box_program =
    fun _menhir_stack _menhir_lexbuf _menhir_lexer ->
      let _ = _menhir_lexer _menhir_lexbuf in
      let _v = _menhir_action_1 () in
      MenhirBox_program _v
  
end

let program =
  fun _menhir_lexer _menhir_lexbuf ->
    let _menhir_stack = () in
    let MenhirBox_program v = _menhir_run_0 _menhir_stack _menhir_lexbuf _menhir_lexer in
    v
