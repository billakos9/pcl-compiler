# PCL Compiler

This is my compiler for the PCL language, written in OCaml for the Compilers
course at NTUA.

It reads a PCL program, checks it, creates LLVM IR and assembly, and then links
the result with `runtime/pcl_runtime.c`.

It works like this:

```text
PCL source
  -> lexer
  -> parser
  -> AST
  -> semantic analysis
  -> typed AST
  -> optimizer (only with -O)
  -> LLVM IR (.imm)
  -> assembly (.asm)
  -> executable
```

## Installation on Debian/Ubuntu

First install the system packages:

```bash
sudo apt update
sudo apt install git opam build-essential clang m4 pkg-config
```

Then initialize opam and create an OCaml switch. This only needs to be done
once:

```bash
opam init -y
eval $(opam env)
opam switch create pcl-compiler ocaml-base-compiler.5.2.1
eval $(opam env --switch=pcl-compiler)
opam install dune menhir
```

The project needs Dune 3 or newer. The generated LLVM uses opaque pointers, so
Clang 15-19 is recommended. You can check the installed versions with:

```bash
dune --version
clang --version
```

If the system's default `clang` is too old but a newer one is installed, select
it like this:

```bash
export PCL_CLANG=clang-18
```

Finally clone and build the project:

```bash
git clone https://github.com/billakos9/pcl-compiler.git
cd pcl-compiler
dune build
```

When opening a new terminal, remember to load the opam switch again:

```bash
eval $(opam env --switch=pcl-compiler)
```

### Setup problems

If `dune` or `menhir` is not found after installation, the opam environment is
probably not loaded. Run the `eval $(opam env ...)` command above again.

If the compiler cannot find Clang, set its command explicitly:

```bash
export PCL_CLANG=clang-18
```

The compiler normally finds its C runtime on its own. If it cannot find it,
give the path manually from the repository root:

```bash
export PCL_RUNTIME="$PWD/runtime/pcl_runtime.c"
```

## Basic usage

Compile a PCL file with:

```bash
dune exec ./bin/main.exe -- pcl/programs/hello.pcl
```

This creates:

- `outputs/hello.imm`: generated LLVM IR
- `outputs/hello.asm`: generated assembly
- `outputs/a.out`: final executable

Run it with:

```bash
./outputs/a.out
```

Use `-o` to choose another executable name:

```bash
dune exec ./bin/main.exe -- -o hello pcl/programs/hello.pcl
./hello
```

### Optimizations

Pass `-O` to turn optimizations on:

```bash
dune exec ./bin/main.exe -- -O pcl/programs/hello.pcl
```

With `-O`, the compiler simplifies constant expressions in the typed AST and
then asks Clang to use `-O2`.

### Intermediate and final code

```bash
# Read PCL from stdin and print LLVM IR
cat pcl/programs/hello.pcl | dune exec ./bin/main.exe -- -i

# Read PCL from stdin and print assembly
cat pcl/programs/hello.pcl | dune exec ./bin/main.exe -- -f
```

`-O` can also be combined with `-i` or `-f`.

## Data sizes

These are the sizes I used:

| PCL type | LLVM type | Size |
| --- | --- | --- |
| `integer` | signed `i64` | 8 bytes |
| `real` | IEEE 754 `double` | 8 bytes |
| `boolean` | `i1` internally, `i8` at the C runtime boundary | 1 byte in memory |
| `char` | ASCII `i8` | 1 byte |
| pointer (`^t`) | `ptr` | 8 bytes on a 64-bit machine |
| `array [n] of t` | `[n x t]` | `n * sizeof(t)` |

PCL integer calculations, `readInteger`, and `writeInteger` all use 64-bit
integers. The `i32` used by the generated native `main` function is only its
process exit status; it is not the PCL integer type.

## Supported features

The compiler supports:

- primitive types, fixed/open arrays and pointers
- expressions, assignments, conditions and loops
- functions, procedures, `result` and `return`
- by-value and by-reference parameters
- nested subprograms and static links
- recursion, mutual recursion and `forward`
- `new`, `new [n]`, `dispose` and `dispose []`
- labels and `goto`
- the predefined PCL input/output and mathematical functions
- short-circuit `and`/`or`
- optional typed-AST and LLVM optimizations

## Known problems

- It generates code for the machine where it runs. There is no
  cross-compilation.
- There are no array-bounds checks at runtime.
- There are no runtime checks for null pointer dereference, division by zero,
  double `dispose`, or allocation failure.
- Lexer and parser errors include a source position, but most semantic errors
  do not yet include line and column information because source locations are
  not stored in the AST.
- PCL integers are represented as `i64`, but integer literals are initially
  parsed using OCaml's `int`, so the full `i64` literal range is not available
  on every OCaml host.
- The custom optimizer is small. LLVM handles the more advanced optimizations.

## Testing

The repository contains two sets of test programs:

- `pcl/programs/`: 34 valid programs
- `pcl/programs-erroneous/`: 35 programs that must be rejected

Right now, all 34 valid programs compile and give the expected output. All 35
erroneous programs are rejected.

Useful commands while working on the compiler:

```bash
dune build
dune runtest
dune clean
```

The small programs in `debug_helpers/` show the output of each compiler step:

```bash
dune exec ./debug_helpers/lexer_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/parser_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/semantic_inspect.exe -- pcl/programs/hello.pcl
dune exec ./debug_helpers/optimizer_inspect.exe -- pcl/programs/rand_gen.pcl
dune exec ./debug_helpers/codegen_inspect.exe -- pcl/programs/hello.pcl
```

## Repository layout

- `lib/`: AST, lexer, parser, semantic analysis, optimizer and LLVM codegen
- `bin/`: command-line compiler
- `runtime/`: the C runtime linked with generated programs
- `debug_helpers/`: small tools for checking each compiler step
- `pcl/`: valid and erroneous test programs

The smaller READMEs have a few more notes about each folder.
