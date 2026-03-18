%{
  (* =========================================================
     parser.mly  –  Menhir parser for PCL
     ========================================================= *)
  open Ast
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

%start <Ast.program> program

(* ── Types for each non-terminal ── *)
%type <Ast.typ>                      typ
%type <Ast.expr>                     expr
%type <Ast.stmt>                     stmt
%type <Ast.stmt list>                stmt_list block
%type <Ast.local>                    local
%type <Ast.local list>               locals
%type <(string list * Ast.typ) list> var_decl_list
%type <string list * Ast.typ>        var_decl
%type <string list>                  id_list
%type <Ast.header>                   header
%type <Ast.formal list>              formal_list
%type <Ast.formal>                   formal
%type <Ast.body>                     body
%type <string * Ast.expr list>       call
%type <Ast.expr list>                expr_list

(* ── Operator precedence (lowest to highest) ── *)
%nonassoc T_then              (* dangling else: shift "else" over closer "then" *)
%nonassoc T_else
%left     T_or
%left     T_and
%nonassoc T_not
%nonassoc T_eq T_ne T_lt T_gt T_le T_ge
%left     T_plus T_minus
%left     T_times T_fdiv T_div T_mod
%nonassoc UNARY T_at          (* unary +, -, @x address-of *)
%nonassoc T_lbracket          (* a[i] array indexing        *)
%nonassoc T_caret             (* p^   dereference — highest *)

%%

(* ═══════════════════════════════════════════════════════════
   PROGRAM STRUCTURE
   ═══════════════════════════════════════════════════════════ *)

program:
  T_program T_id T_semicolon body T_dot T_eof  { { name = $2; body = $4 } }

(* body = zero or more locals, then a block *)
body:
  locals block  { { locals = $1; block = $2 } }

(* zero or more local declarations *)
locals:
  (* empty *)    { [] }
| locals local   { $1 @ [$2] }

(* a single local declaration *)
local:
  T_var var_decl_list                   { LVar $2 }
| T_label id_list T_semicolon           { LLabel $2 }
| header T_semicolon body T_semicolon   { LDef($1, $3) }
| T_forward header T_semicolon          { LForward $2 }

(* ═══════════════════════════════════════════════════════════
   DECLARATIONS
   ═══════════════════════════════════════════════════════════ *)

(* one or more var declaration lines: x, y : integer;  a : boolean; *)
var_decl_list:
  var_decl                 { [$1] }
| var_decl_list var_decl   { $1 @ [$2] }

(* one declaration line: x, y, z : integer; *)
var_decl:
  id_list T_colon typ T_semicolon  { ($1, $3) }

(* comma-separated names: x, y, z *)
id_list:
  T_id                   { [$1] }
| id_list T_comma T_id   { $1 @ [$3] }

(* procedure or function header (without body) *)
header:
  T_procedure T_id T_lparen formal_list T_rparen             { HProcedure($2, $4) }
| T_function  T_id T_lparen formal_list T_rparen T_colon typ { HFunction($2, $4, $7) }

(* zero or more formal parameter groups separated by ";" *)
formal_list:
  (* empty *)                    { [] }
| formal                         { [$1] }
| formal_list T_semicolon formal { $1 @ [$3] }

(* one parameter group: [var] x, y : integer *)
formal:
  T_var id_list T_colon typ { (ByRef, $2, $4) }
| id_list T_colon typ       { (ByValue, $1, $3) }

(* variable type *)
typ:
  T_integer                                           { TInteger }
| T_real                                              { TReal }
| T_boolean                                           { TBoolean }
| T_char                                              { TChar }
| T_array T_lbracket T_int_const T_rbracket T_of typ  { TArray(Some $3, $6) }
| T_array T_lbracket T_rbracket T_of typ              { TArray(None, $5) }
| T_array T_of typ                                    { TArray(None, $3) }
| T_caret typ                                         { TPointer $2 }

(* ═══════════════════════════════════════════════════════════
   STATEMENTS
   ═══════════════════════════════════════════════════════════ *)

(* begin stmt ; stmt ; ... end *)
block:
  T_begin stmt_list T_end  { $2 }

(* one or more stmts separated by ";" *)
stmt_list:
  stmt                        { [$1] }
| stmt_list T_semicolon stmt  { $1 @ [$3] }

stmt:
  (* empty *)                                         { SEmpty }
| expr T_assign expr                                  { SAssign($1, $3) }
| block                                               { SBlock $1 }
| call                                                { let (name, args) = $1 in SCall(name, args) }
| T_if expr T_then stmt                               { SIf($2, $4, None) }
| T_if expr T_then stmt T_else stmt                   { SIf($2, $4, Some $6) }
| T_while expr T_do stmt                              { SWhile($2, $4) }
| T_id T_colon stmt                                   { SLabel($1, $3) }
| T_goto T_id                                         { SGoto $2 }
| T_return                                            { SReturn }
| T_new expr                                          { SNew $2 }
| T_new T_lbracket expr T_rbracket expr               { SNewArray($3, $5) }
| T_dispose expr                                      { SDispose $2 }
| T_dispose T_lbracket T_rbracket expr                { SDisposeArray $4 }

(* ═══════════════════════════════════════════════════════════
   EXPRESSIONS
   ═══════════════════════════════════════════════════════════ *)

expr:
  T_id                              { EId $1 }
| T_result                          { EResult }
| T_string_const                    { EString $1 }
| T_int_const                       { EInt $1 }
| T_real_const                      { EReal $1 }
| T_char_const                      { EChar $1 }
| T_true                            { EBool true }
| T_false                           { EBool false }
| T_nil                             { ENil }
| call                              { let (name, args) = $1 in ECall(name, args) }
| T_lparen expr T_rparen            { $2 }
| T_at expr          %prec T_at     { EUnop(UAddrOf, $2) }
| expr T_caret                      { EUnop(UDeref, $1) }
| expr T_lbracket expr T_rbracket   { EIndex($1, $3) }
| T_not   expr       %prec T_not    { EUnop(UNot, $2) }
| T_plus  expr       %prec UNARY    { EUnop(UPlus, $2) }
| T_minus expr       %prec UNARY    { EUnop(UMinus, $2) }
| expr T_plus   expr                { EBinop(BPlus,  $1, $3) }
| expr T_minus  expr                { EBinop(BMinus, $1, $3) }
| expr T_times  expr                { EBinop(BTimes, $1, $3) }
| expr T_fdiv   expr                { EBinop(BFDiv,  $1, $3) }
| expr T_div    expr                { EBinop(BDiv,   $1, $3) }
| expr T_mod    expr                { EBinop(BMod,   $1, $3) }
| expr T_or     expr                { EBinop(BOr,    $1, $3) }
| expr T_and    expr                { EBinop(BAnd,   $1, $3) }
| expr T_eq     expr                { EBinop(BEq,    $1, $3) }
| expr T_ne     expr                { EBinop(BNe,    $1, $3) }
| expr T_lt     expr                { EBinop(BLt,    $1, $3) }
| expr T_gt     expr                { EBinop(BGt,    $1, $3) }
| expr T_le     expr                { EBinop(BLe,    $1, $3) }
| expr T_ge     expr                { EBinop(BGe,    $1, $3) }

(* function/procedure call: foo(x, y, z) or foo() *)
call:
  T_id T_lparen expr_list T_rparen  { ($1, $3) }

(* zero or more comma-separated expressions *)
expr_list:
  (* empty *)              { [] }
| expr                     { [$1] }
| expr_list T_comma expr   { $1 @ [$3] }