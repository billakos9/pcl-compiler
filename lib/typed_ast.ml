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




