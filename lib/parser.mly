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

program:
  T_program T_id T_semicolon body T_dot T_eof { () }

body:
  locals block { () }

locals:
  (* empty *)    { () }
| locals local   { () }

(* ⟨local⟩ — τι μπορεί να υπάρχει πριν το begin/end block:
   - var δηλώσεις μεταβλητών
   - label δηλώσεις ετικετών
   - ορισμός procedure/function (header + body)
   - forward δήλωση (ότι αυτό ορίζεται αργότερα) *)
local:
  T_var var_decl_list                   { () }
| T_label id_list T_semicolon           { () }
| header T_semicolon body T_semicolon   { () }
| T_forward header T_semicolon          { () }

(* Ένα ή περισσότερα var declarations:
   var x, y : integer;
       a    : boolean;   ← δύο var_decl *)
var_decl_list:
  var_decl                 { () }
| var_decl_list var_decl   { () }

(* Μια γραμμή δήλωσης: x, y, z : integer; *)
var_decl:
  id_list T_colon typ T_semicolon  { () }

(* Λίστα από ονόματα χωρισμένα με κόμμα: x, y, z *)
id_list:
  T_id                 { () }
| id_list T_comma T_id { () }
