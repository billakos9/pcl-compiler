# Compiler Library

This directory contains the compiler itself. Dune packages these modules as the
wrapped OCaml library `Pcl_compiler`.

## Files

- `lexer.mll`: ocamllex rules that convert source characters into parser tokens.
- `parser.mly`: Menhir grammar that converts tokens into `Ast.program`.
- `ast.ml`: untyped syntax tree produced by the parser.
- `symbol.ml`: lexical-scope symbol table used during semantic analysis.
- `pcl_library.ml`: declarations of PCL's predefined routines.
- `semantic.ml`: name resolution, declaration checks, and type checking. It
  produces `Typed_ast.program` and inserts integer-to-real conversions.
- `typed_ast.ml`: AST annotated with every expression's PCL type and whether it
  is an lvalue or rvalue.
- `codegen.ml`: lowers the typed AST to textual LLVM IR.

## Important Boundaries

The parser records what the program says; it does not decide whether the
program is type-correct. The semantic analyzer validates the AST and adds the
facts codegen needs. Codegen therefore consumes only the typed AST.

Semantic analysis checks, among other rules:

- identifier lookup from the innermost scope outward
- duplicate declarations and matching forward definitions
- complete variable types and complete array element types
- non-array function results and reference-only array parameters
- operator, assignment, call, return, allocation, and disposal types
- definite `result` assignment on every reachable function exit
- lvalue requirements for assignment, by-reference arguments, `@`, and memory
  operations
- declared, uniquely defined label targets

Code generation implements:

- stack storage for variables and by-value formals
- addresses for by-reference formals and lvalues
- static-link frames for variables captured from enclosing subprograms
- unique LLVM names for nested routines and labels
- short-circuit Boolean control flow
- libc allocation through `malloc` and `free`
- calls to the C runtime for PCL input/output

User subprogram lookup is performed before builtin codegen cases. Combined with
the nested symbol table, this gives user declarations correct lexical
shadowing over predefined routines.
