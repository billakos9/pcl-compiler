# PCL compiler written in OCaml 

###  Dynamic repo - updates keep coming

- "_build" & "bin" folders are created by # dune build
- "lib" folder contains all the files I will create during my work on this project
- "pcl" folder contains pcl programs for testing
- "dune-project" is a file needed only in the root folder of the project

### Run the compiler
- dune build
- dune exec ./bin/main.exe -- program.pcl
- dune clean
