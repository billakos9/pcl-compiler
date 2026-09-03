(* =========================================================
   codegen.ml  –  Code generation for PCL (LLVM IR)
   AST -> LLVM text
   ========================================================= *)

open Ast

let emit_line buffer line =
   Buffer.add_string buffer line;
   Buffer.add_char buffer '\n'

let generate_program (_program: program) =
   let output = Buffer.create 256 in

   emit_line output "define i32 @main() {";
   emit_line output "entry:";
   emit_line output " ret i32 0";
   emit_line output "}";

   Buffer.contents output