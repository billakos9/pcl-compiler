(* 
typed representation produced by
semantic analysis for cleaner architecture
and better codegen code 
*)


(* Example:

  for 42 semantic analysis produces:
  {
   node = TEInt 42;
   pcl_type = Ast.TInteger;
   category = RValue;
  }
etc.

*)


type value_category =
  | LValue
  | RValue


type expr = {
  node : expr_node;
  pcl_type : Ast.typ;
  category: value_category;
}

and expr_node =
  | TEId of string
  | TEResult
  | TEInt of int
  | TEReal of float
  | TEChar of char
  | TEString of string
  | TEBool of bool
  | TENil
  | TECall of string * expr list
  | TEBinop of Ast.binop * expr * expr
  | TEUnop of Ast.unop * expr
  | TEIndex of expr * expr
  | TEIntToReal of expr


type stmt =
  | TSEmpty
  | TSAssign of expr * expr
  | TSBlock of stmt list
  | TSCall of string * expr list
  | TSIf of expr * stmt * stmt option
  | TSWhile of expr * stmt
  | TSLabel of string * stmt
  | TSGoto of string
  | TSReturn
  | TSNew of expr
  | TSNewArray of expr * expr
  | TSDispose of expr
  | TSDisposeArray of expr


type local =
  | TLVar of (string list * Ast.typ) list
  | TLLabel of string list
  | TLDef of Ast.header * body
  | TLForward of Ast.header

and body = {
  locals : local list;
  block : stmt list;
}

type program = {
  name : string;
  body : body;
}


