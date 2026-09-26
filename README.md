# PCL Compiler

An educational compiler for PCL, written in OCaml. It reads a PCL source file,
checks it, and emits textual LLVM IR.

```text
PCL source
  -> lexer.mll
  -> parser.mly
  -> Ast.program
  -> semantic.ml
  -> Typed_ast.program
  -> codegen.ml
  -> LLVM IR
  -> clang + runtime/pcl_runtime.c
  -> native executable
```

## Requirements

- OCaml and Dune
- Menhir and ocamllex
- Clang/LLVM for compiling generated `.ll` files
- A C compiler and the system math library for `runtime/pcl_runtime.c`

## Build And Run

Build the OCaml project:

```bash
dune build
```

Print LLVM IR to standard output:

```bash
dune exec ./bin/main.exe -- pcl/programs/hello.pcl
```

Write LLVM IR to a file, link it, and run it:

```bash
dune exec ./bin/main.exe -- -o /tmp/hello.ll pcl/programs/hello.pcl
clang /tmp/hello.ll runtime/pcl_runtime.c -lm -o /tmp/hello
/tmp/hello
```

Clean Dune output with `dune clean`. Never edit `_build`; Dune regenerates it.

## Implemented Language Features

- Primitive, fixed-array, open-array, pointer, and `nil` types
- Address-of `@`, dereference `^`, pointer comparison, and array indexing
- `new`, `new [n]`, `dispose`, and `dispose []`
- Procedures, functions, `result`, and `return`
- By-value and by-reference formal parameters
- Nested subprograms with static links and Pascal lexical scoping
- Recursion, mutual recursion, and checked forward declarations
- Labels and `goto`
- Nearest-scope lookup, including correct shadowing of predefined routines
- LLVM output through the command-line compiler

## Project Layout

- `lib/`: compiler phases and shared representations
- `bin/`: command-line compiler entry point
- `debug_helpers/`: one inspector for each compiler phase
- `pcl/programs/`: valid examples and regression fixtures
- `pcl/programs-erroneous/`: negative lexer/parser/semantic fixtures
- `runtime/`: C implementation of PCL input/output routines

Each directory contains its own README with more detail.

## Current Verification

- 48 valid PCL files pass the compiler front end and LLVM generation.
- 37 erroneous PCL files are rejected.
- Programs with `.input` and `.result` files can be compiled and compared
  end to end after linking with the runtime.
