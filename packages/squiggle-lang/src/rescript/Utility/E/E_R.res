/* R for Result */

exception Assertion(string)
module U = E_U

open Belt.Result
let result = (okF, errF, r) =>
  switch r {
  | Ok(a) => okF(a)
  | Error(err) => errF(err)
  }
let id = e => e |> result(U.id, U.id)
let isOk = Belt.Result.isOk
let getError = (r: result<'a, 'b>) =>
  switch r {
  | Ok(_) => None
  | Error(e) => Some(e)
  }
let fmap = (f: 'a => 'b, r: result<'a, 'c>): result<'b, 'c> => {
  switch r {
  | Ok(r') => Ok(f(r'))
  | Error(err) => Error(err)
  }
}
let bind = (r, f) =>
  switch r {
  | Ok(a) => f(a)
  | Error(err) => Error(err)
  }
let toExn = (msg: string, x: result<'a, 'b>): 'a =>
  switch x {
  | Ok(r) => r
  | Error(_) => raise(Assertion(msg))
  }
let toExnFnString = (errorToStringFn, o) =>
  switch o {
  | Ok(r) => r
  | Error(r) => raise(Assertion(errorToStringFn(r)))
  }
let default = (default, res: Belt.Result.t<'a, 'b>) =>
  switch res {
  | Ok(r) => r
  | Error(_) => default
  }
let merge = (a, b) =>
  switch (a, b) {
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  | (Ok(a), Ok(b)) => Ok((a, b))
  }
let toOption = (e: Belt.Result.t<'a, 'b>) =>
  switch e {
  | Ok(r) => Some(r)
  | Error(_) => None
  }

let errorIfCondition = (errorCondition, errorMessage, r) =>
  errorCondition(r) ? Error(errorMessage) : Ok(r)

let ap = (r, a) =>
  switch r {
  | Ok(f) => Ok(f(a))
  | Error(err) => Error(err)
  }
let ap' = (r, a) =>
  switch r {
  | Ok(f) => fmap(f, a)
  | Error(err) => Error(err)
  }

let liftM2: (('a, 'b) => 'c, result<'a, 'd>, result<'b, 'd>) => result<'c, 'd> = (op, xR, yR) => {
  ap'(fmap(op, xR), yR)
}

let liftJoin2: (('a, 'b) => result<'c, 'd>, result<'a, 'd>, result<'b, 'd>) => result<'c, 'd> = (
  op,
  xR,
  yR,
) => {
  bind(liftM2(op, xR, yR), x => x)
}

let fmap2 = (f, r) =>
  switch r {
  | Ok(r) => r->Ok
  | Error(x) => x->f->Error
  }

//I'm not sure what to call this.
let unify = (a: result<'a, 'b>, c: 'b => 'a): 'a =>
  switch a {
  | Ok(x) => x
  | Error(x) => c(x)
  }
