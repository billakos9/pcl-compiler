%{
  (* =========================================================
     parser.mly  –  Menhir parser for PCL
     ========================================================= *)
%}

(* ── Keywords ── *)
%token T_and T_array T_begin T_boolean T_char T_dispose T_div T_do
%token T_else T_end T_false T_forward T_function T_goto T_if T_integer
%token T_label T_mod T_new T_nil T_not T_of T_or T_procedure T_program
%token T_real T_result T_return T_then T_true T_var T_while

(* ── Identifiers & Literals ── *)
%token <string> T_id
%token <int>    T_int_const
%token <float>  T_real_const
%token <char>   T_char_const
%token <string> T_string_const

(* ── Operators ── *)
%token T_assign    (* := *)
%token T_eq        (* =  *)
%token T_ne        (* <> *)
%token T_lt        (* <  *)
%token T_gt        (* >  *)
%token T_le        (* <= *)
%token T_ge        (* >= *)
%token T_plus      (* +  *)
%token T_minus     (* -  *)
%token T_times     (* *  *)
%token T_fdiv      (* /  *)
%token T_caret     (* ^  *)
%token T_at        (* @  *)

(* ── Punctuation ── *)
%token T_semicolon (* ; *)
%token T_dot       (* . *)
%token T_lparen    (* ( *)
%token T_rparen    (* ) *)
%token T_colon     (* : *)
%token T_comma     (* , *)
%token T_lbracket  (* [ *)
%token T_rbracket  (* ] *)

(* ── End of file ── *)
%token T_eof

%start <unit> program
%%

(* ═══════════════════════════════════════════════════════════
   PROGRAM STRUCTURE
   ═══════════════════════════════════════════════════════════ *)

program:
  T_program T_id T_semicolon body T_dot T_eof { () }

(* body = zero or more locals, then a block *)
body:
  locals block { () }

(* zero or more local declarations *)
locals:
  (* empty *)    { () }
| locals local   { () }

(* a single local declaration *)
local:
  T_var var_decl_list                   { () }  (* var x, y : integer; ...        *)
| T_label id_list T_semicolon           { () }  (* label foo, bar;                *)
| header T_semicolon body T_semicolon   { () }  (* procedure/function definition  *)
| T_forward header T_semicolon          { () }  (* forward declaration            *)

(* ═══════════════════════════════════════════════════════════
   DECLARATIONS
   ═══════════════════════════════════════════════════════════ *)

(* one or more var declaration lines: x, y : integer;  a : boolean; *)
var_decl_list:
  var_decl                 { () }
| var_decl_list var_decl   { () }

(* one declaration line: x, y, z : integer; *)
var_decl:
  id_list T_colon typ T_semicolon  { () }

(* comma-separated names: x, y, z *)
id_list:
  T_id                   { () }
| id_list T_comma T_id   { () }

(* procedure or function header (without body) *)
header:
  T_procedure T_id T_lparen formal_list T_rparen             { () }
| T_function  T_id T_lparen formal_list T_rparen T_colon typ { () }

(* zero or more formal parameter groups separated by ";" *)
formal_list:
  (* empty *)                    { () }
| formal                         { () }
| formal_list T_semicolon formal { () }

(* one parameter group: [var] x, y : integer
   "var" = call-by-reference, without = call-by-value *)
formal:
  T_var id_list T_colon typ { () }
| id_list T_colon typ       { () }

(* variable type *)
typ:
  T_integer                                           { () }  (* integer            *)
| T_real                                              { () }  (* real               *)
| T_boolean                                           { () }  (* boolean            *)
| T_char                                              { () }  (* char               *)
| T_array T_lbracket T_int_const T_rbracket T_of typ  { () }  (* array [10] of int  *)
| T_array T_lbracket T_rbracket T_of typ              { () }  (* array [] of int    *)
| T_caret typ                                         { () }  (* ^integer (pointer) *)

