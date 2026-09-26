# Erroneous PCL Programs

Every `.pcl` file in this directory is intentionally invalid and must be
rejected by the compiler.

- `lex_error*` files exercise invalid source characters and literals.
- `syntax_error*` files exercise invalid grammatical structure.
- `semantic_error*` files exercise name, type, lvalue, call, label, return,
  and forward-declaration rules.
- `undefined_label.pcl` exercises an undeclared `goto` target.

A successful compiler invocation for one of these files is a regression. The
compiler should print an error to standard error and return a nonzero exit code.
