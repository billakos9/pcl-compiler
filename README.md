# PCL Compiler

An educational compiler for PCL, written in OCaml. It reads a PCL source file,
checks it, generates LLVM IR and assembly, and links a native executable.

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
- Clang/LLVM for compiling generated `.imm` files
- A C compiler and the system math library for `runtime/pcl_runtime.c`

## Build And Run

Build the OCaml project:

```bash
dune build
```

Compile a source program. This creates `hello.imm` and `hello.asm` beside the
source file, then links `./a.out`:

```bash
dune exec ./bin/main.exe -- pcl/programs/hello.pcl
./a.out
```

Choose another executable path:

```bash
dune exec ./bin/main.exe -- -o /tmp/hello pcl/programs/hello.pcl
/tmp/hello
```

The course stream modes read PCL source from standard input. `-i` writes LLVM
intermediate code and `-f` writes target assembly:

```bash
cat pcl/programs/hello.pcl | dune exec ./bin/main.exe -- -i
cat pcl/programs/hello.pcl | dune exec ./bin/main.exe -- -f
```

Add `-O` to any mode to enable LLVM optimization.

Clean Dune output with `dune clean`. Never edit `_build`; Dune regenerates it.

## Implemented Language Features

- Primitive, fixed-array, open-array, pointer, and `nil` types
- Course-defined operator precedence and `array of t` open-array syntax
- Address-of `@`, dereference `^`, pointer comparison, and array indexing
- `new`, `new [n]`, `dispose`, and `dispose []`
- Procedures, functions, `result`, and `return`
- Definite assignment of function results across branches, loops, and jumps
- By-value and by-reference formal parameters
- Nested subprograms with static links and Pascal lexical scoping
- Recursion, mutual recursion, and checked forward declarations
- Labels and `goto`
- Nearest-scope lookup, including correct shadowing of predefined routines
- Course-compatible `.imm`, `.asm`, executable, `-i`, `-f`, `-o`, and `-O`
  command-line output modes

## Project Layout

- `lib/`: compiler phases and shared representations
- `bin/`: command-line compiler entry point
- `debug_helpers/`: one inspector for each compiler phase
- `pcl/programs/`: valid examples and regression fixtures
- `pcl/programs-erroneous/`: negative lexer/parser/semantic fixtures
- `runtime/`: C implementation of PCL input/output routines

Each directory contains its own README with more detail.

## Current Verification

- 50 valid PCL files pass the compiler front end and LLVM generation.
- 52 erroneous PCL files are rejected.
- 37 programs with expected results compile, link, execute, and match their
  expected output under the course test harness.
