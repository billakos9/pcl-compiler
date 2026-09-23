(* =========================================================
   codegen.ml  –  Code generation for PCL (LLVM IR)
   AST -> LLVM text
   ========================================================= *)

open Ast
open Typed_ast


exception CodegenError of string


(* context *)
type variable_storage = {
   address: string;
   stored_type : typ;
}


type subprogram_info = {
   llvm_name : string;
   header : Ast.header;
   parent_depth : int;
}


type module_context = {
   globals : Buffer.t;
   functions : Buffer.t;
   mutable next_string_id : int;
   mutable next_subprogram_id : int;
}


type generation_context = {
   module_context : module_context;
   instructions : Buffer.t;
   mutable next_temp_id : int;
   mutable variables : (string * variable_storage) list;
   mutable next_label_id : int;
   mutable current_block : string;
   mutable subprograms : (string * subprogram_info) list;
   lexical_depth : int;
}


let create_module_context () =
   {
      globals = Buffer.create 256;
      functions = Buffer.create 256;
      next_string_id = 0;
      next_subprogram_id = 0;
   }


let create_generation_context module_context lexical_depth =
   {
      module_context;
      instructions = Buffer.create 256;
      next_temp_id = 0;
      variables = [];
      next_label_id = 0;
      current_block = "entry";
      subprograms = [];
      lexical_depth;
   }


let fresh_string_id context =
   let id = context.module_context.next_string_id in
   context.module_context.next_string_id <- id + 1;
   id


let fresh_temp context =
   let id = context.next_temp_id in
   context.next_temp_id <- id +1;
   Printf.sprintf "%%tmp%d" id


let fresh_label context prefix =
   let id = context.next_label_id in
   context.next_label_id <- id + 1;
   Printf.sprintf "%s%d" prefix id


let fresh_subprogram_name module_context source_name =
   let id = module_context.next_subprogram_id in
   module_context.next_subprogram_id <- id + 1;
   Printf.sprintf "pcl_%s_%d" source_name id


let name_of_header = function
   | HProcedure (name, _) ->
      name

   | HFunction (name, _, _) ->
      name


let formals_of_header = function
   | HProcedure (_, formals) ->
      formals

   | HFunction (_, formals, _) ->
      formals


let return_type_of_header = function
   | HProcedure _ ->
      None

   | HFunction (_, _, return_type) ->
      Some return_type


let rec flatten_formals formals =
   match formals with
   | [] ->
      []

   | (mode, names, parameter_type) :: rest ->
      let current_parameters =
         List.map
            (fun name -> (name, mode, parameter_type))
            names
      in
      current_parameters @ flatten_formals rest


let register_subprogram context header =
   let source_name =
      name_of_header header
   in

   match List.assoc_opt source_name context.subprograms with
   | Some info
     when info.parent_depth = context.lexical_depth ->
      info

   | _ ->
      let info =
         {
            llvm_name =
               fresh_subprogram_name
                  context.module_context
                  source_name;
            header;
            parent_depth = context.lexical_depth;
         }
      in

      context.subprograms <-
         (source_name, info) :: context.subprograms;

      info


let register_local_subprogram context = function
   | TLForward header ->
      ignore (register_subprogram context header)

   | TLDef (header, _) ->
      ignore (register_subprogram context header)

   | TLVar _
   | TLLabel _ ->
      ()


let lookup_subprogram context name =
   match List.assoc_opt name context.subprograms with
   | Some info ->
      info

   | None ->
      raise
         (CodegenError
            ("unknown subprogram during code generation: " ^ name))


let lookup_variable context name =
   match List.assoc_opt name context.variables with
   | Some storage -> storage

   | None ->
      raise(CodegenError ("unknown variable during code generation: " ^ name))


(* Helper functions *)
type generated_value = {
   pcl_type: typ;
   operand: string;
}


let rec llvm_type = function
   | TInteger -> "i64"
   | TReal -> "double"
   | TBoolean -> "i1"
   | TChar -> "i8"
   | TPointer _ -> "ptr"
   | TArray (Some size, element_type) ->
      Printf.sprintf "[%d x %s]" size(llvm_type element_type)
   | TArray(None, _) ->
      "ptr"
   | TNil -> "ptr"


