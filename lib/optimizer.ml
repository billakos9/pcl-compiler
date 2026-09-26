open Ast
open Typed_ast


let with_node expression node =
   { expression with node }


let integer_of_int64 value =
   let minimum = Int64.of_int Stdlib.min_int in
   let maximum = Int64.of_int Stdlib.max_int in
   if Int64.compare value minimum < 0
      || Int64.compare value maximum > 0
   then
      None
   else
      Some (Int64.to_int value)


let fold_integer_arithmetic operator left right =
   let left = Int64.of_int left in
   let right = Int64.of_int right in
   let result =
      match operator with
      | BPlus -> Some (Int64.add left right)
      | BMinus -> Some (Int64.sub left right)
      | BTimes -> Some (Int64.mul left right)
      | BDiv when right <> 0L -> Some (Int64.div left right)
      | BMod when right <> 0L -> Some (Int64.rem left right)
      | _ -> None
   in
   Option.bind result integer_of_int64


let fold_comparison operator comparison =
   match operator with
   | BEq -> Some (comparison = 0)
   | BNe -> Some (comparison <> 0)
   | BLt -> Some (comparison < 0)
   | BGt -> Some (comparison > 0)
   | BLe -> Some (comparison <= 0)
   | BGe -> Some (comparison >= 0)
   | _ -> None


let is_finite value =
   match classify_float value with
   | FP_normal
   | FP_subnormal
   | FP_zero -> true
   | FP_infinite
   | FP_nan -> false


let fold_real_arithmetic operator left right =
   let result =
      match operator with
      | BPlus -> Some (left +. right)
      | BMinus -> Some (left -. right)
      | BTimes -> Some (left *. right)
      | BFDiv -> Some (left /. right)
      | _ -> None
   in
   match result with
   | Some value when is_finite value -> Some value
   | Some _
   | None -> None


let fold_literal_binary expression operator left right =
   match left.node, right.node with
   | TEInt left_value, TEInt right_value ->
      (match fold_integer_arithmetic operator left_value right_value with
      | Some value -> Some (with_node expression (TEInt value))
      | None ->
         Option.map
            (fun value -> with_node expression (TEBool value))
            (fold_comparison operator (Int.compare left_value right_value)))

   | TEReal left_value, TEReal right_value ->
      (match fold_real_arithmetic operator left_value right_value with
      | Some value -> Some (with_node expression (TEReal value))
      | None ->
         Option.map
            (fun value -> with_node expression (TEBool value))
            (fold_comparison operator (Float.compare left_value right_value)))

   | TEChar left_value, TEChar right_value ->
      Option.map
         (fun value -> with_node expression (TEBool value))
         (fold_comparison operator (Char.compare left_value right_value))

   | TEBool left_value, TEBool right_value ->
      let comparison = Bool.compare left_value right_value in
      Option.map
         (fun value -> with_node expression (TEBool value))
         (fold_comparison operator comparison)

   | TENil, TENil ->
      (match operator with
      | BEq -> Some (with_node expression (TEBool true))
      | BNe -> Some (with_node expression (TEBool false))
      | _ -> None)

   | _ -> None


let simplify_binary expression operator left right =
   match fold_literal_binary expression operator left right with
   | Some folded -> folded
   | None ->
      match operator, left.node, right.node with
      | BPlus, _, TEInt 0
      | BMinus, _, TEInt 0
      | BTimes, _, TEInt 1
      | BAnd, _, TEBool true
      | BOr, _, TEBool false ->
         with_node expression left.node

      | BPlus, TEInt 0, _
      | BTimes, TEInt 1, _
      | BAnd, TEBool true, _
      | BOr, TEBool false, _ ->
         with_node expression right.node

      | BAnd, TEBool false, _ ->
         with_node expression (TEBool false)

      | BOr, TEBool true, _ ->
         with_node expression (TEBool true)

      | _ ->
         with_node expression (TEBinop (operator, left, right))


let rec optimize_expr expression =
   match expression.node with
   | TEBinop (operator, left, right) ->
      let optimized_left = optimize_expr left in
      let optimized_right = optimize_expr right in
      simplify_binary expression operator optimized_left optimized_right

   | TEUnop (operator, operand) ->
      let optimized_operand = optimize_expr operand in
      (match operator, optimized_operand.node with
      | UPlus, (TEInt _ | TEReal _) ->
         with_node expression optimized_operand.node

      | UMinus, TEInt value ->
         let negated = Int64.neg (Int64.of_int value) in
         (match integer_of_int64 negated with
         | Some result -> with_node expression (TEInt result)
         | None -> with_node expression (TEUnop (operator, optimized_operand)))

      | UMinus, TEReal value when is_finite (-.value) ->
         with_node expression (TEReal (-.value))

      | UNot, TEBool value ->
         with_node expression (TEBool (not value))

      | _ ->
         with_node expression (TEUnop (operator, optimized_operand)))

   | TECall (name, arguments) ->
      with_node expression (TECall (name, List.map optimize_expr arguments))

   | TEIndex (array, index) ->
      with_node expression
         (TEIndex (optimize_expr array, optimize_expr index))

   | TEIntToReal operand ->
      let optimized_operand = optimize_expr operand in
      (match optimized_operand.node with
      | TEInt value ->
         with_node expression (TEReal (float_of_int value))
      | _ ->
         with_node expression (TEIntToReal optimized_operand))

   | TEId _
   | TEResult
   | TEInt _
   | TEReal _
   | TEChar _
   | TEString _
   | TEBool _
   | TENil ->
      expression


let rec optimize_stmt statement =
   match statement with
   | TSEmpty
   | TSGoto _
   | TSReturn ->
      statement

   | TSAssign (destination, value) ->
      TSAssign (optimize_expr destination, optimize_expr value)

   | TSBlock statements ->
      TSBlock (List.map optimize_stmt statements)

   | TSCall (name, arguments) ->
      TSCall (name, List.map optimize_expr arguments)

   | TSIf (condition, then_statement, else_statement) ->
      TSIf
         ( optimize_expr condition,
           optimize_stmt then_statement,
           Option.map optimize_stmt else_statement )

   | TSWhile (condition, body) ->
      TSWhile (optimize_expr condition, optimize_stmt body)

   | TSLabel (name, labeled_statement) ->
      TSLabel (name, optimize_stmt labeled_statement)

   | TSNew expression ->
      TSNew (optimize_expr expression)

   | TSNewArray (size, array) ->
      TSNewArray (optimize_expr size, optimize_expr array)

   | TSDispose expression ->
      TSDispose (optimize_expr expression)

   | TSDisposeArray expression ->
      TSDisposeArray (optimize_expr expression)


let rec optimize_local local =
   match local with
   | TLDef (header, body) ->
      TLDef (header, optimize_body body)
   | TLVar _
   | TLLabel _
   | TLForward _ ->
      local


and optimize_body body =
   {
      locals = List.map optimize_local body.locals;
      block = List.map optimize_stmt body.block;
   }


let optimize_program program =
   { program with body = optimize_body program.body }
