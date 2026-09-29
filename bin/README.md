# Compiler Driver

`main.ml` is the file that runs the compiler. It connects the steps in this
order:

1. `parse_channel` runs the lexer and parser on a source stream.
2. `compile_channel` runs semantic analysis and retains the typed AST. With
   `-O`, it applies the typed-AST optimizer before generating LLVM IR.
3. Normal mode writes `outputs/<source>.imm`, asks Clang for
   `outputs/<source>.asm`, and links the assembly with
   `runtime/pcl_runtime.c`.
4. `-i` and `-f` expose the intermediate and final-code stages through standard
   input and standard output.

Errors are printed to standard error and the program exits with a nonzero
status.

## Usage

```bash
dune exec ./bin/main.exe -- input.pcl
dune exec ./bin/main.exe -- -o output input.pcl
cat input.pcl | dune exec ./bin/main.exe -- -i
cat input.pcl | dune exec ./bin/main.exe -- -f
dune exec ./bin/main.exe -- -O input.pcl
```

Normal mode creates an `outputs/` folder. The `.imm`, `.asm`, and default
executable are saved there. Use `-o` to choose another executable path and
`-O` to enable the compiler optimizations and Clang `-O2`.

Set `PCL_CLANG` to select a different Clang executable. Set `PCL_RUNTIME` to an
explicit `pcl_runtime.c` path if the driver cannot discover the repository's
runtime while invoked from another directory.

The executable uses the `pcl_compiler` library for the compiler code and the
OCaml `unix` library to run Clang.