let llvm_parameter_type mode parameter_type =
   match mode with
   | ByValue ->
      llvm_type parameter_type

   | ByRef ->
      "ptr"


let llvm_return_type header =
   match return_type_of_header header with
   | None ->
      "void"

   | Some return_type ->
      llvm_type return_type


let llvm_argument_name index =
   Printf.sprintf "%%arg%d" index


let llvm_explicit_parameter_list header =
   let formals =
      flatten_formals (formals_of_header header)
   in

   let declarations =
      List.mapi
         (fun index (_, mode, parameter_type) ->
            Printf.sprintf
               "%s %s"
               (llvm_parameter_type mode parameter_type)
               (llvm_argument_name index))
         formals
   in

   String.concat ", " declarations


let emit_line buffer line =
   Buffer.add_string buffer line;
   Buffer.add_char buffer '\n'


let emit_label context label =
   emit_line context.instructions (label ^ ":");
   context.current_block <- label


let declare_variable context name variable_type =
   let address = fresh_temp context
   in
   let instruction =
      Printf.sprintf "%s = alloca %s" 
      address
      (llvm_type variable_type)
   in
   emit_line context.instructions instruction;

   let storage = {
      address;
      stored_type = variable_type; 
   }
   in
   context.variables <- (name, storage) :: context.variables


let llvm_escape_string value =
   let escaped = Buffer.create (String.length value + 1) in
   String.iter (fun character ->
      match character with
      | '"' ->
         Buffer.add_string escaped "\\22"
      
      | '\\' ->
         Buffer.add_string escaped "\\5C"
      
      | character ->
         let code = Char.code character in
         if code >= 32 && code <= 126 then
            Buffer.add_char escaped character
         else
            Printf.bprintf escaped "\\%02X" code)
      value;

   Buffer.add_string escaped "\\00";
   Buffer.contents escaped



let generate_string_constant context value =
   let id = fresh_string_id context in
   let global_name = Printf.sprintf ".str.%d" id in
   let length = String.length value + 1 in
   let escaped = llvm_escape_string value in

   let declaration = 
      Printf.sprintf "@%s = private unnamed_addr constant [%d x i8] c\"%s\""
      global_name length escaped in

      emit_line context.module_context.globals declaration;
      (global_name, length)



let arithmetic_opcode operator operand_type =
   match operator, operand_type with
   | BPlus, TInteger -> "add"
   | BMinus, TInteger -> "sub"
   | BTimes, TInteger -> "mul"
   | BDiv, TInteger -> "sdiv"
   | BMod, TInteger -> "srem"

   | BPlus, TReal -> "fadd"
   | BMinus, TReal -> "fsub"
   | BTimes, TReal -> "fmul"
   | BFDiv , TReal -> "fdiv"

   | _ ->
      raise (CodegenError "binary operator not supported by code generation yet")

   
let comparison_opcode operator operand_type =
   match operand_type with
   | TReal ->
      let predicate =
         match operator with
         | BEq -> "oeq"
         | BNe -> "une"
         | BLt -> "olt"
         | BGt -> "ogt"
         | BLe -> "ole"
         | BGe -> "oge"
         | _ ->
            raise
               (CodegenError "invalid real comparison")
      in
      "fcmp", predicate

   | TInteger ->
      let predicate =
         match operator with
         | BEq -> "eq"
         | BNe -> "ne"
         | BLt -> "slt"
         | BGt -> "sgt"
         | BLe -> "sle"
         | BGe -> "sge"
         | _ ->
            raise
               (CodegenError "invalid integer comparison")
      in
      "icmp", predicate

   | TBoolean
   | TChar
   | TPointer _
   | TNil ->
      let predicate =
         match operator with
         | BEq -> "eq"
         | BNe -> "ne"
         | _ ->
            raise
               (CodegenError
                  "this type supports only equality comparisons")
      in
      "icmp", predicate

   | TArray _ ->
      raise
         (CodegenError "arrays cannot be compared")


