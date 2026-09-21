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


type generation_context = {
   globals : Buffer.t;
   instructions : Buffer.t;
   mutable next_string_id : int;
   mutable next_temp_id : int;
   mutable variables : (string * variable_storage) list;
}


let create_context () =
   {
      globals = Buffer.create 256;
      instructions = Buffer.create 256;
      next_string_id = 0;
      next_temp_id = 0;
      variables = [];
   }


let fresh_string_id context =
   let id = context.next_string_id in
   context.next_string_id <- id + 1;
   id


let fresh_temp context =
   let id = context.next_temp_id in
   context.next_temp_id <- id +1;
   Printf.sprintf "%%tmp%d" id


let lookup_variable context name =
   match List.assoc_opt name context.variables with
   | Some storage -> storage

   | None ->
      raise(CodegenError ("unknown variable during code generation: " ^ name))


type generated_value = {
   pcl_type: typ;
   operand: string;
}


(* Helper functions *)
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


let emit_line buffer line =
   Buffer.add_string buffer line;
   Buffer.add_char buffer '\n'


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


let generate_address context(expression : Typed_ast.expr) =
   match expression.node with
   | TEId name ->
      lookup_variable context name

   | _ ->
      raise(CodegenError "this lvalue form is not supported yet")


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

      emit_line context.globals declaration;
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
      let storage = lookup_variable context name 
      in
      let result = fresh_temp context
      in
      let instruction =
         Printf.sprintf "%s = load %s, ptr %s"
         result
         (llvm_type storage.stored_type)
         storage.address
      in
      emit_line context.instructions instruction;
      {
         pcl_type = expression.pcl_type;
         operand = result;
      }

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
      
   | _ ->
      raise(CodegenError "expression not supported by code generation yet")



let generate_stmt context statement =
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

   
(* Helper functions end *)


let generate_program (program: Typed_ast.program) =

   let context = create_context () in
   
   List.iter (generate_local context) program.body.locals;
   List.iter (generate_stmt context) program.body.block;
   
   let output = Buffer.create 256 in

   emit_line output "declare void @writeInteger(i64)";
   emit_line output "declare void @writeString(ptr)";
   emit_line output "declare void @writeBoolean(i8)";
   emit_line output "declare void @writeChar(i8)";
   Buffer.add_buffer output context.globals;


   emit_line output "define i32 @main() {";
   emit_line output "entry:";
   Buffer.add_buffer output context.instructions;


   emit_line output " ret i32 0";
   emit_line output "}";
   Buffer.contents output