(* ═══════════════════════════════════════════════════════════
   STATEMENTS
   ═══════════════════════════════════════════════════════════ *)

(* begin stmt ; stmt ; ... end *)
block:
  T_begin stmt_list T_end  { () }

(* one or more stmts separated by ";" — ";" is a separator not a terminator *)
stmt_list:
  stmt                        { () }
| stmt_list T_semicolon stmt  { () }

stmt:
  (* empty *)                                         { () }  (* allowed: begin end or begin ; end  *)
| lvalue T_assign expr                                { () }  (* x := 5                            *)
| block                                               { () }  (* nested begin/end                  *)
| call                                                { () }  (* foo(x, y)                         *)
| T_if expr T_then stmt                               { () }  (* if x then ...                     *)
| T_if expr T_then stmt T_else stmt                   { () }  (* if x then ... else ...            *)
| T_while expr T_do stmt                              { () }  (* while x do ...                    *)
| T_id T_colon stmt                                   { () }  (* myLabel: stmt  (label definition) *)
| T_goto T_id                                         { () }  (* goto myLabel                      *)
| T_return                                            { () }  (* return from function/procedure    *)
| T_new lvalue                                        { () }  (* new p        (pointer alloc)      *)
| T_new T_lbracket expr T_rbracket lvalue             { () }  (* new [n] arr  (array alloc)        *)
| T_dispose lvalue                                    { () }  (* dispose p    (pointer free)       *)
| T_dispose T_lbracket T_rbracket lvalue              { () }  (* dispose [] arr (array free)       *)

(* ═══════════════════════════════════════════════════════════
   EXPRESSIONS
   ═══════════════════════════════════════════════════════════ *)

expr:
  lvalue  { () }  |   rvalue  { () }

lvalue:
  T_id                                { () }  (* x                   *)
| T_result                            { () }  (* result (in function) *)
| T_string_const                      { () }  (* "hello"              *)
| lvalue T_lbracket expr T_rbracket   { () }  (* a[i]                *)
| expr T_caret                        { () }  (* p^  (dereference)   *)
| T_lparen lvalue T_rparen            { () }  (* (x)                 *)

rvalue:
  T_int_const                { () }  (* 42                *)
| T_real_const               { () }  (* 3.14              *)
| T_char_const               { () }  (* 'a'               *)
| T_true                     { () }  (* true              *)
| T_false                    { () }  (* false             *)
| T_nil                      { () }  (* nil               *)
| T_lparen rvalue T_rparen   { () }  (* (r-value)         *)
| call                       { () }  (* foo(x, y)         *)
| T_at lvalue                { () }  (* @x  (address-of)  *)
| T_not expr                 { () }  (* not x             *)
| T_plus expr                { () }  (* +x  (unary plus)  *)
| T_minus expr               { () }  (* -x  (unary minus) *)
| expr T_plus expr           { () }  (* x + y             *)
| expr T_minus expr          { () }  (* x - y             *)
| expr T_times expr          { () }  (* x * y             *)
| expr T_fdiv expr           { () }  (* x / y             *)
| expr T_div expr            { () }  (* x div y           *)
| expr T_mod expr            { () }  (* x mod y           *)
| expr T_or expr             { () }  (* x or y            *)
| expr T_and expr            { () }  (* x and y           *)
| expr T_eq expr             { () }  (* x = y             *)
| expr T_ne expr             { () }  (* x <> y            *)
| expr T_lt expr             { () }  (* x < y             *)
| expr T_gt expr             { () }  (* x > y             *)
| expr T_le expr             { () }  (* x <= y            *)
| expr T_ge expr             { () }  (* x >= y            *)

(* function/procedure call: foo(x, y, z) or foo() *)
call:
  T_id T_lparen expr_list T_rparen  { () }

(* zero or more comma-separated expressions *)
expr_list:
  (* empty *)              { () }
| expr                     { () }
| expr_list T_comma expr   { () }