let generate_value_from_storage context value_type storage =
   match value_type with
   | TArray _ ->
      {
         pcl_type = value_type;
         operand = storage.address;
      }

   | _ ->
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = load %s, ptr %s"
            result
            (llvm_type value_type)
            storage.address);
      {
         pcl_type = value_type;
         operand = result;
      }


(* Helper functions end *)


(* Generation functions start *)
let rec generate_expr context (expression : Typed_ast.expr) =
   match expression.node with
   | TEInt value ->
      {
         pcl_type = expression.pcl_type;
         operand = string_of_int value;
      }
   
   | TEReal value ->
      {
         pcl_type = expression.pcl_type;
         operand = Printf.sprintf "%.17e" value;
      }

   | TEBool value ->
      {
         pcl_type = expression.pcl_type;
         operand = if value then "1" else "0";
      }

   | TEChar value ->
      {
         pcl_type = expression.pcl_type;
         operand = string_of_int (Char.code value);
      }

   | TENil ->
      {
         pcl_type = expression.pcl_type;
         operand = "null";
      }

   | TEString value ->
      let global_name, length =
      generate_string_constant context value
      in
      {
         pcl_type = expression.pcl_type;
         operand = Printf.sprintf 
         "getelementptr inbounds ([%d x i8], ptr @%s, i64 0, i64 0)"
         length global_name;
      }
   
   | TEUnop (UAddrOf, operand) ->
      let storage =
         generate_address context operand
      in
      {
         pcl_type = expression.pcl_type;
         operand = storage.address;
      }

   | TEUnop (UDeref, _) ->
      let storage =
         generate_address context expression
      in
      generate_value_from_storage context expression.pcl_type storage

   | TEUnop (operator, operand) ->
      let generated_operand =
         generate_expr context operand
      in
      (match operator, generated_operand.pcl_type with
      | UPlus, (TInteger | TReal) ->
         generated_operand
      
      | UMinus, TInteger ->
         let result =
            fresh_temp context 
         in
         let instruction =
            Printf.sprintf "%s = sub i64 0, %s" 
            result
            generated_operand.operand
         in
         emit_line context.instructions instruction;
         {
            pcl_type = expression.pcl_type;
            operand= result;
         }

      | UMinus, TReal ->
         let result =
            fresh_temp context 
         in
         let instruction =
            Printf.sprintf "%s = fneg double %s"
            result
            generated_operand.operand
         in
         emit_line context.instructions instruction;
         {
            pcl_type = expression.pcl_type;
            operand = result;
         }
      
      | UNot, TBoolean ->
         let result = 
            fresh_temp context
         in
         let instruction =
            Printf.sprintf "%s = xor i1 %s, 1"
            result
            generated_operand.operand
         in
         emit_line context.instructions instruction;
         {
            pcl_type = expression.pcl_type;
            operand = result;
         }

      | _ ->
         raise(CodegenError "unary operator not supported yet"))

   | TEBinop (BAnd, left, right) ->
      let generated_left =
         generate_expr context left
      in
      let left_block =
         context.current_block
      in
      let right_label =
         fresh_label context "and_right_"
      in
      let end_label =
         fresh_label context "and_end_"
      in
      emit_line context.instructions
         (Printf.sprintf
            "br i1 %s, label %%%s, label %%%s"
            generated_left.operand
            right_label
            end_label);

      emit_label context right_label;

      let generated_right = 
         generate_expr context right
      in
      let right_block =
         context.current_block
      in
      emit_line context.instructions
         (Printf.sprintf "br label %%%s" end_label);

      emit_label context end_label;
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = phi i1 [ 0, %%%s ], [ %s, %%%s ]"
            result
            left_block
            generated_right.operand
            right_block);

      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TEBinop (BOr, left, right) ->
      let generated_left =
         generate_expr context left
      in
      let left_block =
         context.current_block
      in
      let right_label =
         fresh_label context "or_right_"
      in
      let end_label =
         fresh_label context "or_end_"
      in
      emit_line context.instructions
         (Printf.sprintf
            "br i1 %s, label %%%s, label %%%s"
            generated_left.operand
            end_label
            right_label);

      emit_label context right_label;

      let generated_right =
         generate_expr context right
      in
      let right_block =
         context.current_block
      in
      emit_line context.instructions
         (Printf.sprintf "br label %%%s" end_label);

      emit_label context end_label;
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = phi i1 [ 1, %%%s ], [ %s, %%%s ]"
            result
            left_block
            generated_right.operand
            right_block);

      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TEBinop (operator, left, right) ->
      let generated_left =
         generate_expr context left
      in
      let generated_right =
         generate_expr context right
      in
      let result =
         fresh_temp context
      in

      let instruction =
         match operator with
         | BEq | BNe | BLt | BGt | BLe | BGe ->
            let comparison, predicate =
               comparison_opcode operator generated_left.pcl_type
            in
            Printf.sprintf
               "%s = %s %s %s %s, %s"
               result
               comparison
               predicate
               (llvm_type generated_left.pcl_type)
               generated_left.operand
               generated_right.operand
   
   | _ ->
      let opcode =
         arithmetic_opcode operator generated_left.pcl_type
      in
      Printf.sprintf
         "%s = %s %s %s, %s"
         result
         opcode
         (llvm_type generated_left.pcl_type)
         generated_left.operand
         generated_right.operand

      in
      emit_line context.instructions instruction;
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }
         
   | TEId name ->
      let storage =
         lookup_variable context name
      in
      generate_value_from_storage context expression.pcl_type storage

   | TEIndex _ ->
      let storage =
         generate_address context expression
      in
      generate_value_from_storage context expression.pcl_type storage

   | TEIntToReal operand ->
      let generated_operand =
         generate_expr context operand 
         in
         let result = fresh_temp context 
         in 
         let instruction =
            Printf.sprintf "%s = sitofp %s %s to %s"
            result
            (llvm_type generated_operand.pcl_type)
            generated_operand.operand
            (llvm_type expression.pcl_type)
         in
         emit_line context.instructions instruction;
         {
            pcl_type = expression.pcl_type;
            operand = result;
         }

   | TECall ("readInteger", []) ->
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf "%s = call i64 @readInteger()" result);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("readBoolean", []) ->
      let runtime_result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf "%s = call i8 @readBoolean()" runtime_result);

      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf "%s = trunc i8 %s to i1" result runtime_result);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("readChar", []) ->
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf "%s = call i8 @readChar()" result);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("readReal", []) ->
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf "%s = call double @readReal()" result);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("abs", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = call i64 @labs(i64 %s)"
            result
            generated_argument.operand);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall
        (("fabs" | "sqrt" | "sin" | "cos" | "tan" | "arctan" | "exp" | "ln" as name),
         [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let runtime_name =
         match name with
         | "arctan" -> "atan"
         | "ln" -> "log"
         | _ -> name
      in
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = call double @%s(double %s)"
            result
            runtime_name
            generated_argument.operand);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("pi", []) ->
      {
         pcl_type = expression.pcl_type;
         operand = "3.14159265358979312e+00";
      }

   | TECall ("trunc", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = fptosi double %s to i64"
            result
            generated_argument.operand);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("round", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let rounded =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = call double @round(double %s)"
            rounded
            generated_argument.operand);

      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = fptosi double %s to i64"
            result
            rounded);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("ord", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = zext i8 %s to i64"
            result
            generated_argument.operand);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

   | TECall ("chr", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let result =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = trunc i64 %s to i8"
            result
            generated_argument.operand);
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }
      
   | _ ->
      raise(CodegenError "expression not supported by code generation yet")


