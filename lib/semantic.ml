(* =========================================================
   semantic.ml  –  Type checker / semantic analysis for PCL
   Filled in during Phase 3.
   ========================================================= *)
open Ast
open Symbol

exception TypeError of string

(* 
-----------------
helper functions 
-----------------
*)

let rec add_names table names typ =
   match names with
   | [] -> table
   | name :: rest ->
      let updated_table = add_symbol table name (SVar typ) in
      add_names updated_table rest typ

let rec add_groups table groups =
   match groups with
   | [] -> table
   | (names, typ) :: rest ->
      let updated_table = add_names table names typ in
      add_groups updated_table rest

let symbol_from_header header =
   match header with
   | HProcedure (name, formals) ->
      (name, SFunc (formals, None))
   | HFunction (name, formals, return_type) ->
      (name, SFunc (formals, Some return_type))

let rec add_formals table formals =
   match formals with
   | [] -> table
   | (_mode, names, typ) :: rest ->
      let updated_table = add_names table names typ in
      add_formals updated_table rest


(* expand formals makes the list vertical , one entry for each parameter *)
let rec expand_formals formals =
   match formals with 
   | [] -> []
   | (mode, names, typ) :: rest ->
      let current =
         List.map (fun name -> (name, mode, typ)) names
      in
      current @ expand_formals rest

(* 
----------------------
helper functions ended
----------------------
*)

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

         (* logical *)
            | (BAnd | BOr), TBoolean, TBoolean -> TBoolean
            | (BAnd | BOr), _, _ -> raise (TypeError "and/or requires booleans")
         )
      | EString _ -> TArray(None, TChar)
      | ECall (name, args) ->
         ( match lookup table name with
            | None -> raise (TypeError ("undefined function: " ^ name))
            | Some (SVar _) -> raise (TypeError (name ^ " is not a function"))
            | Some (SFunc (formals, ret)) ->
               check_arguments table return_type formals args;
               
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

and check_arguments table return_type formals args =
   let expected = expand_formals formals in

   let rec compare expected actual =
      match expected, actual with
      | [], [] -> ()
      | [], _ :: _ ->
         raise (TypeError "too many arguments")
      | _ :: _, [] ->
         raise (TypeError "not enough arguments")
      | (parameter_name, _mode, expected_type) :: expected_rest,
      argument :: argument_rest ->

         let actual_type =
            check_expr table return_type argument
         in

         if actual_type = expected_type then
            compare expected_rest argument_rest
         else
            raise (TypeError ("wrong type for argument " ^parameter_name))
      
   in
   compare expected args

and check_stmt table return_type stmt =
   match stmt with
   | SEmpty -> ()

   (* Type x = Type of the assigned value *)
   | SAssign (left, right) ->
      let t_left = check_expr table return_type left in
      let t_right = check_expr table return_type right in
      if t_left = t_right then ()
      else raise (TypeError "assignement type missmatch")

   | SBlock stmts ->
      (* .iter means run this function on every element of the list *)
      List.iter (check_stmt table return_type) stmts

   | SIf (cond, then_stmt, else_stmt) ->
      let t_cond = check_expr table return_type cond in
      if t_cond <> TBoolean then
         raise (TypeError "if condition must be boolean")
      else
         check_stmt table return_type then_stmt;
      (match else_stmt with
      | None -> ()
      | Some stmt -> check_stmt table return_type stmt) 

   | SWhile (cond, body) ->
      let t_cond = check_expr table return_type cond in
      if t_cond <> TBoolean then
         raise (TypeError "while condition must be boolean")
      else 
         check_stmt table return_type body
      
   | SCall (name, _args) ->
      (match lookup table name with
      | None -> raise(TypeError ("undefined procedure: " ^ name))
      | Some (SVar _) -> raise (TypeError (name ^ " is not a procedure"))
      | Some (SFunc _) -> ())
   
   | SReturn -> ()
   
   | SLabel (_name, stmt) ->
      check_stmt table return_type stmt
   
   | SGoto _ -> ()

   | SNew e ->
      let t = check_expr table return_type e in
      (match t with 
      | TPointer _ -> ()
      | _ -> raise(TypeError "new requires pointer"))
   
   | SNewArray (size, arr) ->
      let t_size = check_expr table return_type size in
      let t_arr = check_expr table return_type arr in
      (match t_size, t_arr with
      | TInteger, TPointer (TArray _) -> ()
      | TInteger, _ -> raise(TypeError "new array requires pointer to array")
      | _, _ -> raise (TypeError "new array size must be integer"))
   
   | SDispose e ->
      let t = check_expr table return_type e in
      (match t with
      | TPointer _ -> ()
      | _ -> raise (TypeError "dispose requires pointer"))

   | SDisposeArray arr ->
      let t = check_expr table return_type arr in
      (match t with
      | TPointer (TArray _) -> ()
      | _ -> raise(TypeError "dispose array requires pointer to array"))

and check_local table local =
   match local with
   | LVar groups ->
      add_groups table groups
   | LLabel _names ->
      table
   | LForward header ->
      let name, info = symbol_from_header header in
      add_symbol table name info
   | LDef (header, body) ->
      let name, info = symbol_from_header header in
      let table_with_definition = add_symbol table name info in

      let formals, function_return_type = 
      match header with
      | HProcedure (_, formals) ->
         (formals, None)
      | HFunction (_, formals, typ) ->
         (formals, Some typ)
      
      in

      let inner_table = enter_scope table_with_definition in
      let inner_table = add_formals inner_table formals in

      check_body inner_table function_return_type body;
      table_with_definition
   
and check_body table return_type body =
   let table_with_locals =
      List.fold_left check_local table body.locals
   in
   List.iter(check_stmt table_with_locals return_type)
   body.block
