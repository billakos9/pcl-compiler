open Pcl_compiler


let inspect ast =
   let typed_program = Semantic.analyze_program ast in
   let optimized_program = Optimizer.optimize_program typed_program in
   let llvm_ir = Codegen.generate_program optimized_program in
   print_string llvm_ir


let () =
   Inspect_common.run "optimizer_inspect" inspect
