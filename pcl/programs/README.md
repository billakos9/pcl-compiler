# Valid PCL Programs

This directory mirrors the valid `.pcl` programs supplied in the course
`ntua_compilers` repository. Every program should pass lexing, parsing,
semantic analysis, LLVM generation, native linking, and execution.

Many course programs have matching files:

- `<name>.input`: standard input supplied to the compiled program
- `<name>.result`: expected standard output

Compile one fixture with:

```bash
dune exec ./bin/main.exe -- pcl/programs/hello.pcl
./outputs/a.out
```
