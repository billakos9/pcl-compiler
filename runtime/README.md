# PCL Runtime

`pcl_runtime.c` supplies the input/output functions called by generated LLVM
IR. It is linked with the generated module; it is not executed by the OCaml
compiler itself.

Provided routines:

- output: `writeInteger`, `writeBoolean`, `writeChar`, `writeReal`,
  `writeString`
- input: `readInteger`, `readBoolean`, `readChar`, `readReal`, `readString`

Generated LLVM calls the platform C library directly for mathematical
functions, `malloc`, and `free`. Scalar and array allocation therefore happens
when the compiled program runs, not while the compiler is running.

Link a generated module with:

```bash
clang output.ll runtime/pcl_runtime.c -lm -o output
```

The `-lm` flag links the system math library used by PCL's real-number
predefined functions.
