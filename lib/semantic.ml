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

let make_typed_expr node pcl_type category = {
   Typed_ast.node = node;
   pcl_type;
   category;
}


type local_declaration =
   | DeclaredVariable
   | ForwardHeader of header
   | DefinedHeader of header


let promote_to_real expression =
   match expression.Typed_ast.pcl_type with
   | TInteger -> make_typed_expr (Typed_ast.TEIntToReal expression)
                  TReal
                  Typed_ast.RValue
   | _ -> expression


let rec add_names table names typ =
   match names with
   | [] -> table
   | name :: rest ->
      let already_declared =
         match table with
         | scope :: _ -> List.mem_assoc name scope
         | [] -> false
      in
      if already_declared then
         raise (TypeError ("duplicate declaration: " ^ name));

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


let header_name = function
   | HProcedure (name, _) -> name
   | HFunction (name, _, _) -> name


let validate_local_declarations locals =
   let add_new declarations name declaration =
      match List.assoc_opt name declarations with
      | None -> (name, declaration) :: declarations
      | Some _ -> raise (TypeError ("duplicate declaration: " ^ name))
   in

   let validate_local declarations = function
      | LVar groups ->
         List.fold_left
            (fun current (names, _) ->
               List.fold_left
                  (fun current name ->
                     add_new current name DeclaredVariable)
                  current
                  names)
            declarations
            groups

      | LForward header ->
         add_new
            declarations
            (header_name header)
            (ForwardHeader header)

      | LDef (header, _) ->
         let name = header_name header in
         (match List.assoc_opt name declarations with
         | None ->
            (name, DefinedHeader header) :: declarations

         | Some (ForwardHeader forward_header) ->
            if forward_header <> header then
               raise
                  (TypeError
                     ("definition does not match forward declaration: " ^ name));

            (name, DefinedHeader header)
            :: List.remove_assoc name declarations

         | Some DeclaredVariable
         | Some (DefinedHeader _) ->
            raise (TypeError ("duplicate declaration: " ^ name)))

      | LLabel _ ->
         declarations
   in

   ignore (List.fold_left validate_local [] locals)


let validate_labels locals statements =
   let declared =
      List.fold_left
         (fun names local ->
            match local with
            | LLabel label_names ->
               List.fold_left
                  (fun current name ->
                     if List.mem name current then
                        raise
                           (TypeError
                              ("duplicate label declaration: " ^ name));
                     name :: current)
                  names
                  label_names
            | _ -> names)
         []
         locals
   in

   let ensure_declared name =
      if not (List.mem name declared) then
         raise (TypeError ("undeclared label: " ^ name))
   in

   let defined = ref [] in
   let referenced = ref [] in

   let rec validate_stmt = function
      | SLabel (name, statement) ->
         ensure_declared name;
         if List.mem name !defined then
            raise (TypeError ("label defined more than once: " ^ name));
         defined := name :: !defined;
         validate_stmt statement

      | SGoto name ->
         ensure_declared name;
         referenced := name :: !referenced

      | SBlock statements ->
         List.iter validate_stmt statements

      | SIf (_, then_statement, else_statement) ->
         validate_stmt then_statement;
         Option.iter validate_stmt else_statement

      | SWhile (_, statement) ->
         validate_stmt statement

      | SEmpty
      | SAssign _
      | SCall _
      | SReturn
      | SNew _
      | SNewArray _
      | SDispose _
      | SDisposeArray _ ->
         ()
   in

   List.iter validate_stmt statements;
   List.iter
      (fun name ->
         if not (List.mem name !defined) then
            raise (TypeError ("goto target is not defined: " ^ name)))
      !referenced


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

