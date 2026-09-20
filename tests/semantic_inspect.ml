open Pcl_compiler

let inspect ast =
   ignore(Semantic.analyze_program ast);
   Printf.printf "Semantic Analysis OK\n"

let () =
   Inspect_common.run "semantic_inspect" inspect