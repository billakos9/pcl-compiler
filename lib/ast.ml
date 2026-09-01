(* =========================================================
   ast.ml  –  Abstract Syntax Tree for PCL
   ========================================================= *)

(* ── Types ── *)
type typ =
  | TInteger
  | TReal
  | TBoolean
  | TChar
  | TArray   of int option * typ   (* Some n = fixed size; None = open *)
  | TPointer of typ
  | TNil

(* ── Operators ── *)
type binop =
  | BPlus | BMinus | BTimes | BFDiv   (* +  -  *  /  *)
  | BDiv  | BMod                      (* div  mod     *)
  | BOr   | BAnd                      (* or   and     *)
  | BEq   | BNe                       (* =  <>        *)
  | BLt   | BGt   | BLe   | BGe       (* <  >  <=  >= *)

type unop =
  | UPlus                 (* unary +  *)
  | UMinus                (* unary -  *)
  | UNot                  (* not      *)
  | UDeref                (* expr^    *)
  | UAddrOf               (* @expr    *)

(* ── Expressions ── *)
type expr =
  | EId     of string
  | EResult                             (* result keyword inside a function *)
  | EInt    of int
  | EReal   of float
  | EChar   of char
  | EString of string
  | EBool   of bool
  | ENil
  | ECall   of string * expr list       (* f(e1, e2, ...) *)
  | EBinop  of binop * expr * expr
  | EUnop   of unop  * expr
  | EIndex  of expr  * expr             (* a[i]           *)

(* ── Statements ── *)
type stmt =
  | SEmpty
  | SAssign       of expr * expr              (* lval := expr          *)
  | SBlock        of stmt list                (* begin ... end         *)
  | SCall         of string * expr list       (* procedure call        *)
  | SIf           of expr * stmt * stmt option
  | SWhile        of expr * stmt
  | SLabel        of string * stmt            (* myLabel: stmt         *)
  | SGoto         of string
  | SReturn
  | SNew          of expr                     (* new p                 *)
  | SNewArray     of expr * expr              (* new [n] arr           *)
  | SDispose      of expr                     (* dispose p             *)
  | SDisposeArray of expr                     (* dispose [] arr        *)

(* ── Formal parameters ── *)
type pass_mode = ByValue | ByRef

type formal = pass_mode * string list * typ

(* ── Procedure / function header ── *)
type header =
  | HProcedure of string * formal list
  | HFunction  of string * formal list * typ

(* ── Local declarations & body (mutually recursive) ── *)
type local =
  | LVar     of (string list * typ) list   (* var x,y:int; a:bool; — all groups under one var *)
  | LLabel   of string list                (* label foo, bar;       *)
  | LDef     of header * body              (* proc/func + body      *)
  | LForward of header                     (* forward decl          *)

and body = {
  locals : local list;
  block  : stmt list;
}

(* ── Top-level program ── *)
type program = {
  name : string;
  body : body;
}

