# Valid PCL Programs

This folder contains valid `.pcl` programs. Every program should compile and
run without an error.

Many programs also have:

- `<name>.input`: standard input supplied to the compiled program
- `<name>.result`: expected standard output

Compile one fixture with:

```bash
dune exec ./bin/main.exe -- pcl/programs/hello.pcl
./outputs/a.out
```
