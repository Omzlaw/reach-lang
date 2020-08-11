#lang scribble/manual
@(require "lib.rkt")

@title[#:version reach-vers #:tag "ref-programs"]{Reach Programs}

This document describes the structure and content of Reach @tech{programs}, including
their syntactic forms,
the @tech{standard library},
and the standards of @tech{valid} programs.

A Reach @deftech{program} is
a @tech{module} @tech{export} which is a @tech{Reach.App}, as defined by a @tech{source file}.

@tech{Programs} may be @tech{compile}d using the command
@litchar{reachc SOURCE EXPORT}.


@section{Validity}

Reach imposes further restrictions on syntactically well-formed programs.
These restrictions are described throughout this manual using the term @deftech{valid} to refer to constructions that obey the restrictions,
and the term @deftech{invalid} to refer to constructions that do not obey them.

It is always @tech{invalid} to use a @tech{value} with an operation for which it is undefined.
For example, @reachin{1 + true} is @tech{invalid}.
In other words, Reach enforces a static type discipline.


@section{Modules}

A Reach @deftech{source file} is a textual file which specifies a Reach @tech{module}.
It is traditionally given the file extension @litchar{rsh},
e.g. @filepath{dao.rsh}.

A @deftech{module} starts with @reachin{'reach @|reach-short-vers|';}
followed by a sequence of @tech{imports} and @tech{identifier definitions}.
A module must contain one or more @tech{exports}.


@section{Imports}

@reach{import "games-of-chance.rsh";}

When a @tech{module}, @litchar{X}, contains an @deftech{import},
written @reachin{import "LIB.rsh";},
then the path @filepath{LIB.rsh} must resolve to another Reach @tech{source file}.
The @tech{exports} from the @tech{module} defined by @filepath{LIB.rsh} are included in the set of @tech{bound identifier}s in @litchar{X}.
@tech{Import} cycles are @tech{invalid}.

@margin-note{The path given to an @tech{import} may include @litchar{..} to specify files outside the current directory.
Relative paths resolve relative to the parent directory of the @tech{source file} in which they appear.}


@section{Comments}

@reach{
       // single-line comment
       /* multi-line
       * comment
       */ }

Comments are text that is ignored by the compiler.  Text starting with @litchar{//} up until the end of the line forms a @deftech{single-line comment}.  Text enclosed with @litchar{/*} and @litchar{*/} forms a @deftech{multi-line comment}.  It is @tech{invalid} to nest a @tech{multi-line comment} within a @tech{multi-line comment}.


@section{Reach.App}

@reach{
export const main =
  Reach.App({}, [["A", {displayResult: Fun(Int, Null)}]], (A) => {
    const result = 0;
    A.only(() => { interact.displayResult(result); })
    return result;
  });
}

@deftech{Reach.App} is a function which accepts three arguments:
@litchar{options},
@litchar{participantDefinitions},
and @litchar{program}.

The @litchar{options} argument is currently unused.

The @litchar{participantDefinitions} argument is an array of tuples.
Each tuple is a pair of
@litchar{participantName}
and @litchar{participantInteractInterface}.
@litchar{participantName} is a string which indicates the name of the participant function in the generated @tech{backend} code. Each @litchar{participantName} must be unique.
@litchar{participantInteractInterface} is an object where each field indicates the type of a function or value which must be provided to the @tech{backend} by the @tech{frontend} for @tech{interact}ing with the participant.

The @litchar{program} argument is a function. The arguments this function accepts must match the number and order of @litchar{participantDefinitions}. The function body is the program to be @tech{compile}d.


@section{Types}

Reach's @deftech{type}s are:

@itemlist[
  @item{@reachin{Null}.}
  @item{@reachin{Bool}, which denotes a boolean.}
  @item{@reachin{UInt256}, which denotes an unsigned integer of 256 bits.}
  @item{@reachin{bytes}, which denotes a string of bytes.}
  @item{@reachin{Address}, which denotes an @tech{account} @tech{address}.}
  @item{@reachin{Fun([...TArgs], TRet)}, which denotes a function type.}
  @item{@reachin{Array(...TArgs)}, which denotes a tuple.}
  @item{@reachin{Obj({...TFields})}, which denotes an object.}]


@section{Identifier Definitions}

An @deftech{identifier definition} is either
a @tech{value definition}
or a @tech{function definition}.
Each of these introduces one or more @deftech{bound identifier}s.

@(hrule)
@reach{
  const DELAY = 10;
  const [ Good, Bad ] = [ 42, 43 ]; }

@margin-note{@tech{Valid} @deftech{identifiers} follow the same rules as JavaScript identifiers:
they may consist of Unicode alphanumeric characters,
or @reachin{_} or @reachin{$},
but may not begin with a digit.}

A @deftech{value definition} is written @reachin{const LHS = RHS;} where @reachin{LHS} is either a single identifier, e.g. @reachin{isDelicious}, or an array of identifiers, e.g. @reachin{[ bestSushi, mediumestSushi, worstSushi ]}, and @reachin{RHS} is an @tech{expression}. @reachin{RHS} must evaluate to as many @tech{values} as there are identifiers in @reachin{LHS}. Those @tech{values} are available as their corresponding @tech{bound identifier}s in the rest of the program.

@(hrule)
@reach{
  function randomBool() {
    return (random() % 2) == 0; }; }

A @deftech{function definition}, written @reachin{function FUN(ARG_0, ..., ARG_n) BLOCK;}, defines @reachin{FUN} as a function which abstracts its @deftech{function body}, the @tech{block} @reachin{BLOCK}, over the identifiers @reachin{ARG_0} through @reachin{ARG_n}.

@(hrule)

All identifiers in Reach programs must be @deftech{unbound} at the position of the program where they are bound, i.e., it is @tech{invalid} to shadow identifiers with new definitions. For example,

@reach{
 const x = 3;
 const x = 4; }

is @tech{invalid}. This restriction is independent of whether a binding is only known to a single @tech{participant}. For example,

@reach{
 Alice.only(() => {
   const x = 3; });
 Bob.only(() => {
   const x = 3; }); }

is @tech{invalid}.

@(hrule)

Top-level @tech{identifier definitions} may be @deftech{export}ed
by writing @litchar{export const} in place of @litchar{const}.
An @tech{export}ed identifier in a given @tech{module} may be @tech{import}ed by other @tech{modules}.

@section{Blocks}

@reach{
  { return 42; }
  { const x = 31;
    return x + 11; }
  { if ( x < y ) {
      return "Why";
    } else {
      return "Ecks"; } } }

A @deftech{block} is a sequence of @tech{statements} surrounded by braces, i.e. @litchar["{"] and @litchar["}"].

@section{Statements}

There are a large variety of different @deftech{statements} in Reach programs.

Each @tech{statement} affects the meaning of the subsequent @tech{statements}, which is called its @deftech{tail}. For example, if @reachin{{X; Y; Z;}} is a @tech{block}, then @reachin{X}'s @tech{tail} is @reachin{{Y; Z;}} and @reachin{Y}'s @tech{tail} is @reachin{{Z;}}.

Distinct from @tech{tails} are @deftech{continuations} which include everything after the @tech{statement}. For example, in @reachin{{{X; Y;}; Z;}}, @reachin{X}'s @tech{tail} is just @reachin{Y}, but its @tech{continuation} is @reachin{{Y;}; Z;}.

@tech{Tails} are statically apparent from the structure of the program source code, while @tech{continuations} are influenced by function calls.

A sequence of @tech{statements} that does not end in a @deftech{terminator statement}
(a @tech{statement} with no @tech{tail}),
such as a @tech{return statement} or @tech{continue statement}
is treated as if it ended with @reachin{return null;}.

The remainder of this section enumerates each kind of @tech{statement}.

@subsection{Return statements}

@reach{
 return 17;
 return 3 + 4;
 return f(2, false);
 return; }

A @deftech{return statement}, written @reachin{return EXPR;}, where @reachin{EXPR} is an @tech{expression} evaluates to the same @tech{value} as @reachin{EXPR}. As a special case, @reachin{return;} is interpreted the same as @reachin{return [];}, that is, it evaluates to zero values.

A @tech{return statement} is a @tech{terminator statement}, so it must have an empty @tech{tail}. For example,

@reach{
 { return 1;
   return 2; } }

is @tech{invalid}, because the first @reachin{return}'s @tech{tail} is not empty.

@subsection{Identifier definition statements}

If a @tech{value definition} or @tech{function definition} occurs in a @tech{statement} position, then the identifiers are bound in the @tech{statement}'s @tech{tail}. For example,

@reach{
 const [ x, y ] = [ 3, 4 ];
 const z = x + y;
 return z; }

evaluates to @reachin{7}. And,

@reach{
 function f(x) { return x+1; };
 return f(1); }

evaluates to @reachin{2}.

@subsection{Conditional statements}

@reach{
 if ( 1 + 2 < 3 ) {
   return "Yes!";
 } else {
   return "No, waaah!"; } }

A @deftech{conditional statement},
written @reachin{if (COND) TRUE else FALSE},
where @reachin{COND} is an @tech{expression} which evaluates to a boolean
and @reachin{TRUE} and @reachin{FALSE} as @tech{statements}
(potentially @tech{block statements}),
selects between the @reachin{TRUE} @tech{statement} and @reachin{FALSE} @tech{statement} based on whether @reachin{COND} evaluates to @reachin{true}.

Both @reachin{TRUE} and @reachin{FALSE} have empty @tech{tails}, i.e. the @tech{tail} of the @tech{conditional statement} is not propagated. For example,

@reach{
 if ( x < y ) {
   const z = 3; }
 else {
   const z = 4; }
 return z; }

is erroneous, because the identifier @reachin{z} is not bound outside the @tech{conditional statement}.

A @tech{conditional statement} may only include a @tech{consensus transfer} in @reachin{TRUE} or @reachin{FALSE} if it is within a @tech{consensus step}.

@subsection{Block statements}

A @deftech{block statement} is when a @tech{block} occurs in a @tech{statement} position, then it establishes a local, separate scope for the definitions of identifiers within that @tech{block}. In other words, the @tech{block} is evaluated for effect, but the @tech{tail} of the @tech{statements} within the @tech{block} are isolated from the surrounding @tech{tail}. For example,

@reach{
 const x = 4;
 return x; }

evaluates to @reachin{4}, but

@reach{
 { const x = 4; }
 return x; }

is erroneous, because the identifier @reachin{x} is not bound outside the @tech{block statement}.

@subsection{Expression statements}

@reach{
 4;
 f(2, true); }

An @tech{expression}, @reachin{E}, in a @tech{statement} position is equivalent to the @tech{block statement} @reachin{{ return E; }}.

@subsection{Local step}

@reach{
 Alice.only(() => {
   const pretzel = random(); }); }

A @tech{local step} statement is written @reachin{PART.only(() => BLOCK)}, where @reachin{PART} is a @tech{participant} identifier and @reachin{BLOCK} is a @tech{block}. Any bindings defined within the @tech{block} of a @tech{local step} are available in the @tech{statement}'s @tech{tail} as new @tech{local state}. For example,

@reach{
 Alice.only(() => {
   const x = 3; });
 Alice.only(() => {
   const y = x + 1; }); }

is a @tech{valid} program where @reachin{Alice}'s @tech{local state} includes the @tech{private} values @reachin{x} (bound to @reachin{3}) and @reachin{y} (bound to @reachin{4}). However, such bindings are @emph{not} @tech{consensus state}, so they are purely @tech{local state}. For example,

@reach{
 Alice.only(() => {
   const x = 3; });
 Bob.only(() => {
   const y = x + 1; }); }

is an @tech{invalid} program, because @reachin{Bob} does not know @reachin{x}.

@subsection{Consensus transfers}

@reach{
 Alice.publish(wagerAmount)
      .pay(wagerAmount)
      .timeout(DELAY, () => {
        Bob.publish();
        commit();
        return false; }); }
@reach{
 Alice.publish(wagerAmount)
      .pay(wagerAmount)
      .timeout(DELAY, closeTo(Bob, false)); }

      A @tech{consensus transfer} is written @reachin{PART.publish(ID_0, ..., ID_n).pay(PAY_EXPR).timeout(DELAY_EXPR, TIMEOUT_EXPR)}, where @reachin{PART} is a @tech{participant} identifier, @reachin{ID_0} through @reachin{ID_n} are identifiers for @reachin{PART}'s @tech{public} @tech{local state}, @reachin{PAY_EXPR} is a @tech{public} @tech{expression} evaluating to an amount of @tech{network tokens}, @reachin{DELAY_EXPR} is a @tech{public} @tech{expression} that depends on only @tech{consensus state} and evaluates to a @tech{time delta} represented by a natural number, @reachin{TIMEOUT_EXPR} is an @tech{expression} that evaluates to a @tech{timeout} represented by a zero-arity function, which will be executed after @reachin{DELAY_EXPR} units of @tech{time} have passed from the end of the last @tech{consensus step} without @reachin{PART} executing this @tech{consensus transfer}. The @tech{tail} of a @tech{consensus transfer} @tech{statement} is a @tech{consensus step}, which is finalized with a @tech{commit statement}, which must occur in the @tech{tail}.

The @reachin{publish} component exclusive-or the @reachin{pay} component may be omitted, if either there is no @tech{publication} or no @tech{transfer} of @tech{network tokens} to accompany this @tech{consensus transfer}. The @reachin{timeout} component may always be omitted. For example, the following are all @tech{valid}:

@reach{
 Alice.publish(coinFlip);

 Alice.pay(penaltyAmount);

 Alice.publish(coinFlip)
      .timeout(DELAY, closeTo(Bob, false));

 Alice.pay(penaltyAmount)
      .timeout(DELAY, () => {
        Bob.publish();
        commit();
        return false; }); }

@subsection{Commit statements}

@reach{
 commit(); }

A @deftech{commit statement}, written @reachin{commit();}, @tech{commits} to @tech{statement}'s @tech{continuation} as the next @tech{step} of the @DApp computation. In other words, it ends the current @tech{consensus step} and allows more @tech{local steps}.

@subsection{While statements}

@reach{
 var [ heap1, heap2 ] = [ 21, 21 ];
 invariant(balance() == 2 * wagerAmount);
 while ( heap1 + heap2 > 0 ) {
   ....
   [ heap1, heap2 ] = [ heap1 - 1, heap2 ];
   continue; } }

A @deftech{while statement} may occur within a @tech{consensus step} and is written:

@reach{
 var [ VAR_0, ..., VAR_n ] = INIT_EXPR;
 invariant(INVARIANT_EXPR);
 while( COND_EXPR ) BLOCK }

where the identifiers @reachin{VAR_0} through @reachin{VAR_n} are bound to the result of the @tech{expression} @reachin{INIT_EXPR}, which must evaluate to @reachin{n} values, and @reachin{INVARIANT_EXPR} is an @tech{expression}, called the @deftech{loop invariant}, that must be true before and after every execution of the @tech{block} @reachin{BLOCK}, and if @reachin{COND_EXPR} is true, then the @tech{block} executes, and if not, then the loop terminates and control transfers to the @tech{continuation} of the @tech{while statement}. The identifiers @reachin{VAR_0} through @reachin{VAR_n} are bound within @reachin{INVARIANT_EXPR}, @reachin{COND_EXPR}, @reachin{BLOCK}, and the @tech{tail} of the @tech{while statement}.

@subsection{Continue statements}

@reach{
 [ heap1, heap2 ] = [ heap1 - 1, heap2 ];
 continue; }

A @deftech{continue statement} may occur within a @tech{while statement}'s @tech{block} and is written:

@reach{
 [ VAR_0, ..., VAR_n ] = UPDATE_EXPR;
 continue; }

where the identifiers @reachin{VAR_0} through @reachin{VAR_n} are the variables bound by the nearest enclosing @tech{while statement} and @reachin{UPDATE_EXPR} is an @tech{expression} which evaluates to @reachin{n} values.

A @tech{continue statement} is a @tech{terminator statement}, so it must have an empty @tech{tail}.

A @tech{continue statement} may be written without the preceding identifier update, in which case another iteration begins with the same loop state.

@section{Expressions}

There are a large variety of different @deftech{expressions} in Reach programs.

The remainder of this section enumerates each kind of @tech{expression}.

@(hrule)
@reach{
 X
 Y
 Z }

An identifier, written @reachin{ID}, is an @tech{expression} that evaluates to the value of the @tech{bound identifier}.

@(hrule)
@reach{
 10
 0xdeadbeef
 007
 true
 false
 "reality bytes"
 'it just does' }

A @deftech{literal value},
written @reachin{VALUE},
is an @tech{expression} that evaluates to the given @tech{value}.
@deftech{Numeric literal}s may be written in decimal, hexadecimal, or octal.
@deftech{Boolean literal}s may be written as @reachin{true} or @reachin{false}.
@deftech{String literal}s (aka byte strings)
may be written between double or single quotes
(with no distinction between the different styles)
and use the same escaping rules as JavaScript.

@(hrule)

An @deftech{operator} is a special identifier,
which is either a @tech{unary operator}, or a @tech{binary operator}.

@(hrule)
@reach{
 ! a
 - a}

A @deftech{unary expression}, written @reachin{UNAOP EXPR_rhs}, where @reachin{EXPR_rhs} is an @tech{expression} and @reachin{UNAOP} is one of the @deftech{unary operator}s: @litchar{! -}.

@margin-note{Since all numbers are non-negative in Reach, the @reachin{-} unary operator is useless.}

It is @tech{invalid} to use unary operations on the wrong types of @tech{values}.

@(hrule)
@reach{
 a && b
 a || b
 a + b
 a - b
 a * b
 a / b
 a % b
 a | b
 a & b
 a ^ b
 a << b
 a >> b
 a == b
 a != b
 a === b
 a !== b
 a > b
 a >= b
 a <= b
 a < b }

A @deftech{binary expression}, written @reachin{EXPR_lhs BINOP EXPR_rhs}, where @reachin{EXPR_lhs} and @reachin{EXPR_rhs} are @tech{expressions} and @reachin{BINOP} is one of the @deftech{binary operator}s: @litchar{&& || + - * / % | & ^ << >> == != === !== > >= <= <}. The operators @reachin{==} and @reachin{!=} operate on numbers, while the operators @reachin{===} and @reachin{!==} operate on byte strings. Numeric operations, like @reachin{+} and @reachin{>}, only operate on numbers. Since all numbers in Reach are integers, operations like @reachin{/} truncate their result. Boolean operations, like @reachin{&&}, only operate on booleans. It is @tech{invalid} to use binary operations on the wrong types of @tech{values}.

@(hrule)
@reach{
 (a + b) - c }

An @tech{expression} may be parenthesized, as in @reachin{(EXPR)}.

@(hrule)
@reach{
 [ ]
 [ 1, 2 + 3, 4 * 5 ] }

A @deftech{tuple literal},
written @reachin{[ EXPR_0, ..., EXPR_n ]},
is an @tech{expression} which evaluates to a tuple of @reachin{n} values,
where @reachin{EXPR_0} through @reachin{EXPR_n} are @tech{expressions}.

@(hrule)
@reach{
 arr[3] }

An @deftech{array reference}, written @reachin{ARRAY_EXPR[IDX_EXPR]},
where @reachin{ARRAY_EXPR} is an @tech{expression} that evaluates to statically sized @deftech{array}
(a tuple where all values are the same type)
and @reachin{IDX_EXPR} is an @tech{expression} that evaluates to a natural number which is less than the size of the array,
selects the element at the given index of the array.
Array indices start at zero.

@(hrule)
@reach{
  { }
  { x: 3, "yo-yo": 4 }
}

An @deftech{object literal},
typically written @reachin{{ KEY_0: EXPR_0, ..., KEY_n: EXPR_n }},
where @reachin{KEY_0} through @reachin{KEY_n} are @tech{identifiers} or @tech{string literal}s
and @reachin{EXPR_0} through @reachin{EXPR_n} are @tech{expressions},
is an @tech{expression} which evaluates to an object
with fields @reachin{KEY_0} through @reachin{KEY_n}.

Additional object literal syntax exists for convenience, such as:

@reach{
  { ...obj, z: 5 }
}

An @deftech{object spread}, where all fields from @reachin{obj} are copied into the object, but these fields may be overridden by additional fields specified afterwards.

@reach{
  { x, z: 5 }
}

Shorthand for @reachin{{ x: x, z: 5}}, where @reachin{x} is any @tech{bound identifier}.

@(hrule)
@reach{
  obj["x"]
}

An @deftech{object reference},
written @reachin{OBJ[FIELD]},
where @reachin{OBJ} is an expression of type object,
and @reachin{FIELD} is an expression of type bytes,
accesses the FIELD field of object OBJ.

This syntax is identical to @tech{array reference};
the difference is only in the types involved.

@(hrule)
@reach{
 choosesFirst ? [ heap1 - amount, heap2 ] : [ heap1, heap2 - amount ] }

A @deftech{conditional expression}, written @reachin{COND_E ? TRUE_E : FALSE_E}, where @reachin{COND_E}, @reachin{TRUE_E}, and @reachin{FALSE_E} are @tech{expressions}, selects between the @tech{values} which @reachin{TRUE_E} and @reachin{FALSE_E} evaluate to based on whether @reachin{COND_E} evaluates to @reachin{true}.

@(hrule)
@reach{
 (() => 4)
 ((x) => x + 1)
 ((x) => { const y = x + 1;
           return y + 1; }) }

A @deftech{lambda expression}, written @reachin{(ID_0, ..., ID_n) => EXPR}, where @reachin{ID_0} through @reachin{ID_n} are identifiers and @reachin{EXPR} is an @tech{expression}, evaluates to an function which is an abstraction of @reachin{EXPR} over @reachin{n} values.

@(hrule)
@reach{
 transfer(10).to(Alice) }

A @deftech{transfer expression}, written @reachin{transfer(AMOUNT_EXPR).to(PART)}, where @reachin{AMOUNT_EXPR} is an @tech{expression} that evaluates to a natural number and @reachin{PART} is a @tech{participant} identifier, performs a @tech{transfer} of @tech{network tokens} from the @tech{contract} to the named @tech{participant}. @reachin{AMOUNT_EXPR} must evaluate to less than or equal to the balance of @tech{network tokens} in the @tech{contract} @tech{account}. A @tech{transfer expression} may only occur within a @tech{consensus step}.

@(hrule)
@reach{
 interact.notify(handA, handB);
 is(uint256, interact.chooseAmount(heap1, heap2)) }

An @deftech{interaction expression}, written @reachin{is(TYPE, interact.METHOD(EXPR_0, ..., EXPR_n))}, where @reachin{TYPE} is a @tech{type}, @reachin{METHOD} is an identifier, and @reachin{EXPR_0} through @reachin{EXPR_n} are @tech{expressions} that evaluate to one value, evaluates to the result of an @tech{interact}ion with a @tech{frontend} that receives the evaluation of the @reachin{n} @tech{expressions} and sends a @tech{value} of @tech{type} @reachin{TYPE} if it is @tech{honest}. The @reachin{is} component may be omitted, in which case it is treated as though it were @reachin{is(boolean, ....)}.

@(hrule)
@reach{
 assert( amount <= heap1 )
 step( moveA )
 digest( coinFlip )
 random()
 declassify( _coinFlip ) }

A @deftech{function application}, written @reachin{EXPR_rator(EXPR_rand_0, ..., EXPR_rand_n)}, where @reachin{EXPR_rator} and @reachin{EXPR_rand_0} through @reachin{EXPR_rand_n} are @tech{expressions} that evaluate to one value. @reachin{EXPR_rator} must evaluate to an abstraction over @reachin{n} values or a primitive of arity @reachin{n}.

@section{Standard Library}

Reach's @deftech{standard library} is a set of @tech{bound identifier}s and @tech{operators} which are implicitly bound in all @tech{modules}.
It is sometimes treated as a @tech{module} referred to as @litchar{"STDLIB"}.
All @tech{standard library} @tech{bound identifier}s and @tech{operators} are documented in this section.

@(hrule)
@reach{
  const [ isHand, ROCK, PAPER, SCISSORS ] = makeEnum(3); }

An @deftech{enumeration} (or @deftech{enum}, for short),
can be created with @reachin{makeEnum(N)},
where @reachin{N} is the number of distinct values in the enum.
This produces a tuple of @reachin{N+1} values,
where the first value is a @reachin{Fun([UInt256], Bool)}
which tells you if its argument is one of the enum's values,
and the next N values are distinct @reachin{UInt256}s.


@(hrule)
@reach{
 assert( claim ) }

@index{assert} A @tech{static assertion} which is only @tech{valid} if @reachin{claim} always evaluates to @reachin{true}. @margin-note{The Reach compiler will produce a counter-example (i.e. an assignment of the identifiers in the program to falsify the @reachin{claim}) when an @tech{invalid} @reachin{claim} is provided. It is possible to write a @reachin{claim} that actually always evaluates to @reachin{true}, but for which our current approach cannot prove always evaluates to @reachin{true}; if this is the case, Reach will fail to compile the program, reporting that its analysis is incomplete. Reach will never produce an erroneous counter-example.}

@(hrule)
@reach{
 assume( claim ) }

@index{assume} An @tech{assumption} where @reachin{claim} evaluates to @reachin{true} with @tech{honest} @tech{frontends}.

@(hrule)
@reach{
 require( claim ) }

@index{require} An @tech{requirement} where @reachin{claim} evaluates to @reachin{true} with @tech{honest} @tech{participants}.

@(hrule)
@reach{
 possible( claim ) }

@index{possible} A @tech{possibility assertion} which is only @tech{valid} if it is possible for @reachin{claim} to evaluate to @reachin{true} with @tech{honest} @tech{frontends} and @tech{participants}.

@(hrule)
@reach{
 digest( arg_0, ..., arg_n ) }

The @deftech{digest} primitive performs a @link["https://en.wikipedia.org/wiki/Cryptographic_hash_function"]{cryptographic hash} of the binary encoding of the given arguments, using the Keccak256 algorithm.

@(hrule)
@reach{
 balance() }

The @deftech{balance} primitive returns the balance of the @tech{contract} @tech{account} for the @|DApp|.

@(hrule)
@reach{
 random() }

The @deftech{random} primitive returns a random unsigned integer of 256 bits. This primitive may not be called in @tech{consensus steps}.

@(hrule)
@reach{
 declassify( arg ) }

The @deftech{declassify} primitive performs a @tech{declassification} of the given argument.

@(hrule)
@reach{
 implies( x, y ) }

@index{implies} Returns @reachin{true} if @reachin{x} is @reachin{false} or @reachin{y} is @reachin{true}.

@(hrule)
@reach{
 ensure( pred, x ) }

@index{ensure} Makes a @tech{static assertion} that @reachin{pred(x)} is @reachin{true} and returns @reachin{x}.

@(hrule)
@reach{
 makeCommitment( x ) }

@index{makeCommitment} Returns two values, @reachin{[ commitment, salt ]}, where @reachin{salt} is a random @reachin{uint256}, and
@reachin{commitment} is the @tech{digest} of @reachin{salt} and @reachin{x}.

@(hrule)
@reach{
 checkCommitment( commitment, salt, x ) }

@index{checkCommitment} Makes a @tech{requirement} that @reachin{commitment} is the @tech{digest} of @reachin{salt} and @reachin{x}.

@(hrule)
@reach{
 closeTo( Who, value ) }

@index{closeTo} Returns a function which accepts no arguments, has @tech{participant} @reachin{Who} make a @tech{publication}, then @tech{transfer} the @reachin{balance()} to @reachin{Who} and end the @|DApp| with the result @reachin{value}.