and generate_address context (expression : Typed_ast.expr) =
   match expression.node with
   | TEId name ->
      lookup_variable context name

   | TEString value ->
      let global_name, length =
         generate_string_constant context value
      in
      {
         address =
            Printf.sprintf
               "getelementptr inbounds ([%d x i8], ptr @%s, i64 0, i64 0)"
               length
               global_name;
         stored_type = expression.pcl_type;
      }

   | TEIndex (array, index) ->
      let array_storage =
         generate_address context array
      in
      let generated_index =
         generate_expr context index
      in
      let address =
         fresh_temp context
      in
      (match array.pcl_type with
      | TArray (Some size, element_type) ->
         emit_line context.instructions
            (Printf.sprintf
               "%s = getelementptr inbounds [%d x %s], ptr %s, i64 0, i64 %s"
               address
               size
               (llvm_type element_type)
               array_storage.address
               generated_index.operand);
         {
            address;
            stored_type = element_type;
         }

      | TArray (None, element_type) ->
         emit_line context.instructions
            (Printf.sprintf
               "%s = getelementptr inbounds %s, ptr %s, i64 %s"
               address
               (llvm_type element_type)
               array_storage.address
               generated_index.operand);
         {
            address;
            stored_type = element_type;
         }

      | _ ->
         raise (CodegenError "indexing requires an array"))

   | TEUnop (UDeref, pointer) ->
      let generated_pointer =
         generate_expr context pointer
      in
      {
         address = generated_pointer.operand;
         stored_type = expression.pcl_type;
      }

   | _ ->
      raise (CodegenError "this lvalue form is not supported yet")



