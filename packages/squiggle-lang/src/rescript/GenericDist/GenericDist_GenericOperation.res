type operation = GenericDist_Types.Operation.genericFunction
type genericDist = GenericDist_Types.genericDist
type error = GenericDist_Types.error

// TODO: It could be great to use a cache for some calculations (basically, do memoization). Also, better analytics/tracking could go a long way.

type params = {
  sampleCount: int,
  xyPointLength: int,
}

let genericParams = {
  sampleCount: 1000,
  xyPointLength: 1000,
}

type wrapped = (genericDist, params)

let wrapWithParams = (g: genericDist, f: params): wrapped => (g, f)
type outputType = [
  | #Dist(genericDist)
  | #Error(error)
  | #Float(float)
]

let fromResult = (r: result<outputType, error>): outputType =>
  switch r {
  | Ok(o) => o
  | Error(e) => #Error(e)
  }

let rec run = (extra, fnName: operation): outputType => {
  let {sampleCount, xyPointLength} = extra
  let reCall = (~extra=extra, ~fnName=fnName, ()) => {
    run(extra, fnName)
  }
  let toPointSet = r => {
    switch reCall(~fnName=#fromDist(#toDist(#toPointSet), r), ()) {
    | #Dist(#PointSet(p)) => Ok(p)
    | #Error(r) => Error(r)
    | _ => Error(ImpossiblePath)
    }
  }
  let toSampleSet = r => {
    switch reCall(~fnName=#fromDist(#toDist(#toSampleSet(sampleCount)), r), ()) {
    | #Dist(#SampleSet(p)) => Ok(p)
    | #Error(r) => Error(r)
    | _ => Error(ImpossiblePath)
    }
  }

  let fromDistFn = (subFn: GenericDist_Types.Operation.fromDist, dist: genericDist) =>
    switch subFn {
    | #toFloat(fnName) =>
      GenericDist.operationToFloat(toPointSet, fnName, dist)
      |> E.R.fmap(r => #Float(r))
      |> fromResult
    | #toString => #Error(GenericDist_Types.NotYetImplemented)
    | #toDist(#normalize) => dist |> GenericDist.normalize |> (r => #Dist(r))
    | #toDist(#truncate(left, right)) =>
      dist
      |> GenericDist.Truncate.run(toPointSet, left, right)
      |> E.R.fmap(r => #Dist(r))
      |> fromResult
    | #toDist(#toPointSet) =>
      dist
      |> GenericDist.toPointSet(xyPointLength)
      |> E.R.fmap(r => #Dist(#PointSet(r)))
      |> fromResult
    | #toDist(#toSampleSet(n)) =>
      dist |> GenericDist.sampleN(n) |> E.R.fmap(r => #Dist(#SampleSet(r))) |> fromResult
    | #toDistCombination(#Algebraic, _, #Float(_)) => #Error(NotYetImplemented)
    | #toDistCombination(#Algebraic, operation, #Dist(dist2)) =>
      dist
      |> GenericDist.AlgebraicCombination.run(toPointSet, toSampleSet, operation, dist2)
      |> E.R.fmap(r => #Dist(r))
      |> fromResult
    | #toDistCombination(#Pointwise, operation, #Dist(dist2)) =>
      dist
      |> GenericDist.pointwiseCombination(toPointSet, operation, dist2)
      |> E.R.fmap(r => #Dist(r))
      |> fromResult
    | #toDistCombination(#Pointwise, operation, #Float(f)) =>
      dist
      |> GenericDist.pointwiseCombinationFloat(toPointSet, operation, f)
      |> E.R.fmap(r => #Dist(r))
      |> fromResult
    }

  switch fnName {
  | #fromDist(subFn, dist) => fromDistFn(subFn, dist)
  | #fromFloat(subFn, float) => reCall(
      ~fnName=#fromDist(subFn, #Symbolic(SymbolicDist.Float.make(float))),
      (),
    )
  | _ => #Error(NotYetImplemented)
  }
}
