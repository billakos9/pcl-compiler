# Compiler Driver

`main.ml` is the user-facing compiler executable. It connects the phases in
this order:

1. `parse_file` opens the PCL file and runs the lexer and parser.
2. `compile_file` sends the AST through semantic analysis and code generation.
3. `write_output` prints LLVM IR or writes it to the path supplied with `-o`.

The driver reports lexical, syntax, semantic, code-generation, and file errors
on standard error and exits with a nonzero status.

## Usage

```bash
dune exec ./bin/main.exe -- input.pcl
dune exec ./bin/main.exe -- -o output.ll input.pcl
```

The first command writes LLVM IR to standard output. The second writes only to
`output.ll`, which can then be passed to Clang.

`dune` defines the executable and links it against the `pcl_compiler` library.
