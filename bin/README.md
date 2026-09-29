# Compiler Driver

`main.ml` is the user-facing compiler executable. It connects the phases in
this order:

1. `parse_channel` runs the lexer and parser on a source stream.
2. `compile_channel` runs semantic analysis and retains the typed AST. With
   `-O`, it applies the typed-AST optimizer before generating LLVM IR.
3. Normal mode writes `outputs/<source>.imm`, asks Clang for
   `outputs/<source>.asm`, and links the assembly with
   `runtime/pcl_runtime.c`.
4. `-i` and `-f` expose the intermediate and final-code stages through standard
   input and standard output.

The driver reports lexical, syntax, semantic, code-generation, process, and
file errors on standard error and exits with a nonzero status.

## Usage

```bash
dune exec ./bin/main.exe -- input.pcl
dune exec ./bin/main.exe -- -o output input.pcl
cat input.pcl | dune exec ./bin/main.exe -- -i
cat input.pcl | dune exec ./bin/main.exe -- -f
dune exec ./bin/main.exe -- -O input.pcl
```

Normal mode creates an `outputs/` directory in the current working directory.
It keeps the `.imm` and `.asm` files there, and the default executable is
`outputs/a.out`. An explicit `-o` still selects another executable path. `-O`
enables Clang's `-O2` optimization after the compiler's own constant folding
and safe algebraic simplification.

Set `PCL_CLANG` to select a different Clang executable. Set `PCL_RUNTIME` to an
explicit `pcl_runtime.c` path if the driver cannot discover the repository's
runtime while invoked from another directory.

`dune` defines the executable and links it against the `pcl_compiler` and
`unix` libraries. The latter is used to run Clang without passing commands
through a shell.
