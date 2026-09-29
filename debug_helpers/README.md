# Compiler Phase Inspectors

These are small programs I use to see what each compiler step produces. They
are only for debugging and are not part of the normal compiler command.

```bash
dune exec ./debug_helpers/lexer_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/parser_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/semantic_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/optimizer_inspect.exe -- pcl/programs/rand_gen.pcl
dune exec ./debug_helpers/codegen_inspect.exe -- pcl/programs/hello.pcl
```

- `lexer_inspect.ml` prints the token stream.
- `parser_inspect.ml` prints the untyped AST through `ast_printer.ml`.
- `semantic_inspect.ml` prints the typed expressions and their lvalue/rvalue
  information.
- `optimizer_inspect.ml` prints the LLVM IR after my optimizer.
- `codegen_inspect.ml` prints generated LLVM IR.
- `inspect_common.ml` has the parsing and error-handling code shared by some
  inspectors.

Each inspector stops at a different step, so it is easier to find where
something first goes wrong.
