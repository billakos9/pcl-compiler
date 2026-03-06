%{
  (* =========================================================
     parser.mly  –  Menhir parser for PCL
     Filled in during Phase 2.
     ========================================================= *)
%}

(* ── Token declarations (must mirror tokens.ml) ── *)
%token T_and T_array T_begin T_boolean T_char T_dispose T_div T_do
%token T_else T_end T_false T_forward T_function T_goto T_if T_integer
%token T_label T_mod T_new T_nil T_not T_of T_or T_procedure T_program
%token T_real T_result T_return T_then T_true T_var T_while
%token <string> T_id
%token <int>    T_int_const
%token <float>  T_real_const
%token <char>   T_char_const
%token <string> T_string_const
%token T_assign T_eq T_ne T_lt T_gt T_le T_ge
%token T_plus T_minus T_times T_fdiv T_caret T_at
%token T_semicolon T_dot T_lparen T_rparen T_colon T_comma
%token T_lbracket T_rbracket
%token T_eof

%start <Ast.program> program
%%

(* ── Grammar rules – TODO: implement in Phase 2 ── *)
program:
  | T_eof { () }
