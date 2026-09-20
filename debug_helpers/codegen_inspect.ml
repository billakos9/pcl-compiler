open Pcl_compiler

let inspect ast =
  let typed_program =
    Semantic.analyze_program ast in 
  let llvm_ir = Codegen.generate_program typed_program in
  print_string llvm_ir

let () =
  Inspect_common.run "codegen_inspect" inspect