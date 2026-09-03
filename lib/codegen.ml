(* =========================================================
   codegen.ml  –  Code generation for PCL (LLVM IR)
   AST -> LLVM text
   ========================================================= *)

open Ast

exception CodegenError of string

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

let generate_stmt output stmt =
   match stmt with
   | SEmpty -> ()

   | SCall ("writeInteger", [EInt value]) ->
      let instruction =
         Printf.sprintf " call void @writeInteger(i64 %d)" value in
      emit_line output instruction

   | _ -> raise (CodegenError "statement not supported by code generation yet")

(* Helper functions end *)

let generate_program (program: program) =
   let output = Buffer.create 256 in

   emit_line output "declare void @writeInteger(i64)";
   emit_line output "define i32 @main() {";
   emit_line output "entry:";

   List.iter (generate_stmt output) program.body.block;


   emit_line output " ret i32 0";
   emit_line output "}";

   Buffer.contents output