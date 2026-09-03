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


(* lvalue or byref ?*)
let rec is_lvalue expr =
   match expr with
   | EId _ -> true
   | EResult -> true
   | EString _ -> true
   | EIndex (arr, _) -> is_lvalue arr
   | EUnop (UDeref, _) -> true
   | _ -> false


let rec is_complete_type typ =
   match typ with
   | TInteger
   | TReal
   | TBoolean
   | TChar -> true

   | TArray (Some size, element_type) ->
      size > 0 && is_complete_type element_type
   
   | TArray (None, _) -> false

   | TPointer _ -> true
   | TNil -> false


let is_assignment_compatible destination_type source_type =
   match destination_type, source_type with
   | TReal, TInteger -> true
   | TPointer (TArray(None, destination_element)), TPointer (TArray (Some _, source_element)) -> 
      destination_element = source_element
   
   | TPointer _, TNil -> true
   | _ ->
      destination_type = source_type && is_complete_type destination_type


let is_numeric = function
      | TInteger
      | TReal -> true
      | _ -> false


let add_predefined table =
   List.fold_left
      (fun current_table header ->
         let name, info = symbol_from_header header in
         add_symbol current_table name info)
      table
      Pcl_library.predefined_headers

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
      | ENil -> TNil
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
         (* Arithmetic - same type in , same type out
            not always, this is true only for integers *)
            | (BPlus | BMinus | BTimes), TInteger, TInteger -> TInteger
            | (BPlus | BMinus | BTimes), t1, t2 when is_numeric t1 && is_numeric t2 ->
               TReal
            | (BPlus | BMinus | BTimes), _ , _ -> raise (TypeError "+, - and * require numeric operands")

         (* integer only: 5 div 2 *)
            | (BDiv | BMod) , TInteger, TInteger -> TInteger
            | (BDiv | BMod) , _, _ -> raise (TypeError " div/mod requires integers")
         
         (* real division (can be int also): 5 / 2 *)
            | BFDiv, t1, t2 when is_numeric t1 && is_numeric t2 ->
               TReal
            | BFDiv, _, _ -> raise (TypeError "/ requires numeric operands")

         (* comparisons - any matching type, returns bool *)
            (* equality between numeric types, including mixed int/real *)
            | (BEq | BNe), t1, t2 when is_numeric t1 && is_numeric t2 ->
               TBoolean
            (* pointer compared with nil accepted *)
            | (BEq | BNe), TPointer _, TNil
            | (BEq | BNe), TNil, TPointer _ ->
                  TBoolean
            (* equal non-array types *)
            | (BEq | BNe), t1, t2 when t1 = t2 ->
               (match t1 with
               | TArray _ -> raise (TypeError "arrays cannot be compared")
               | _ -> TBoolean)
            | (BEq | BNe), _, _ ->
               raise (TypeError "invalid types for equality comparison")
            (* ordering available for numeric operands *)
            | (BLt | BGt | BLe | BGe), t1, t2 when is_numeric t1 && is_numeric t2 ->
               TBoolean
            | (BLt | BGt | BLe | BGe), _, _ ->
               raise(TypeError "ordering comparison requires numeric operands")

         (* logical *)
            | (BAnd | BOr), TBoolean, TBoolean -> TBoolean
            | (BAnd | BOr), _, _ -> raise (TypeError "and/or requires booleans")
         )

      (* string literals = fixed arrays
      length = #Chars + \0 *)
      | EString value -> TArray(Some (String.length value + 1), TChar)

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
            | UAddrOf, t -> 
               if not (is_lvalue e) then
                  raise (TypeError "address-of requires an lvalue");
               
               TPointer t
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
      | (parameter_name, mode, expected_type) :: expected_rest,
      argument :: argument_rest ->

         let actual_type =
            check_expr table return_type argument
         in

         if mode = ByRef && not (is_lvalue argument) then
            raise(TypeError ("argument " ^parameter_name ^" must be an lvalue"));
         
         let types_compatible = match mode with
         | ByValue -> is_assignment_compatible expected_type actual_type
         | ByRef -> is_assignment_compatible 
         (TPointer expected_type)
         (TPointer actual_type)
         in

         if types_compatible then
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
      (* safeguard for proper assignment *)
      if not (is_lvalue left) then
         raise(TypeError "assignment destination must be an lvalue");
      let t_left = check_expr table return_type left in
      let t_right = check_expr table return_type right in
      
      if is_assignment_compatible t_left t_right then ()
      else raise (TypeError "assignment type missmatch")

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
      
   | SCall (name, args) ->
      (match lookup table name with
      | None -> raise(TypeError ("undefined procedure: " ^ name))
      | Some (SVar _) -> raise (TypeError (name ^ " is not a procedure"))
      | Some (SFunc (formals, ret)) -> (
         match ret with
         | Some _ ->
            raise (TypeError (name ^" is a function, not a procedure"))
         | None ->
            check_arguments table return_type formals args;
            ())
      )
   
   | SReturn -> ()
   
   | SLabel (_name, stmt) ->
      check_stmt table return_type stmt
   
   | SGoto _ -> ()

   | SNew e ->
      if not (is_lvalue e) then
         raise (TypeError "new requires an lvalue");
      
      let t = check_expr table return_type e in
      (match t with
      | TPointer target_type when is_complete_type
      target_type -> ()

      | TPointer _ -> raise (TypeError "new requires pointer to complete type")
      | _ -> raise(TypeError "new requires pointer"))
   
   | SNewArray (size, arr) ->
      if not (is_lvalue arr) then
         raise(TypeError "new array requires an lvalue");

      let t_size = check_expr table return_type size in
      let t_arr = check_expr table return_type arr in
      (match t_size, t_arr with
      | TInteger, TPointer (TArray (None, _)) -> ()
      | TInteger, _ -> raise(TypeError "new array requires pointer to open array")
      | _, _ -> raise (TypeError "new array size must be integer"))
   
   | SDispose e ->
      if not (is_lvalue e) then
         raise (TypeError "dispose requires an lvalue");
      
      let t = check_expr table return_type e in
      (match t with
      | TPointer target_type when is_complete_type target_type -> ()
      | TPointer _ -> raise (TypeError "dispose requires pointer to complete type")
      | _ -> raise (TypeError "dispose requires pointer"))

   | SDisposeArray arr ->
      if not (is_lvalue arr) then
         raise (TypeError "dispose array requires an lvalue");

      let t = check_expr table return_type arr in
      (match t with
      | TPointer (TArray (None, _)) -> ()
      | _ -> raise(TypeError "dispose array requires pointer to open array"))

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



(* entry point *)
let check_program program =
   let builtins_table =
      add_predefined (enter_scope empty_table)
   in
   let program_table = enter_scope builtins_table in
   check_body program_table None program.body