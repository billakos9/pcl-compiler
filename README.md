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

## Data Representation

The compiler uses the following concrete representation on its supported
64-bit targets:

| PCL type | LLVM representation | Storage size |
| --- | --- | --- |
| `integer` | signed `i64`, two's complement | 8 bytes |
| `real` | `double`, IEEE 754 binary64 | 8 bytes |
| `boolean` | `i1` in generated expressions | 1 addressable byte in memory |
| `char` | `i8`, ASCII | 1 byte |
| `^t` | opaque `ptr` | 8 bytes |
| `array [n] of t` | `[n x llvm_type(t)]` | `n * sizeof(t)` |
| `array of t` | `ptr` to caller-owned elements | incomplete type |
| `nil` | null `ptr` | pointer-sized |

Boolean values are extended from `i1` to `i8` when passed to the C runtime and
truncated back to `i1` when read from it. PCL integer arithmetic and the
`readInteger`/`writeInteger` runtime interface use `i64` throughout. This is
why programs such as `rand_gen.pcl`, whose intermediate products can overflow
a signed 32-bit integer, execute with 64-bit arithmetic.

The generated entry point is `i32 @main()` because that is the native C ABI
process interface. Its `i32` result is the process exit status and is unrelated
to the 64-bit representation of PCL's `integer` type.

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
