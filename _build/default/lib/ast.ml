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

(* =========================================================
   Pretty-printer  –  prints the AST as an indented tree
   ========================================================= *)

let ind n = String.make (n * 2) ' '

let string_of_binop = function
  | BPlus -> "+" | BMinus -> "-" | BTimes -> "*" | BFDiv -> "/"
  | BDiv  -> "div" | BMod -> "mod"
  | BOr   -> "or"  | BAnd -> "and"
  | BEq   -> "="   | BNe  -> "<>"
  | BLt   -> "<"   | BGt  -> ">"  | BLe -> "<=" | BGe -> ">="

let string_of_unop = function
  | UPlus  -> "unary+" | UMinus -> "unary-"
  | UNot   -> "not"    | UDeref -> "deref^" | UAddrOf -> "@"

let rec string_of_typ = function
  | TInteger   -> "integer"
  | TReal      -> "real"
  | TBoolean   -> "boolean"
  | TChar      -> "char"
  | TPointer t -> "^" ^ string_of_typ t
  | TArray (None,   t) -> "array[] of " ^ string_of_typ t
  | TArray (Some n, t) -> Printf.sprintf "array[%d] of %s" n (string_of_typ t)

let rec print_expr depth e =
  let p = Printf.printf in
  match e with
  | EId s        -> p "%sEId(%s)\n"    (ind depth) s
  | EResult      -> p "%sEResult\n"    (ind depth)
  | EInt n       -> p "%sEInt(%d)\n"   (ind depth) n
  | EReal f      -> p "%sEReal(%g)\n"  (ind depth) f
  | EChar c      -> p "%sEChar(%C)\n"  (ind depth) c
  | EString s    -> p "%sEString(%S)\n"(ind depth) s
  | EBool b      -> p "%sEBool(%b)\n"  (ind depth) b
  | ENil         -> p "%sENil\n"       (ind depth)
  | ECall (f, args) ->
      p "%sECall(%s)\n" (ind depth) f;
      List.iter (print_expr (depth+1)) args
  | EBinop (op, l, r) ->
      p "%sEBinop(%s)\n" (ind depth) (string_of_binop op);
      print_expr (depth+1) l;
      print_expr (depth+1) r
  | EUnop (op, e) ->
      p "%sEUnop(%s)\n" (ind depth) (string_of_unop op);
      print_expr (depth+1) e
  | EIndex (arr, idx) ->
      p "%sEIndex\n" (ind depth);
      print_expr (depth+1) arr;
      print_expr (depth+1) idx

and print_stmt depth s =
  let p = Printf.printf in
  match s with
  | SEmpty   -> p "%sSEmpty\n" (ind depth)
  | SReturn  -> p "%sSReturn\n" (ind depth)
  | SGoto lbl -> p "%sSGoto(%s)\n" (ind depth) lbl
  | SAssign (lv, rv) ->
      p "%sSAssign\n" (ind depth);
      print_expr (depth+1) lv;
      print_expr (depth+1) rv
  | SBlock stmts ->
      p "%sSBlock\n" (ind depth);
      List.iter (print_stmt (depth+1)) stmts
  | SCall (f, args) ->
      p "%sSCall(%s)\n" (ind depth) f;
      List.iter (print_expr (depth+1)) args
  | SIf (cond, th, el) ->
      p "%sSIf\n" (ind depth);
      print_expr (depth+1) cond;
      p "%sthen:\n" (ind (depth+1));
      print_stmt (depth+2) th;
      (match el with
       | None    -> ()
       | Some e  -> p "%selse:\n" (ind (depth+1)); print_stmt (depth+2) e)
  | SWhile (cond, body) ->
      p "%sSWhile\n" (ind depth);
      print_expr (depth+1) cond;
      print_stmt (depth+1) body
  | SLabel (lbl, s) ->
      p "%sSLabel(%s)\n" (ind depth) lbl;
      print_stmt (depth+1) s
  | SNew e ->
      p "%sSNew\n" (ind depth);
      print_expr (depth+1) e
  | SNewArray (n, arr) ->
      p "%sSNewArray\n" (ind depth);
      print_expr (depth+1) n;
      print_expr (depth+1) arr
  | SDispose e ->
      p "%sSDispose\n" (ind depth);
      print_expr (depth+1) e
  | SDisposeArray e ->
      p "%sSDisposeArray\n" (ind depth);
      print_expr (depth+1) e

and print_formal depth (mode, names, t) =
  let pass = match mode with ByValue -> "val" | ByRef -> "ref" in
  Printf.printf "%sformal(%s) [%s] : %s\n"
    (ind depth) pass (String.concat ", " names) (string_of_typ t)

and print_header depth h =
  match h with
  | HProcedure (name, formals) ->
      Printf.printf "%sProcedure(%s)\n" (ind depth) name;
      List.iter (print_formal (depth+1)) formals
  | HFunction (name, formals, ret) ->
      Printf.printf "%sFunction(%s) : %s\n" (ind depth) name (string_of_typ ret);
      List.iter (print_formal (depth+1)) formals

and print_local depth l =
  match l with
  | LVar groups ->
      Printf.printf "%sLVar\n" (ind depth);
      List.iter (fun (names, t) ->
        Printf.printf "%s[%s] : %s\n"
          (ind (depth+1)) (String.concat ", " names) (string_of_typ t)
      ) groups
  | LLabel names ->
      Printf.printf "%sLLabel [%s]\n" (ind depth) (String.concat ", " names)
  | LForward h ->
      Printf.printf "%sLForward\n" (ind depth);
      print_header (depth+1) h
  | LDef (h, b) ->
      Printf.printf "%sLDef\n" (ind depth);
      print_header (depth+1) h;
      print_body  (depth+1) b

and print_body depth b =
  List.iter (print_local depth) b.locals;
  Printf.printf "%sBlock\n" (ind depth);
  List.iter (print_stmt (depth+1)) b.block

let print_program prog =
  Printf.printf "Program(%s)\n" prog.name;
  print_body 1 prog.body