let rec generate_stmt context statement =
   match statement with
   | TSEmpty -> ()

   | TSAssign (destination, value) ->
      let destination_storage =
         generate_address context destination 
      in
      let generated_value =
         generate_expr context value
      in
      let instruction =
         Printf.sprintf "store %s %s, ptr %s"
         (llvm_type destination_storage.stored_type)
         generated_value.operand
         destination_storage.address
      in
      emit_line context.instructions instruction


   | TSCall ("writeInteger", [argument]) ->
      let generated_argument = generate_expr context argument
      in
      let argument_type =
         llvm_type generated_argument.pcl_type
      in
      let instruction = Printf.sprintf " call void @writeInteger(%s %s)" argument_type generated_argument.operand 
      in
      emit_line context.instructions instruction

   | TSCall ("writeString", [argument]) ->
      let generated_argument = generate_expr context argument
      in
      let instruction =
         Printf.sprintf "call void @writeString(ptr %s)" generated_argument.operand
      in
      emit_line context.instructions instruction

   | TSCall ("writeBoolean", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let extended_argument =
         fresh_temp context
      in
      let extension =
         Printf.sprintf
            "%s = zext i1 %s to i8"
            extended_argument
            generated_argument.operand
      in
      emit_line context.instructions extension;

      let instruction =
         Printf.sprintf
            "call void @writeBoolean(i8 %s)"
            extended_argument
      in
      emit_line context.instructions instruction
   
   | TSCall ("writeChar", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      let instruction =
         Printf.sprintf
            "call void @writeChar(i8 %s)"
            generated_argument.operand
      in
      emit_line context.instructions instruction

   | TSCall ("writeReal", [argument]) ->
      let generated_argument =
         generate_expr context argument
      in
      emit_line context.instructions
         (Printf.sprintf
            "call void @writeReal(double %s)"
            generated_argument.operand)

   | TSCall ("readString", [size; destination]) ->
      let generated_size =
         generate_expr context size
      in
      let destination_storage =
         generate_address context destination
      in
      emit_line context.instructions
         (Printf.sprintf
            "call void @readString(i64 %s, ptr %s)"
            generated_size.operand
            destination_storage.address)

   | TSBlock statements ->
      List.iter (generate_stmt context) statements

   | TSIf (condition, then_statement, else_statement) ->
      let generated_condition =
         generate_expr context condition
      in

      let then_label = fresh_label context "if_then_" in
      let else_label = fresh_label context "if_else_" in
      let end_label = fresh_label context "if_end_" in

      emit_line context.instructions
         (Printf.sprintf
            "br i1 %s, label %%%s, label %%%s"
            generated_condition.operand
            then_label
            else_label);

      emit_label context then_label;
      generate_stmt context then_statement;
      emit_line context.instructions
         (Printf.sprintf "br label %%%s" end_label);

      emit_label context else_label;
      (match else_statement with
      | None -> ()
      | Some statement ->
         generate_stmt context statement);
      emit_line context.instructions
         (Printf.sprintf "br label %%%s" end_label);

      emit_label context end_label

   | TSWhile (condition, body) ->
      let condition_label =
         fresh_label context "while_condition_"
      in
      let body_label =
         fresh_label context "while_body_"
      in
      let end_label =
         fresh_label context "while_end_"
      in

      emit_line context.instructions
         (Printf.sprintf
            "br label %%%s"
            condition_label);

      emit_label context condition_label;

      let generated_condition =
         generate_expr context condition
      in

      emit_line context.instructions
         (Printf.sprintf
            "br i1 %s, label %%%s, label %%%s"
            generated_condition.operand
            body_label
            end_label);

      emit_label context body_label;

      generate_stmt context body;

      emit_line context.instructions
         (Printf.sprintf
            "br label %%%s"
            condition_label);

      emit_label context end_label

   | TSNewArray (size, destination) ->
      let generated_size =
         generate_expr context size
      in
      let destination_storage =
         generate_address context destination
      in
      let element_type =
         match destination.pcl_type with
         | TPointer (TArray (None, element_type)) -> element_type
         | _ ->
            raise (CodegenError "new array requires a pointer to an open array")
      in
      let allocation_end =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = getelementptr %s, ptr null, i64 %s"
            allocation_end
            (llvm_type element_type)
            generated_size.operand);

      let allocation_size =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = ptrtoint ptr %s to i64"
            allocation_size
            allocation_end);

      let allocation =
         fresh_temp context
      in
      emit_line context.instructions
         (Printf.sprintf
            "%s = call ptr @malloc(i64 %s)"
            allocation
            allocation_size);
      emit_line context.instructions
         (Printf.sprintf
            "store ptr %s, ptr %s"
            allocation
            destination_storage.address)

   | TSDisposeArray destination ->
      let destination_storage =
         generate_address context destination
      in
      let generated_pointer =
         generate_expr context destination
      in
      emit_line context.instructions
         (Printf.sprintf "call void @free(ptr %s)" generated_pointer.operand);
      emit_line context.instructions
         (Printf.sprintf "store ptr null, ptr %s" destination_storage.address)

   | _ ->
      raise(CodegenError "statement not supported by code generation yet")

      
