(* =========================================================
   semantic.ml  –  Type checker / semantic analysis for PCL
   Filled in during Phase 3.
   ========================================================= *)
open Ast
open Symbol

exception TypeError of string

let rec check_expr table return_type expr = 
   match expr with 
      | EInt _ -> TInteger 
      | EReal _ -> TReal
      | EBool _ -> TBoolean
      | EChar _ -> TChar
      | ENil -> TPointer TInteger
      | EId name ->
         ( match lookup table name with
            | None -> raise (TypeError ("undefined variable : " ^ name))
            | Some (SVar t) -> t
            | Some (SFunc _) -> raise (TypeError (name ^ " is a function , not a variable "))
         )
      | EResult -> 
         ( match return_type with
            | Some t -> t
            | None -> raise (TypeError "result used outside a function")
         )
      | EBinop (op, left, right) -> 
         let t1 = check_expr table return_type left in
         let t2 = check_expr table return_type right in
         ( match op ,t1, t2 with
         (* Arithmetic - same type in , same type out *)
            | (BPlus | BMinus | BTimes), TInteger, TInteger -> TInteger
            | (BPlus | BMinus | BTimes), TReal, TReal -> TReal
            | (BPlus | BMinus | BTimes), _ , _ -> raise (TypeError "invalid types for + ")

         (* integer only *)
            | (BDiv | BMod) , TInteger, TInteger -> TInteger
            | (BDiv | BMod) , _, _ -> raise (TypeError " div/mod requires integers")
         
         (* real division only *)
            | BFDiv, TReal, TReal -> TReal
            | BFDiv, _, _ -> raise (TypeError "/ requires reals")

         (* comparisons - any matching type, returns bool *)
            | (BEq | BNe | BLt | BGt | BLe | BGe), t1, t2 when t1 = t2 -> TBoolean
            | (BEq | BNe | BLt | BGt | BLe | BGe), _ , _ -> raise (TypeError "comparison requires matching types")

         (* lofical *)
            | (BAnd | BOr), TBoolean, TBoolean -> TBoolean
            | (BAnd | BOr), _, _ -> raise (TypeError "and/or requires booleans")
         )
      | EString _ -> TArray(None, TChar)
      | ECall (name, args) ->
         ( match lookup table name with
            | None -> raise (TypeError ("undefined function: " ^ name))
            | Some (SVar _) -> raise (TypeError (name ^ " is not a function"))
            | Some (SFunc (_, ret)) ->
               ( match ret with
                  | Some t -> t
                  | None -> raise (TypeError (name^ " is a procedure, has no value"))
               )
         ) 
      | EUnop (op, e) ->
         let t = check_expr table return_type e in
         ( match op, t with
            | (UPlus | UMinus), TInteger -> TInteger
            | (UPlus | UMinus), TReal -> TReal
            | (UPlus | UMinus), _ -> raise (TypeError "unary +/- requires numeric")
            | UNot, TBoolean -> TBoolean
            | UNot, _ -> raise (TypeError "not requires boolean")
            | UDeref, TPointer t -> t
            | UDeref, _ -> raise (TypeError "deref requires pointer")
            | UAddrOf, t -> TPointer t
         )
      | EIndex(arr, idx) ->
         let t_arr = check_expr table return_type arr in
         let t_idx = check_expr table return_type idx in
         ( match t_arr, t_idx with
         | TArray(_, elem_type), TInteger -> elem_type
         | TArray(_, _), _ -> raise (TypeError "array index must be integer")
         | _, _ -> raise (TypeError "cannot index a non-array")
         )
         
     
