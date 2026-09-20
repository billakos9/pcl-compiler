(* =========================================================
   codegen.ml  –  Code generation for PCL (LLVM IR)
   AST -> LLVM text
   ========================================================= *)

open Ast
open Typed_ast


exception CodegenError of string

(* context *)

type generation_context = {
   globals : Buffer.t;
   instructions : Buffer.t;
   mutable next_string_id : int;
}

let create_context () =
   {
      globals = Buffer.create 256;
      instructions = Buffer.create 256;
      next_string_id = 0;
   }


let fresh_string_id context =
   let id = context.next_string_id in
   context.next_string_id <- id + 1;
   id


type generated_value = {
   pcl_type: typ;
   operand: string;
}

(* Helper functions *)

let emit_line buffer line =
   Buffer.add_string buffer line;
   Buffer.add_char buffer '\n'


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



let generate_expr _context expression =
   match expression with
   | TEInt value ->
      {
         pcl_type = expression.pcl_type;
         operand = string_of_int value;
      }
   
   | _ ->
      raise(CodegenError "expression not supported by code generation yet")



let generate_stmt context statement =
   match statemenst with
   | TSEmpty -> ()

   | TSCall ("writeInteger", [argument]) ->
      let generated_argument = generate_expr context argument
      in
      let instruction = Printf.sprintf " call void @writeInteger(i64 %s)" generated_argument.operand 
      in
      emit_line context.instructions instruction

   | TSCall ("writeString", [argument]) ->
      (match argument.node with
      | TEString value ->
         let global_name, length = generate_string_constant context value
         in
         let instruction = Printf.sprintf "call void @writeString(ptr getelementptr inbounds ([%d x i8], ptr @%s, i64 0, i64 0))" length global_name
         in
         emit_line context.instructions instruction
      
      | _ ->
         raise(CodegenError "writeString currently support only string literals"))

      | _ ->
         raise(CodegenError "statement not supported by code generation yet")




(* Helper functions end *)


let generate_program (program: Typed_ast.program) =

   let context = create_context () in
   
   List.iter (generate_stmt context) program.body.block;
   
   let output = Buffer.create 256 in

   emit_line output "declare void @writeInteger(i64)";
   emit_line output "declare void @writeString(ptr)";
   Buffer.add_buffer output context.globals;


   emit_line output "define i32 @main() {";
   emit_line output "entry:";
   Buffer.add_buffer output context.instructions;


   emit_line output " ret i32 0";
   emit_line output "}";
   Buffer.contents output