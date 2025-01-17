type internalExpressionValueType = Reducer_Value.internalExpressionValueType
type errorValue = Reducer_ErrorValue.errorValue

/*
  Function Registry "Type". A type, without any other information.
  Like, #Float
*/
type rec frType =
  | FRTypeNumber
  | FRTypeBool
  | FRTypeNumeric
  | FRTypeDate
  | FRTypeTimeDuration
  | FRTypeDistOrNumber
  | FRTypeDist
  | FRTypeLambda
  | FRTypeRecord(frTypeRecord)
  | FRTypeDict(frType)
  | FRTypeArray(frType)
  | FRTypeString
  | FRTypeAny
  | FRTypeVariant(array<string>)
and frTypeRecord = array<frTypeRecordParam>
and frTypeRecordParam = (string, frType)

type frValueDistOrNumber = FRValueNumber(float) | FRValueDist(DistributionTypes.genericDist)

type fnDefinition = {
  name: string,
  inputs: array<frType>,
  run: (
    array<Reducer_T.value>,
    Reducer_T.environment,
    Reducer_T.reducerFn,
  ) => result<Reducer_T.value, errorValue>,
}

type function = {
  name: string,
  definitions: array<fnDefinition>,
  requiresNamespace: bool,
  nameSpace: string,
  output: option<internalExpressionValueType>,
  examples: array<string>,
  description: option<string>,
  isExperimental: bool,
}

module FRType = {
  type t = frType
  let rec toString = (t: t) =>
    switch t {
    | FRTypeNumber => "number"
    | FRTypeBool => "bool"
    | FRTypeDate => "date"
    | FRTypeTimeDuration => "duration"
    | FRTypeNumeric => "numeric"
    | FRTypeDist => "distribution"
    | FRTypeDistOrNumber => "distribution|number"
    | FRTypeRecord(r) => {
        let input = ((name, frType): frTypeRecordParam) => `${name}: ${toString(frType)}`
        `{${r->E.A2.fmap(input)->E.A2.joinWith(", ")}}`
      }
    | FRTypeArray(r) => `list(${toString(r)})`
    | FRTypeLambda => `lambda`
    | FRTypeString => `string`
    | FRTypeVariant(_) => "variant"
    | FRTypeDict(r) => `dict(${toString(r)})`
    | FRTypeAny => `any`
    }

