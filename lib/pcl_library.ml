open Ast

(* PCL's predefined procs & funcs *)
let predefined_headers =
  [
    HProcedure ("writeInteger", [(ByValue, ["n"], TInteger)]);

    HProcedure ("writeBoolean", [(ByValue, ["b"], TBoolean)]);

    HProcedure ("writeChar",    [(ByValue, ["c"], TChar)]);
      
    HProcedure ("writeReal",    [(ByValue, ["r"], TReal)]);
      
    HProcedure ("writeString",  [(ByRef, ["s"], TArray (None, TChar))]);

    HFunction ("readInteger", [], TInteger);
      
    HFunction ("readBoolean", [], TBoolean);
      
    HFunction ("readChar",    [], TChar);
      
    HFunction ("readReal",    [], TReal);
      
    HProcedure ("readString",[ (ByValue, ["size"], TInteger); (ByRef, ["s"], TArray (None, TChar)) ]);
      
    HFunction ("abs",  [(ByValue, ["n"], TInteger)], TInteger);
      
    HFunction ("fabs", [(ByValue, ["r"], TReal)], TReal);

      
    HFunction ("sqrt",   [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("sin",    [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("cos",    [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("tan",    [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("arctan", [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("exp",    [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("ln",     [(ByValue, ["r"], TReal)], TReal);
      
    HFunction ("pi", [], TReal);

      
    HFunction ("trunc", [(ByValue, ["r"], TReal)], TInteger);
      
    HFunction ("round", [(ByValue, ["r"], TReal)], TInteger);
      
    HFunction ("ord",   [(ByValue, ["c"], TChar)], TInteger);
      
    HFunction ("chr",   [(ByValue, ["n"], TInteger)], TChar)
   ]