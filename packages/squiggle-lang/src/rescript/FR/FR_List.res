open FunctionRegistry_Core
open FunctionRegistry_Helpers

let nameSpace = "List"
let requiresNamespace = true

module Internals = {
  let makeFromNumber = (n: float, value: Reducer_T.value): Reducer_T.value => IEvArray(
    Belt.Array.make(E.Float.toInt(n), value),
  )

  let upTo = (low: float, high: float): Reducer_T.value => IEvArray(
    E.A.Floats.range(low, high, (high -. low +. 1.0)->E.Float.toInt)->E.A2.fmap(Wrappers.evNumber),
  )

  let first = (v: array<Reducer_T.value>): result<Reducer_T.value, string> =>
    v->E.A.first |> E.O.toResult("No first element")

  let last = (v: array<Reducer_T.value>): result<Reducer_T.value, string> =>
    v->E.A.last |> E.O.toResult("No last element")

  let reverse = (array: array<Reducer_T.value>): Reducer_T.value => IEvArray(
    Belt.Array.reverse(array),
  )

  let map = (
    array: array<Reducer_T.value>,
    eLambdaValue,
    env: Reducer_T.environment,
    reducer: Reducer_T.reducerFn,
  ): Reducer_T.value => {
    Belt.Array.map(array, elem =>
      Reducer_Expression_Lambda.doLambdaCall(eLambdaValue, [elem], env, reducer)
    )->Wrappers.evArray
  }

  let reduce = (
    aValueArray,
    initialValue,
    aLambdaValue,
    env: Reducer_T.environment,
    reducer: Reducer_T.reducerFn,
  ) => {
    aValueArray->E.A.reduce(initialValue, (acc, elem) =>
      Reducer_Expression_Lambda.doLambdaCall(aLambdaValue, [acc, elem], env, reducer)
    )
  }

  let reduceReverse = (
    aValueArray,
    initialValue,
    aLambdaValue,
    env: Reducer_T.environment,
    reducer: Reducer_T.reducerFn,
  ) => {
    aValueArray->Belt.Array.reduceReverse(initialValue, (acc, elem) =>
      Reducer_Expression_Lambda.doLambdaCall(aLambdaValue, [acc, elem], env, reducer)
    )
  }

  let filter = (
    aValueArray,
    aLambdaValue,
    env: Reducer_T.environment,
    reducer: Reducer_T.reducerFn,
  ) => {
    Js.Array2.filter(aValueArray, elem => {
      let result = Reducer_Expression_Lambda.doLambdaCall(aLambdaValue, [elem], env, reducer)
      switch result {
      | IEvBool(true) => true
      | _ => false
      }
    })->Wrappers.evArray
  }
}

let library = [
  Function.make(
    ~name="make",
    ~nameSpace,
    ~requiresNamespace=true,
    ~output=EvtArray,
    ~examples=[`List.make(2, "testValue")`],
    ~definitions=[
      //Todo: If the second item is a function with no args, it could be nice to run this function and return the result.
      FnDefinition.make(
        ~name="make",
        ~inputs=[FRTypeNumber, FRTypeAny],
        ~run=(inputs, _, _) => {
          switch inputs {
          | [IEvNumber(number), value] => Internals.makeFromNumber(number, value)->Ok
          | _ => Error(impossibleError)
          }
        },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="upTo",
    ~nameSpace,
    ~requiresNamespace=true,
    ~output=EvtArray,
    ~examples=[`List.upTo(1,4)`],
    ~definitions=[
      FnDefinition.make(
        ~name="upTo",
        ~inputs=[FRTypeNumber, FRTypeNumber],
        ~run=(inputs, _, _) =>
          switch inputs {
          | [IEvNumber(low), IEvNumber(high)] => Internals.upTo(low, high)->Ok
          | _ => impossibleError->Error
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="first",
    ~nameSpace,
    ~requiresNamespace=true,
    ~examples=[`List.first([1,4,5])`],
    ~definitions=[
      FnDefinition.make(
        ~name="first",
        ~inputs=[FRTypeArray(FRTypeAny)],
        ~run=(inputs, _, _) =>
          switch inputs {
          | [IEvArray(array)] => Internals.first(array)->E.R2.errMap(wrapError)
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="last",
    ~nameSpace,
    ~requiresNamespace=true,
    ~examples=[`List.last([1,4,5])`],
    ~definitions=[
      FnDefinition.make(
        ~name="last",
        ~inputs=[FRTypeArray(FRTypeAny)],
        ~run=(inputs, _, _) =>
          switch inputs {
          | [IEvArray(array)] => Internals.last(array)->E.R2.errMap(wrapError)
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="reverse",
    ~nameSpace,
    ~output=EvtArray,
    ~requiresNamespace=false,
    ~examples=[`List.reverse([1,4,5])`],
    ~definitions=[
      FnDefinition.make(
        ~name="reverse",
        ~inputs=[FRTypeArray(FRTypeAny)],
        ~run=(inputs, _, _) =>
          switch inputs {
          | [IEvArray(array)] => Internals.reverse(array)->Ok
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="map",
    ~nameSpace,
    ~output=EvtArray,
    ~requiresNamespace=false,
    ~examples=[`List.map([1,4,5], {|x| x+1})`],
    ~definitions=[
      FnDefinition.make(
        ~name="map",
        ~inputs=[FRTypeArray(FRTypeAny), FRTypeLambda],
        ~run=(inputs, env, reducer) =>
          switch inputs {
          | [IEvArray(array), IEvLambda(lambda)] => Ok(Internals.map(array, lambda, env, reducer))
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="reduce",
    ~nameSpace,
    ~requiresNamespace=false,
    ~examples=[`List.reduce([1,4,5], 2, {|acc, el| acc+el})`],
    ~definitions=[
      FnDefinition.make(
        ~name="reduce",
        ~inputs=[FRTypeArray(FRTypeAny), FRTypeAny, FRTypeLambda],
        ~run=(inputs, env, reducer) =>
          switch inputs {
          | [IEvArray(array), initialValue, IEvLambda(lambda)] =>
            Ok(Internals.reduce(array, initialValue, lambda, env, reducer))
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="reduceReverse",
    ~nameSpace,
    ~requiresNamespace=false,
    ~examples=[`List.reduceReverse([1,4,5], 2, {|acc, el| acc-el})`],
    ~definitions=[
      FnDefinition.make(
        ~name="reduceReverse",
        ~inputs=[FRTypeArray(FRTypeAny), FRTypeAny, FRTypeLambda],
        ~run=(inputs, env, reducer) =>
          switch inputs {
          | [IEvArray(array), initialValue, IEvLambda(lambda)] =>
            Ok(Internals.reduceReverse(array, initialValue, lambda, env, reducer))
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
  Function.make(
    ~name="filter",
    ~nameSpace,
    ~requiresNamespace=false,
    ~examples=[`List.filter([1,4,5], {|x| x>3})`],
    ~definitions=[
      FnDefinition.make(
        ~name="filter",
        ~inputs=[FRTypeArray(FRTypeAny), FRTypeLambda],
        ~run=(inputs, env, reducer) =>
          switch inputs {
          | [IEvArray(array), IEvLambda(lambda)] =>
            Ok(Internals.filter(array, lambda, env, reducer))
          | _ => Error(impossibleError)
          },
        (),
      ),
    ],
    (),
  ),
]
