module Bindings = Reducer_Bindings
module Lambda = Reducer_Expression_Lambda
module Result = Belt.Result
module T = Reducer_T

type errorValue = Reducer_ErrorValue.errorValue

exception ErrorException = Reducer_ErrorValue.ErrorException

/*
  Recursively evaluate the expression
*/
let rec evaluate: T.reducerFn = (
  expression,
  context
) => {
  Js.log(`reduce: ${expression->Reducer_Expression_T.toString}`)
  switch expression {
    | T.EBlock(statements) => {
      let innerContext = {...context, bindings: context.bindings->Bindings.extend}
      statements->Js.Array2.reduce(
        (acc, statement) => statement->evaluate(innerContext),
        T.IEvVoid
      )
    }

    | T.EProgram(statements) => {
      Js.log(`bindings: ${context.bindings->Reducer_Bindings.toString}`)
      let res = statements->Js.Array2.reduce(
        (acc, statement) => statement->evaluate(context),
        T.IEvVoid
      )
      Js.log(`bindings after: ${context.bindings->Reducer_Bindings.toString}`)
      res
    }

    | T.EArray(elements) =>
      elements->Js.Array2.map(element => evaluate(element, context))->T.IEvArray

    | T.ERecord(map) =>
      RETodo("TODO")->ErrorException->raise

    | T.EAssign(left, right) => {
      let result = right->evaluate(context)
      let _ = context.bindings->Bindings.set(left, result)
      T.IEvVoid
    }

    | T.ESymbol(name) =>
      switch context.bindings->Bindings.get(name) {
      | Some(v) => v
      | None => Reducer_ErrorValue.RESymbolNotFound(name)->ErrorException->raise
      }

    | T.EValue(value) =>
      value

    | T.ETernary(predicate, trueCase, falseCase) => {
      let predicateResult = predicate->evaluate(context)
      switch predicateResult {
      | T.IEvBool(value) =>
        (value ? trueCase : falseCase)->evaluate(context)
      | _ => REExpectedType("Boolean", "")->ErrorException->raise
      }
    }

    | T.ELambda(parameters, body) =>
      Lambda.makeLambda(parameters, context.bindings, body)->T.IEvLambda

    | T.ECall(fn, args) => {
      let lambda = fn->evaluate(context)
      let argValues = Js.Array2.map(args, arg => arg->evaluate(context))
      switch lambda {
        | T.IEvLambda(lambda) => 
          Lambda.doLambdaCall(lambda, argValues, context.environment, evaluate)
        | _ => REExpectedType("Lambda", "")->ErrorException->raise
      }
    }
  }
}

module BackCompatible = {
  // Those methods are used to support the existing tests
  // If they are used outside limited testing context, error location reporting will fail
  let parse = (peggyCode: string): result<Reducer_T.expression, errorValue> =>
    peggyCode->Reducer_Peggy_Parse.parse->Result.map(Reducer_Peggy_ToExpression.fromNode)

  let evaluate = (expression: Reducer_T.expression): result<Reducer_T.value, errorValue> => {
    let context = Reducer_Context.createDefaultContext()
    try {
      expression->evaluate(context)->Ok
    } catch {
    | ErrorException(e) => Error(e)
    | _ => raise(ErrorException(RETodo("internal exception")))
    }
  }

  let evaluateString = (peggyCode: string): result<Reducer_T.value, errorValue> =>
    parse(peggyCode)->Result.flatMap(evaluate)
}
