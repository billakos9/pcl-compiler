# PCL Fixtures

This directory stores source programs used to exercise the compiler.

- `programs/` contains valid PCL programs and expected-output fixtures.
- `programs-erroneous/` contains programs that must fail during lexing,
  parsing, or semantic analysis.

The files are inputs to the compiler, not OCaml source files, so Dune does not
compile them directly.
