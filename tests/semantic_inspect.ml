open Pcl_compiler
open Ast
open Typed_ast

let ind depth = String.make (depth * 2) ' '

let string_of_category = function
   | LValue -> "LValue"
   | RValue -> "RValue"

let string_of_typ = function
   | TInteger -> "integer"
   | TReal -> "real"
   | TBoolean -> "boolean"
   | TChar -> "char"
   | TArray (None, typ) ->
      Printf.sprintf "array[%d] of %s" 
      size(string_of_typ typ)
   | TPointer typ ->
      "^" ^ string_of_typ typ
   | TNil -> "nil"


let expr_description expression =
   Printf.sprintf ": %s [%s]"
   (string_of_typ expression.pcl_type)
   (string_of_category expression.category)


let rec print_expr depth expression =
   let p = Printf.sprintf in
   let info = expr_description expression 
   in
   match expression.node with
   | TEId name ->
      p "%sTEId(%s)%s\n" (ind depth) name info

   | TEResult ->
      p "s%TEResult%s\n" (ind depth) info

   | TEInt value ->
      p "%sTEInt(%d)%s\n" (ind depth) value info
   
   | TEReal value ->
      p "%sTEReal(%g)%s\n" (ind depth) value info
  
   | TEChar value ->
      p "%sTEChar(%C)%s\n" (ind depth) value info
  
   | TEString value ->
      p "%sTEString(%S)%s\n" (ind depth) value info
  
   | TEBool value ->
      p "%sTEBool(%b)%s\n" (ind depth) value info
  
   | TENil ->
      p "%sTENil%s\n" (ind depth) info