let generate_local context local =
   match local with
   | TLVar groups ->
      List.iter(fun(names, variable_type) ->
         List.iter(fun name ->
            declare_variable context name variable_type)
            names) 
      groups
   
   | TLLabel _ -> ()

   | TLForward _ -> ()

   | TLDef _ ->
      raise(CodegenError "subprogram gen is not supported yet")

(* Generation functions end *)


(* main *)
let generate_program (program: Typed_ast.program) =

   let module_context = create_module_context ()
   in
   let context = create_generation_context module_context 0
   in
   
   List.iter (register_local_subprogram context) program.body.locals;
   List.iter (generate_local context) program.body.locals;
   List.iter (generate_stmt context) program.body.block;
   
   let output = Buffer.create 256 in

   emit_line output "declare void @writeInteger(i64)";
   emit_line output "declare void @writeString(ptr)";
   emit_line output "declare void @writeBoolean(i8)";
   emit_line output "declare void @writeChar(i8)";
   emit_line output "declare void @writeReal(double)";
   emit_line output "declare void @readString(i64, ptr)";
   emit_line output "declare i64 @readInteger()";
   emit_line output "declare i8 @readBoolean()";
   emit_line output "declare i8 @readChar()";
   emit_line output "declare double @readReal()";
   emit_line output "declare i64 @labs(i64)";
   emit_line output "declare double @fabs(double)";
   emit_line output "declare double @sqrt(double)";
   emit_line output "declare double @sin(double)";
   emit_line output "declare double @cos(double)";
   emit_line output "declare double @tan(double)";
   emit_line output "declare double @atan(double)";
   emit_line output "declare double @exp(double)";
   emit_line output "declare double @log(double)";
   emit_line output "declare double @round(double)";
   emit_line output "declare ptr @malloc(i64)";
   emit_line output "declare void @free(ptr)";
   Buffer.add_buffer output module_context.globals;
   Buffer.add_buffer output module_context.functions;


   emit_line output "define i32 @main() {";
   emit_line output "entry:";
   Buffer.add_buffer output context.instructions;


   emit_line output " ret i32 0";
   emit_line output "}";
   Buffer.contents output
