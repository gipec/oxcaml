# 2 "stdlib.mli"
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

@@ portable

(** The OCaml Standard library.

    This module is automatically opened at the beginning of each
    compilation. All components of this module can therefore be
    referred by their short name, without prefixing them by [Stdlib].

    In particular, it provides the basic operations over the built-in
    types (numbers, booleans, byte sequences, strings, exceptions,
    references, lists, arrays, input-output channels, ...) and the
    {{!modules}standard library modules}.
*)

[@@@ocaml.warning "-49"]

(** {1 Exceptions} *)

external raise : ('a : value_or_null). exn -> 'a @ portable unique = "%reraise"
(** Raise the given exception value *)

external raise_notrace : ('a : value_or_null). exn -> 'a @ portable unique
  = "%raise_notrace"
(** A faster version [raise] which does not record the backtrace.
    @since 4.02
*)

val invalid_arg : ('a : value_or_null) . string -> 'a @ portable unique
(** Raise exception [Invalid_argument] with the given string. *)

val failwith : ('a : value_or_null) . string -> 'a @ portable unique
(** Raise exception [Failure] with the given string. *)

exception Exit
(** The [Exit] exception is not raised by any library function.  It is
    provided for use in your programs. *)

exception Match_failure of (string * int * int)
  [@ocaml.warn_on_literal_pattern]
(** Exception raised when none of the cases of a pattern-matching
   apply. The arguments are the location of the match keyword in the
   source code (file name, line number, column number). *)

exception Assert_failure of (string * int * int)
  [@ocaml.warn_on_literal_pattern]
(** Exception raised when an assertion fails. The arguments are the
   location of the assert keyword in the source code (file name, line
   number, column number). *)

exception Invalid_argument of string
  [@ocaml.warn_on_literal_pattern]
(** Exception raised by library functions to signal that the given
   arguments do not make sense. The string gives some information to
   the programmer. As a general rule, this exception should not be
   caught, it denotes a programming error and the code should be
   modified not to trigger it. *)

exception Failure of string
  [@ocaml.warn_on_literal_pattern]
(** Exception raised by library functions to signal that they are
   undefined on the given arguments. The string is meant to give some
   information to the programmer; you must not pattern match on the
   string literal because it may change in future versions (use
   Failure _ instead). *)

exception Not_found
(** Exception raised by search functions when the desired object could
   not be found. *)

exception Out_of_memory
(** Exception raised by functions such as those for array and bigarray
    creation when there is insufficient memory.  Failure to allocate
    memory during garbage collection causes a fatal error, unlike in
    previous versions, where it did not always do so. *)

exception Stack_overflow
(** Exception raised by the bytecode interpreter when the evaluation
   stack reaches its maximal size. This often indicates infinite or
   excessively deep recursion in the user's program.

   Before 4.10, it was not fully implemented by the native-code
   compiler. *)

exception Sys_error of string
  [@ocaml.warn_on_literal_pattern]
(** Exception raised by the input/output functions to report an
   operating system error. The string is meant to give some
   information to the programmer; you must not pattern match on the
   string literal because it may change in future versions (use
   Sys_error _ instead). *)

exception End_of_file
(** Exception raised by input functions to signal that the end of file
   has been reached. *)

exception Division_by_zero
(** Exception raised by integer division and remainder operations when
   their second argument is zero. *)

exception Sys_blocked_io
(** A special case of Sys_error raised when no I/O is possible on a
   non-blocking I/O channel. *)

exception Undefined_recursive_module of (string * int * int)
  [@ocaml.warn_on_literal_pattern]
(** Exception raised when an ill-founded recursive module definition
   is evaluated. The arguments are the location of the definition in
   the source code (file name, line number, column number). *)

(** {1 Comparisons} *)

external ( = ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%equal"
(** [e1 = e2] tests for structural equality of [e1] and [e2].
   Mutable structures (e.g. references and arrays) are equal
   if and only if their current contents are structurally equal,
   even if the two mutable objects are not the same physical object.
   Equality between functional values raises [Invalid_argument].
   Equality between cyclic data structures may not terminate.
   Left-associative operator, see {!Ocaml_operators} for more information. *)

external ( <> ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%notequal"
(** Negation of {!Stdlib.( = )}.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( < ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%lessthan"
(** See {!Stdlib.( >= )}.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( > ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%greaterthan"
(** See {!Stdlib.( >= )}.
    Left-associative operator,  see {!Ocaml_operators} for more information.
*)

external ( <= ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%lessequal"
(** See {!Stdlib.( >= )}.
    Left-associative operator,  see {!Ocaml_operators} for more information.
*)

external ( >= ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%greaterequal"
(** Structural ordering functions. These functions coincide with
   the usual orderings over integers, characters, strings, byte sequences
   and floating-point numbers, and extend them to a
   total ordering over all types.
   The ordering is compatible with [( = )]. As in the case
   of [( = )], mutable structures are compared by contents.
   Comparison between functional values raises [Invalid_argument].
   Comparison between cyclic structures may not terminate.
   Left-associative operator, see {!Ocaml_operators} for more information.
*)

external compare : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> int = "%compare"
(** [compare x y] returns [0] if [x] is equal to [y],
   a negative integer if [x] is less than [y], and a positive integer
   if [x] is greater than [y].  The ordering implemented by [compare]
   is compatible with the comparison predicates [=], [<] and [>]
   defined above,  with one difference on the treatment of the float value
   {!Stdlib.nan}.  Namely, the comparison predicates treat [nan]
   as different from any other float value, including itself;
   while [compare] treats [nan] as equal to itself and less than any
   other float value.  This treatment of [nan] ensures that [compare]
   defines a total ordering relation.

   [compare] applied to functional values may raise [Invalid_argument].
   [compare] applied to cyclic structures may not terminate.

   The [compare] function can be used as the comparison function
   required by the {!Set.Make} and {!Map.Make} functors, as well as
   the {!List.sort} and {!Array.sort} functions. *)

val min : ('a : value_or_null) . 'a -> 'a -> 'a
(** Return the smaller of the two arguments.
    The result is unspecified if one of the arguments contains
    the float value [nan]. *)

val max : ('a : value_or_null) . 'a -> 'a -> 'a
(** Return the greater of the two arguments.
    The result is unspecified if one of the arguments contains
    the float value [nan]. *)

external ( == ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%eq"
(** [e1 == e2] tests for physical equality of [e1] and [e2].
   On mutable types such as references, arrays, byte sequences, records with
   mutable fields and objects with mutable instance variables,
   [e1 == e2] is true if and only if physical modification of [e1]
   also affects [e2].
   On non-mutable types, the behavior of [( == )] is
   implementation-dependent; however, it is guaranteed that
   [e1 == e2] implies [compare e1 e2 = 0].
   Left-associative operator,  see {!Ocaml_operators} for more information.
*)

external ( != ) : ('a : value_or_null) . ('a[@local_opt]) -> ('a[@local_opt]) -> bool = "%noteq"
(** Negation of {!Stdlib.( == )}.
    Left-associative operator,  see {!Ocaml_operators} for more information.
*)


(** {1 Boolean operations} *)

external not : (bool[@local_opt]) -> bool = "%boolnot"
(** The boolean negation. *)

external ( && ) : (bool[@local_opt]) -> (bool[@local_opt]) -> bool = "%sequand"
(** The boolean 'and'. Evaluation is sequential, left-to-right:
   in [e1 && e2], [e1] is evaluated first, and if it returns [false],
   [e2] is not evaluated at all.
   Right-associative operator,  see {!Ocaml_operators} for more information.
*)

external ( || ) : (bool[@local_opt]) -> (bool[@local_opt]) -> bool = "%sequor"
(** The boolean 'or'. Evaluation is sequential, left-to-right:
   in [e1 || e2], [e1] is evaluated first, and if it returns [true],
   [e2] is not evaluated at all.
   Right-associative operator,  see {!Ocaml_operators} for more information.
*)

(** {1 Debugging} *)

external __LOC__ : string = "%loc_LOC"
(** [__LOC__] returns the location at which this expression appears in
    the file currently being parsed by the compiler, with the standard
    error format of OCaml: "File %S, line %d, characters %d-%d".
    @since 4.02
*)

external __FILE__ : string = "%loc_FILE"
(** [__FILE__] returns the name of the file currently being
    parsed by the compiler.
    @since 4.02
*)

external __LINE__ : int = "%loc_LINE"
(** [__LINE__] returns the line number at which this expression
    appears in the file currently being parsed by the compiler.
    @since 4.02
*)

external __MODULE__ : string = "%loc_MODULE"
(** [__MODULE__] returns the module name of the file being
    parsed by the compiler.
    @since 4.02
*)

external __POS__ : string * int * int * int = "%loc_POS"
(** [__POS__] returns a tuple [(file,lnum,cnum,enum)], corresponding
    to the location at which this expression appears in the file
    currently being parsed by the compiler. [file] is the current
    filename, [lnum] the line number, [cnum] the character position in
    the line and [enum] the last character position in the line.
    @since 4.02
 *)

external __FUNCTION__ : string = "%loc_FUNCTION"
(** [__FUNCTION__] returns the name of the current function or method, including
    any enclosing modules or classes.

    @since 4.12 *)

external __LOC_OF__ : ('a : value_or_null) . 'a -> string * 'a = "%loc_LOC"
(** [__LOC_OF__ expr] returns a pair [(loc, expr)] where [loc] is the
    location of [expr] in the file currently being parsed by the
    compiler, with the standard error format of OCaml: "File %S, line
    %d, characters %d-%d".
    @since 4.02
*)

external __LINE_OF__ : ('a : value_or_null) . 'a -> int * 'a = "%loc_LINE"
(** [__LINE_OF__ expr] returns a pair [(line, expr)], where [line] is the
    line number at which the expression [expr] appears in the file
    currently being parsed by the compiler.
    @since 4.02
 *)

external __POS_OF__ : ('a : value_or_null) . 'a -> (string * int * int * int) * 'a = "%loc_POS"
(** [__POS_OF__ expr] returns a pair [(loc,expr)], where [loc] is a
    tuple [(file,lnum,cnum,enum)] corresponding to the location at
    which the expression [expr] appears in the file currently being
    parsed by the compiler. [file] is the current filename, [lnum] the
    line number, [cnum] the character position in the line and [enum]
    the last character position in the line.
    @since 4.02
 *)

(** {1 Composition operators} *)

external ( |> ) : ('a : value_or_null) ('b : value_or_null)
  . 'a -> ('a -> 'b) -> 'b = "%revapply"
(** Reverse-application operator: [x |> f |> g] is exactly equivalent
 to [g (f (x))].
 Left-associative operator, see {!Ocaml_operators} for more information.
 @since 4.01
*)

external ( @@ ) : ('a : value_or_null) ('b : value_or_null)
  . ('a -> 'b) -> 'a -> 'b = "%apply"
(** Application operator: [g @@ f @@ x] is exactly equivalent to
 [g (f (x))].
 Right-associative operator, see {!Ocaml_operators} for more information.
 @since 4.01
*)

(** {1 Integer arithmetic} *)

(** Integers are [Sys.int_size] bits wide.
    All operations are taken modulo 2{^[Sys.int_size]}.
    They do not fail on overflow. *)

external ( ~- ) : (int[@local_opt]) -> int = "%negint"
(** Unary negation. You can also write [- e] instead of [~- e].
    Unary operator, see {!Ocaml_operators} for more information.
*)


external ( ~+ ) : (int[@local_opt]) -> int = "%identity"
(** Unary addition. You can also write [+ e] instead of [~+ e].
    Unary operator, see {!Ocaml_operators} for more information.
    @since 3.12
*)

external succ : (int[@local_opt]) -> int = "%succint"
(** [succ x] is [x + 1]. *)

external pred : (int[@local_opt]) -> int = "%predint"
(** [pred x] is [x - 1]. *)

external ( + ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%addint"
(** Integer addition.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( - ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%subint"
(** Integer subtraction.
    Left-associative operator, , see {!Ocaml_operators} for more information.
*)

external ( * ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%mulint"
(** Integer multiplication.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( / ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%divint"
(** Integer division.
   Integer division rounds the real quotient of its arguments towards zero.
   More precisely, if [x >= 0] and [y > 0], [x / y] is the greatest integer
   less than or equal to the real quotient of [x] by [y].  Moreover,
   [(- x) / y = x / (- y) = - (x / y)].
   Left-associative operator, see {!Ocaml_operators} for more information.

   @raise Division_by_zero if the second argument is 0.
*)

external ( mod ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%modint"
(** Integer remainder.  If [y] is not zero, the result
   of [x mod y] satisfies the following properties:
   [x = (x / y) * y + x mod y] and
   [abs(x mod y) <= abs(y) - 1].
   If [y = 0], [x mod y] raises [Division_by_zero].
   Note that [x mod y] is negative only if [x < 0].
   Left-associative operator, see {!Ocaml_operators} for more information.

   @raise Division_by_zero if [y] is zero.
*)

val abs : int -> int
(** [abs x] is the absolute value of [x]. On [min_int] this
   is [min_int] itself and thus remains negative. *)

val max_int : int
(** The greatest representable integer. *)

val min_int : int
(** The smallest representable integer. *)


(** {2 Bitwise operations} *)

external ( land ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%andint"
(** Bitwise logical and.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( lor ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%orint"
(** Bitwise logical or.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( lxor ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%xorint"
(** Bitwise logical exclusive or.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

val lnot : int -> int
(** Bitwise logical negation. *)

external ( lsl ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%lslint"
(** [n lsl m] shifts [n] to the left by [m] bits.
    The result is unspecified if [m < 0] or [m > Sys.int_size].
    Right-associative operator, see {!Ocaml_operators} for more information.
*)

external ( lsr ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%lsrint"
(** [n lsr m] shifts [n] to the right by [m] bits.
    This is a logical shift: zeroes are inserted regardless of
    the sign of [n].
    The result is unspecified if [m < 0] or [m > Sys.int_size].
    Right-associative operator, see {!Ocaml_operators} for more information.
*)

external ( asr ) : (int[@local_opt]) -> (int[@local_opt]) -> int = "%asrint"
(** [n asr m] shifts [n] to the right by [m] bits.
    This is an arithmetic shift: the sign bit of [n] is replicated.
    The result is unspecified if [m < 0] or [m > Sys.int_size].
    Right-associative operator, see {!Ocaml_operators} for more information.
*)

(** {1 Floating-point arithmetic}

   OCaml's floating-point numbers follow the
   IEEE 754 standard, using double precision (64 bits) numbers.
   Floating-point operations never raise an exception on overflow,
   underflow, division by zero, etc.  Instead, special IEEE numbers
   are returned as appropriate, such as [infinity] for [1.0 /. 0.0],
   [neg_infinity] for [-1.0 /. 0.0], and [nan] ('not a number')
   for [0.0 /. 0.0].  These special numbers then propagate through
   floating-point computations as expected: for instance,
    [1.0 /. infinity] is [0.0], basic arithmetic operations
    ([+.], [-.], [*.], [/.]) with [nan] as an argument return [nan], ...
*)

external ( ~-. ) : (float[@local_opt]) -> (float[@local_opt]) = "%negfloat"
(** Unary negation. You can also write [-. e] instead of [~-. e].
    Unary operator, see {!Ocaml_operators} for more information.
*)

external ( ~+. ) : (float[@local_opt]) -> (float[@local_opt]) = "%identity"
(** Unary addition. You can also write [+. e] instead of [~+. e].
    Unary operator, see {!Ocaml_operators} for more information.
    @since 3.12
*)

external ( +. ) : (float[@local_opt]) -> (float[@local_opt]) -> (float[@local_opt]) = "%addfloat"
(** Floating-point addition.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( -. ) : (float[@local_opt]) -> (float[@local_opt]) -> (float[@local_opt]) = "%subfloat"
(** Floating-point subtraction.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( *. ) : (float[@local_opt]) -> (float[@local_opt]) -> (float[@local_opt]) = "%mulfloat"
(** Floating-point multiplication.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( /. ) : (float[@local_opt]) -> (float[@local_opt]) -> (float[@local_opt]) = "%divfloat"
(** Floating-point division.
    Left-associative operator, see {!Ocaml_operators} for more information.
*)

external ( ** ) : float -> float -> float = "caml_power_float" "pow"
  [@@unboxed] [@@noalloc]
(** Exponentiation.
    Right-associative operator, see {!Ocaml_operators} for more information.
*)

external sqrt : float -> float = "caml_sqrt_float" "sqrt"
  [@@unboxed] [@@noalloc]
(** Square root. *)

external exp : float -> float = "caml_exp_float" "exp" [@@unboxed] [@@noalloc]
(** Exponential. *)

external log : float -> float = "caml_log_float" "log" [@@unboxed] [@@noalloc]
(** Natural logarithm. *)

external log10 : float -> float = "caml_log10_float" "log10"
  [@@unboxed] [@@noalloc]
(** Base 10 logarithm. *)

external expm1 : float -> float = "caml_expm1_float" "caml_expm1"
  [@@unboxed] [@@noalloc]
(** [expm1 x] computes [exp x -. 1.0], giving numerically-accurate results
    even if [x] is close to [0.0].
    @since 3.12
*)

external log1p : float -> float = "caml_log1p_float" "caml_log1p"
  [@@unboxed] [@@noalloc]
(** [log1p x] computes [log(1.0 +. x)] (natural logarithm),
    giving numerically-accurate results even if [x] is close to [0.0].
    @since 3.12
*)

external cos : float -> float = "caml_cos_float" "cos" [@@unboxed] [@@noalloc]
(** Cosine.  Argument is in radians. *)

external sin : float -> float = "caml_sin_float" "sin" [@@unboxed] [@@noalloc]
(** Sine.  Argument is in radians. *)

external tan : float -> float = "caml_tan_float" "tan" [@@unboxed] [@@noalloc]
(** Tangent.  Argument is in radians. *)

external acos : float -> float = "caml_acos_float" "acos"
  [@@unboxed] [@@noalloc]
(** Arc cosine.  The argument must fall within the range [[-1.0, 1.0]].
    Result is in radians and is between [0.0] and [pi]. *)

external asin : float -> float = "caml_asin_float" "asin"
  [@@unboxed] [@@noalloc]
(** Arc sine.  The argument must fall within the range [[-1.0, 1.0]].
    Result is in radians and is between [-pi/2] and [pi/2]. *)

external atan : float -> float = "caml_atan_float" "atan"
  [@@unboxed] [@@noalloc]
(** Arc tangent.
    Result is in radians and is between [-pi/2] and [pi/2]. *)

external atan2 : float -> float -> float = "caml_atan2_float" "atan2"
  [@@unboxed] [@@noalloc]
(** [atan2 y x] returns the arc tangent of [y /. x].  The signs of [x]
    and [y] are used to determine the quadrant of the result.
    Result is in radians and is between [-pi] and [pi]. *)

external hypot : float -> float -> float = "caml_hypot_float" "caml_hypot"
  [@@unboxed] [@@noalloc]
(** [hypot x y] returns [sqrt(x *. x + y *. y)], that is, the length
  of the hypotenuse of a right-angled triangle with sides of length
  [x] and [y], or, equivalently, the distance of the point [(x,y)]
  to origin.  If one of [x] or [y] is infinite, returns [infinity]
  even if the other is [nan].
  @since 4.00  *)

external cosh : float -> float = "caml_cosh_float" "cosh"
  [@@unboxed] [@@noalloc]
(** Hyperbolic cosine.  Argument is in radians. *)

external sinh : float -> float = "caml_sinh_float" "sinh"
  [@@unboxed] [@@noalloc]
(** Hyperbolic sine.  Argument is in radians. *)

external tanh : float -> float = "caml_tanh_float" "tanh"
  [@@unboxed] [@@noalloc]
(** Hyperbolic tangent.  Argument is in radians. *)

external acosh : float -> float = "caml_acosh_float" "caml_acosh"
  [@@unboxed] [@@noalloc]
(** Hyperbolic arc cosine.  The argument must fall within the range
    [[1.0, inf]].
    Result is in radians and is between [0.0] and [inf].

    @since 4.13
*)

external asinh : float -> float = "caml_asinh_float" "caml_asinh"
  [@@unboxed] [@@noalloc]
(** Hyperbolic arc sine.  The argument and result range over the entire
    real line.
    Result is in radians.

    @since 4.13
*)

external atanh : float -> float = "caml_atanh_float" "caml_atanh"
  [@@unboxed] [@@noalloc]
(** Hyperbolic arc tangent.  The argument must fall within the range
    [[-1.0, 1.0]].
    Result is in radians and ranges over the entire real line.

    @since 4.13
*)

external ceil : float -> float = "caml_ceil_float" "ceil"
  [@@unboxed] [@@noalloc]
(** Round above to an integer value.
    [ceil f] returns the least integer value greater than or equal to [f].
    The result is returned as a float. *)

external floor : float -> float = "caml_floor_float" "floor"
  [@@unboxed] [@@noalloc]
(** Round below to an integer value.
    [floor f] returns the greatest integer value less than or
    equal to [f].
    The result is returned as a float. *)

external abs_float : (float[@local_opt]) -> (float[@local_opt]) = "%absfloat"
(** [abs_float f] returns the absolute value of [f]. *)

external copysign : float -> float -> float
                  = "caml_copysign_float" "caml_copysign"
                  [@@unboxed] [@@noalloc]
(** [copysign x y] returns a float whose absolute value is that of [x]
  and whose sign is that of [y].  If [x] is [nan], returns [nan].
  If [y] is [nan], returns either [x] or [-. x], but it is not
  specified which.
  @since 4.00  *)

external mod_float : float -> float -> float = "caml_fmod_float" "fmod"
  [@@unboxed] [@@noalloc]
(** [mod_float a b] returns the remainder of [a] with respect to
   [b].  The returned value is [a -. n *. b], where [n]
   is the quotient [a /. b] rounded towards zero to an integer. *)

external frexp : float -> float * int = "caml_frexp_float"
(** [frexp f] returns the pair of the significant
   and the exponent of [f].  When [f] is zero, the
   significant [x] and the exponent [n] of [f] are equal to
   zero.  When [f] is non-zero, they are defined by
   [f = x *. 2 ** n] and [0.5 <= x < 1.0]. *)


external ldexp : (float [@unboxed]) -> (int [@untagged]) -> (float [@unboxed]) =
  "caml_ldexp_float" "caml_ldexp_float_unboxed" [@@noalloc]
(** [ldexp x n] returns [x *. 2 ** n]. *)

external modf : float -> float * float = "caml_modf_float"
(** [modf f] returns the pair of the fractional and integral
   part of [f]. *)

external float : (int[@local_opt]) -> (float[@local_opt]) = "%floatofint"
(** Same as {!Stdlib.float_of_int}. *)

external float_of_int : (int[@local_opt]) -> (float[@local_opt]) = "%floatofint"
(** Convert an integer to floating-point. *)

external truncate : (float[@local_opt]) -> int = "%intoffloat"
(** Same as {!Stdlib.int_of_float}. *)

external int_of_float : (float[@local_opt]) -> int = "%intoffloat"
(** Truncate the given floating-point number to an integer.
   The result is unspecified if the argument is [nan] or falls outside the
   range of representable integers. *)

val infinity : float
(** Positive infinity. *)

val neg_infinity : float
(** Negative infinity. *)

val nan : float
(** A special floating-point value denoting the result of an
    undefined operation such as [0.0 /. 0.0].  Stands for
    'not a number'.  Any floating-point operation with [nan] as
    argument returns [nan] as result, unless otherwise specified in
    IEEE 754 standard.  As for floating-point comparisons,
    [=], [<], [<=], [>] and [>=] return [false] and [<>] returns [true]
    if one or both of their arguments is [nan].

    [nan] is a quiet NaN since 5.1;  it was a signaling NaN before. *)

val max_float : float
(** The largest positive finite value of type [float]. *)

val min_float : float
(** The smallest positive, non-zero, non-denormalized value of type [float]. *)

val epsilon_float : float
(** The difference between [1.0] and the smallest exactly representable
    floating-point number greater than [1.0]. *)

type fpclass =
    FP_normal           (** Normal number, none of the below *)
  | FP_subnormal        (** Number very close to 0.0, has reduced precision *)
  | FP_zero             (** Number is 0.0 or -0.0 *)
  | FP_infinite         (** Number is positive or negative infinity *)
  | FP_nan              (** Not a number: result of an undefined operation *)
(** The five classes of floating-point numbers, as determined by
   the {!Stdlib.classify_float} function. *)

external classify_float : (float [@unboxed]) -> fpclass =
  "caml_classify_float" "caml_classify_float_unboxed" [@@noalloc]
(** Return the class of the given floating-point number:
   normal, subnormal, zero, infinite, or not a number. *)


(** {1 String operations}

   More string operations are provided in module {!String}.
*)

val ( ^ ) : string -> string -> string
(** String concatenation.
    Right-associative operator, see {!Ocaml_operators} for more information.

    @raise Invalid_argument if the result is longer then
    than {!Sys.max_string_length} bytes.
*)

(** {1 Character operations}

   More character operations are provided in module {!Char}.
*)

external int_of_char : char -> int = "%identity"
(** Return the ASCII code of the argument. *)

val char_of_int : int -> char
(** Return the character with the given ASCII code.
   @raise Invalid_argument if the argument is
   outside the range 0--255. *)


(** {1 Unit operations} *)

external ignore : ('a : value_or_null) . 'a -> unit = "%ignore"
(** Discard the value of its argument and return [()].
   For instance, [ignore(f x)] discards the result of
   the side-effecting function [f].  It is equivalent to
   [f x; ()], except that the latter may generate a
   compiler warning; writing [ignore(f x)] instead
   avoids the warning. *)

external ignore_contended : ('a : value_or_null) . 'a @ contended local once -> unit
  = "%ignore"
(** Like {!ignore}, but takes a [contended local once] value. This is technically strictly
    stronger than [ignore], but changing [ignore] in place causes backwards compatibility
    issues due to type inference. *)

(** {1 String conversion functions} *)

val string_of_bool : bool -> string
(** Return the string representation of a boolean. As the returned values
   may be shared, the user should not modify them directly.
*)

val bool_of_string_opt: string -> bool option
(** Convert the given string to a boolean.

   Return [None] if the string is not ["true"] or ["false"].
   @since 4.05
*)

val bool_of_string : string -> bool
(** Same as {!Stdlib.bool_of_string_opt}, but raise
   [Invalid_argument "bool_of_string"] instead of returning [None]. *)

val string_of_int : int -> string
(** Return the string representation of an integer, in decimal. *)

val int_of_string_opt: string -> int option
(** Convert the given string to an integer.
   The string is read in decimal (by default, or if the string
   begins with [0u]), in hexadecimal (if it begins with [0x] or
   [0X]), in octal (if it begins with [0o] or [0O]), or in binary
   (if it begins with [0b] or [0B]).

   The [0u] prefix reads the input as an unsigned integer in the range
   [[0, 2*max_int+1]].  If the input exceeds {!max_int}
   it is converted to the signed integer
   [min_int + input - max_int - 1].

   The [_] (underscore) character can appear anywhere in the string
   and is ignored.

   Return [None] if the given string is not a valid representation of an
   integer, or if the integer represented exceeds the range of integers
   representable in type [int].
   @since 4.05
*)

external int_of_string : string -> int = "caml_int_of_string"
(** Same as {!Stdlib.int_of_string_opt}, but raise
   [Failure "int_of_string"] instead of returning [None]. *)

val string_of_float : float -> string
(** Return a string representation of a floating-point number.

    This conversion can involve a loss of precision. For greater control over
    the manner in which the number is printed, see {!Printf}. *)

val float_of_string_opt: string -> float option
(** Convert the given string to a float.  The string is read in decimal
   (by default) or in hexadecimal (marked by [0x] or [0X]).

   The format of decimal floating-point numbers is
   [ [-] dd.ddd (e|E) [+|-] dd ], where [d] stands for a decimal digit.

   The format of hexadecimal floating-point numbers is
   [ [-] 0(x|X) hh.hhh (p|P) [+|-] dd ], where [h] stands for an
   hexadecimal digit and [d] for a decimal digit.

   In both cases, at least one of the integer and fractional parts must be
   given; the exponent part is optional.

   The [_] (underscore) character can appear anywhere in the string
   and is ignored.

   Depending on the execution platforms, other representations of
   floating-point numbers can be accepted, but should not be relied upon.

   Return [None] if the given string is not a valid representation of a float.
   @since 4.05
*)

external float_of_string : string -> float = "caml_float_of_string"
(** Same as {!Stdlib.float_of_string_opt}, but raise
   [Failure "float_of_string"] instead of returning [None]. *)

(** {1 Pair operations} *)

external fst : ('a * 'b[@local_opt]) -> ('a[@local_opt]) = "%field0_immut"
(** Return the first component of a pair. *)

external snd : ('a * 'b[@local_opt]) -> ('b[@local_opt]) = "%field1_immut"
(** Return the second component of a pair. *)


(** {1 List operations}

   More list operations are provided in module {!List}.
*)

val ( @ ) : ('a : value_or_null) . 'a list -> 'a list -> 'a list
(** [l0 @ l1] appends [l1] to [l0]. Same function as {!List.append}.
  Right-associative operator, see {!Ocaml_operators} for more information.
  @since 5.1 this function is tail-recursive.
*)

(** {1 Input/output}
    Note: all input/output functions can raise [Sys_error] when the system
    calls they invoke fail. *)

type in_channel : value mod portable contended
(** The type of input channel. *)

type out_channel : value mod portable contended
(** The type of output channel. *)

val stdin : in_channel
(** The standard input for the process. *)

val stdout : out_channel
(** The standard output for the process. *)

val stderr : out_channel
(** The standard error output for the process. *)


(** {2 Output functions on standard output} *)

val print_char : char -> unit
(** Print a character on standard output. *)

val print_string : string -> unit
(** Print a string on standard output. *)

val print_bytes : bytes -> unit
(** Print a byte sequence on standard output.
   @since 4.02 *)

val print_int : int -> unit
(** Print an integer, in decimal, on standard output. *)

val print_float : float -> unit
(** Print a floating-point number, in decimal, on standard output.

    The conversion of the number to a string uses {!string_of_float} and
    can involve a loss of precision. *)

val print_endline : string -> unit
(** Print a string, followed by a newline character, on
   standard output and flush standard output. *)

val print_newline : unit -> unit
(** Print a newline character on standard output, and flush
   standard output. This can be used to simulate line
   buffering of standard output. *)


(** {2 Output functions on standard error} *)

val prerr_char : char -> unit
(** Print a character on standard error. *)

val prerr_string : string -> unit
(** Print a string on standard error. *)

val prerr_bytes : bytes -> unit
(** Print a byte sequence on standard error.
   @since 4.02 *)

val prerr_int : int -> unit
(** Print an integer, in decimal, on standard error. *)

val prerr_float : float -> unit
(** Print a floating-point number, in decimal, on standard error.

    The conversion of the number to a string uses {!string_of_float} and
    can involve a loss of precision. *)

val prerr_endline : string -> unit
(** Print a string, followed by a newline character on standard
   error and flush standard error. *)

val prerr_newline : unit -> unit
(** Print a newline character on standard error, and flush
   standard error. *)


(** {2 Input functions on standard input} *)

val read_line : unit -> string
(** Flush standard output, then read characters from standard input
   until a newline character is encountered.

   Return the string of all characters read, without the newline character
   at the end.

   @raise End_of_file if the end of the file is reached at the beginning of
   line.
*)

val read_int_opt: unit -> int option
(** Flush standard output, then read one line from standard input
   and convert it to an integer.

   Return [None] if the line read is not a valid representation of an integer.
   @since 4.05
*)

val read_int : unit -> int
(** Same as {!Stdlib.read_int_opt}, but raise [Failure "int_of_string"]
   instead of returning [None]. *)

val read_float_opt: unit -> float option
(** Flush standard output, then read one line from standard input
   and convert it to a floating-point number.

   Return [None] if the line read is not a valid representation of a
   floating-point number.
   @since 4.05
*)

val read_float : unit -> float
(** Same as {!Stdlib.read_float_opt}, but raise [Failure "float_of_string"]
   instead of returning [None]. *)


(** {2 General output functions} *)

type open_flag =
    Open_rdonly      (** open for reading. *)
  | Open_wronly      (** open for writing. *)
  | Open_append      (** open for appending: always write at end of file. *)
  | Open_creat       (** create the file if it does not exist. *)
  | Open_trunc       (** empty the file if it already exists. *)
  | Open_excl        (** fail if Open_creat and the file already exists. *)
  | Open_binary      (** open in binary mode (no conversion). *)
  | Open_text        (** open in text mode (may perform conversions). *)
  | Open_nonblock    (** open in non-blocking mode. *)
(** Opening modes for {!Stdlib.open_out_gen} and
  {!Stdlib.open_in_gen}. *)

val open_out : string -> out_channel
(** Open the named file for writing, and return a new output channel
   on that file, positioned at the beginning of the file. The
   file is truncated to zero length if it already exists. It
   is created if it does not already exists. *)

val open_out_bin : string -> out_channel
(** Same as {!Stdlib.open_out}, but the file is opened in binary mode,
   so that no translation takes place during writes. On operating
   systems that do not distinguish between text mode and binary
   mode, this function behaves like {!Stdlib.open_out}. *)

val open_out_gen : open_flag list -> int -> string -> out_channel
(** [open_out_gen mode perm filename] opens the named file for writing,
   as described above. The extra argument [mode]
   specifies the opening mode. The extra argument [perm] specifies
   the file permissions, in case the file must be created.
   {!Stdlib.open_out} and {!Stdlib.open_out_bin} are special
   cases of this function. *)

val flush : out_channel -> unit
(** Flush the buffer associated with the given output channel,
   performing all pending writes on that channel.
   Interactive programs must be careful about flushing standard
   output and standard error at the right time. *)

val flush_all : unit -> unit
(** Flush all open output channels; ignore errors. *)

val output_char : out_channel -> char -> unit
(** Write the character on the given output channel. *)

val output_string : out_channel -> string -> unit
(** Write the string on the given output channel. *)

val output_bytes : out_channel -> bytes -> unit
(** Write the byte sequence on the given output channel.
   @since 4.02 *)

val output : out_channel -> bytes -> int -> int -> unit
(** [output oc buf pos len] writes [len] characters from byte sequence [buf],
   starting at offset [pos], to the given output channel [oc].
   @raise Invalid_argument if [pos] and [len] do not
   designate a valid range of [buf]. *)

val output_substring : out_channel -> string -> int -> int -> unit
(** Same as [output] but take a string as argument instead of
   a byte sequence.
   @since 4.02 *)

val output_byte : out_channel -> int -> unit
(** Write one 8-bit integer (as the single character with that code)
   on the given output channel. The given integer is taken modulo
   256. *)

val output_binary_int : out_channel -> int -> unit
(** Write one integer in binary format (4 bytes, big-endian)
   on the given output channel.
   The given integer is taken modulo 2{^32}.
   The only reliable way to read it back is through the
   {!Stdlib.input_binary_int} function. The format is compatible across
   all machines for a given version of OCaml. *)

val output_value :  ('a : value_or_null) . out_channel -> 'a -> unit
(** Write the representation of a structured value of any type
   to a channel. Circularities and sharing inside the value
   are detected and preserved. The object can be read back,
   by the function {!Stdlib.input_value}. See the description of module
   {!Marshal} for more information. {!Stdlib.output_value} is equivalent
   to {!Marshal.to_channel} with an empty list of flags. *)

val seek_out : out_channel -> int -> unit
(** [seek_out chan pos] sets the current writing position to [pos]
   for channel [chan]. This works only for regular files. On
   files of other kinds (such as terminals, pipes and sockets),
   the behavior is unspecified. *)

val pos_out : out_channel -> int
(** Return the current writing position for the given channel.  Does
    not work on channels opened with the [Open_append] flag (returns
    unspecified results).
    For files opened in text mode under Windows, the returned position
    is approximate (owing to end-of-line conversion); in particular,
    saving the current position with [pos_out], then going back to
    this position using [seek_out] will not work.  For this
    programming idiom to work reliably and portably, the file must be
    opened in binary mode. *)

val out_channel_length : out_channel -> int
(** Return the size (number of characters) of the regular file
   on which the given channel is opened.  If the channel is opened
    on a file that is not a regular file, the result is meaningless. *)

val close_out : out_channel -> unit
(** Close the given channel, flushing all buffered write operations.
   Output functions raise a [Sys_error] exception when they are
   applied to a closed output channel, except [close_out] and [flush],
   which do nothing when applied to an already closed channel.
   Note that [close_out] may raise [Sys_error] if the operating
   system signals an error when flushing or closing. *)

val close_out_noerr : out_channel -> unit
(** Same as [close_out], but ignore all errors. *)

val set_binary_mode_out : out_channel -> bool -> unit
(** [set_binary_mode_out oc true] sets the channel [oc] to binary
   mode: no translations take place during output.
   [set_binary_mode_out oc false] sets the channel [oc] to text
   mode: depending on the operating system, some translations
   may take place during output.  For instance, under Windows,
   end-of-lines will be translated from [\n] to [\r\n].
   This function has no effect under operating systems that
   do not distinguish between text mode and binary mode. *)


(** {2 General input functions} *)

val open_in : string -> in_channel
(** Open the named file for reading, and return a new input channel
   on that file, positioned at the beginning of the file. *)

val open_in_bin : string -> in_channel
(** Same as {!Stdlib.open_in}, but the file is opened in binary mode,
   so that no translation takes place during reads. On operating
   systems that do not distinguish between text mode and binary
   mode, this function behaves like {!Stdlib.open_in}. *)

val open_in_gen : open_flag list -> int -> string -> in_channel
(** [open_in_gen mode perm filename] opens the named file for reading,
   as described above. The extra arguments
   [mode] and [perm] specify the opening mode and file permissions.
   {!Stdlib.open_in} and {!Stdlib.open_in_bin} are special
   cases of this function. *)

val input_char : in_channel -> char
(** Read one character from the given input channel.
   @raise End_of_file if there are no more characters to read. *)

val input_line : in_channel -> string
(** Read characters from the given input channel, until a
   newline character is encountered. Return the string of
   all characters read, without the newline character at the end.
   @raise End_of_file if the end of the file is reached
   at the beginning of line. *)

val input : in_channel -> bytes -> int -> int -> int
(** [input ic buf pos len] reads up to [len] characters from
   the given channel [ic], storing them in byte sequence [buf], starting at
   character number [pos].
   It returns the actual number of characters read, between 0 and
   [len] (inclusive).
   A return value of 0 means that the end of file was reached.
   A return value between 0 and [len] exclusive means that
   not all requested [len] characters were read, either because
   no more characters were available at that time, or because
   the implementation found it convenient to do a partial read;
   [input] must be called again to read the remaining characters,
   if desired.  (See also {!Stdlib.really_input} for reading
   exactly [len] characters.)
   Exception [Invalid_argument "input"] is raised if [pos] and [len]
   do not designate a valid range of [buf]. *)

val really_input : in_channel -> bytes -> int -> int -> unit
(** [really_input ic buf pos len] reads [len] characters from channel [ic],
   storing them in byte sequence [buf], starting at character number [pos].
   @raise End_of_file if the end of file is reached before [len]
   characters have been read.
   @raise Invalid_argument if
   [pos] and [len] do not designate a valid range of [buf]. *)

val really_input_string : in_channel -> int -> string
(** [really_input_string ic len] reads [len] characters from channel [ic]
   and returns them in a new string.
   @raise End_of_file if the end of file is reached before [len]
   characters have been read.
   @since 4.02 *)

val input_byte : in_channel -> int
(** Same as {!Stdlib.input_char}, but return the 8-bit integer representing
   the character.
   @raise End_of_file if the end of file was reached. *)

val input_binary_int : in_channel -> int
(** Read an integer encoded in binary format (4 bytes, big-endian)
   from the given input channel. See {!Stdlib.output_binary_int}.
   @raise End_of_file if the end of file was reached while reading the
   integer. *)

val input_value : ('a : value_or_null) . in_channel -> 'a
(** Read the representation of a structured value, as produced
   by {!Stdlib.output_value}, and return the corresponding value.
   This function is identical to {!Marshal.from_channel};
   see the description of module {!Marshal} for more information,
   in particular concerning the lack of type safety. *)

val seek_in : in_channel -> int -> unit
(** [seek_in chan pos] sets the current reading position to [pos]
   for channel [chan]. This works only for regular files. On
   files of other kinds, the behavior is unspecified. *)

val pos_in : in_channel -> int
(** Return the current reading position for the given channel.  For
    files opened in text mode under Windows, the returned position is
    approximate (owing to end-of-line conversion); in particular,
    saving the current position with [pos_in], then going back to this
    position using [seek_in] will not work.  For this programming
    idiom to work reliably and portably, the file must be opened in
    binary mode. *)

val in_channel_length : in_channel -> int
(** Return the size (number of characters) of the regular file
    on which the given channel is opened.  If the channel is opened
    on a file that is not a regular file, the result is meaningless.
    The returned size does not take into account the end-of-line
    translations that can be performed when reading from a channel
    opened in text mode. *)

val close_in : in_channel -> unit
(** Close the given channel.  Input functions raise a [Sys_error]
  exception when they are applied to a closed input channel,
  except [close_in], which does nothing when applied to an already
  closed channel. *)

val close_in_noerr : in_channel -> unit
(** Same as [close_in], but ignore all errors. *)

val set_binary_mode_in : in_channel -> bool -> unit
(** [set_binary_mode_in ic true] sets the channel [ic] to binary
   mode: no translations take place during input.
   [set_binary_mode_out ic false] sets the channel [ic] to text
   mode: depending on the operating system, some translations
   may take place during input.  For instance, under Windows,
   end-of-lines will be translated from [\r\n] to [\n].
   This function has no effect under operating systems that
   do not distinguish between text mode and binary mode. *)


(** {2 Operations on large files} *)

module LargeFile :
  sig
    val seek_out : out_channel -> int64 -> unit
    val pos_out : out_channel -> int64
    val out_channel_length : out_channel -> int64
    val seek_in : in_channel -> int64 -> unit
    val pos_in : in_channel -> int64
    val in_channel_length : in_channel -> int64
  end
(** Operations on large files.
  This sub-module provides 64-bit variants of the channel functions
  that manipulate file positions and file sizes.  By representing
  positions and sizes by 64-bit integers (type [int64]) instead of
  regular integers (type [int]), these alternate functions allow
  operating on files whose sizes are greater than [max_int]. *)

(** {1 References} *)

type ('a : value_or_null) ref = { mutable contents : 'a }
(** The type of references (mutable indirection cells) containing
   a value of type ['a]. *)

external ref : ('a : value_or_null) . 'a -> ('a ref[@local_opt]) = "%makemutable"
(** Return a fresh reference containing the given value. *)

external ( ! ) : ('a : value_or_null) . ('a ref[@local_opt]) -> 'a = "%field0"
(** [!r] returns the current contents of reference [r].
   Equivalent to [fun r -> r.contents].
   Unary operator, see {!Ocaml_operators} for more information.
*)

external ( := ) : ('a : value_or_null) . ('a ref[@local_opt]) -> 'a -> unit = "%setfield0"
(** [r := a] stores the value of [a] in reference [r].
   Equivalent to [fun r v -> r.contents <- v].
   Right-associative operator, see {!Ocaml_operators} for more information.
*)

external incr : (int ref[@local_opt]) -> unit = "%incr"
(** Increment the integer contained in the given reference.
   Equivalent to [fun r -> r := succ !r]. *)

external decr : (int ref[@local_opt]) -> unit = "%decr"
(** Decrement the integer contained in the given reference.
   Equivalent to [fun r -> r := pred !r]. *)

(** {1 Result type} *)

(** @since 4.03 *)
type ('a : value_or_null, 'b : value_or_null) result = Ok of 'a | Error of 'b

(** {1 Operations on format strings} *)

(** Format strings are character strings with special lexical conventions
  that defines the functionality of formatted input/output functions. Format
  strings are used to read data with formatted input functions from module
  {!Scanf} and to print data with formatted output functions from modules
  {!Printf} and {!Format}.

  Format strings are made of three kinds of entities:
  - {e conversions specifications}, introduced by the special character ['%']
    followed by one or more characters specifying what kind of argument to
    read or print,
  - {e formatting indications}, introduced by the special character ['@']
    followed by one or more characters specifying how to read or print the
    argument,
  - {e plain characters} that are regular characters with usual lexical
    conventions. Plain characters specify string literals to be read in the
    input or printed in the output.

  There is an additional lexical rule to escape the special characters ['%']
  and ['@'] in format strings: if a special character follows a ['%']
  character, it is treated as a plain character. In other words, ["%%"] is
  considered as a plain ['%'] and ["%@"] as a plain ['@'].

  For more information about conversion specifications and formatting
  indications available, read the documentation of modules {!Scanf},
  {!Printf} and {!Format}.
*)

(** Format strings have a general and highly polymorphic type
    [('a, 'b, 'c, 'd, 'e, 'f) format6].
    The two simplified types, [format] and [format4] below are
    included for backward compatibility with earlier releases of
    OCaml.

    The meaning of format string type parameters is as follows:

    - ['a] is the type of the parameters of the format for formatted output
      functions ([printf]-style functions);
      ['a] is the type of the values read by the format for formatted input
      functions ([scanf]-style functions).

    - ['b] is the type of input source for formatted input functions and the
      type of output target for formatted output functions.
      For [printf]-style functions from module {!Printf}, ['b] is typically
      [out_channel];
      for [printf]-style functions from module {!Format}, ['b] is typically
      {!type:Format.formatter};
      for [scanf]-style functions from module {!Scanf}, ['b] is typically
      {!Scanf.Scanning.in_channel}.

      Type argument ['b] is also the type of the first argument given to
      user's defined printing functions for [%a] and [%t] conversions,
      and user's defined reading functions for [%r] conversion.

    - ['c] is the type of the result of the [%a] and [%t] printing
      functions, and also the type of the argument transmitted to the
      first argument of [kprintf]-style functions or to the
      [kscanf]-style functions.

    - ['d] is the type of parameters for the [scanf]-style functions.

    - ['e] is the type of the receiver function for the [scanf]-style functions.

    - ['f] is the final result type of a formatted input/output function
      invocation: for the [printf]-style functions, it is typically [unit];
      for the [scanf]-style functions, it is typically the result type of the
      receiver function.
*)

type ('a, 'b, 'c, 'd, 'e, 'f) format6 =
  ('a, 'b, 'c, 'd, 'e, 'f) CamlinternalFormatBasics.format6

type ('a, 'b, 'c, 'd) format4 = ('a, 'b, 'c, 'c, 'c, 'd) format6

type ('a, 'b, 'c) format = ('a, 'b, 'c, 'c) format4

val string_of_format : ('a, 'b, 'c, 'd, 'e, 'f) format6 -> string
(** Converts a format string into a string. *)

external format_of_string :
  ('a, 'b, 'c, 'd, 'e, 'f) format6 ->
  ('a, 'b, 'c, 'd, 'e, 'f) format6 = "%identity"
(** [format_of_string s] returns a format string read from the string
    literal [s].
    Note: [format_of_string] can not convert a string argument that is not a
    literal. If you need this functionality, use the more general
    {!Scanf.format_from_string} function.
*)

val ( ^^ ) :
  ('a, 'b, 'c, 'd, 'e, 'f) format6 ->
  ('f, 'b, 'c, 'e, 'g, 'h) format6 ->
  ('a, 'b, 'c, 'd, 'g, 'h) format6
(** [f1 ^^ f2] catenates format strings [f1] and [f2]. The result is a
  format string that behaves as the concatenation of format strings [f1] and
  [f2]: in case of formatted output, it accepts arguments from [f1], then
  arguments from [f2]; in case of formatted input, it returns results from
  [f1], then results from [f2].
  Right-associative operator, see {!Ocaml_operators} for more information.
*)

(** {1 Program termination} *)

val exit : int -> 'a @@ nonportable
(** Terminate the process, returning the given status code to the operating
    system: usually 0 to indicate no errors, and a small positive integer to
    indicate failure. All open output channels are flushed with [flush_all].
    The callbacks registered with {!Domain.at_exit} are called followed by
    those registered with {!Stdlib.at_exit}.

    An implicit [exit 0] is performed each time a program terminates normally.
    An implicit [exit 2] is performed if the program terminates early because
    of an uncaught exception. *)

val at_exit : (unit -> unit) -> unit @@ nonportable
(** Register the given function to be called at program termination
   time. The functions registered with [at_exit] will be called when
   the program does any of the following:
   - executes {!Stdlib.exit}
   - terminates, either normally or because of an uncaught
     exception
   - executes the C function [caml_shutdown].
   The functions are called in 'last in, first out' order: the
   function most recently added with [at_exit] is called first. *)

(** Submodule containing non-backwards-compatible functions which enforce thread safety
    via modes. *)
module Safe : sig
  val at_exit : (unit -> unit) @ portable -> unit
  (** Like {!at_exit}, but can be called from any domain.

      The provided closure must be [portable] as it might be called from another domain.
      In particular, the primary domain may call {!exit}, thus calling the provided
      closure even if it came from a secondary domain. *)
end

(**/**)

(* The following is for system use only. Do not call directly. *)

val valid_float_lexem : string -> string @@ nonportable

val unsafe_really_input : in_channel -> bytes -> int -> int -> unit @@ nonportable

val do_at_exit : unit -> unit @@ nonportable

val do_domain_local_at_exit : (unit -> unit) ref @@ nonportable

(**/**)

(** {1:modules Standard library modules } *)

(*MODULE_ALIASES*)
include sig
module Arg            = Arg
module Array          = Array
module ArrayLabels    = ArrayLabels
module Atomic         = Atomic
module Backoff        = Backoff
module Bigarray       = Bigarray
module Bool           = Bool
module Buffer         = Buffer
module Bytes          = Bytes
module BytesLabels    = BytesLabels
module Callback       = Callback
module Char           = Char
module Complex        = Complex
module Condition      = Condition
module Digest         = Digest
module Domain         = Domain
[@@alert "-unstable"]
[@@alert unstable
    "The Domain interface may change in incompatible ways in the future."
]
module Dynarray       = Dynarray
module Effect         = Effect
[@@alert "-unstable"]
[@@alert unstable
    "The Effect interface may change in incompatible ways in the future."
]
module Either         = Either
module Ephemeron      = Ephemeron
module Filename       = Filename
module Float          = Float
module Format         = Format
module Fun            = Fun
module Gc             = Gc
module Hashtbl        = Hashtbl
module In_channel     = In_channel
module Int            = Int
module Int32          = Int32
module Int64          = Int64
module Lazy           = Lazy
module Lexing         = Lexing
module List           = List
module ListLabels     = ListLabels
module Map            = Map
module Marshal        = Marshal
module Modes          = Modes
module MoreLabels     = MoreLabels
module Mutex          = Mutex
module Nativeint      = Nativeint
module Obj            = Obj
module Oo             = Oo
module Option         = Option
module Out_channel    = Out_channel
module Parsing        = Parsing
module Printexc       = Printexc
module Printf         = Printf
module Queue          = Queue
module Random         = Random
module Result         = Result
module Scanf          = Scanf
module Semaphore      = Semaphore
module Seq            = Seq
module Set            = Set
module Stack          = Stack
module StdLabels      = StdLabels
module String         = String
module StringLabels   = StringLabels
module Sys            = Sys
module Type           = Type
module Uchar          = Uchar
module Unit           = Unit
module Weak           = Weak
end @@ nonportable