let rec analyze_expr table return_type expr = 
   match expr with 
      | EInt value -> 
         make_typed_expr (Typed_ast.TEInt value)
         TInteger
         Typed_ast.RValue
      
      | EReal value -> 
         make_typed_expr (Typed_ast.TEReal value)
         TReal
         Typed_ast.RValue

      | EBool value -> 
         make_typed_expr (Typed_ast.TEBool value)
         TBoolean
         Typed_ast.RValue

      | EChar value -> 
         make_typed_expr (Typed_ast.TEChar value)
         TChar
         Typed_ast.RValue

      | ENil -> 
         make_typed_expr
            Typed_ast.TENil
            TNil
            Typed_ast.RValue

      | EId name ->
         ( match lookup table name with
            | None -> raise (TypeError ("undefined variable : " ^ name))
            | Some (SVar typ) -> 
               make_typed_expr (Typed_ast.TEId name)
               typ
               Typed_ast.LValue

            | Some (SFunc _) -> raise (TypeError (name ^ " is a function , not a variable "))
         )

      | EResult -> 
         ( match return_type with
            | Some typ -> 
               make_typed_expr
               Typed_ast.TEResult
               typ
               Typed_ast.LValue

            | None -> raise (TypeError "result used outside a function")
         )

      | EBinop (op, left, right) -> 
         let typed_left = analyze_expr table return_type left 
         in
         let typed_right = analyze_expr table return_type right
         in
         let left_type = 
            typed_left.Typed_ast.pcl_type 
         in
         let right_type =
            typed_right.Typed_ast.pcl_type
         in
         let make_result left right result_type =
            make_typed_expr(Typed_ast.TEBinop (op, left, right))
            result_type
            Typed_ast.RValue
         in
         let promote_numeric_pair () =
            match left_type, right_type with
            | TInteger, TInteger ->
               typed_left,
               typed_right
            | _ ->
               promote_to_real typed_left,
               promote_to_real typed_right
         in

         ( match op , left_type, right_type with
         (* Arithmetic - same type in , same type out
            not always, this is true only for integers *)
            | (BPlus | BMinus | BTimes), TInteger, TInteger -> 
               make_result typed_left typed_right TInteger

            | (BPlus | BMinus | BTimes), t1, t2 when is_numeric t1 && is_numeric t2 ->
               make_result (promote_to_real typed_left) (promote_to_real typed_right) TReal

            | (BPlus | BMinus | BTimes), _ , _ -> raise (TypeError "+, - and * require numeric operands")


         (* integer only: 5 div 2 *)
            | (BDiv | BMod) , TInteger, TInteger ->
               make_result typed_left typed_right TInteger

            | (BDiv | BMod) , _, _ -> raise (TypeError " div/mod requires integers")
         

         (* real division (can be int also): 5 / 2 *)
            | BFDiv, t1, t2 when is_numeric t1 && is_numeric t2 ->
               make_result (promote_to_real typed_left) (promote_to_real typed_right) TReal

            | BFDiv, _, _ -> raise (TypeError "/ requires numeric operands")


         (* comparisons - any matching type, returns bool *)
            (* equality between numeric types, including mixed int/real *)
            | (BEq | BNe), t1, t2 when is_numeric t1 && is_numeric t2 ->
               let promoted_left, promoted_right = promote_numeric_pair()
               in
               make_result promoted_left promoted_right TBoolean

            (* pointer compared with nil accepted *)
            | (BEq | BNe), TPointer _, TNil
            | (BEq | BNe), TNil, TPointer _ ->
                  make_result typed_left typed_right TBoolean
            
            (* equal non-array types *)
            | (BEq | BNe), t1, t2 when t1 = t2 ->
               (match t1 with
               | TArray _ -> raise (TypeError "arrays cannot be compared")
               | _ -> make_result typed_left typed_right TBoolean)

            | (BEq | BNe), _, _ ->
               raise (TypeError "invalid types for equality comparison")


            (* ordering available for numeric operands *)
            | (BLt | BGt | BLe | BGe), t1, t2 when is_numeric t1 && is_numeric t2 ->
               let promoted_left, promoted_right = promote_numeric_pair () 
               in make_result promoted_left promoted_right TBoolean

            | (BLt | BGt | BLe | BGe), _, _ ->
               raise(TypeError "ordering comparison requires numeric operands")

         (* logical *)
            | (BAnd | BOr), TBoolean, TBoolean -> 
               make_result typed_left typed_right TBoolean
            | (BAnd | BOr), _, _ -> raise (TypeError "and/or requires booleans")
         )

      (* string literals = fixed arrays
      length = #Chars + \0 *)
      | EString value -> 
         make_typed_expr(Typed_ast.TEString value)
         (TArray(Some (String.length value + 1), TChar))
         Typed_ast.LValue

      | ECall (name, args) ->
         ( match lookup table name with
            | None -> raise (TypeError ("undefined function: " ^ name))

            | Some (SVar _) -> raise (TypeError (name ^ " is not a function"))

            | Some (SFunc (formals, callee_return_type)) ->
               let typed_args = analyze_arguments table return_type formals args
               in
               ( match callee_return_type with
                  | Some result_type -> 
                     make_typed_expr (Typed_ast.TECall (name, typed_args)) 
                     result_type
                     Typed_ast.RValue

                  | None -> raise (TypeError (name^ " is a procedure, has no value"))
               )
         ) 
      | EUnop (op, expression) ->
         let typed_expression = analyze_expr table return_type expression 
         in
         let operand_type = typed_expression.Typed_ast.pcl_type
         in
         let make_result result_type category =
            make_typed_expr(Typed_ast.TEUnop(op, typed_expression))
            result_type
            category
         in
         (match op, operand_type with
            | (UPlus | UMinus), TInteger -> 
               make_result 
               TInteger
               Typed_ast.RValue
            
            | (UPlus | UMinus), TReal -> 
               make_result
               TReal
               Typed_ast.RValue

            | (UPlus | UMinus), _ -> raise (TypeError "unary +/- requires numeric")

            | UNot, TBoolean -> 
               make_result
               TBoolean
               Typed_ast.RValue

            | UNot, _ -> raise (TypeError "not requires boolean")

            | UDeref, TPointer target_type -> 
               make_result
               target_type
               Typed_ast.LValue

            | UDeref, _ -> raise (TypeError "deref requires pointer operand")

            | UAddrOf, target_type -> 
               if typed_expression.Typed_ast.category <> Typed_ast.LValue then
                  raise (TypeError "address-of requires an lvalue");
               
               make_result (TPointer target_type) Typed_ast.RValue
         )

      | EIndex(array_expression, index_expression) ->
         let typed_array = 
            analyze_expr table return_type array_expression 
         in
         let typed_index = analyze_expr table return_type index_expression 
         in
         let array_type =
            typed_array.Typed_ast.pcl_type
         in
         let index_type =
            typed_index.Typed_ast.pcl_type
         in

         ( match array_type, index_type with
         | TArray(_, element_type), TInteger -> 
            if typed_array.Typed_ast.category <> Typed_ast.LValue then 
               raise (TypeError "array indexing requires an lvalue array");
            
            make_typed_expr(Typed_ast.TEIndex(typed_array, typed_index))
            element_type
            Typed_ast.LValue

         | TArray(_, _), _ -> raise (TypeError "array index must be integer")

         | _, _ -> raise (TypeError "cannot index a non-array"))


and analyze_arguments table return_type formals args =
   let expected = expand_formals formals 
   in

   let rec compare expected actual =
      match expected, actual with
      | [], [] -> []

      | [], _ :: _ ->
         raise (TypeError "too many arguments")

      | _ :: _, [] ->
         raise (TypeError "not enough arguments")

      | (parameter_name, mode, expected_type) :: expected_rest,
      argument :: argument_rest ->

         let typed_argument = analyze_expr table return_type argument
         in

         let actual_type =
            typed_argument.Typed_ast.pcl_type
         in

         if mode = ByRef && typed_argument.Typed_ast.category <> Typed_ast.LValue then
            raise(TypeError ("argument " ^parameter_name ^" must be an lvalue"));
         
         let types_compatible = match mode with
         | ByValue -> is_assignment_compatible expected_type actual_type

         | ByRef -> is_assignment_compatible 
         (TPointer expected_type)
         (TPointer actual_type)
         in

         if not types_compatible then
            raise (TypeError ("wrong type for argument " ^parameter_name));

         let converted_argument = 
            match mode, expected_type, actual_type with
            | ByValue, TReal, TInteger ->
               promote_to_real typed_argument
            
            | _ -> typed_argument 
            in
            let typed_rest = compare expected_rest argument_rest
            in 
            converted_argument :: typed_rest

   in
   compare expected args

and analyze_stmt table return_type inside_subprogram stmt =
   match stmt with
   | SEmpty -> 
      Typed_ast.TSEmpty

   (* Type x = Type of the assigned value *)
   | SAssign (left, right) ->
      let typed_left = analyze_expr table return_type left
      in
      let typed_right = analyze_expr table return_type right
      in
      (* safeguard for proper assignment *)
      if typed_left.Typed_ast.category <> Typed_ast.LValue then
         raise(TypeError "assignment destination must be an lvalue");

      let left_type = typed_left.Typed_ast.pcl_type
      in
      let right_type = typed_right.Typed_ast.pcl_type
      in
      
      if not (is_assignment_compatible left_type right_type) then 
         raise(TypeError "assignment type mismatch");
      
      let converted_right =
         match left_type, right_type with
         | TReal, TInteger ->
            promote_to_real typed_right
         
         | _ -> typed_right
      in
      Typed_ast.TSAssign(typed_left, converted_right)

   | SBlock statements ->
      let typed_statements =
         List.map(
            (analyze_stmt table return_type inside_subprogram)) statements
      in
      Typed_ast.TSBlock 
   typed_statements


   | SIf (condition, then_statement, else_statement) ->
      let typed_condition = analyze_expr table return_type condition
      in
      if typed_condition.Typed_ast.pcl_type <> TBoolean then
         raise (TypeError "if condition must be boolean");

      let typed_then =
         analyze_stmt table return_type inside_subprogram then_statement
      in
      let typed_else =
         match else_statement with
         | None -> None
      
         | Some statement -> 
            Some(analyze_stmt table return_type inside_subprogram statement)
      in
      Typed_ast.TSIf(typed_condition, typed_then, typed_else)


   | SWhile (condition, body) ->
      let typed_condition = analyze_expr table return_type condition
      in
      if typed_condition.Typed_ast.pcl_type <> TBoolean then
         raise (TypeError "while condition must be boolean");
      
      let typed_body =
         analyze_stmt table return_type inside_subprogram body
      in
      Typed_ast.TSWhile(typed_condition, typed_body)

      
   | SCall (name, args) ->
      (match lookup table name with
      | None -> raise(TypeError ("undefined procedure: " ^ name))

      | Some (SVar _) -> raise (TypeError (name ^ " is not a procedure"))

      | Some (SFunc (_, Some _)) -> 
         raise (TypeError(name ^ " is a function, not a procedure"))
         
      | Some (SFunc (formals, None)) ->
         let typed_args = analyze_arguments table return_type formals args
         in
         Typed_ast.TSCall(name, typed_args))

   
   | SReturn ->
      if not inside_subprogram then
         raise (TypeError "return used outside a subprogram");
      Typed_ast.TSReturn
   

   | SLabel (name, statement) ->
      let typed_statement =
         analyze_stmt table return_type inside_subprogram statement
      in
      Typed_ast.TSLabel(name, typed_statement)

      
   | SGoto name -> 
      Typed_ast.TSGoto name
      

   | SNew expression ->
      let typed_expression = analyze_expr table return_type expression 
      in
      if typed_expression.Typed_ast.category <> Typed_ast.LValue then
         raise(TypeError "new requires an lvalue");

      (match typed_expression.Typed_ast.pcl_type with
      | TPointer target_type when is_complete_type
      target_type ->
         Typed_ast.TSNew typed_expression

      | TPointer _ -> raise (TypeError "new requires pointer to complete type")

      | _ -> raise(TypeError "new requires pointer"))
   

   | SNewArray (size, array_expression) ->
   
      let typed_size = analyze_expr table return_type size 
      in
      let typed_array = analyze_expr table return_type array_expression 
      in
      if typed_array.Typed_ast.category <> Typed_ast.LValue then
         raise(TypeError "new array requires an lvalue");

      (match typed_size.Typed_ast.pcl_type, typed_array.Typed_ast.pcl_type with
      | TInteger, TPointer (TArray (None, _)) -> 
         Typed_ast.TSNewArray(typed_size, typed_array)
      
      | TInteger, _ -> raise(TypeError "new array requires pointer to open array")

      | _, _ -> raise (TypeError "new array size must be integer"))
   

   | SDispose expression ->
      let typed_expression =
         analyze_expr table return_type expression
      in

      if typed_expression.Typed_ast.category <> Typed_ast.LValue then
         raise (TypeError "dispose requires an lvalue");
      
      (match typed_expression.Typed_ast.pcl_type with
      | TPointer target_type when is_complete_type target_type -> 
         Typed_ast.TSDispose typed_expression

      | TPointer _ -> raise (TypeError "dispose requires pointer to complete type")

      | _ -> raise (TypeError "dispose requires pointer"))

   | SDisposeArray array_expression ->
      let typed_array = analyze_expr table return_type array_expression
      in
      if typed_array.Typed_ast.category <> Typed_ast.LValue then
         raise (TypeError "dispose array requires an lvalue");

      (match typed_array.Typed_ast.pcl_type with
      | TPointer (TArray (None, _)) -> 
         Typed_ast.TSDisposeArray typed_array

      | _ -> raise(TypeError "dispose array requires pointer to open array"))


and analyze_local table local =
   match local with
   | LVar groups ->
      let updated_table = add_groups table groups
      in
      updated_table, Typed_ast.TLVar groups

   | LLabel names ->
      table, Typed_ast.TLLabel names
   
   | LForward header ->
      let name, info = symbol_from_header header 
      in
      let updated_table = add_symbol table name info 
      in 
      updated_table, Typed_ast.TLForward header

   | LDef (header, body) ->
      let name, info = symbol_from_header header 
      in
      let table_with_definition = add_symbol table name info 
      in

      let formals, function_return_type = 
      match header with
      | HProcedure (_, formals) ->
         formals, None

      | HFunction (_, formals, typ) ->
         formals, Some typ
      
      in

      let inner_table = enter_scope table_with_definition 
      in
      let inner_table = add_formals inner_table formals 
      in

      let typed_body =
         analyze_body inner_table function_return_type true body
      in

      table_with_definition, Typed_ast.TLDef(header, typed_body)

   
and analyze_body table return_type inside_subprogram body =
   validate_local_declarations body.locals;
   validate_labels body.locals body.block;

   let table_with_locals, reversed_typed_locals =
      List.fold_left (fun(current_table, typed_locals) local ->
         let updated_table, typed_local = 
         analyze_local current_table local
         in
         updated_table, typed_local :: typed_locals) 
         (table, []) 
         body.locals
   in
   let typed_block = 
      List.map
         (analyze_stmt
            table_with_locals
            return_type
            inside_subprogram)
      body.block
   in

   {
      Typed_ast.locals = List.rev 
      reversed_typed_locals; 
      block = typed_block;
   }



(* entry point *)
let analyze_program program =
   let builtins_table =
      add_predefined (enter_scope empty_table)
   in
   let program_table = enter_scope builtins_table 
   in
   let typed_body = analyze_body program_table None false program.body
   in
   {
      Typed_ast.name = program.name;
      body = typed_body;
   }
