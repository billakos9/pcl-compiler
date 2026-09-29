# Compiler Library

This folder contains most of the compiler. Dune puts these files in the OCaml
library `Pcl_compiler`.

## What each file does

- `lexer.mll`: ocamllex rules that convert source characters into parser tokens.
- `parser.mly`: Menhir grammar that converts tokens into `Ast.program`.
- `ast.ml`: untyped syntax tree produced by the parser.
- `symbol.ml`: lexical-scope symbol table used during semantic analysis.
- `pcl_library.ml`: declarations of PCL's predefined routines.
- `semantic.ml`: name resolution, declaration checks, and type checking. It
  produces `Typed_ast.program` and inserts integer-to-real conversions.
- `typed_ast.ml`: AST annotated with every expression's PCL type and whether it
  is an lvalue or rvalue.
- `optimizer.ml`: optional typed-AST constant folding and side-effect-safe
  algebraic simplification.
- `codegen.ml`: lowers the typed AST to textual LLVM IR.

## How the parts connect

The parser builds the AST but does not check if the types make sense. The
semantic analyzer does those checks and creates the typed AST. Codegen uses
that typed AST to create LLVM IR.

The semantic analyzer checks:

- identifier lookup from the innermost scope outward
- duplicate declarations and matching forward definitions
- complete variable types and complete array element types
- non-array function results and reference-only array parameters
- operator, assignment, call, return, allocation, and disposal types
- definite `result` assignment on every reachable function exit
- lvalue requirements for assignment, by-reference arguments, `@`, and memory
  operations
- read-only string-literal storage, including indexed literal elements
- declared, uniquely defined label targets

Code generation implements:

- stack storage for variables and by-value formals
- addresses for by-reference formals and lvalues
- static-link frames for variables captured from enclosing subprograms
- unique LLVM names for nested routines and labels
- short-circuit Boolean control flow
- libc allocation through `malloc` and `free`
- calls to the C runtime for PCL input/output

Codegen looks for user functions before builtins. This allows a user function
to shadow a builtin with the same name.

## Optimizer

`Optimizer.optimize_program` runs only with `-O`. It folds constant arithmetic,
comparisons, Boolean and unary operations, and integer-to-real conversions. It
also simplifies things such as `x + 0`, `x * 1`, and `x and true`.

It does not fold `x * 0`, `x and false`, or `x or true`, because evaluating `x`
may have side effects. It also does not remove branches because a `goto` may
still reach a label inside them. LLVM does the rest of the optimization.
