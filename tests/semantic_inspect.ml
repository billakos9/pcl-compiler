open Pcl_compiler
open Ast
open Typed_ast

let ind depth = String.make (depth * 2) ' '

let string_of_category = function
   | LValue -> "LValue"
   | RValue -> "RValue"

let rec string_of_typ = function
   | TInteger -> "integer"
   | TReal -> "real"
   | TBoolean -> "boolean"
   | TChar -> "char"
   | TArray (None, typ) ->
      "array of " ^ string_of_typ typ
   |TArray (Some size, typ) ->
      Printf.sprintf "array[%d] of %s" 
      size(string_of_typ typ)
   | TPointer typ ->
      "^" ^ string_of_typ typ
   | TNil -> "nil"


let expr_description expression =
   Printf.sprintf ": %s [%s]"
   (string_of_typ expression.pcl_type)
   (string_of_category expression.category)


let string_of_binop = function
   | BPlus -> "+"
   | BMinus -> "-"
   | BTimes -> "*"
   | BFDiv -> "/"
   | BDiv -> "div"
   | BMod -> "mod"
   | BOr -> "or"
   | BAnd -> "and"
   | BEq -> "="
   | BNe -> "<>"
   | BLt -> "<"
   | BGt -> ">"
   | BLe -> "<="
   | BGe -> ">="


let string_of_unop = function
   | UPlus -> "unary+"
   | UMinus -> "unary-"
   | UNot -> "not"
   | UDeref -> "deref^"
   | UAddrOf -> "@"


let rec print_expr depth expression =
   let p = Printf.printf in
   let info = expr_description expression 
   in
   match expression.node with
   | TEId name ->
      p "%sTEId(%s)%s\n" (ind depth) name info

   | TEResult ->
      p "%sTEResult%s\n" (ind depth) info

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
   
   | TECall (name, arguments) ->
      p "%sTECall(%s)%s\n" (ind depth) name info;
      List.iter (print_expr (depth + 1)) arguments

   | TEBinop (operator, left, right) ->
      p "%sTEBinop(%s)%s\n"
      (ind depth) (string_of_binop operator) info;
      print_expr (depth + 1) left;
      print_expr (depth + 1) right

   | TEUnop (operator, operand) ->
      p "%sTEUnop(%s)%s\n"
      (ind depth) (string_of_unop operator) info;
      print_expr (depth + 1) operand

   | TEIndex (array, index) ->
      p "%sTEIndex%s\n" (ind depth) info;
      print_expr (depth + 1) array;
      print_expr (depth + 1) index

   | TEIntToReal operand ->
      p "%sTEIntToReal%s\n" (ind depth) info;
      print_expr (depth + 1) operand


let rec print_stmt depth statement =
   let p = Printf.printf in

   match statement with
   | TSEmpty ->
      p "%sTSEmpty\n" (ind depth)

   | TSAssign (destination, value) ->
      p "%sTSAssign\n" (ind depth);
      p "%sdestination:\n" (ind (depth + 1));
      print_expr (depth + 2) destination;
      p "%svalue:\n" (ind (depth + 1));
      print_expr (depth + 2) value

   | TSBlock statements ->
      p "%sTSBlock\n" (ind depth);
      List.iter (print_stmt (depth + 1)) statements

   | TSCall (name, arguments) ->
      p "%sTSCall(%s)\n" (ind depth) name;
      List.iter (print_expr (depth + 1)) arguments

   | TSIf (condition, then_statement, else_statement) ->
      p "%sTSIf\n" (ind depth);
      p "%scondition:\n" (ind (depth + 1));
      print_expr (depth + 2) condition;
      p "%sthen:\n" (ind (depth + 1));
      print_stmt (depth + 2) then_statement;
      (match else_statement with
       | None -> ()
       | Some statement ->
          p "%selse:\n" (ind (depth + 1));
          print_stmt (depth + 2) statement)

   | TSWhile (condition, body) ->
      p "%sTSWhile\n" (ind depth);
      p "%scondition:\n" (ind (depth + 1));
      print_expr (depth + 2) condition;
      p "%sbody:\n" (ind (depth + 1));
      print_stmt (depth + 2) body

   | TSLabel (name, statement) ->
      p "%sTSLabel(%s)\n" (ind depth) name;
      print_stmt (depth + 1) statement

   | TSGoto name ->
      p "%sTSGoto(%s)\n" (ind depth) name

   | TSReturn ->
      p "%sTSReturn\n" (ind depth)

   | TSNew expression ->
      p "%sTSNew\n" (ind depth);
      print_expr (depth + 1) expression

   | TSNewArray (size, array) ->
      p "%sTSNewArray\n" (ind depth);
      p "%ssize:\n" (ind (depth + 1));
      print_expr (depth + 2) size;
      p "%sarray:\n" (ind (depth + 1));
      print_expr (depth + 2) array

   | TSDispose expression ->
      p "%sTSDispose\n" (ind depth);
      print_expr (depth + 1) expression

   | TSDisposeArray expression ->
      p "%sTSDisposeArray\n" (ind depth);
      print_expr (depth + 1) expression


let print_formal depth (mode, names, typ) =
   let passing =
      match mode with
      | ByValue -> "value"
      | ByRef -> "reference"
   in
   Printf.printf "%sformal(%s) [%s] : %s\n"
      (ind depth)
      passing
      (String.concat ", " names)
      (string_of_typ typ)


let print_header depth header =
   match header with
   | HProcedure (name, formals) ->
      Printf.printf "%sProcedure(%s)\n" (ind depth) name;
      List.iter (print_formal (depth + 1)) formals

   | HFunction (name, formals, return_type) ->
      Printf.printf "%sFunction(%s) : %s\n"
         (ind depth) name (string_of_typ return_type);
      List.iter (print_formal (depth + 1)) formals


let rec print_local depth local =
   match local with
   | TLVar groups ->
      Printf.printf "%sTLVar\n" (ind depth);
      List.iter
         (fun (names, typ) ->
            Printf.printf "%s[%s] : %s\n"
               (ind (depth + 1))
               (String.concat ", " names)
               (string_of_typ typ))
         groups

   | TLLabel names ->
      Printf.printf "%sTLLabel [%s]\n"
         (ind depth)
         (String.concat ", " names)

   | TLForward header ->
      Printf.printf "%sTLForward\n" (ind depth);
      print_header (depth + 1) header

   | TLDef (header, body) ->
      Printf.printf "%sTLDef\n" (ind depth);
      print_header (depth + 1) header;
      print_body (depth + 1) body


and print_body depth (body : Typed_ast.body) =
   List.iter (print_local depth) body.locals;
   Printf.printf "%sBlock\n" (ind depth);
   List.iter (print_stmt (depth + 1)) body.block


let print_program (program : Typed_ast.program) =
   Printf.printf "TypedProgram(%s)\n" program.name;
   print_body 1 program.body


let inspect ast =
   let typed_program = Semantic.analyze_program ast in
   print_program typed_program


let () =
   Inspect_common.run "semantic_inspect" inspect