# Erroneous PCL Programs

Every `.pcl` file in this directory is intentionally invalid and must be
rejected by the compiler.

- `lex_error*` files exercise invalid source characters and literals.
- `syntax_error*` files exercise invalid grammatical structure.
- `semantic_error*` files exercise name, type, lvalue, call, label, return,
  forward-declaration, complete-type, parameter, and result-type rules.
- `undefined_label.pcl` exercises an undeclared `goto` target.

If one of these files compiles successfully, something is wrong. The compiler
should print an error and return a nonzero exit code.
