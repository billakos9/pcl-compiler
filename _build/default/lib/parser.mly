%{
  (* =========================================================
     parser.mly  –  Menhir parser for PCL
     Filled in during Phase 2.
     ========================================================= *)
%}

%token T_eof
%start <unit> program
%%

program: T_eof { () }
