# Compiler Phase Inspectors

These executables expose intermediate compiler results for learning and
debugging. They are not part of the final compiler CLI.

```bash
dune exec ./debug_helpers/lexer_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/parser_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/semantic_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/optimizer_inspect.exe -- pcl/programs/rand_gen.pcl
dune exec ./debug_helpers/codegen_inspect.exe -- pcl/programs/hello.pcl
```

- `lexer_inspect.ml` prints the token stream.
- `parser_inspect.ml` prints the untyped AST through `ast_printer.ml`.
- `semantic_inspect.ml` prints typed expressions, including types and
  lvalue/rvalue categories.
- `optimizer_inspect.ml` prints LLVM IR generated from the optimized typed AST,
  before Clang performs its own optimization passes.
- `codegen_inspect.ml` prints generated LLVM IR.
- `inspect_common.ml` contains shared file parsing and error handling for the
  parser, semantic, and codegen inspectors.

The inspectors intentionally stop at different phase boundaries. This makes it
possible to identify the first phase where a source program becomes incorrect.
