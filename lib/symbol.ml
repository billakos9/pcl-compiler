(* =========================================================
   symbol.ml  –  Symbol table for PCL
   Filled in during Phase 3 (Semantic Analysis).
   ========================================================= *)

open Ast

type symbol_info = 
      | SVar of typ
      | SFunc of formal list * typ option

type scope = 
      (string * symbol_info) list

type symbol_table = 
      scope list

let empty_table = []

let enter_scope table = [] :: table

let exit_scope table = List.tl table      
(* returns the given list without the first element *)
(* first element is the innermost scope , the one i am exiting *)

let add_symbol table name info =
      match table with
      | [] -> failwith "no scope"
      | scope :: rest -> ((name,info) :: scope) :: rest     
      (* add scope to first element *)
      (* add info to new first scope *)
      (* lists are immutable in Ocaml , created list from scratch *)
      (* pattern -> code to run *)
let rec lookup table name =
      match table with
      | [] -> None
      | scope :: rest ->
         (* search for name in the current scope *)
         match List.assoc_opt name scope with   
         | Some info -> Some info
         | None -> lookup rest name