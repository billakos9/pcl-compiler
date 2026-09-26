# Valid PCL Programs

Every `.pcl` file in this directory should pass lexing, parsing, semantic
analysis, and LLVM generation.

Many course programs have matching files:

- `<name>.input`: standard input supplied to the compiled program
- `<name>.result`: expected standard output

Files prefixed with `codegen_` are focused regression programs for individual
features. For example, `codegen_builtin_shadowing.pcl` verifies that local
definitions of `abs` and `writeInteger` override the predefined routines.

Compile one fixture with:

```bash
dune exec ./bin/main.exe -- -o /tmp/test.ll pcl/programs/hello.pcl
clang /tmp/test.ll runtime/pcl_runtime.c -lm -o /tmp/test
/tmp/test
```
