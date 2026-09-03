open Pcl_compiler

let inspect ast =
  Semantic.check_program ast;
  let llvm_ir = Codegen.generate_program ast in
  print_string llvm_ir

let () =
  Inspect_common.run "codegen_inspect" inspect