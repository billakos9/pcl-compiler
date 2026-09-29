# PCL Runtime

`pcl_runtime.c` supplies the input/output functions called by generated LLVM IR. The compiler driver passes it to Clang while linking the generated assembly; the OCaml compiler does not execute the runtime itself.

Provided routines:

- output: `writeInteger`, `writeBoolean`, `writeChar`, `writeReal`,
  `writeString`
- input: `readInteger`, `readBoolean`, `readChar`, `readReal`, `readString`

Generated LLVM calls the platform C library directly for mathematical functions, `malloc`, and `free`. Scalar and array allocation therefore happens when the compiled program runs, not while the compiler is running.

The compiler performs this link automatically in normal mode. The equivalent manual command for an LLVM module is:

```bash
clang -x ir output.imm -x c runtime/pcl_runtime.c -lm -o output
```

The `-lm` flag links the system math library used by PCL's real-number
predefined functions.