  let rec matchWithValue = (t: t, r: Reducer_T.value): bool =>
    switch (t, r) {
    | (FRTypeAny, _) => true
    | (FRTypeString, IEvString(_)) => true
    | (FRTypeNumber, IEvNumber(_)) => true
    | (FRTypeBool, IEvBool(_)) => true
    | (FRTypeDate, IEvDate(_)) => true
    | (FRTypeTimeDuration, IEvTimeDuration(_)) => true
    | (FRTypeDistOrNumber, IEvNumber(_)) => true
    | (FRTypeDistOrNumber, IEvDistribution(_)) => true
    | (FRTypeDist, IEvDistribution(_)) => true
    | (FRTypeNumeric, IEvNumber(_)) => true
    | (FRTypeNumeric, IEvDistribution(Symbolic(#Float(_)))) => true
    | (FRTypeLambda, IEvLambda(_)) => true
    | (FRTypeArray(intendedType), IEvArray(elements)) =>
      elements->Belt.Array.every(v => matchWithValue(intendedType, v))
    | (FRTypeDict(r), IEvRecord(map)) =>
      map->Belt.Map.String.valuesToArray->Belt.Array.every(v => matchWithValue(r, v))
    | (FRTypeRecord(recordParams), IEvRecord(map)) =>
      recordParams->Belt.Array.every(((name, input)) => {
        switch map->Belt.Map.String.get(name) {
        | Some(v) => matchWithValue(input, v)
        | None => false
        }
      })
    | _ => false
    }

  let matchWithValueArray = (inputs: array<t>, args: array<Reducer_T.value>): bool => {
    let isSameLength = E.A.length(inputs) == E.A.length(args)
    if !isSameLength {
      false
    } else {
      E.A.zip(inputs, args)->Belt.Array.every(((input, arg)) => matchWithValue(input, arg))
    }
  }
}

module FnDefinition = {
  type t = fnDefinition

  let toString = (t: t) => {
    let inputs = t.inputs->E.A2.fmap(FRType.toString)->E.A2.joinWith(", ")
    t.name ++ `(${inputs})`
  }

  let isMatch = (t: t, args: array<Reducer_T.value>) => {
    FRType.matchWithValueArray(t.inputs, args)
  }

  let run = (
    t: t,
    args: array<Reducer_T.value>,
    env: Reducer_T.environment,
    reducer: Reducer_T.reducerFn,
  ) => {
    switch t->isMatch(args) {
    | true => t.run(args, env, reducer)
    | false => REOther("Incorrect Types")->Error
    }
  }

  let make = (~name, ~inputs, ~run, ()): t => {
    name: name,
    inputs: inputs,
    run: run,
  }
}

module Function = {
  type t = function

  type functionJson = {
    name: string,
    definitions: array<string>,
    examples: array<string>,
    description: option<string>,
    isExperimental: bool,
  }

  let make = (
    ~name,
    ~nameSpace,
    ~requiresNamespace,
    ~definitions,
    ~examples=?,
    ~output=?,
    ~description=?,
    ~isExperimental=false,
    (),
  ): t => {
    name: name,
    nameSpace: nameSpace,
    definitions: definitions,
    output: output,
    examples: examples |> E.O.default([]),
    isExperimental: isExperimental,
    requiresNamespace: requiresNamespace,
    description: description,
  }

  let toJson = (t: t): functionJson => {
    name: t.name,
    definitions: t.definitions->E.A2.fmap(FnDefinition.toString),
    examples: t.examples,
    description: t.description,
    isExperimental: t.isExperimental,
  }
}

module Registry = {
  type fnNameDict = Belt.Map.String.t<array<fnDefinition>>
  type registry = {functions: array<function>, fnNameDict: fnNameDict}

  let toJson = (r: registry) => r.functions->E.A2.fmap(Function.toJson)
  let allExamples = (r: registry) => r.functions->E.A2.fmap(r => r.examples)->E.A.concatMany
  let allExamplesWithFns = (r: registry) =>
    r.functions->E.A2.fmap(fn => fn.examples->E.A2.fmap(example => (fn, example)))->E.A.concatMany

  let allNames = (r: registry) => r.fnNameDict->Belt.Map.String.keysToArray

  let _buildFnNameDict = (r: array<function>): fnNameDict => {
    // Three layers of reduce:
    // 1. functions
    // 2. definitions of each function
    // 3. name variations of each definition
    r->Belt.Array.reduce(Belt.Map.String.empty, (acc, fn) =>
      fn.definitions->Belt.Array.reduce(acc, (acc, def) => {
        let names =
          [
            fn.nameSpace == "" ? [] : [`${fn.nameSpace}.${def.name}`],
            fn.requiresNamespace ? [] : [def.name],
          ]->E.A.concatMany

        names->Belt.Array.reduce(acc, (acc, name) => {
          switch acc->Belt.Map.String.get(name) {
          | Some(fns) => {
              let _ = fns->Js.Array2.push(def) // mutates the array, no need to update acc
              acc
            }
          | None => acc->Belt.Map.String.set(name, [def])
          }
        })
      })
    )
  }

  let make = (fns: array<function>): registry => {
    let dict = _buildFnNameDict(fns)
    {functions: fns, fnNameDict: dict}
  }

  let call = (
    registry,
    fnName: string,
    args: array<Reducer_T.value>,
    env: Reducer_T.environment,
    reducer: Reducer_T.reducerFn,
  ): result<Reducer_T.value, errorValue> => {
    switch Belt.Map.String.get(registry.fnNameDict, fnName) {
    | Some(definitions) => {
        let showNameMatchDefinitions = () => {
          let defsString =
            definitions
            ->E.A2.fmap(FnDefinition.toString)
            ->E.A2.fmap(r => `[${r}]`)
            ->E.A2.joinWith("; ")
          `There are function matches for ${fnName}(), but with different arguments: ${defsString}`
        }

        let match = definitions->Js.Array2.find(def => def->FnDefinition.isMatch(args))
        switch match {
        | Some(def) => def->FnDefinition.run(args, env, reducer)
        | None => REOther(showNameMatchDefinitions())->Error
        }
      }
    | None => RESymbolNotFound(fnName)->Error
    }
  }
}
