// types are disabled until review and rewrite for 0.5 interpreter compatibility
/*
module ProjectAccessorsT = ReducerProject_ProjectAccessors_T
module T = Reducer_Dispatch_T
module TypeChecker = Reducer_Type_TypeChecker
open Reducer_Value

type errorValue = Reducer_ErrorValue.errorValue

let makeFromTypes = jumpTable => {
  let dispatchChainPiece: T.dispatchChainPiece = (
    (fnName, fnArgs): functionCall,
    accessors: ProjectAccessorsT.t,
  ) => {
    let jumpTableEntry = jumpTable->Js.Array2.find(elem => {
      let (candidName, candidType, _) = elem
      candidName == fnName && TypeChecker.checkITypeArgumentsBool(candidType, fnArgs)
    })
    switch jumpTableEntry {
    | Some((_, _, bridgeFn)) => bridgeFn(fnArgs, accessors)->Some
    | _ => None
    }
  }
  dispatchChainPiece
}

*/
