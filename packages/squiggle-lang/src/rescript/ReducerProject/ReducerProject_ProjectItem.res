// TODO: Use topological sorting to prevent unnecessary runs
module T = ReducerProject_ProjectItem_T

type projectItem = T.projectItem
type t = T.t

let emptyItem: projectItem = {
  source: "",
  rawParse: None,
  expression: None,
  continuation: Reducer_Namespace.make(),
  result: None,
  continues: [],
  includes: []->Ok,
  directIncludes: [],
  includeAsVariables: [],
}
// source -> rawParse -> includes -> expression -> continuation -> result

let getSource = (r: t): T.sourceType => r.source
let getRawParse = (r: t): T.rawParseType => r.rawParse
let getExpression = (r: t): T.expressionType => r.expression
let getContinuation = (r: t): T.continuationArgumentType => r.continuation
let getResult = (r: t): T.resultType => r.result

let getContinues = (r: t): T.continuesType => r.continues
let getIncludes = (r: t): T.includesType => r.includes
let getDirectIncludes = (r: t): array<string> => r.directIncludes
let getIncludesAsVariables = (r: t): T.importAsVariablesType => r.includeAsVariables

let touchSource = (this: t): t => {
  let r = emptyItem
  {
    ...r,
    source: getSource(this),
    continues: getContinues(this),
    includes: getIncludes(this),
    includeAsVariables: getIncludesAsVariables(this),
    directIncludes: getDirectIncludes(this),
  }
}

let touchRawParse = (this: t): t => {
  {
    ...emptyItem,
    source: getSource(this),
    continues: getContinues(this),
    includes: getIncludes(this),
    includeAsVariables: getIncludesAsVariables(this),
    directIncludes: getDirectIncludes(this),
    rawParse: getRawParse(this),
  }
}

let touchExpression = (this: t): t => {
  {
    ...this,
    source: getSource(this),
    continues: getContinues(this),
    includes: getIncludes(this),
    includeAsVariables: getIncludesAsVariables(this),
    directIncludes: getDirectIncludes(this),
    rawParse: getRawParse(this),
    expression: getExpression(this),
  }
}

let resetIncludes = (r: t): t => {
  ...r,
  includes: []->Ok,
  includeAsVariables: [],
  directIncludes: [],
}

let setSource = (r: t, source: T.sourceArgumentType): t =>
  {...r, source: source}->resetIncludes->touchSource

let setRawParse = (r: t, rawParse: T.rawParseArgumentType): t =>
  {...r, rawParse: Some(rawParse)}->touchRawParse

let setExpression = (r: t, expression: T.expressionArgumentType): t =>
  {...r, expression: Some(expression)}->touchExpression

let setContinuation = (r: t, continuation: T.continuationArgumentType): t => {
  ...r,
  continuation: continuation,
}

let setResult = (r: t, result: T.resultArgumentType): t => {
  ...r,
  result: Some(result),
}

let cleanResults = touchExpression

let clean = (this: t): t => {
  ...this,
  source: getSource(this),
  continuation: getContinuation(this),
  result: getResult(this),
}

let getImmediateDependencies = (this: t): T.includesType =>
  getIncludes(this)->Belt.Result.map(Js.Array2.concat(_, getContinues(this)))

let getPastChain = (this: t): array<string> => {
  Js.Array2.concat(getDirectIncludes(this), getContinues(this))
}

let setContinues = (this: t, continues: array<string>): t =>
  {...this, continues: continues}->touchSource

let removeContinues = (this: t): t => {...this, continues: []}->touchSource

let setIncludes = (this: t, includes: T.includesType): t => {
  ...this,
  includes: includes,
}

let setImportAsVariables = (this: t, includeAsVariables: T.importAsVariablesType): t => {
  ...this,
  includeAsVariables: includeAsVariables,
}

let setDirectImports = (this: t, directIncludes: array<string>): t => {
  ...this,
  directIncludes: directIncludes,
}

let parseIncludes = (this: t): t => {
  let rRawImportAsVariables = getSource(this)->ReducerProject_ParseIncludes.parseIncludes
  switch rRawImportAsVariables {
  | Error(e) => resetIncludes(this)->setIncludes(Error(e))
  | Ok(rawImportAsVariables) => {
      let includes = rawImportAsVariables->Belt.Array.map(((_variable, file)) => file)->Ok
      let includeAsVariables =
        rawImportAsVariables->Belt.Array.keep(((variable, _file)) => variable != "")
      let directIncludes =
        rawImportAsVariables
        ->Belt.Array.keep(((variable, _file)) => variable == "")
        ->Belt.Array.map(((_variable, file)) => file)
      {
        ...this,
        includes: includes,
        includeAsVariables: includeAsVariables,
        directIncludes: directIncludes,
      }
    }
  }
}
let doRawParse = (this: t): T.rawParseArgumentType => this->getSource->Reducer_Peggy_Parse.parse

let rawParse = (this: t): t =>
  this->getRawParse->E.O2.defaultFn(() => doRawParse(this))->setRawParse(this, _)

let doBuildExpression = (this: t): T.expressionType =>
  this
  ->getRawParse
  ->Belt.Option.map(o => o->Belt.Result.map(r => r->Reducer_Peggy_ToExpression.fromNode))

let buildExpression = (this: t): t => {
  let this = this->rawParse
  switch this->getExpression {
  | Some(_) => this // cached
  | None =>
    this->doBuildExpression->Belt.Option.map(setExpression(this, _))->E.O2.defaultFn(() => this)
  }
}

let failRun = (this: t, e: Reducer_ErrorValue.errorValue): t =>
  this->setResult(e->Error)->setContinuation(Reducer_Namespace.make())

let doRun = (this: t, context: Reducer_T.context): t =>
  switch this->getExpression {
  | Some(expressionResult) =>
    switch expressionResult {
    | Ok(expression) =>
      try {
        let (result, contextAfterEvaluation) = Reducer_Expression.evaluate(expression, context)
        this
        ->setResult(result->Ok)
        ->setContinuation(contextAfterEvaluation.bindings->Reducer_Bindings.locals)
      } catch {
      | Reducer_ErrorValue.ErrorException(e) => this->failRun(e)
      | _ => this->failRun(RETodo("unhandled rescript exception"))
      }
    | Error(e) => this->failRun(e)
    }
  | None => this->failRun(RETodo("attempt to run without expression"))
  }

let run = (this: t, context: Reducer_T.context): t => {
  let this = this->buildExpression
  switch this->getResult {
  | Some(_) => this
  | None => this->doRun(context)
  }
}
