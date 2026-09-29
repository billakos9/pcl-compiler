# PCL Runtime

`pcl_runtime.c` contains the input/output functions used by the generated LLVM
IR. Clang links it with the generated assembly.

Provided routines:

- output: `writeInteger`, `writeBoolean`, `writeChar`, `writeReal`,
  `writeString`
- input: `readInteger`, `readBoolean`, `readChar`, `readReal`, `readString`

The generated code uses the C library for maths, `malloc`, and `free`. Memory is
allocated when the compiled program runs, not while the compiler runs.

The compiler links this file automatically. The same step can be done manually:

```bash
clang -x ir output.imm -x c runtime/pcl_runtime.c -lm -o output
```

`-lm` links the system math library.
