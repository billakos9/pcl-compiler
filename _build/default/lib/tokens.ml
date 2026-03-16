type token =
  (* Keywords (As shown in pdf) *)
  | T_and
  | T_array
  | T_begin
  | T_boolean
  | T_char
  | T_dispose
  | T_div
  | T_do
  | T_else
  | T_end
  | T_false
  | T_forward
  | T_function
  | T_goto
  | T_if
  | T_integer
  | T_label
  | T_mod
  | T_new
  | T_nil
  | T_not
  | T_of
  | T_or
  | T_procedure
  | T_program
  | T_real
  | T_result
  | T_return
  | T_then
  | T_true
  | T_var
  | T_while
  (* Identifiers *)
  | T_id of string
  (* Constants *)
  | T_int_const of int
  | T_real_const of float
  | T_char_const of char
  | T_string_const of string
  (* Operators *)
  | T_assign    (* := *)
  | T_eq        (* =  *)
  | T_ne        (* <> *)
  | T_lt        (* <  *)
  | T_gt        (* >  *)
  | T_le        (* <= *)
  | T_ge        (* >= *)
  | T_plus      (* +  *)
  | T_minus     (* -  *)
  | T_times     (* *  *)
  | T_fdiv      (* /  *)
  | T_caret     (* ^  *)
  | T_at        (* @  *)
  (* Separators / Punctuation *)
  | T_semicolon (* ; *)
  | T_dot       (* . *)
  | T_lparen    (* ( *)
  | T_rparen    (* ) *)
  | T_colon     (* : *)
  | T_comma     (* , *)
  | T_lbracket  (* [ *)
  | T_rbracket  (* ] *)
  (* End of file *)
  | T_eof
