(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                    Zesen Qian, Jane Street, London                     *)
(*                                                                        *)
(*   Copyright 2024 Jane Street Group LLC                                 *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* warn on fragile matches *)
[@@@warning "+4"]

open Allowance
open Solver
open Mode_intf

type nonrec allowed = allowed

type nonrec disallowed = disallowed

type nonrec equate_step = equate_step

module type Heyting = sig
  (** Extend the [Lattice] interface with operations of Heyting algebras *)

  include Lattice

  (** [imply c] is the right adjoint of [meet c]; That is, for any [a] and [b],
      [meet c a <= b] iff [a <= imply c b] *)
  val imply : t -> t -> t
end

module type CoHeyting = sig
  (** Extend the [Lattice] interface with operations of co-Heyting algebras *)

  include Lattice

  (** [subtract _ c] is the left adjoint of [join c]. That is, for any [a] and [b],
      [subtract a c <= b] iff [a <= join c b] *)
  val subtract : t -> t -> t
end

(* Even though our lattices are all bi-heyting algebras, that knowledge is
   internal to this module. Externally they are seen as normal lattices. *)
module Lattices = struct
  module Total = struct
    (** A lattice is total order, if for any [a] [b], [a <= b] or [b <= a]. *)

    module CoHeyting (L : Lattice) : CoHeyting with type t := L.t = struct
      (** A total lattice has a co-heyting structure. *)

      include L

      (* Prove the [subtract] below is the left adjoint of [join].
         - If [subtract a c <= b], by the definition of [subtract] below,
           that could mean one of two things:
           - Took the branch [a <= c], and [min <= b]. In this case, we have [a <= c <= join c b].
           - Took the other branch, and [a <= b]. In this case, we have [a <= b <= join c b].

         - In the other direction: Given [a <= join c b], compare [c] and [b]:
           - if [c <= b], then [a <= join c b = b], and:
             - either [a <= c], then [subtract a c = min <= b]
             - or the other branch, then [subtract a c = a <= b]
           - if [b <= c], then [a <= join c b = c], then [subtract a c = min <= b]
      *)
      let subtract a c = if le a c then min else a
    end
    [@@inline]

    module Heyting (L : Lattice) : Heyting with type t := L.t = struct
      (** A total lattice has a heyting structure. *)

      include L

      (* The proof for [imply] is dual and omitted. *)
      let imply c b = if le c b then max else b
    end
    [@@inline]
  end

  (* Make the type of [Locality] and [Regionality] below distinguishable,
     so that we can be sure [Comonadic_with] is applied correctly. *)
  module type Areality = sig
    include Heyting

    val _is_areality : unit
  end

  module Locality = struct
    type t =
      | Global
      | Local

    include Total.Heyting (struct
      type nonrec t = t

      let min = Global

      let max = Local

      let legacy = Global

      let[@inline] le a b =
        match a, b with Global, _ | _, Local -> true | Local, Global -> false

      let[@inline] equal a b =
        match a, b with
        | Global, Global | Local, Local -> true
        | Global, Local | Local, Global -> false

      let join a b =
        match a, b with
        | Local, _ | _, Local -> Local
        | Global, Global -> Global

      let meet a b =
        match a, b with
        | Global, _ | _, Global -> Global
        | Local, Local -> Local

      let print ppf = function
        | Global -> Format.fprintf ppf "global"
        | Local -> Format.fprintf ppf "local"
    end)

    let _is_areality = ()
  end

  module Regionality = struct
    type t =
      | Global
      | Regional
      | Local

    include Total.Heyting (struct
      type nonrec t = t

      let min = Global

      let max = Local

      let legacy = Global

      let[@inline] equal a b =
        match a, b with
        | Global, Global -> true
        | Regional, Regional -> true
        | Local, Local -> true
        | Global, (Regional | Local)
        | Regional, (Global | Local)
        | Local, (Global | Regional) ->
          false

      let join a b =
        match a, b with
        | Local, _ | _, Local -> Local
        | Regional, _ | _, Regional -> Regional
        | Global, Global -> Global

      let meet a b =
        match a, b with
        | Global, _ | _, Global -> Global
        | Regional, _ | _, Regional -> Regional
        | Local, Local -> Local

      let[@inline] le a b =
        match a, b with
        | Global, _ | _, Local -> true
        | _, Global | Local, _ -> false
        | Regional, Regional -> true

      let print ppf = function
        | Global -> Format.fprintf ppf "global"
        | Regional -> Format.fprintf ppf "regional"
        | Local -> Format.fprintf ppf "local"
    end)

    let _is_areality = ()
  end

  module Uniqueness = struct
    type t =
      | Unique
      | Aliased

    include Total.CoHeyting (struct
      type nonrec t = t

      let min = Unique

      let max = Aliased

      let legacy = Aliased

      let[@inline] le a b =
        match a, b with
        | Unique, _ | _, Aliased -> true
        | Aliased, Unique -> false

      let[@inline] equal a b =
        match a, b with
        | Unique, Unique -> true
        | Aliased, Aliased -> true
        | Unique, Aliased | Aliased, Unique -> false

      let join a b =
        match a, b with
        | Aliased, _ | _, Aliased -> Aliased
        | Unique, Unique -> Unique

      let meet a b =
        match a, b with
        | Unique, _ | _, Unique -> Unique
        | Aliased, Aliased -> Aliased

      let print ppf = function
        | Aliased -> Format.fprintf ppf "aliased"
        | Unique -> Format.fprintf ppf "unique"
    end)
  end

  module Linearity = struct
    type t =
      | Many
      | Once

    include Total.Heyting (struct
      type nonrec t = t

      let min = Many

      let max = Once

      let legacy = Many

      let[@inline] le a b =
        match a, b with Many, _ | _, Once -> true | Once, Many -> false

      let[@inline] equal a b =
        match a, b with
        | Many, Many -> true
        | Once, Once -> true
        | Many, Once | Once, Many -> false

      let join a b =
        match a, b with Once, _ | _, Once -> Once | Many, Many -> Many

      let meet a b =
        match a, b with Many, _ | _, Many -> Many | Once, Once -> Once

      let print ppf = function
        | Once -> Format.fprintf ppf "once"
        | Many -> Format.fprintf ppf "many"
    end)
  end

  module Portability = struct
    type t =
      | Portable
      | Nonportable

    include Total.Heyting (struct
      type nonrec t = t

      let min = Portable

      let max = Nonportable

      let legacy = Nonportable

      let[@inline] le a b =
        match a, b with
        | Portable, _ | _, Nonportable -> true
        | Nonportable, Portable -> false

      let[@inline] equal a b =
        match a, b with
        | Portable, Portable -> true
        | Nonportable, Nonportable -> true
        | Portable, Nonportable | Nonportable, Portable -> false

      let join a b =
        match a, b with
        | Nonportable, _ | _, Nonportable -> Nonportable
        | Portable, Portable -> Portable

      let meet a b =
        match a, b with
        | Portable, _ | _, Portable -> Portable
        | Nonportable, Nonportable -> Nonportable

      let print ppf = function
        | Portable -> Format.fprintf ppf "portable"
        | Nonportable -> Format.fprintf ppf "nonportable"
    end)
  end

  module Contention = struct
    type t =
      | Contended
      | Shared
      | Uncontended

    include Total.CoHeyting (struct
      type nonrec t = t

      let min = Uncontended

      let max = Contended

      let legacy = Uncontended

      let[@inline] le a b =
        match a, b with
        | Uncontended, _ | _, Contended -> true
        | _, Uncontended | Contended, _ -> false
        | Shared, Shared -> true

      let[@inline] equal a b =
        match a, b with
        | Contended, Contended -> true
        | Shared, Shared -> true
        | Uncontended, Uncontended -> true
        | Contended, (Shared | Uncontended)
        | Shared, (Contended | Uncontended)
        | Uncontended, (Contended | Shared) ->
          false

      let join a b =
        match a, b with
        | Contended, _ | _, Contended -> Contended
        | Shared, _ | _, Shared -> Shared
        | Uncontended, Uncontended -> Uncontended

      let meet a b =
        match a, b with
        | Uncontended, _ | _, Uncontended -> Uncontended
        | Shared, _ | _, Shared -> Shared
        | Contended, Contended -> Contended

      let print ppf = function
        | Contended -> Format.fprintf ppf "contended"
        | Shared -> Format.fprintf ppf "shared"
        | Uncontended -> Format.fprintf ppf "uncontended"
    end)
  end

  module Yielding = struct
    type t =
      | Yielding
      | Unyielding

    include Total.Heyting (struct
      type nonrec t = t

      let min = Unyielding

      let max = Yielding

      let legacy = Unyielding

      let[@inline] le a b =
        match a, b with
        | Unyielding, _ | _, Yielding -> true
        | Yielding, Unyielding -> false

      let[@inline] equal a b =
        match a, b with
        | Yielding, Yielding -> true
        | Unyielding, Unyielding -> true
        | Yielding, Unyielding | Unyielding, Yielding -> false

      let join a b =
        match a, b with
        | Yielding, _ | _, Yielding -> Yielding
        | Unyielding, Unyielding -> Unyielding

      let meet a b =
        match a, b with
        | Unyielding, _ | _, Unyielding -> Unyielding
        | Yielding, Yielding -> Yielding

      let print ppf = function
        | Yielding -> Format.fprintf ppf "yielding"
        | Unyielding -> Format.fprintf ppf "unyielding"
    end)
  end

  module Statefulness = struct
    type t =
      | Stateless
      | Observing
      | Stateful

    include Total.Heyting (struct
      type nonrec t = t

      let min = Stateless

      let max = Stateful

      let legacy = Stateful

      let[@inline] le a b =
        match a, b with
        | Stateless, _ | _, Stateful -> true
        | _, Stateless | Stateful, _ -> false
        | Observing, Observing -> true

      let[@inline] equal a b =
        match a, b with
        | Stateless, Stateless -> true
        | Observing, Observing -> true
        | Stateful, Stateful -> true
        | Stateless, (Observing | Stateful)
        | Observing, (Stateless | Stateful)
        | Stateful, (Stateless | Observing) ->
          false

      let join a b =
        match a, b with
        | Stateful, _ | _, Stateful -> Stateful
        | Observing, _ | _, Observing -> Observing
        | Stateless, Stateless -> Stateless

      let meet a b =
        match a, b with
        | Stateless, _ | _, Stateless -> Stateless
        | Observing, _ | _, Observing -> Observing
        | Stateful, Stateful -> Stateful

      let print ppf = function
        | Stateless -> Format.fprintf ppf "stateless"
        | Observing -> Format.fprintf ppf "observing"
        | Stateful -> Format.fprintf ppf "stateful"
    end)
  end

  module Visibility = struct
    type t =
      | Immutable
      | Read
      | Read_write

    include Total.CoHeyting (struct
      type nonrec t = t

      let min = Read_write

      let max = Immutable

      let legacy = Read_write

      let[@inline] le a b =
        match a, b with
        | Read_write, _ | _, Immutable -> true
        | _, Read_write | Immutable, _ -> false
        | Read, Read -> true

      let[@inline] equal a b =
        match a, b with
        | Immutable, Immutable -> true
        | Read, Read -> true
        | Read_write, Read_write -> true
        | Immutable, (Read | Read_write)
        | Read, (Immutable | Read_write)
        | Read_write, (Immutable | Read) ->
          false

      let join a b =
        match a, b with
        | Immutable, _ | _, Immutable -> Immutable
        | Read, _ | _, Read -> Read
        | Read_write, Read_write -> Read_write

      let meet a b =
        match a, b with
        | Read_write, _ | _, Read_write -> Read_write
        | Read, _ | _, Read -> Read
        | Immutable, Immutable -> Immutable

      let print ppf = function
        | Immutable -> Format.fprintf ppf "immutable"
        | Read -> Format.fprintf ppf "read"
        | Read_write -> Format.fprintf ppf "read_write"
    end)
  end

  type monadic =
    { uniqueness : Uniqueness.t;
      contention : Contention.t;
      visibility : Visibility.t
    }

  module Monadic = struct
    type t = monadic

    let min =
      let uniqueness = Uniqueness.min in
      let contention = Contention.min in
      let visibility = Visibility.min in
      { uniqueness; contention; visibility }

    let max =
      let uniqueness = Uniqueness.max in
      let contention = Contention.max in
      let visibility = Visibility.max in
      { uniqueness; contention; visibility }

    let legacy =
      let uniqueness = Uniqueness.legacy in
      let contention = Contention.legacy in
      let visibility = Visibility.legacy in
      { uniqueness; contention; visibility }

    let le m1 m2 =
      let { uniqueness = uniqueness1;
            contention = contention1;
            visibility = visibility1
          } =
        m1
      in
      let { uniqueness = uniqueness2;
            contention = contention2;
            visibility = visibility2
          } =
        m2
      in
      Uniqueness.le uniqueness1 uniqueness2
      && Contention.le contention1 contention2
      && Visibility.le visibility1 visibility2

    let equal m1 m2 =
      let { uniqueness = uniqueness1;
            contention = contention1;
            visibility = visibility1
          } =
        m1
      in
      let { uniqueness = uniqueness2;
            contention = contention2;
            visibility = visibility2
          } =
        m2
      in
      Uniqueness.equal uniqueness1 uniqueness2
      && Contention.equal contention1 contention2
      && Visibility.equal visibility1 visibility2

    let join m1 m2 =
      let uniqueness = Uniqueness.join m1.uniqueness m2.uniqueness in
      let contention = Contention.join m1.contention m2.contention in
      let visibility = Visibility.join m1.visibility m2.visibility in
      { uniqueness; contention; visibility }

    let meet m1 m2 =
      let uniqueness = Uniqueness.meet m1.uniqueness m2.uniqueness in
      let contention = Contention.meet m1.contention m2.contention in
      let visibility = Visibility.meet m1.visibility m2.visibility in
      { uniqueness; contention; visibility }

    let subtract m1 m2 =
      let uniqueness = Uniqueness.subtract m1.uniqueness m2.uniqueness in
      let contention = Contention.subtract m1.contention m2.contention in
      let visibility = Visibility.subtract m1.visibility m2.visibility in
      { uniqueness; contention; visibility }

    let print ppf m =
      Format.fprintf ppf "%a,%a,%a" Uniqueness.print m.uniqueness
        Contention.print m.contention Visibility.print m.visibility
  end

  type 'areality comonadic_with =
    { areality : 'areality;
      linearity : Linearity.t;
      portability : Portability.t;
      yielding : Yielding.t;
      statefulness : Statefulness.t
    }

  module Comonadic_with (Areality : Areality) = struct
    type t = Areality.t comonadic_with

    let min =
      let areality = Areality.min in
      let linearity = Linearity.min in
      let portability = Portability.min in
      let yielding = Yielding.min in
      let statefulness = Statefulness.min in
      { areality; linearity; portability; yielding; statefulness }

    let max =
      let areality = Areality.max in
      let linearity = Linearity.max in
      let portability = Portability.max in
      let yielding = Yielding.max in
      let statefulness = Statefulness.max in
      { areality; linearity; portability; yielding; statefulness }

    let legacy =
      let areality = Areality.legacy in
      let linearity = Linearity.legacy in
      let portability = Portability.legacy in
      let yielding = Yielding.legacy in
      let statefulness = Statefulness.legacy in
      { areality; linearity; portability; yielding; statefulness }

    let le m1 m2 =
      let { areality = areality1;
            linearity = linearity1;
            portability = portability1;
            yielding = yielding1;
            statefulness = statefulness1
          } =
        m1
      in
      let { areality = areality2;
            linearity = linearity2;
            portability = portability2;
            yielding = yielding2;
            statefulness = statefulness2
          } =
        m2
      in
      Areality.le areality1 areality2
      && Linearity.le linearity1 linearity2
      && Portability.le portability1 portability2
      && Yielding.le yielding1 yielding2
      && Statefulness.le statefulness1 statefulness2

    let equal m1 m2 =
      let { areality = areality1;
            linearity = linearity1;
            portability = portability1;
            yielding = yielding1;
            statefulness = statefulness1
          } =
        m1
      in
      let { areality = areality2;
            linearity = linearity2;
            portability = portability2;
            yielding = yielding2;
            statefulness = statefulness2
          } =
        m2
      in
      Areality.equal areality1 areality2
      && Linearity.equal linearity1 linearity2
      && Portability.equal portability1 portability2
      && Yielding.equal yielding1 yielding2
      && Statefulness.equal statefulness1 statefulness2

    let join m1 m2 =
      let areality = Areality.join m1.areality m2.areality in
      let linearity = Linearity.join m1.linearity m2.linearity in
      let portability = Portability.join m1.portability m2.portability in
      let yielding = Yielding.join m1.yielding m2.yielding in
      let statefulness = Statefulness.join m1.statefulness m2.statefulness in
      { areality; linearity; portability; yielding; statefulness }

    let meet m1 m2 =
      let areality = Areality.meet m1.areality m2.areality in
      let linearity = Linearity.meet m1.linearity m2.linearity in
      let portability = Portability.meet m1.portability m2.portability in
      let yielding = Yielding.meet m1.yielding m2.yielding in
      let statefulness = Statefulness.meet m1.statefulness m2.statefulness in
      { areality; linearity; portability; yielding; statefulness }

    let imply m1 m2 =
      let areality = Areality.imply m1.areality m2.areality in
      let linearity = Linearity.imply m1.linearity m2.linearity in
      let portability = Portability.imply m1.portability m2.portability in
      let yielding = Yielding.imply m1.yielding m2.yielding in
      let statefulness = Statefulness.imply m1.statefulness m2.statefulness in
      { areality; linearity; portability; yielding; statefulness }

    let print ppf m =
      Format.fprintf ppf "%a,%a,%a,%a,%a" Areality.print m.areality
        Linearity.print m.linearity Portability.print m.portability
        Yielding.print m.yielding Statefulness.print m.statefulness
  end
  [@@inline]

  module Opposite (L : CoHeyting) : Heyting with type t = L.t = struct
    type t = L.t

    let min = L.max

    let max = L.min

    let legacy = L.legacy

    let[@inline] le a b = L.le b a

    let equal = L.equal

    let join = L.meet

    let meet = L.join

    let print = L.print

    let imply a b = L.subtract b a
  end
  [@@inline]

  (* Notes on flipping

     Our lattices are categorized into two fragments: monadic and comonadic. Moreover:
     - Morphisms between lattices in the same fragment are always monotone.
     - Morphisms between lattices from opposite fragments are always antitone.

     [Solver_mono] only supports monotone morphisms. To conform to this limitation, we
     flip all lattices in the monadic fragment, which makes morphisms between opposite
     fragments monotone. We submit this category of lattices (original comonadic lattices
     + flipped monadic lattices) to [Solver_mono].

     The resulted interface given by [Solver_mono] therefore has the monadic lattices
     flipped, which is unsuitable for the user of [mode.ml]. Therefore, We build on top of
     that and provide an interface to the user where monadic lattices are flipped back to
     its original ordering. See [module Monadic_gen] and [module Monadic].
  *)
  module Uniqueness_op = Opposite (Uniqueness)
  module Contention_op = Opposite (Contention)
  module Visibility_op = Opposite (Visibility)
  module Monadic_op = Opposite (Monadic)
  module Comonadic_with_locality = Comonadic_with (Locality)
  module Comonadic_with_regionality = Comonadic_with (Regionality)

  type 'a obj =
    | Locality : Locality.t obj
    | Regionality : Regionality.t obj
    | Uniqueness_op : Uniqueness_op.t obj
    | Linearity : Linearity.t obj
    | Portability : Portability.t obj
    | Yielding : Yielding.t obj
    | Statefulness : Statefulness.t obj
    | Contention_op : Contention_op.t obj
    | Visibility_op : Visibility_op.t obj
    | Monadic_op : Monadic_op.t obj
    | Comonadic_with_regionality : Comonadic_with_regionality.t obj
    | Comonadic_with_locality : Comonadic_with_locality.t obj

  let print_obj : type a. _ -> a obj -> unit =
   fun ppf -> function
    | Locality -> Format.fprintf ppf "Locality"
    | Regionality -> Format.fprintf ppf "Regionality"
    | Uniqueness_op -> Format.fprintf ppf "Uniqueness_op"
    | Linearity -> Format.fprintf ppf "Linearity"
    | Portability -> Format.fprintf ppf "Portability"
    | Yielding -> Format.fprintf ppf "Yielding"
    | Statefulness -> Format.fprintf ppf "Statefulness"
    | Contention_op -> Format.fprintf ppf "Contention_op"
    | Visibility_op -> Format.fprintf ppf "Visibility_op"
    | Monadic_op -> Format.fprintf ppf "Monadic_op"
    | Comonadic_with_locality -> Format.fprintf ppf "Comonadic_with_locality"
    | Comonadic_with_regionality ->
      Format.fprintf ppf "Comonadic_with_regionality"

  let min : type a. a obj -> a = function
    | Locality -> Locality.min
    | Regionality -> Regionality.min
    | Uniqueness_op -> Uniqueness_op.min
    | Contention_op -> Contention_op.min
    | Visibility_op -> Visibility_op.min
    | Yielding -> Yielding.min
    | Statefulness -> Statefulness.min
    | Linearity -> Linearity.min
    | Portability -> Portability.min
    | Monadic_op -> Monadic_op.min
    | Comonadic_with_locality -> Comonadic_with_locality.min
    | Comonadic_with_regionality -> Comonadic_with_regionality.min

  let max : type a. a obj -> a = function
    | Locality -> Locality.max
    | Regionality -> Regionality.max
    | Uniqueness_op -> Uniqueness_op.max
    | Contention_op -> Contention_op.max
    | Visibility_op -> Visibility_op.max
    | Linearity -> Linearity.max
    | Portability -> Portability.max
    | Yielding -> Yielding.max
    | Statefulness -> Statefulness.max
    | Monadic_op -> Monadic_op.max
    | Comonadic_with_locality -> Comonadic_with_locality.max
    | Comonadic_with_regionality -> Comonadic_with_regionality.max

  let le : type a. a obj -> a -> a -> bool =
   fun obj a b ->
    match obj with
    | Locality -> Locality.le a b
    | Regionality -> Regionality.le a b
    | Uniqueness_op -> Uniqueness_op.le a b
    | Contention_op -> Contention_op.le a b
    | Visibility_op -> Visibility_op.le a b
    | Linearity -> Linearity.le a b
    | Portability -> Portability.le a b
    | Yielding -> Yielding.le a b
    | Statefulness -> Statefulness.le a b
    | Monadic_op -> Monadic_op.le a b
    | Comonadic_with_locality -> Comonadic_with_locality.le a b
    | Comonadic_with_regionality -> Comonadic_with_regionality.le a b

  let join : type a. a obj -> a -> a -> a =
   fun obj a b ->
    match obj with
    | Locality -> Locality.join a b
    | Regionality -> Regionality.join a b
    | Uniqueness_op -> Uniqueness_op.join a b
    | Contention_op -> Contention_op.join a b
    | Visibility_op -> Visibility_op.join a b
    | Linearity -> Linearity.join a b
    | Portability -> Portability.join a b
    | Yielding -> Yielding.join a b
    | Statefulness -> Statefulness.join a b
    | Monadic_op -> Monadic_op.join a b
    | Comonadic_with_locality -> Comonadic_with_locality.join a b
    | Comonadic_with_regionality -> Comonadic_with_regionality.join a b

  let meet : type a. a obj -> a -> a -> a =
   fun obj a b ->
    match obj with
    | Locality -> Locality.meet a b
    | Regionality -> Regionality.meet a b
    | Uniqueness_op -> Uniqueness_op.meet a b
    | Contention_op -> Contention_op.meet a b
    | Visibility_op -> Visibility_op.meet a b
    | Linearity -> Linearity.meet a b
    | Portability -> Portability.meet a b
    | Yielding -> Yielding.meet a b
    | Statefulness -> Statefulness.meet a b
    | Monadic_op -> Monadic_op.meet a b
    | Comonadic_with_locality -> Comonadic_with_locality.meet a b
    | Comonadic_with_regionality -> Comonadic_with_regionality.meet a b

  let imply : type a. a obj -> a -> a -> a =
   fun obj a b ->
    match obj with
    | Locality -> Locality.imply a b
    | Regionality -> Regionality.imply a b
    | Uniqueness_op -> Uniqueness_op.imply a b
    | Contention_op -> Contention_op.imply a b
    | Visibility_op -> Visibility_op.imply a b
    | Linearity -> Linearity.imply a b
    | Portability -> Portability.imply a b
    | Yielding -> Yielding.imply a b
    | Statefulness -> Statefulness.imply a b
    | Comonadic_with_locality -> Comonadic_with_locality.imply a b
    | Comonadic_with_regionality -> Comonadic_with_regionality.imply a b
    | Monadic_op -> Monadic_op.imply a b

  (* not hotpath, Ok to curry *)
  let print : type a. a obj -> _ -> a -> unit = function
    | Locality -> Locality.print
    | Regionality -> Regionality.print
    | Uniqueness_op -> Uniqueness_op.print
    | Contention_op -> Contention_op.print
    | Visibility_op -> Visibility_op.print
    | Linearity -> Linearity.print
    | Portability -> Portability.print
    | Yielding -> Yielding.print
    | Statefulness -> Statefulness.print
    | Monadic_op -> Monadic_op.print
    | Comonadic_with_locality -> Comonadic_with_locality.print
    | Comonadic_with_regionality -> Comonadic_with_regionality.print

  module Equal_obj = Magic_equal (struct
    type ('a, _, 'd) t = 'a obj constraint 'd = 'l * 'r

    let equal : type a b. a obj -> b obj -> (a, b) Misc.eq option =
     fun a b ->
      match a, b with
      | Locality, Locality -> Some Refl
      | Regionality, Regionality -> Some Refl
      | Uniqueness_op, Uniqueness_op -> Some Refl
      | Contention_op, Contention_op -> Some Refl
      | Visibility_op, Visibility_op -> Some Refl
      | Linearity, Linearity -> Some Refl
      | Portability, Portability -> Some Refl
      | Yielding, Yielding -> Some Refl
      | Statefulness, Statefulness -> Some Refl
      | Monadic_op, Monadic_op -> Some Refl
      | Comonadic_with_locality, Comonadic_with_locality -> Some Refl
      | Comonadic_with_regionality, Comonadic_with_regionality -> Some Refl
      | ( ( Locality | Regionality | Uniqueness_op | Contention_op
          | Visibility_op | Linearity | Portability | Yielding | Statefulness
          | Monadic_op | Comonadic_with_locality | Comonadic_with_regionality ),
          _ ) ->
        None
  end)

  let eq_obj = Equal_obj.equal
end

module Lattices_mono = struct
  include Lattices

  module Axis = struct
    type ('t, 'r) t =
      | Areality : ('a comonadic_with, 'a) t
      | Yielding : ('areality comonadic_with, Yielding.t) t
      | Linearity : ('areality comonadic_with, Linearity.t) t
      | Statefulness : ('areality comonadic_with, Statefulness.t) t
      | Portability : ('areality comonadic_with, Portability.t) t
      | Uniqueness : (Monadic_op.t, Uniqueness_op.t) t
      | Visibility : (Monadic_op.t, Visibility_op.t) t
      | Contention : (Monadic_op.t, Contention_op.t) t

    let to_int : type a b. (a, b) t -> int = function
      | Areality -> 0
      | Yielding -> 1
      | Linearity -> 2
      | Statefulness -> 3
      | Portability -> 4
      | Uniqueness -> 5
      | Visibility -> 6
      | Contention -> 7

    let compare a b = to_int a - to_int b

    let print : type p r. _ -> (p, r) t -> unit =
     fun ppf -> function
      | Areality -> Format.fprintf ppf "locality"
      | Linearity -> Format.fprintf ppf "linearity"
      | Portability -> Format.fprintf ppf "portability"
      | Uniqueness -> Format.fprintf ppf "uniqueness"
      | Contention -> Format.fprintf ppf "contention"
      | Yielding -> Format.fprintf ppf "yielding"
      | Statefulness -> Format.fprintf ppf "statefulness"
      | Visibility -> Format.fprintf ppf "visibility"

    let eq : type p r0 r1. (p, r0) t -> (p, r1) t -> (r0, r1) Misc.eq option =
     fun ax0 ax1 ->
      match ax0, ax1 with
      | Areality, Areality -> Some Refl
      | Linearity, Linearity -> Some Refl
      | Portability, Portability -> Some Refl
      | Uniqueness, Uniqueness -> Some Refl
      | Contention, Contention -> Some Refl
      | Yielding, Yielding -> Some Refl
      | Statefulness, Statefulness -> Some Refl
      | Visibility, Visibility -> Some Refl
      | ( ( Areality | Linearity | Uniqueness | Portability | Contention
          | Yielding | Statefulness | Visibility ),
          _ ) ->
        None

    let proj : type p r. (p, r) t -> p -> r =
     fun ax t ->
      match ax with
      | Areality -> t.areality
      | Linearity -> t.linearity
      | Portability -> t.portability
      | Yielding -> t.yielding
      | Statefulness -> t.statefulness
      | Uniqueness -> t.uniqueness
      | Contention -> t.contention
      | Visibility -> t.visibility

    let set : type p r. (p, r) t -> r -> p -> p =
     fun ax r t ->
      match ax with
      | Areality -> { t with areality = r }
      | Linearity -> { t with linearity = r }
      | Portability -> { t with portability = r }
      | Yielding -> { t with yielding = r }
      | Statefulness -> { t with statefulness = r }
      | Uniqueness -> { t with uniqueness = r }
      | Contention -> { t with contention = r }
      | Visibility -> { t with visibility = r }
  end

  type ('a, 'b, 'd) morph =
    | Id : ('a, 'a, 'l * 'r) morph  (** identity morphism *)
    | Meet_with : 'a -> ('a, 'a, 'l * 'r) morph
        (** Meet the input with the parameter *)
    | Imply : 'a -> ('a, 'a, disallowed * 'r) morph
        (** The right adjoint of [Meet_with] *)
    | Proj : 't obj * ('t, 'r_) Axis.t -> ('t, 'r_, 'l * 'r) morph
        (** Project from a product to an axis *)
    | Max_with : ('t, 'r_) Axis.t -> ('r_, 't, disallowed * 'r) morph
        (** Combine an axis with maxima along other axes *)
    | Min_with : ('t, 'r_) Axis.t -> ('r_, 't, 'l * disallowed) morph
        (** Combine an axis with minima along other axes *)
    | Map_comonadic :
        ('a0, 'a1, 'l * 'r) morph
        -> ('a0 comonadic_with, 'a1 comonadic_with, 'l * 'r) morph
        (** Lift an morphism on areality to a morphism on the comonadic fragment   *)
    | Monadic_to_comonadic_min
        : (Monadic_op.t, 'a comonadic_with, 'l * disallowed) morph
        (** Dualize the monadic fragment to the comonadic fragment. The areality is set to min. *)
    | Comonadic_to_monadic :
        'a comonadic_with obj
        -> ('a comonadic_with, Monadic_op.t, 'l * 'r) morph
        (** Dualize the comonadic fragment to the monadic fragment. The areality axis is ignored.  *)
    | Monadic_to_comonadic_max
        : (Monadic_op.t, 'a comonadic_with, disallowed * 'r) morph
        (** Dualize the monadic fragment to the comonadic fragment. The areality is set to max. *)
    (* Following is a chain of adjunction (complete and cannot extend in
       either direction) *)
    | Local_to_regional : (Locality.t, Regionality.t, 'l * disallowed) morph
        (** Maps local to regional, global to global *)
    | Regional_to_local : (Regionality.t, Locality.t, 'l * 'r) morph
        (** Maps regional to local, identity otherwise *)
    | Locality_as_regionality : (Locality.t, Regionality.t, 'l * 'r) morph
        (** Inject locality into regionality  *)
    | Regional_to_global : (Regionality.t, Locality.t, 'l * 'r) morph
        (** Maps regional to global, identity otherwise *)
    | Global_to_regional : (Locality.t, Regionality.t, disallowed * 'r) morph
        (** Maps global to regional, local to local *)
    | Compose :
        ('b, 'c, 'l * 'r) morph * ('a, 'b, 'l * 'r) morph
        -> ('a, 'c, 'l * 'r) morph  (** Compoistion of two morphisms *)
    constraint 'd = _ * _
  [@@ocaml.warning "-62"]

  include Magic_allow_disallow (struct
    type ('a, 'b, 'd) sided = ('a, 'b, 'd) morph constraint 'd = 'l * 'r

    let rec allow_left :
        type a b l r. (a, b, allowed * r) morph -> (a, b, l * r) morph =
      function
      | Id -> Id
      | Proj (src, ax) -> Proj (src, ax)
      | Min_with ax -> Min_with ax
      | Meet_with c -> Meet_with c
      | Compose (f, g) ->
        let f = allow_left f in
        let g = allow_left g in
        Compose (f, g)
      | Monadic_to_comonadic_min -> Monadic_to_comonadic_min
      | Comonadic_to_monadic a -> Comonadic_to_monadic a
      | Local_to_regional -> Local_to_regional
      | Locality_as_regionality -> Locality_as_regionality
      | Regional_to_local -> Regional_to_local
      | Regional_to_global -> Regional_to_global
      | Map_comonadic f ->
        let f = allow_left f in
        Map_comonadic f

    let rec allow_right :
        type a b l r. (a, b, l * allowed) morph -> (a, b, l * r) morph =
      function
      | Id -> Id
      | Proj (src, ax) -> Proj (src, ax)
      | Max_with ax -> Max_with ax
      | Meet_with c -> Meet_with c
      | Imply c -> Imply c
      | Compose (f, g) ->
        let f = allow_right f in
        let g = allow_right g in
        Compose (f, g)
      | Comonadic_to_monadic a -> Comonadic_to_monadic a
      | Monadic_to_comonadic_max -> Monadic_to_comonadic_max
      | Global_to_regional -> Global_to_regional
      | Locality_as_regionality -> Locality_as_regionality
      | Regional_to_local -> Regional_to_local
      | Regional_to_global -> Regional_to_global
      | Map_comonadic f ->
        let f = allow_right f in
        Map_comonadic f

    let rec disallow_left :
        type a b l r. (a, b, l * r) morph -> (a, b, disallowed * r) morph =
      function
      | Id -> Id
      | Proj (src, ax) -> Proj (src, ax)
      | Min_with ax -> Min_with ax
      | Max_with ax -> Max_with ax
      | Meet_with c -> Meet_with c
      | Imply c -> Imply c
      | Compose (f, g) ->
        let f = disallow_left f in
        let g = disallow_left g in
        Compose (f, g)
      | Monadic_to_comonadic_min -> Monadic_to_comonadic_min
      | Comonadic_to_monadic a -> Comonadic_to_monadic a
      | Monadic_to_comonadic_max -> Monadic_to_comonadic_max
      | Local_to_regional -> Local_to_regional
      | Global_to_regional -> Global_to_regional
      | Locality_as_regionality -> Locality_as_regionality
      | Regional_to_local -> Regional_to_local
      | Regional_to_global -> Regional_to_global
      | Map_comonadic f ->
        let f = disallow_left f in
        Map_comonadic f

    let rec disallow_right :
        type a b l r. (a, b, l * r) morph -> (a, b, l * disallowed) morph =
      function
      | Id -> Id
      | Proj (src, ax) -> Proj (src, ax)
      | Min_with ax -> Min_with ax
      | Max_with ax -> Max_with ax
      | Meet_with c -> Meet_with c
      | Imply c -> Imply c
      | Compose (f, g) ->
        let f = disallow_right f in
        let g = disallow_right g in
        Compose (f, g)
      | Monadic_to_comonadic_min -> Monadic_to_comonadic_min
      | Comonadic_to_monadic a -> Comonadic_to_monadic a
      | Monadic_to_comonadic_max -> Monadic_to_comonadic_max
      | Local_to_regional -> Local_to_regional
      | Global_to_regional -> Global_to_regional
      | Locality_as_regionality -> Locality_as_regionality
      | Regional_to_local -> Regional_to_local
      | Regional_to_global -> Regional_to_global
      | Map_comonadic f ->
        let f = disallow_right f in
        Map_comonadic f
  end)

  let set_areality : type a0 a1. a1 -> a0 comonadic_with -> a1 comonadic_with =
   fun r t -> { t with areality = r }

  let proj_obj : type t r. (t, r) Axis.t -> t obj -> r obj =
   fun ax obj ->
    match ax, obj with
    | Areality, Comonadic_with_locality -> Locality
    | Areality, Comonadic_with_regionality -> Regionality
    | Linearity, Comonadic_with_locality -> Linearity
    | Linearity, Comonadic_with_regionality -> Linearity
    | Portability, Comonadic_with_locality -> Portability
    | Portability, Comonadic_with_regionality -> Portability
    | Yielding, Comonadic_with_locality -> Yielding
    | Yielding, Comonadic_with_regionality -> Yielding
    | Statefulness, Comonadic_with_locality -> Statefulness
    | Statefulness, Comonadic_with_regionality -> Statefulness
    | Uniqueness, Monadic_op -> Uniqueness_op
    | Contention, Monadic_op -> Contention_op
    | Visibility, Monadic_op -> Visibility_op

  let comonadic_with_obj : type a. a obj -> a comonadic_with obj =
   fun a0 ->
    match a0 with
    | Locality -> Comonadic_with_locality
    | Regionality -> Comonadic_with_regionality
    | Uniqueness_op | Linearity | Monadic_op | Comonadic_with_regionality
    | Comonadic_with_locality | Contention_op | Visibility_op | Portability
    | Yielding | Statefulness ->
      assert false

  let rec src : type a b l r. b obj -> (a, b, l * r) morph -> a obj =
   fun dst f ->
    match f with
    | Id -> dst
    | Proj (src, _) -> src
    | Max_with ax -> proj_obj ax dst
    | Min_with ax -> proj_obj ax dst
    | Meet_with _ -> dst
    | Imply _ -> dst
    | Compose (f, g) ->
      let mid = src dst f in
      src mid g
    | Monadic_to_comonadic_min -> Monadic_op
    | Comonadic_to_monadic src -> src
    | Monadic_to_comonadic_max -> Monadic_op
    | Local_to_regional -> Locality
    | Locality_as_regionality -> Locality
    | Global_to_regional -> Locality
    | Regional_to_local -> Regionality
    | Regional_to_global -> Regionality
    | Map_comonadic f ->
      let dst0 = proj_obj Areality dst in
      let src0 = src dst0 f in
      comonadic_with_obj src0

  module Equal_morph = Magic_equal (struct
    type ('a, 'b, 'd) t = ('a, 'b, 'd) morph constraint 'd = 'l * 'r

    let rec equal :
        type a0 l0 r0 a1 b l1 r1.
        (a0, b, l0 * r0) morph ->
        (a1, b, l1 * r1) morph ->
        (a0, a1) Misc.eq option =
     fun f0 f1 ->
      match f0, f1 with
      | Id, Id -> Some Refl
      | Proj (src0, ax0), Proj (src1, ax1) -> (
        match eq_obj src0 src1 with
        | Some Refl -> (
          match Axis.eq ax0 ax1 with None -> None | Some Refl -> Some Refl)
        | None -> None)
      | Max_with ax0, Max_with ax1 -> (
        match Axis.eq ax0 ax1 with Some Refl -> Some Refl | None -> None)
      | Min_with ax0, Min_with ax1 -> (
        match Axis.eq ax0 ax1 with Some Refl -> Some Refl | None -> None)
      | Meet_with c0, Meet_with c1 ->
        (* This polymorphic equality is correct only if runtime representation
           uniquely identifies a constant, which could be false. For example,
           the lattice of rational number would be represented as the tuple of
           numerator and denominator, and (9,4) and (18, 8) means the same
           thing. However, even in that case, it's not unsound, as [eq_morph] is
           not requird to be complete: i.e., it's allowed to return [None] when
           it should return [Some]. It would cause duplication but not error. *)
        if c0 = c1 then Some Refl else None
      | Imply c0, Imply c1 -> if c0 = c1 then Some Refl else None
      | Monadic_to_comonadic_min, Monadic_to_comonadic_min -> Some Refl
      | Comonadic_to_monadic a0, Comonadic_to_monadic a1 -> (
        match eq_obj a0 a1 with None -> None | Some Refl -> Some Refl)
      | Monadic_to_comonadic_max, Monadic_to_comonadic_max -> Some Refl
      | Local_to_regional, Local_to_regional -> Some Refl
      | Locality_as_regionality, Locality_as_regionality -> Some Refl
      | Global_to_regional, Global_to_regional -> Some Refl
      | Regional_to_local, Regional_to_local -> Some Refl
      | Regional_to_global, Regional_to_global -> Some Refl
      | Compose (f0, g0), Compose (f1, g1) -> (
        match equal f0 f1 with
        | None -> None
        | Some Refl -> (
          match equal g0 g1 with None -> None | Some Refl -> Some Refl))
      | Map_comonadic f, Map_comonadic g -> (
        match equal f g with Some Refl -> Some Refl | None -> None)
      | ( ( Id | Proj _ | Max_with _ | Min_with _ | Meet_with _
          | Monadic_to_comonadic_min | Comonadic_to_monadic _
          | Monadic_to_comonadic_max | Local_to_regional
          | Locality_as_regionality | Global_to_regional | Regional_to_local
          | Regional_to_global | Compose _ | Map_comonadic _ | Imply _ ),
          _ ) ->
        None
  end)

  let eq_morph = Equal_morph.equal

  let rec print_morph :
      type a b l r. b obj -> Format.formatter -> (a, b, l * r) morph -> unit =
   fun dst ppf -> function
    | Id -> Format.fprintf ppf "id"
    | Meet_with c -> Format.fprintf ppf "meet(%a)" (print dst) c
    | Imply c -> Format.fprintf ppf "imply(%a)" (print dst) c
    | Proj (_, ax) -> Format.fprintf ppf "proj_%a" Axis.print ax
    | Max_with ax -> Format.fprintf ppf "max_with_%a" Axis.print ax
    | Min_with ax -> Format.fprintf ppf "min_with_%a" Axis.print ax
    | Map_comonadic f ->
      let dst0 = proj_obj Areality dst in
      Format.fprintf ppf "map_comonadic(%a)" (print_morph dst0) f
    | Monadic_to_comonadic_min -> Format.fprintf ppf "monadic_to_comonadic_min"
    | Comonadic_to_monadic _ -> Format.fprintf ppf "comonadic_to_monadic"
    | Monadic_to_comonadic_max -> Format.fprintf ppf "monadic_to_comonadic_max"
    | Local_to_regional -> Format.fprintf ppf "local_to_regional"
    | Regional_to_local -> Format.fprintf ppf "regional_to_local"
    | Locality_as_regionality -> Format.fprintf ppf "locality_as_regionality"
    | Regional_to_global -> Format.fprintf ppf "regional_to_global"
    | Global_to_regional -> Format.fprintf ppf "global_to_regional"
    | Compose (f0, f1) ->
      let mid = src dst f0 in
      Format.fprintf ppf "%a ∘ %a" (print_morph dst) f0 (print_morph mid) f1

  let id = Id

  let linear_to_unique = function
    | Linearity.Many -> Uniqueness.Aliased
    | Linearity.Once -> Uniqueness.Unique

  let unique_to_linear = function
    | Uniqueness.Unique -> Linearity.Once
    | Uniqueness.Aliased -> Linearity.Many

  let portable_to_contended = function
    | Portability.Portable -> Contention.Contended
    | Portability.Nonportable -> Contention.Uncontended

  let contended_to_portable = function
    | Contention.Contended -> Portability.Portable
    | Contention.Shared -> Portability.Nonportable
    | Contention.Uncontended -> Portability.Nonportable

  let local_to_regional = function
    | Locality.Global -> Regionality.Global
    | Locality.Local -> Regionality.Regional

  let regional_to_local = function
    | Regionality.Local -> Locality.Local
    | Regionality.Regional -> Locality.Local
    | Regionality.Global -> Locality.Global

  let locality_as_regionality = function
    | Locality.Local -> Regionality.Local
    | Locality.Global -> Regionality.Global

  let regional_to_global = function
    | Regionality.Local -> Locality.Local
    | Regionality.Regional -> Locality.Global
    | Regionality.Global -> Locality.Global

  let global_to_regional = function
    | Locality.Local -> Regionality.Local
    | Locality.Global -> Regionality.Regional

  let statefulness_to_visibility = function
    | Statefulness.Stateless -> Visibility.Immutable
    | Statefulness.Observing -> Visibility.Read
    | Statefulness.Stateful -> Visibility.Read_write

  let visibility_to_statefulness = function
    | Visibility.Immutable -> Statefulness.Stateless
    | Visibility.Read -> Statefulness.Observing
    | Visibility.Read_write -> Statefulness.Stateful

  let min_with dst ax a = Axis.set ax a (min dst)

  let max_with dst ax a = Axis.set ax a (max dst)

  let monadic_to_comonadic_min :
      type a. a comonadic_with obj -> Monadic_op.t -> a comonadic_with =
   fun obj m ->
    let areality : a =
      match obj with
      | Comonadic_with_locality -> Locality.min
      | Comonadic_with_regionality -> Regionality.min
    in
    let linearity = unique_to_linear m.uniqueness in
    let portability = contended_to_portable m.contention in
    let yielding = Yielding.min in
    let statefulness = visibility_to_statefulness m.visibility in
    { areality; linearity; portability; yielding; statefulness }

  let comonadic_to_monadic :
      type a. a comonadic_with obj -> a comonadic_with -> Monadic_op.t =
   fun _ m ->
    let uniqueness = linear_to_unique m.linearity in
    let contention = portable_to_contended m.portability in
    let visibility = statefulness_to_visibility m.statefulness in
    { uniqueness; contention; visibility }

  let monadic_to_comonadic_max :
      type a. a comonadic_with obj -> Monadic_op.t -> a comonadic_with =
   fun obj m ->
    let areality : a =
      match obj with
      | Comonadic_with_locality -> Locality.max
      | Comonadic_with_regionality -> Regionality.max
    in
    let linearity = unique_to_linear m.uniqueness in
    let portability = contended_to_portable m.contention in
    let yielding = Yielding.max in
    let statefulness = visibility_to_statefulness m.visibility in
    { areality; linearity; portability; yielding; statefulness }

  let rec apply : type a b l r. b obj -> (a, b, l * r) morph -> a -> b =
   fun dst f a ->
    match f with
    | Compose (f, g) ->
      let mid = src dst f in
      let g' = apply mid g in
      let f' = apply dst f in
      f' (g' a)
    | Id -> a
    | Proj (_, ax) -> Axis.proj ax a
    | Max_with ax -> max_with dst ax a
    | Min_with ax -> min_with dst ax a
    | Meet_with c -> meet dst c a
    | Imply c -> imply dst c a
    | Monadic_to_comonadic_min -> monadic_to_comonadic_min dst a
    | Comonadic_to_monadic src -> comonadic_to_monadic src a
    | Monadic_to_comonadic_max -> monadic_to_comonadic_max dst a
    | Local_to_regional -> local_to_regional a
    | Regional_to_local -> regional_to_local a
    | Locality_as_regionality -> locality_as_regionality a
    | Regional_to_global -> regional_to_global a
    | Global_to_regional -> global_to_regional a
    | Map_comonadic f ->
      let dst0 = proj_obj Areality dst in
      let a0 = Axis.proj Areality a in
      set_areality (apply dst0 f a0) a

  (** Compose m0 after m1. Returns [Some f] if the composition can be
    represented by [f] instead of [Compose m0 m1]. [None] otherwise. *)
  let rec maybe_compose :
      type a b c l r.
      c obj ->
      (b, c, l * r) morph ->
      (a, b, l * r) morph ->
      (a, c, l * r) morph option =
   fun dst m0 m1 ->
    let is_max c = le dst (max dst) c in
    let is_mid_max c =
      let mid = src dst m0 in
      le mid (max mid) c
    in
    match m0, m1 with
    | Id, m -> Some m
    | m, Id -> Some m
    | Meet_with c0, Meet_with c1 -> Some (Meet_with (meet dst c0 c1))
    | Imply c0, Imply c1 -> Some (Imply (meet dst c0 c1))
    | Imply c0, Meet_with c1 when le dst c0 c1 -> Some (Imply c0)
    | Meet_with c0, m1 when is_max c0 -> Some m1
    | Imply c0, m1 when is_max c0 -> Some m1
    | m1, Meet_with c0 when is_mid_max c0 -> Some m1
    | m1, Imply c0 when is_mid_max c0 -> Some m1
    | Compose (f0, f1), g -> (
      let mid = src dst f0 in
      match maybe_compose mid f1 g with
      | Some m -> Some (compose dst f0 m)
      (* the check needed to prevent infinite loop *)
      | None -> None)
    | f, Compose (g0, g1) -> (
      match maybe_compose dst f g0 with
      | Some m -> Some (compose dst m g1)
      | None -> None)
    | Proj (mid, ax), Meet_with c ->
      Some (compose dst (Meet_with (Axis.proj ax c)) (Proj (mid, ax)))
    | Proj (_, ax0), Max_with ax1 -> (
      match Axis.eq ax0 ax1 with None -> None | Some Refl -> Some Id)
    | Proj (_, ax0), Min_with ax1 -> (
      match Axis.eq ax0 ax1 with None -> None | Some Refl -> Some Id)
    | Proj (mid, ax), Map_comonadic f -> (
      let src' = src mid m1 in
      match ax with
      | Areality -> Some (compose dst f (Proj (src', Areality)))
      | Linearity -> Some (Proj (src', Linearity))
      | Portability -> Some (Proj (src', Portability))
      | Yielding -> Some (Proj (src', Yielding))
      | Statefulness -> Some (Proj (src', Statefulness)))
    | Proj _, Monadic_to_comonadic_min -> None
    | Proj _, Monadic_to_comonadic_max -> None
    | Proj _, Comonadic_to_monadic _ -> None
    | Map_comonadic f, Map_comonadic g ->
      let dst0 = proj_obj Areality dst in
      Some (Map_comonadic (compose dst0 f g))
    | Regional_to_local, Local_to_regional -> Some Id
    | Regional_to_local, Global_to_regional -> Some (Imply Locality.Global)
    | Regional_to_local, Locality_as_regionality -> Some Id
    | Regional_to_local, Meet_with c ->
      Some (compose dst (Meet_with (regional_to_local c)) Regional_to_local)
    | Regional_to_global, Meet_with c ->
      Some (compose dst (Meet_with (regional_to_global c)) Regional_to_global)
    | Local_to_regional, Meet_with c ->
      Some (compose dst (Meet_with (local_to_regional c)) Local_to_regional)
    | Global_to_regional, Meet_with c ->
      Some (compose dst (Meet_with (global_to_regional c)) Global_to_regional)
    | Locality_as_regionality, Meet_with c ->
      Some
        (compose dst
           (Meet_with (locality_as_regionality c))
           Locality_as_regionality)
    | Map_comonadic f, Meet_with c ->
      let dst0 = proj_obj Areality dst in
      let areality = Axis.proj Areality c in
      Some
        (compose dst
           (Meet_with (set_areality (max dst0) c))
           (Map_comonadic (compose dst0 f (Meet_with areality))))
    | Map_comonadic f, Imply c ->
      let dst0 = proj_obj Areality dst in
      let areality = Axis.proj Areality c in
      Some
        (compose dst
           (Imply (set_areality (max dst0) c))
           (Map_comonadic (compose dst0 f (Imply areality))))
    | Regional_to_global, Locality_as_regionality -> Some Id
    | Regional_to_global, Local_to_regional -> Some (Meet_with Locality.Global)
    | Local_to_regional, Regional_to_local -> None
    | Local_to_regional, Regional_to_global -> None
    | Locality_as_regionality, Regional_to_local -> None
    | Locality_as_regionality, Regional_to_global -> None
    | Global_to_regional, Regional_to_local -> None
    | Regional_to_global, Global_to_regional -> Some Id
    | Global_to_regional, Regional_to_global -> None
    | Min_with _, _ -> None
    | Max_with _, _ -> None
    | _, Meet_with _ -> None
    | Meet_with _, _ -> None
    | _, Imply _ -> None
    | Imply _, _ -> None
    | _, Proj _ -> None
    | Map_comonadic _, _ -> None
    | Monadic_to_comonadic_min, _ -> None
    | Monadic_to_comonadic_max, _ -> None
    | Comonadic_to_monadic _, _ -> None
    | ( Proj _,
        ( Local_to_regional | Regional_to_local | Locality_as_regionality
        | Regional_to_global | Global_to_regional ) ) ->
      .
    | ( ( Local_to_regional | Regional_to_local | Locality_as_regionality
        | Regional_to_global | Global_to_regional ),
        Min_with _ ) ->
      .
    | ( ( Local_to_regional | Regional_to_local | Locality_as_regionality
        | Regional_to_global | Global_to_regional ),
        Max_with _ ) ->
      .

  and compose :
      type a b c l r.
      c obj -> (b, c, l * r) morph -> (a, b, l * r) morph -> (a, c, l * r) morph
      =
   fun dst f g ->
    match maybe_compose dst f g with Some m -> m | None -> Compose (f, g)

  let rec left_adjoint :
      type a b l.
      b obj -> (a, b, l * allowed) morph -> (b, a, allowed * disallowed) morph =
   fun dst f ->
    match f with
    | Id -> Id
    | Proj (_, ax) -> Min_with ax
    | Max_with ax -> Proj (dst, ax)
    | Compose (f, g) ->
      let mid = src dst f in
      let f' = left_adjoint dst f in
      let g' = left_adjoint mid g in
      Compose (g', f')
    | Meet_with _c ->
      (* The downward closure of [Meet_with c]'s image is all [x <= c].
         For those, [x <= meet c y] is equivalent to [x <= y]. *)
      Id
    | Imply c -> Meet_with c
    | Comonadic_to_monadic _ -> Monadic_to_comonadic_min
    | Monadic_to_comonadic_max -> Comonadic_to_monadic dst
    | Global_to_regional -> Regional_to_global
    | Regional_to_global -> Locality_as_regionality
    | Locality_as_regionality -> Regional_to_local
    | Regional_to_local -> Local_to_regional
    | Map_comonadic f ->
      let dst0 = proj_obj Areality dst in
      let f' = left_adjoint dst0 f in
      Map_comonadic f'

  and right_adjoint :
      type a b r.
      b obj -> (a, b, allowed * r) morph -> (b, a, disallowed * allowed) morph =
   fun dst f ->
    match f with
    | Id -> Id
    | Proj (_, ax) -> Max_with ax
    | Min_with ax -> Proj (dst, ax)
    | Compose (f, g) ->
      let mid = src dst f in
      let f' = right_adjoint dst f in
      let g' = right_adjoint mid g in
      Compose (g', f')
    | Meet_with c -> Imply c
    | Comonadic_to_monadic _ -> Monadic_to_comonadic_max
    | Monadic_to_comonadic_min -> Comonadic_to_monadic dst
    | Local_to_regional -> Regional_to_local
    | Regional_to_local -> Locality_as_regionality
    | Locality_as_regionality -> Regional_to_global
    | Regional_to_global -> Global_to_regional
    | Map_comonadic f ->
      let dst0 = proj_obj Areality dst in
      let f' = right_adjoint dst0 f in
      Map_comonadic f'
end

module C = Lattices_mono
module Solver = Solver_mono (C)
module S = Solver

type monadic = C.monadic =
  { uniqueness : C.Uniqueness.t;
    contention : C.Contention.t;
    visibility : C.Visibility.t
  }

type 'a comonadic_with = 'a C.comonadic_with =
  { areality : 'a;
    linearity : C.Linearity.t;
    portability : C.Portability.t;
    yielding : C.Yielding.t;
    statefulness : C.Statefulness.t
  }

module Axis = C.Axis

type changes = S.changes

let undo_changes = S.undo_changes

(* To be filled in by [types.ml] *)
let append_changes : (changes ref -> unit) ref = ref (fun _ -> assert false)

let set_append_changes f = append_changes := f

type ('a, 'd) mode = ('a, 'd) S.mode

(** Representing a single object *)
module type Obj = sig
  type const

  val obj : const C.obj
end

let try_with_log op =
  let log' = ref S.empty_changes in
  let log = Some log' in
  match op ~log with
  | Ok _ as x ->
    !append_changes log';
    x
  | Error _ as x ->
    S.undo_changes !log';
    x
  [@@inline]

let with_log op =
  let log' = ref S.empty_changes in
  let log = Some log' in
  let r = op ~log in
  !append_changes log';
  r
  [@@inline]

let equate_from_submode submode_log m0 m1 ~log =
  match submode_log m0 m1 ~log with
  | Error e -> Error (Left_le_right, e)
  | Ok () -> (
    match submode_log m1 m0 ~log with
    | Error e -> Error (Right_le_left, e)
    | Ok () -> Ok ())
  [@@inline]

let equate_from_submode' submode m0 m1 =
  match submode m0 m1 with
  | Error e -> Error (Left_le_right, e)
  | Ok () -> (
    match submode m1 m0 with
    | Error e -> Error (Right_le_left, e)
    | Ok () -> Ok ())
  [@@inline]

module Comonadic_gen (Obj : Obj) = struct
  open Obj

  type 'd t = (const, 'l * 'r) Solver.mode constraint 'd = 'l * 'r

  type l = (allowed * disallowed) t

  type r = (disallowed * allowed) t

  type lr = (allowed * allowed) t

  type nonrec error = const error

  type equate_error = equate_step * error

  type (_, _, 'd) sided = 'd t

  let disallow_right m = Solver.disallow_right m

  let disallow_left m = Solver.disallow_left m

  let allow_left m = Solver.allow_left m

  let allow_right m = Solver.allow_right m

  let newvar () = Solver.newvar obj

  let min = Solver.min obj

  let max = Solver.max obj

  let newvar_above m = Solver.newvar_above obj m

  let newvar_below m = Solver.newvar_below obj m

  let submode_log a b ~log = Solver.submode obj a b ~log

  let submode a b = try_with_log (submode_log a b)

  let join l = Solver.join obj l

  let meet l = Solver.meet obj l

  let submode_exn m0 m1 = submode m0 m1 |> Result.get_ok

  let equate a b = try_with_log (equate_from_submode submode_log a b)

  let equate_exn m0 m1 = equate m0 m1 |> Result.get_ok

  let print ?verbose () ppf m = Solver.print ?verbose obj ppf m

  let zap_to_ceil m = with_log (Solver.zap_to_ceil obj m)

  let zap_to_floor m = with_log (Solver.zap_to_floor obj m)

  let of_const : type l r. const -> (l * r) t = fun a -> Solver.of_const obj a

  let meet_const c m = Solver.apply obj (Meet_with c) m

  let imply c m = Solver.apply obj (Imply c) (Solver.disallow_left m)

  module Guts = struct
    let get_floor m = Solver.get_floor obj m

    let get_ceil m = Solver.get_ceil obj m

    let get_loose_floor m = Solver.get_loose_floor obj m

    let get_loose_ceil m = Solver.get_loose_ceil obj m
  end
end
[@@inline]

module Monadic_gen (Obj : Obj) = struct
  (* Monadic lattices are flipped. See "Notes on flipping". *)
  open Obj

  type 'd t = (const, 'r * 'l) Solver.mode constraint 'd = 'l * 'r

  type l = (allowed * disallowed) t

  type r = (disallowed * allowed) t

  type lr = (allowed * allowed) t

  type nonrec error = const error

  type equate_error = equate_step * error

  type (_, _, 'd) sided = 'd t

  let flip_error = function
    | Ok _ as r -> r
    | Error { left; right } -> Error { left = right; right = left }

  let disallow_right m = Solver.disallow_left m

  let disallow_left m = Solver.disallow_right m

  let allow_left m = Solver.allow_right m

  let allow_right m = Solver.allow_left m

  let newvar () = Solver.newvar obj

  let min = Solver.max obj

  let max = Solver.min obj

  let newvar_above m = Solver.newvar_below obj m

  let newvar_below m = Solver.newvar_above obj m

  let submode_log a b ~log = Solver.submode obj b a ~log |> flip_error

  let submode a b = try_with_log (submode_log a b)

  let join l = Solver.meet obj l

  let meet l = Solver.join obj l

  let submode_exn m0 m1 = submode m0 m1 |> Result.get_ok

  let equate a b = try_with_log (equate_from_submode submode_log a b)

  let equate_exn m0 m1 = equate m0 m1 |> Result.get_ok

  let print ?verbose () ppf m = Solver.print ?verbose obj ppf m

  let zap_to_ceil m = with_log (Solver.zap_to_floor obj m)

  let zap_to_floor m = with_log (Solver.zap_to_ceil obj m)

  let of_const : type l r. const -> (l * r) t = fun a -> Solver.of_const obj a

  let join_const c m = Solver.apply Obj.obj (Meet_with c) m

  let subtract c m = Solver.apply obj (Imply c) (Solver.disallow_left m)

  module Guts = struct
    let get_ceil m = Solver.get_floor obj m
  end
end
[@@inline]

module Locality = struct
  module Const = C.Locality

  module Obj = struct
    type const = Const.t

    let obj = C.Locality
  end

  include Comonadic_gen (Obj)

  let global = of_const Global

  let local = of_const Local

  let legacy = of_const Const.legacy

  let zap_to_legacy = zap_to_floor

  module Guts = struct
    let check_const m =
      let floor = Guts.get_floor m in
      let ceil = Guts.get_ceil m in
      if Const.le ceil floor then Some ceil else None

    let check_const_conservative m =
      let floor = Guts.get_loose_floor m in
      let ceil = Guts.get_loose_ceil m in
      if Const.le ceil floor then Some ceil else None
  end
end

module Regionality = struct
  module Const = C.Regionality

  module Obj = struct
    type const = Const.t

    let obj = C.Regionality
  end

  include Comonadic_gen (Obj)

  let local = of_const Const.Local

  let regional = of_const Const.Regional

  let global = of_const Const.Global

  let legacy = of_const Const.legacy

  let zap_to_legacy = zap_to_floor
end

module Linearity = struct
  module Const = C.Linearity

  module Obj = struct
    type const = Const.t

    let obj : _ C.obj = C.Linearity
  end

  include Comonadic_gen (Obj)

  let many = of_const Many

  let once = of_const Once

  let legacy = of_const Const.legacy

  let zap_to_legacy = zap_to_floor
end

module Statefulness = struct
  module Const = C.Statefulness

  module Obj = struct
    type const = Const.t

    let obj = C.Statefulness
  end

  include Comonadic_gen (Obj)

  let stateless = of_const Stateless

  let observing = of_const Observing

  let stateful = of_const Stateful

  let legacy = of_const Const.legacy

  let zap_to_legacy = zap_to_ceil
end

module Visibility = struct
  module Const = C.Visibility
  module Const_op = C.Visibility_op

  module Obj = struct
    type const = Const.t

    let obj = C.Visibility_op
  end

  include Monadic_gen (Obj)

  let immutable = of_const Immutable

  let read = of_const Read

  let read_write = of_const Read_write

  let legacy = of_const Const.legacy

  let zap_to_legacy = zap_to_floor
end

module Portability = struct
  module Const = C.Portability

  module Obj = struct
    type const = Const.t

    let obj : _ C.obj = C.Portability
  end

  include Comonadic_gen (Obj)

  let legacy = of_const Const.legacy

  let zap_to_legacy ~statefulness =
    match statefulness with
    | Statefulness.Const.Stateful | Statefulness.Const.Observing -> zap_to_ceil
    | Statefulness.Const.Stateless -> zap_to_floor
end

module Uniqueness = struct
  module Const = C.Uniqueness
  module Const_op = C.Uniqueness_op

  module Obj = struct
    type const = Const.t

    let obj = C.Uniqueness_op
  end

  include Monadic_gen (Obj)

  let aliased = of_const Aliased

  let unique = of_const Unique

  let legacy = of_const Const.legacy

  let zap_to_legacy = zap_to_ceil
end

module Contention = struct
  module Const = C.Contention
  module Const_op = C.Contention_op

  module Obj = struct
    type const = Const.t

    let obj = C.Contention_op
  end

  include Monadic_gen (Obj)

  let legacy = of_const Const.legacy

  (* CR dkalinichenko: ideally, [read] should zap to [shared]. *)
  let zap_to_legacy ~visibility =
    match visibility with
    | Visibility.Const.Read_write | Visibility.Const.Read -> zap_to_floor
    | Visibility.Const.Immutable -> zap_to_ceil
end

module Yielding = struct
  module Const = C.Yielding

  module Obj = struct
    type const = Const.t

    let obj = C.Yielding
  end

  include Comonadic_gen (Obj)

  let yielding = of_const Yielding

  let unyielding = of_const Unyielding

  let legacy = of_const Const.legacy

  (* [unyielding] is the default for [global]s and [yielding] for [local]
     or [regional] values, so we vary [zap_to_legacy] accordingly. *)
  let zap_to_legacy ~global =
    match global with true -> zap_to_floor | false -> zap_to_ceil
end

let regional_to_local m = S.apply Locality.Obj.obj C.Regional_to_local m

let locality_as_regionality m =
  S.apply Regionality.Obj.obj C.Locality_as_regionality m

let regional_to_global m = S.apply Locality.Obj.obj C.Regional_to_global m

module type Areality = sig
  module Const : C.Areality

  module Obj : Obj with type const = Const.t

  val zap_to_legacy : (Const.t, allowed * 'r) Solver.mode -> Const.t
end

module Lattice_Product (L : Lattice) = struct
  open L

  let min_with ax c = Axis.set ax c min

  let max_with ax c = Axis.set ax c max

  let min_axis ax = Axis.proj ax min

  let max_axis ax = Axis.proj ax max
end

module Comonadic_with (Areality : Areality) = struct
  module Obj = struct
    type const = Areality.Const.t C.comonadic_with

    let obj = C.comonadic_with_obj Areality.Obj.obj
  end

  include Comonadic_gen (Obj)

  module Axis = struct
    type 'a t = (Obj.const, 'a) Axis.t

    type packed = P : 'a t -> packed

    let print = Axis.print

    let compare = Axis.compare

    let all =
      [P Areality; P Linearity; P Portability; P Yielding; P Statefulness]
      |> List.sort (fun (P ax0) (P ax1) -> compare ax0 ax1)
  end

  type error = Error : 'a Axis.t * 'a Solver.error -> error

  type equate_error = equate_step * error

  let proj_obj ax = C.proj_obj ax Obj.obj

  module Const = struct
    include C.Comonadic_with (Areality.Const)
    include Lattice_Product (C.Comonadic_with (Areality.Const))

    let print_axis ax ppf a =
      let obj = proj_obj ax in
      C.print obj ppf a

    let le_axis ax a b =
      let obj = proj_obj ax in
      C.le obj a b

    let lattice_of_axis (type a) (axis : a Axis.t) :
        (module Lattice with type t = a) =
      match axis with
      | Areality -> (module Areality.Const)
      | Linearity -> (module Linearity.Const)
      | Portability -> (module Portability.Const)
      | Yielding -> (module Yielding.Const)
      | Statefulness -> (module Statefulness.Const)
  end

  let proj ax m = Solver.apply (proj_obj ax) (Proj (Obj.obj, ax)) m

  let min_with ax m =
    Solver.apply Obj.obj (Min_with ax) (Solver.disallow_right m)

  let max_with ax m =
    Solver.apply Obj.obj (Max_with ax) (Solver.disallow_left m)

  let meet_with ax c m = meet_const (Const.max_with ax c) m

  let zap_to_legacy m : Const.t =
    let areality = proj Areality m |> Areality.zap_to_legacy in
    let linearity = proj Linearity m |> Linearity.zap_to_legacy in
    let statefulness = proj Statefulness m |> Statefulness.zap_to_legacy in
    let portability =
      proj Portability m |> Portability.zap_to_legacy ~statefulness
    in
    let global = Areality.Const.(equal areality legacy) in
    let yielding = proj Yielding m |> Yielding.zap_to_legacy ~global in
    { areality; linearity; portability; yielding; statefulness }

  let legacy = of_const Const.legacy

  let axis_of_error (err : Obj.const Solver.error) : error =
    let { left =
            { areality = areality1;
              linearity = linearity1;
              portability = portability1;
              yielding = yielding1;
              statefulness = statefulness1
            };
          right =
            { areality = areality2;
              linearity = linearity2;
              portability = portability2;
              yielding = yielding2;
              statefulness = statefulness2
            }
        } =
      err
    in
    if Areality.Const.le areality1 areality2
    then
      if Linearity.Const.le linearity1 linearity2
      then
        if Portability.Const.le portability1 portability2
        then
          if Yielding.Const.le yielding1 yielding2
          then
            if Statefulness.Const.le statefulness1 statefulness2
            then assert false
            else
              Error
                ( Statefulness,
                  { left = err.left.statefulness;
                    right = err.right.statefulness
                  } )
          else
            Error
              ( Yielding,
                { left = err.left.yielding; right = err.right.yielding } )
        else
          Error
            ( Portability,
              { left = err.left.portability; right = err.right.portability } )
      else
        Error
          (Linearity, { left = err.left.linearity; right = err.right.linearity })
    else
      Error (Areality, { left = err.left.areality; right = err.right.areality })

  (* overriding to report the offending axis *)
  let submode_log m0 m1 ~log : _ result =
    match submode_log m0 m1 ~log with
    | Ok () -> Ok ()
    | Error e -> Error (axis_of_error e)

  let submode a b = try_with_log (submode_log a b)

  (* override to report the offending axis *)
  let equate a b = try_with_log (equate_from_submode submode_log a b)
end
[@@inline]

module Monadic = struct
  (* Monadic lattices are flipped. See "Notes on flipping". *)
  module Obj = struct
    type const = C.Monadic_op.t

    let obj = C.Monadic_op
  end

  include Monadic_gen (Obj)

  module Axis = struct
    type 'a t = (Obj.const, 'a) C.Axis.t

    type packed = P : 'a t -> packed

    let compare = Axis.compare

    let print = Axis.print

    let all =
      [P Uniqueness; P Contention; P Visibility]
      |> List.sort (fun (P ax0) (P ax1) -> compare ax0 ax1)
  end

  type error = Error : 'a Axis.t * 'a Solver.error -> error

  type equate_error = equate_step * error

  let proj_obj ax = C.proj_obj ax Obj.obj

  module Const = struct
    include C.Monadic
    include Lattice_Product (C.Monadic)

    let print_axis ax ppf a =
      let obj = proj_obj ax in
      C.print obj ppf a

    let le_axis ax a b =
      let obj = proj_obj ax in
      C.le obj b a

    let lattice_of_axis (type a) (axis : a Axis.t) :
        (module Lattice with type t = a) =
      match axis with
      | Uniqueness -> (module Uniqueness.Const_op)
      | Contention -> (module Contention.Const_op)
      | Visibility -> (module Visibility.Const_op)
  end

  module Const_op = C.Monadic_op

  let proj ax m = Solver.apply (proj_obj ax) (Proj (Obj.obj, ax)) m

  (* The monadic fragment is inverted. *)

  let join_with ax c m = join_const (Const.min_with ax c) m

  let zap_to_legacy m : Const.t =
    let uniqueness = proj Uniqueness m |> Uniqueness.zap_to_legacy in
    let visibility = proj Visibility m |> Visibility.zap_to_legacy in
    let contention =
      proj Contention m |> Contention.zap_to_legacy ~visibility
    in
    { uniqueness; contention; visibility }

  let legacy = of_const Const.legacy

  let axis_of_error (err : Obj.const Solver.error) : error =
    let { left =
            { uniqueness = uniqueness1;
              contention = contention1;
              visibility = visibility1
            };
          right =
            { uniqueness = uniqueness2;
              contention = contention2;
              visibility = visibility2
            }
        } =
      err
    in
    if Uniqueness.Const.le uniqueness1 uniqueness2
    then
      if Contention.Const.le contention1 contention2
      then
        if Visibility.Const.le visibility1 visibility2
        then assert false
        else
          Error
            ( Visibility,
              { left = err.left.visibility; right = err.right.visibility } )
      else
        Error
          ( Contention,
            { left = err.left.contention; right = err.right.contention } )
    else
      Error
        ( Uniqueness,
          { left = err.left.uniqueness; right = err.right.uniqueness } )

  (* overriding to report the offending axis *)
  let submode_log m0 m1 ~log : _ result =
    match submode_log m0 m1 ~log with
    | Ok () -> Ok ()
    | Error e -> Error (axis_of_error e)

  let submode a b = try_with_log (submode_log a b)

  (* override to report the offending axis *)
  let equate a b = try_with_log (equate_from_submode submode_log a b)
end

type ('mo, 'como) monadic_comonadic =
  { monadic : 'mo;
    comonadic : 'como
  }

module Value_with (Areality : Areality) = struct
  module Comonadic = Comonadic_with (Areality)
  module Monadic = Monadic

  type 'd t = ('d Monadic.t, 'd Comonadic.t) monadic_comonadic

  type l = (allowed * disallowed) t

  type r = (disallowed * allowed) t

  type lr = (allowed * allowed) t

  module Axis = struct
    type 'a t =
      | Monadic : 'a Monadic.Axis.t -> 'a t
      | Comonadic : 'a Comonadic.Axis.t -> 'a t

    let compare : type a b. a t -> b t -> int =
     fun t0 t1 ->
      match t0, t1 with
      | Monadic t0, Monadic t1 -> Axis.compare t0 t1
      | Monadic t0, Comonadic t1 -> Axis.compare t0 t1
      | Comonadic t0, Monadic t1 -> Axis.compare t0 t1
      | Comonadic t0, Comonadic t1 -> Axis.compare t0 t1

    type packed = P : 'a t -> packed

    let print (type a) ppf (t : a t) =
      match t with
      | Monadic ax -> Axis.print ppf ax
      | Comonadic ax -> Axis.print ppf ax

    let all =
      List.map (fun (Monadic.Axis.P ax) -> P (Monadic ax)) Monadic.Axis.all
      @ List.map
          (fun (Comonadic.Axis.P ax) -> P (Comonadic ax))
          Comonadic.Axis.all
      |> List.sort (fun (P ax0) (P ax1) -> compare ax0 ax1)
  end

  let proj_obj : type a. a Axis.t -> a C.obj = function
    | Monadic ax -> Monadic.proj_obj ax
    | Comonadic ax -> Comonadic.proj_obj ax

  type ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h) modes =
    { areality : 'a;
      linearity : 'b;
      uniqueness : 'c;
      portability : 'd;
      contention : 'e;
      yielding : 'f;
      statefulness : 'g;
      visibility : 'h
    }

  let split
      { areality;
        linearity;
        portability;
        yielding;
        statefulness;
        uniqueness;
        contention;
        visibility
      } =
    let monadic : Monadic.Const.t = { uniqueness; contention; visibility } in
    let comonadic : Comonadic.Const.t =
      { areality; linearity; portability; yielding; statefulness }
    in
    { comonadic; monadic }

  let merge { comonadic; monadic } =
    let ({ areality; linearity; portability; yielding; statefulness }
          : Comonadic.Const.t) =
      comonadic
    in
    let ({ uniqueness; contention; visibility } : Monadic.Const.t) = monadic in
    { areality;
      linearity;
      portability;
      yielding;
      statefulness;
      uniqueness;
      contention;
      visibility
    }

  let print ?verbose () ppf { monadic; comonadic } =
    Format.fprintf ppf "%a;%a"
      (Comonadic.print ?verbose ())
      comonadic
      (Monadic.print ?verbose ())
      monadic

  let of_const c =
    let { monadic; comonadic } = split c in
    let comonadic = Comonadic.of_const comonadic in
    let monadic = Monadic.of_const monadic in
    { comonadic; monadic }

  module Const = struct
    module Monadic = Monadic.Const
    module Comonadic = Comonadic.Const

    type t =
      ( Areality.Const.t,
        Linearity.Const.t,
        Uniqueness.Const.t,
        Portability.Const.t,
        Contention.Const.t,
        Yielding.Const.t,
        Statefulness.Const.t,
        Visibility.Const.t )
      modes

    let min = merge { comonadic = Comonadic.min; monadic = Monadic.min }

    let max = merge { comonadic = Comonadic.max; monadic = Monadic.max }

    let le m0 m1 =
      let m0 = split m0 in
      let m1 = split m1 in
      Comonadic.le m0.comonadic m1.comonadic && Monadic.le m0.monadic m1.monadic

    let equal m0 m1 =
      let m0 = split m0 in
      let m1 = split m1 in
      Comonadic.equal m0.comonadic m1.comonadic
      && Monadic.equal m0.monadic m1.monadic

    let print ppf m =
      let { monadic; comonadic } = split m in
      Format.fprintf ppf "%a,%a" Comonadic.print comonadic Monadic.print monadic

    let legacy =
      merge { comonadic = Comonadic.legacy; monadic = Monadic.legacy }

    let meet m0 m1 =
      let m0 = split m0 in
      let m1 = split m1 in
      let monadic = Monadic.meet m0.monadic m1.monadic in
      let comonadic = Comonadic.meet m0.comonadic m1.comonadic in
      merge { monadic; comonadic }

    let join m0 m1 =
      let m0 = split m0 in
      let m1 = split m1 in
      let monadic = Monadic.join m0.monadic m1.monadic in
      let comonadic = Comonadic.join m0.comonadic m1.comonadic in
      merge { monadic; comonadic }

    let lattice_of_axis (type a) (axis : a Axis.t) :
        (module Lattice with type t = a) =
      match axis with
      | Comonadic ax -> Comonadic.lattice_of_axis ax
      | Monadic ax -> Monadic.lattice_of_axis ax

    module Option = struct
      type some = t

      type t =
        ( Areality.Const.t option,
          Linearity.Const.t option,
          Uniqueness.Const.t option,
          Portability.Const.t option,
          Contention.Const.t option,
          Yielding.Const.t option,
          Statefulness.Const.t option,
          Visibility.Const.t option )
        modes

      let none =
        { areality = None;
          uniqueness = None;
          linearity = None;
          portability = None;
          contention = None;
          yielding = None;
          statefulness = None;
          visibility = None
        }

      let value opt ~default =
        let areality = Option.value opt.areality ~default:default.areality in
        let uniqueness =
          Option.value opt.uniqueness ~default:default.uniqueness
        in
        let linearity = Option.value opt.linearity ~default:default.linearity in
        let portability =
          Option.value opt.portability ~default:default.portability
        in
        let contention =
          Option.value opt.contention ~default:default.contention
        in
        let yielding = Option.value opt.yielding ~default:default.yielding in
        let statefulness =
          Option.value opt.statefulness ~default:default.statefulness
        in
        let visibility =
          Option.value opt.visibility ~default:default.visibility
        in
        { areality;
          uniqueness;
          linearity;
          portability;
          contention;
          yielding;
          statefulness;
          visibility
        }

      let print ppf
          { areality;
            uniqueness;
            linearity;
            portability;
            contention;
            yielding;
            statefulness;
            visibility
          } =
        let option_print print ppf = function
          | None -> Format.fprintf ppf "None"
          | Some a -> Format.fprintf ppf "Some %a" print a
        in
        Format.fprintf ppf "%a,%a,%a,%a,%a,%a,%a,%a"
          (option_print Areality.Const.print)
          areality
          (option_print Linearity.Const.print)
          linearity
          (option_print Uniqueness.Const.print)
          uniqueness
          (option_print Portability.Const.print)
          portability
          (option_print Contention.Const.print)
          contention
          (option_print Yielding.Const.print)
          yielding
          (option_print Statefulness.Const.print)
          statefulness
          (option_print Visibility.Const.print)
          visibility
    end

    let diff m0 m1 =
      let diff le a0 a1 = if le a0 a1 && le a1 a0 then None else Some a0 in
      let areality = diff Areality.Const.le m0.areality m1.areality in
      let linearity = diff Linearity.Const.le m0.linearity m1.linearity in
      let uniqueness = diff Uniqueness.Const.le m0.uniqueness m1.uniqueness in
      let portability =
        diff Portability.Const.le m0.portability m1.portability
      in
      let contention = diff Contention.Const.le m0.contention m1.contention in
      let yielding = diff Yielding.Const.le m0.yielding m1.yielding in
      let statefulness =
        diff Statefulness.Const.le m0.statefulness m1.statefulness
      in
      let visibility = diff Visibility.Const.le m0.visibility m1.visibility in
      { areality;
        linearity;
        uniqueness;
        portability;
        contention;
        yielding;
        statefulness;
        visibility
      }

    (** See [Alloc.close_over] for explanation. *)
    let close_over m =
      let { monadic; comonadic } = split m in
      let comonadic =
        Comonadic.join comonadic
          (C.monadic_to_comonadic_min
             (C.comonadic_with_obj Areality.Obj.obj)
             monadic)
      in
      let monadic = Monadic.min in
      merge { comonadic; monadic }

    (** See [Alloc.partial_apply] for explanation. *)
    let partial_apply m =
      let { comonadic; _ } = split m in
      let monadic = Monadic.min in
      merge { comonadic; monadic }

    let print_axis : type a. a Axis.t -> _ -> a -> unit =
     fun ax ppf a ->
      let obj = proj_obj ax in
      C.print obj ppf a

    let le_axis : type a. a Axis.t -> a -> a -> bool =
     fun ax m0 m1 ->
      match ax with
      | Comonadic ax -> Comonadic.le_axis ax m0 m1
      | Monadic ax -> Monadic.le_axis ax m0 m1

    let min_axis : type a. a Axis.t -> a = function
      | Comonadic ax -> Comonadic.min_axis ax
      | Monadic ax -> Monadic.min_axis ax

    let max_axis : type a. a Axis.t -> a = function
      | Comonadic ax -> Comonadic.max_axis ax
      | Monadic ax -> Monadic.max_axis ax

    let is_max : type a. a Axis.t -> a -> bool =
     fun ax m -> le_axis ax (max_axis ax) m

    let is_min : type a. a Axis.t -> a -> bool =
     fun ax m -> le_axis ax m (min_axis ax)

    let split = split

    let merge = merge
  end

  let min = { comonadic = Comonadic.min; monadic = Monadic.min }

  let max = { comonadic = Comonadic.max; monadic = Monadic.max }

  include Magic_allow_disallow (struct
    type (_, _, 'd) sided = 'd t constraint 'd = 'l * 'r

    let allow_left { monadic; comonadic } =
      let monadic = Monadic.allow_left monadic in
      let comonadic = Comonadic.allow_left comonadic in
      { monadic; comonadic }

    let allow_right { monadic; comonadic } =
      let monadic = Monadic.allow_right monadic in
      let comonadic = Comonadic.allow_right comonadic in
      { monadic; comonadic }

    let disallow_left { monadic; comonadic } =
      let monadic = Monadic.disallow_left monadic in
      let comonadic = Comonadic.disallow_left comonadic in
      { monadic; comonadic }

    let disallow_right { monadic; comonadic } =
      let monadic = Monadic.disallow_right monadic in
      let comonadic = Comonadic.disallow_right comonadic in
      { monadic; comonadic }
  end)

  let newvar () =
    let comonadic = Comonadic.newvar () in
    let monadic = Monadic.newvar () in
    { comonadic; monadic }

  let newvar_above { comonadic; monadic } =
    let comonadic, b0 = Comonadic.newvar_above comonadic in
    let monadic, b1 = Monadic.newvar_above monadic in
    { monadic; comonadic }, b0 || b1

  let newvar_below { comonadic; monadic } =
    let comonadic, b0 = Comonadic.newvar_below comonadic in
    let monadic, b1 = Monadic.newvar_below monadic in
    { monadic; comonadic }, b0 || b1

  type error = Error : 'a Axis.t * 'a Solver.error -> error

  type equate_error = equate_step * error

  let submode_log { monadic = monadic0; comonadic = comonadic0 }
      { monadic = monadic1; comonadic = comonadic1 } ~log : (_, error) result =
    (* comonadic before monadic, so that locality errors dominate
       (error message backward compatibility) *)
    match Comonadic.submode_log comonadic0 comonadic1 ~log with
    | Error (Error (ax, e)) -> Error (Error (Comonadic ax, e))
    | Ok () -> (
      match Monadic.submode_log monadic0 monadic1 ~log with
      | Error (Error (ax, e)) -> Error (Error (Monadic ax, e))
      | Ok () -> Ok ())

  let submode a b = try_with_log (submode_log a b)

  let equate a b = try_with_log (equate_from_submode submode_log a b)

  let submode_exn m0 m1 =
    match submode m0 m1 with
    | Ok () -> ()
    | Error _ -> invalid_arg "submode_exn"

  let equate_exn m0 m1 =
    match equate m0 m1 with Ok () -> () | Error _ -> invalid_arg "equate_exn"

  let legacy =
    let comonadic = Comonadic.legacy in
    let monadic = Monadic.legacy in
    { comonadic; monadic }

  let proj_monadic ax { monadic; _ } = Monadic.proj ax monadic

  let proj_comonadic ax { comonadic; _ } = Comonadic.proj ax comonadic

  let max_with_comonadic ax m =
    let comonadic = Comonadic.max_with ax m in
    let monadic = Monadic.max |> Monadic.disallow_left |> Monadic.allow_right in
    { comonadic; monadic }

  let min_with_comonadic ax m =
    let comonadic = Comonadic.min_with ax m in
    let monadic = Monadic.min |> Monadic.disallow_right |> Monadic.allow_left in
    { comonadic; monadic }

  let join_with ax c { monadic; comonadic } =
    let monadic = Monadic.join_with ax c monadic in
    { monadic; comonadic }

  let meet_with ax c { monadic; comonadic } =
    let comonadic = Comonadic.meet_with ax c comonadic in
    { comonadic; monadic }

  let join l =
    let como, mo =
      List.fold_left
        (fun (como, mo) { comonadic; monadic } ->
          comonadic :: como, monadic :: mo)
        ([], []) l
    in
    let comonadic = Comonadic.join como in
    let monadic = Monadic.join mo in
    { comonadic; monadic }

  let meet l =
    let como, mo =
      List.fold_left
        (fun (como, mo) { comonadic; monadic } ->
          comonadic :: como, monadic :: mo)
        ([], []) l
    in
    let comonadic = Comonadic.meet como in
    let monadic = Monadic.meet mo in
    { comonadic; monadic }

  let comonadic_to_monadic m =
    S.apply Monadic.Obj.obj (Comonadic_to_monadic Comonadic.Obj.obj) m

  let monadic_to_comonadic_min m =
    S.apply Comonadic.Obj.obj Monadic_to_comonadic_min (Monadic.disallow_left m)

  let meet_const c { comonadic; monadic } =
    let comonadic = Comonadic.meet_const c comonadic in
    { monadic; comonadic }

  let join_const c { comonadic; monadic } =
    let monadic = Monadic.join_const c monadic in
    { monadic; comonadic }

  let zap_to_ceil { comonadic; monadic } =
    let monadic = Monadic.zap_to_ceil monadic in
    let comonadic = Comonadic.zap_to_ceil comonadic in
    merge { monadic; comonadic }

  let zap_to_floor { comonadic; monadic } =
    let monadic = Monadic.zap_to_floor monadic in
    let comonadic = Comonadic.zap_to_floor comonadic in
    merge { monadic; comonadic }

  let zap_to_legacy { comonadic; monadic } =
    let monadic = Monadic.zap_to_legacy monadic in
    let comonadic = Comonadic.zap_to_legacy comonadic in
    merge { monadic; comonadic }

  (** This is about partially applying [A -> B -> C] to [A] and getting [B ->
    C]. [comonadic] and [monadic] constutute the mode of [A], and we need to
    give the lower bound mode of [B -> C]. *)
  let close_over { comonadic; monadic } =
    let comonadic = Comonadic.disallow_right comonadic in
    (* The comonadic of the returned function is constrained by the monadic of the closed argument via the dualizing morphism. *)
    let comonadic1 = monadic_to_comonadic_min monadic in
    (* It's also constrained by the comonadic of the closed argument. *)
    let comonadic = Comonadic.join [comonadic; comonadic1] in
    (* The returned function crosses all monadic axes that we know of
       (uniqueness/contention). *)
    let monadic = Monadic.disallow_right Monadic.min in
    { comonadic; monadic }

  (** Similar to above, but we are given the mode of [A -> B -> C], and need to
      give the lower bound mode of [B -> C]. *)
  let partial_apply { comonadic; _ } =
    (* The returned function crosses all monadic axes that we know of. *)
    let monadic = Monadic.disallow_right Monadic.min in
    let comonadic = Comonadic.disallow_right comonadic in
    { comonadic; monadic }

  module List = struct
    type nonrec 'd t = 'd t list

    include Magic_allow_disallow (struct
      type (_, _, 'd) sided = 'd t constraint 'd = 'l * 'r

      let allow_left l = List.map allow_left l

      let allow_right l = List.map allow_right l

      let disallow_left l = List.map disallow_left l

      let disallow_right l = List.map disallow_right l
    end)
  end
end
[@@inline]

module Value = Value_with (Regionality)
module Alloc = Value_with (Locality)

module Const = struct
  let alloc_as_value
      ({ areality;
         linearity;
         portability;
         uniqueness;
         contention;
         yielding;
         statefulness;
         visibility
       } :
        Alloc.Const.t) : Value.Const.t =
    let areality = C.locality_as_regionality areality in
    { areality;
      linearity;
      portability;
      uniqueness;
      contention;
      yielding;
      statefulness;
      visibility
    }

  module Axis = struct
    let alloc_as_value : Alloc.Axis.packed -> Value.Axis.packed = function
      | P (Comonadic Areality) -> P (Comonadic Areality)
      | P (Comonadic Linearity) -> P (Comonadic Linearity)
      | P (Comonadic Portability) -> P (Comonadic Portability)
      | P (Comonadic Yielding) -> P (Comonadic Yielding)
      | P (Comonadic Statefulness) -> P (Comonadic Statefulness)
      | P (Monadic Uniqueness) -> P (Monadic Uniqueness)
      | P (Monadic Contention) -> P (Monadic Contention)
      | P (Monadic Visibility) -> P (Monadic Visibility)
  end

  let locality_as_regionality = C.locality_as_regionality
end

let comonadic_locality_as_regionality comonadic =
  S.apply Value.Comonadic.Obj.obj (Map_comonadic Locality_as_regionality)
    comonadic

let comonadic_regional_to_local comonadic =
  S.apply Alloc.Comonadic.Obj.obj (Map_comonadic Regional_to_local) comonadic

let alloc_as_value m =
  let { comonadic; monadic } = m in
  let comonadic = comonadic_locality_as_regionality comonadic in
  { comonadic; monadic }

let alloc_to_value_l2r m =
  let { comonadic; monadic } = Alloc.disallow_right m in
  let comonadic =
    S.apply Value.Comonadic.Obj.obj (Map_comonadic Local_to_regional) comonadic
  in
  { comonadic; monadic }

let value_to_alloc_r2g : type l r. (l * r) Value.t -> (l * r) Alloc.t =
 fun m ->
  let { comonadic; monadic } = m in
  let comonadic =
    S.apply Alloc.Comonadic.Obj.obj (Map_comonadic Regional_to_global) comonadic
  in
  { comonadic; monadic }

let value_to_alloc_r2l m =
  let { comonadic; monadic } = m in
  let comonadic = comonadic_regional_to_local comonadic in
  { comonadic; monadic }

module Modality = struct
  type 'a raw =
    | Meet_with : 'a -> 'a raw
    | Join_with : 'a -> 'a raw

  type t = Atom : 'a Value.Axis.t * 'a raw -> t

  let is_id (Atom (ax, a)) =
    match a with
    | Join_with c -> Value.Const.is_min ax c
    | Meet_with c -> Value.Const.is_max ax c

  let is_constant (Atom (ax, a)) =
    match a with
    | Join_with c -> Value.Const.is_max ax c
    | Meet_with c -> Value.Const.is_min ax c

  let print ppf = function
    | Atom (ax, Join_with c) ->
      Format.fprintf ppf "join_with(%a)" (C.print (Value.proj_obj ax)) c
    | Atom (ax, Meet_with c) ->
      Format.fprintf ppf "meet_with(%a)" (C.print (Value.proj_obj ax)) c

  (* Inferred modalities

      Similar to constant modalities, an inferred modality maps the mode of a
      record/structure to the mode of a value therein. An inferred modality [f]
      is inferred from the structure/record mode [mm] and the value mode [m]. It
      will only be applied on some [x >= mm]: That is, it will only be applied
      on the original module.

      It should satisfy the following conditions:

      Zapping: [f] should be of the form [join_c] for monadic axes, or [meet_c]
      for comonadic axes.

      Soundness: You should not get a value from a record/structure at a mode
      strictly stronger than how it was put in. That is, for any [x >= mm], [f x
      >= m].

      Completeness: Ideally we also want [f mm <= m].

      Monadic axes

      Soundness condition says [join_c x >= m] for any [x >= mm]. Equivalently,
      [join_c mm >= m]. By adjunction, [c >= subtract_mm m]. We take the lower
      bound [c := subtract_mm m]. Note that this is equivalent to taking [c := m
      >= subtract_mm m]. Proof:

      - [join_m x >= join_(subtract_mm m) x] is trivial since [m >= subtract_mm
        m].
      - [join_m x <= join_(subtract_mm m) x], or equivalently [m <=
      join_(subtract_mm m) x], or equivalently [subtract_x m <= subtract_mm m],
      which is trivial since [x >= mm].

      Taking [c := subtract_mm m] is better for zapping since it's lower and
      thus closer to identity modality. Taking [c := m] is easier for [apply]
      and [sub].

      Comonadic axes

      Soundness condition says [meet_c x >= m] for any [x >= mm]. Equivalently,
      [meet_c mm >= m]. By def. of [meet], we have both [c >= m] and [mm >= m].
      The latter is guaranteed by the user of [infer]. We guarantee the former
      by taking [c := imply_mm m >= m]. One might worry that this is too relaxed
      and will be "less complete" than taking [c := m]; however, note that
      [imply_mm m <= imply_mm m] and thus by adjunction [meet_(imply_mm m) mm <=
      m], which means the chosen [c] is complete.

      Taking [c := m] is easier for [apply] and [sub]. Taking [c := imply_mm m]
      is better for zapping since it's higher and thus closer to identity
      modality. However, note that we DON'T have [meet_m x = meet_(imply_mm m)
      x], which means [apply/sub] and [zap] might behave in a confusing (albeit
      sound) manner.

      CR zqian: once we support binary mode solver, [c := imply_mm m] will be
      used uniformly by [apply] [sub] and [zap].
  *)

  module Monadic = struct
    module Mode = Value.Monadic

    type 'a axis = 'a Mode.Axis.t

    type error = Error : 'a axis * 'a raw Solver.error -> error

    module Const = struct
      type t = Join_const of Mode.Const.t

      let id = Join_const Mode.Const.min

      let is_id t = t = id

      let max = Join_const Mode.Const.max

      let sub left right : (_, error) Result.t =
        match left, right with
        | Join_const c0, Join_const c1 ->
          if Mode.Const.le c0 c1
          then Ok ()
          else
            let (Error (ax, { left; right })) =
              Mode.axis_of_error { left = c0; right = c1 }
            in
            Error
              (Error (ax, { left = Join_with left; right = Join_with right }))

      let concat ~then_ t =
        match then_, t with
        | Join_const c0, Join_const c1 -> Join_const (Mode.Const.join c0 c1)

      let apply : type l r. t -> (l * r) Mode.t -> (l * r) Mode.t =
       fun t x -> match t with Join_const c -> Mode.join_const c x

      let proj ax (Join_const c) = Join_with (Axis.proj ax c)

      let set ax a (Join_const c) =
        match a with
        | Join_with a -> Join_const (Axis.set ax a c)
        | Meet_with _ -> assert false

      let print ppf = function
        | Join_const c -> Format.fprintf ppf "join_const(%a)" Mode.Const.print c
    end

    type t =
      | Const of Const.t
      | Diff of Mode.lr * Mode.lr  (** See "Inferred modalities" comments *)
      | Undefined

    let sub_log left right ~log : (unit, error) Result.t =
      match left, right with
      | Const c0, Const c1 -> Const.sub c0 c1
      | Diff (mm, m), Const (Join_const c) -> (
        (* Check that for any x >= mm, join(x, m) <= join(x, c), which (by
           definition of join) is equivalent to m <= join(x, c). This has to
           hold for all x >= mm, so we check m <= join(mm, c). *)
        match Mode.submode_log m (Mode.join_const c mm) ~log with
        | Ok () -> Ok ()
        | Error (Error (ax, { left; _ })) ->
          Error
            (Error
               ( ax,
                 { left = Join_with left; right = Join_with (Axis.proj ax c) }
               )))
      | Diff (_, _m0), Diff (_, _m1) ->
        (* [m1] is a left mode so it cannot appear on the right. So we can't do
           a proper check. However, this branch is only hit by
           [wrap_constraint_with_shape], in which case LHS and RHS should be
           physically equal. *)
        assert (left == right);
        Ok ()
      | Const _, Diff _ ->
        Misc.fatal_error
          "inferred modality Diff should not be on the RHS of sub."
      | Undefined, _ | _, Undefined ->
        Misc.fatal_error "modality Undefined should not be in sub."

    let id = Const Const.id

    let apply : type r. t -> (allowed * r) Mode.t -> Mode.l =
     fun t x ->
      match t with
      | Const c -> Const.apply c x |> Mode.disallow_right
      | Undefined ->
        Misc.fatal_error "modality Undefined should not be applied."
      | Diff (_, m) -> Mode.join [Mode.allow_right m; x]

    let print ppf = function
      | Const c -> Const.print ppf c
      | Undefined -> Format.fprintf ppf "undefined"
      | Diff _ -> Format.fprintf ppf "diff"

    (* All zapping functions mutate [mm] and [m] to the degree that's sufficient
       to fix [subtract_mm m], and return it. [subtract] is antitone for [mm]
       and monotone for [m]. *)

    let zap_to_floor = function
      | Const c -> c
      | Undefined -> Misc.fatal_error "modality Undefined should not be zapped."
      | Diff (mm, m) ->
        (* Ideally we will take [c = subtract_mm m] and zap it to floor.
           However, [subtract] requires [mm] to be constant. We get the ceil of
           [mm] to construct the floor of [c]. *)
        let cc = Mode.Guts.get_ceil mm in
        let c = Mode.subtract cc m in
        let c = Mode.zap_to_floor c in
        (* Note that we did not mutate [mm] but simply took its ceil, which
           might be mutated later. To satisfy the coherence condition (see the
           comment in the mli), we want to:

           - make it impossible that [subtract_mm m < c], which is trivial since
           [mm <= cc] and thus [subtract_mm m >= subtract_cc m = c].
           - make it impossible that [subtract_mm m > c], which is to ensure
           [subtract_mm m <= c], equivalently [m <= join_mm c], which is
           achieved by the following [submode].
        *)
        Mode.submode_exn m (Mode.join_const c mm);
        Const.Join_const c

    let zap_to_id = zap_to_floor

    let to_const_opt = function Const c -> Some c | Undefined | Diff _ -> None

    let of_const c = Const c

    let infer ~md_mode ~mode = Diff (md_mode, mode)

    let max = Const Const.max
  end

  module Comonadic = struct
    module Mode = Value.Comonadic

    type 'a axis = 'a Mode.Axis.t

    type error = Error : 'a axis * 'a raw Solver.error -> error

    module Const = struct
      type t = Meet_const of Mode.Const.t

      let id = Meet_const Mode.Const.max

      let is_id t = t = id

      let max = Meet_const Mode.Const.max

      let sub left right : (_, error) Result.t =
        match left, right with
        | Meet_const c0, Meet_const c1 ->
          if Mode.Const.le c0 c1
          then Ok ()
          else
            let (Error (ax, { left; right })) =
              Mode.axis_of_error { left = c0; right = c1 }
            in
            Error
              (Error (ax, { left = Meet_with left; right = Meet_with right }))

      let concat ~then_ t =
        match then_, t with
        | Meet_const c0, Meet_const c1 -> Meet_const (Mode.Const.meet c0 c1)

      let apply : type l r. t -> (l * r) Mode.t -> (l * r) Mode.t =
       fun t x -> match t with Meet_const c -> Mode.meet_const c x

      let proj ax (Meet_const c) = Meet_with (Axis.proj ax c)

      let set ax a (Meet_const c) =
        match a with
        | Meet_with a -> Meet_const (Axis.set ax a c)
        | Join_with _ -> assert false

      let print ppf = function
        | Meet_const c -> Format.fprintf ppf "meet_const(%a)" Mode.Const.print c
    end

    type t =
      | Const of Const.t
      | Undefined
      | Exactly of Mode.lr * Mode.lr  (** See "Inferred modalities" comments *)

    let sub_log left right ~log : (unit, error) Result.t =
      match left, right with
      | Const c0, Const c1 -> Const.sub c0 c1
      | Exactly (_mm, m), Const (Meet_const c) -> (
        (* Check for all [x >= mm], [meet_(imply_mm m) x <= meet_c x], or
           equivalently [meet_(imply_mm m) x <= c], or equivalently [meet_(imply_mm
           m) max <= c], or equivalently [imply_mm m <= c]. We can't check this
           without binary mode solver.

           So instead we check [meet_m x <= meet_c x] (See "Inferred modalities"
           comments), which amounts to [m <= c]. *)
        match Mode.submode_log m (Mode.of_const c) ~log with
        | Ok () -> Ok ()
        | Error (Error (ax, { left; _ })) ->
          Error
            (Error
               ( ax,
                 { left = Meet_with left; right = Meet_with (Axis.proj ax c) }
               )))
      | Exactly (_, _m0), Exactly (_, _m1) ->
        (* [m1] is a left mode, so there is no good way to check.
           However, this branch only hit by [wrap_constraint_with_shape],
           in which case LHS and RHS should be physically equal. *)
        assert (left == right);
        Ok ()
      | Const _, Exactly _ ->
        Misc.fatal_error
          "inferred modaltiy Exactly should not be on the RHS of sub."
      | Undefined, _ | _, Undefined ->
        Misc.fatal_error "modality Undefined should not be in sub."

    let id = Const Const.id

    let apply : type r. t -> (allowed * r) Mode.t -> Mode.l =
     fun t x ->
      match t with
      | Const c -> Const.apply c x |> Mode.disallow_right
      | Undefined ->
        Misc.fatal_error "modality Undefined should not be applied."
      | Exactly (_mm, m) ->
        (* Ideally want to return [meet_(imply_mm m) x], which we can't do
           without binary mode solver, so instead we return [meet_m x] (See
           "Inferred modalities" comments), which because of [x >= mm >= m] is
           equal to [m]. *)
        Mode.disallow_right m

    let print ppf = function
      | Const c -> Const.print ppf c
      | Undefined -> Format.fprintf ppf "undefined"
      | Exactly _ -> Format.fprintf ppf "exactly"

    let infer ~md_mode ~mode = Exactly (md_mode, mode)

    let max = Const Const.max

    (* All zapping functions mutate [mm] and [m] to the degree that's sufficient
       to fix [imply_mm m], and return it. [imply] is antitone for [mm] and
       monotone for [m]. *)

    let zap_to_ceil = function
      | Const c -> c
      | Undefined -> Misc.fatal_error "modality Undefined should not be zapped."
      | Exactly (mm, m) ->
        (* Ideally we will take [c = imply_mm m] and zap it to ceil. However,
           [imply] requires [mm] to be constant. We get the floor of [mm] to
           construct the ceil of [c]. *)
        let cc = Mode.Guts.get_floor mm in
        let c = Mode.imply cc m in
        let c = Mode.zap_to_ceil c in
        (* Note that we did not mutate [mm] but simply took its floor, which
           might be mutated later. To satisfy the coherence condition (see the
           comment in the mli), we want to:

           - make it impossible that [imply_mm m > c], which is trivial since
           [mm >= cc] and thus [imply_mm m <= imply_cc m = c].
           - make it impossible that [imply_mm m < c], which is to ensure
           [imply_mm m >= c], equivalently [m >= meet_mm c], which is achieved
           by the following [submode].
        *)
        Mode.submode_exn (Mode.meet_const c mm) m;
        Const.Meet_const c

    let zap_to_id = zap_to_ceil

    let zap_to_floor = function
      | Const c -> c
      | Undefined -> Misc.fatal_error "modality Undefined should not be zapped."
      | Exactly (mm, m) ->
        (* The following zaps [mm] to ceil, which might conflict with future
           mode constraints on [mm]. We find constraining [mm] to [legacy] a
           good workaround. *)
        (* CR zqian: Find a better solution *)
        Mode.submode mm Mode.legacy |> ignore;
        let m = Mode.zap_to_floor m in
        let mm = Mode.zap_to_ceil mm in
        let c = Mode.Const.imply mm m in
        Const.Meet_const c

    let to_const_opt = function
      | Const c -> Some c
      | Undefined | Exactly _ -> None

    let of_const c = Const c
  end

  module Value = struct
    type error = Error : 'a Value.Axis.t * 'a raw Solver.error -> error

    type equate_error = equate_step * error

    module Const = struct
      module Monadic = Monadic.Const
      module Comonadic = Comonadic.Const

      type t = (Monadic.t, Comonadic.t) monadic_comonadic

      let id = { monadic = Monadic.id; comonadic = Comonadic.id }

      let is_id { monadic; comonadic } =
        Monadic.is_id monadic && Comonadic.is_id comonadic

      let sub t0 t1 : (unit, error) Result.t =
        match Monadic.sub t0.monadic t1.monadic with
        | Error (Error (ax, e)) -> Error (Error (Monadic ax, e))
        | Ok () -> (
          match Comonadic.sub t0.comonadic t1.comonadic with
          | Ok () -> Ok ()
          | Error (Error (ax, e)) -> Error (Error (Comonadic ax, e)))

      let equate = equate_from_submode' sub

      let apply t { monadic; comonadic } =
        let monadic = Monadic.apply t.monadic monadic in
        let comonadic = Comonadic.apply t.comonadic comonadic in
        { monadic; comonadic }

      let concat ~then_ t =
        let monadic = Monadic.concat ~then_:then_.monadic t.monadic in
        let comonadic = Comonadic.concat ~then_:then_.comonadic t.comonadic in
        { monadic; comonadic }

      let proj (type a) (ax : a Value.Axis.t) { monadic; comonadic } =
        match ax with
        | Monadic ax -> Monadic.proj ax monadic
        | Comonadic ax -> Comonadic.proj ax comonadic

      let set (type a) (ax : a Value.Axis.t) (a : a raw) { monadic; comonadic }
          =
        match ax with
        | Monadic ax ->
          let monadic = Monadic.set ax a monadic in
          { monadic; comonadic }
        | Comonadic ax ->
          let comonadic = Comonadic.set ax a comonadic in
          { monadic; comonadic }

      let diff t0 t1 =
        List.filter_map
          (fun (Value.Axis.P ax) ->
            let a0 = proj ax t0 in
            let a1 = proj ax t1 in
            if a0 = a1 then None else Some (Atom (ax, a1)))
          Value.Axis.all

      let print ppf { monadic; comonadic } =
        Format.fprintf ppf "%a;%a" Monadic.print monadic Comonadic.print
          comonadic
    end

    type t = (Monadic.t, Comonadic.t) monadic_comonadic

    let id : t = { monadic = Monadic.id; comonadic = Comonadic.id }

    let undefined : t = { monadic = Undefined; comonadic = Comonadic.Undefined }

    let apply t { monadic; comonadic } =
      let monadic = Monadic.apply t.monadic monadic in
      let comonadic = Comonadic.apply t.comonadic comonadic in
      { monadic; comonadic }

    let sub_log t0 t1 ~log : (unit, error) Result.t =
      match Monadic.sub_log t0.monadic t1.monadic ~log with
      | Error (Error (ax, e)) -> Error (Error (Monadic ax, e))
      | Ok () -> (
        match Comonadic.sub_log t0.comonadic t1.comonadic ~log with
        | Ok () -> Ok ()
        | Error (Error (ax, e)) -> Error (Error (Comonadic ax, e)))

    let sub l r = try_with_log (sub_log l r)

    let equate m0 m1 = try_with_log (equate_from_submode sub_log m0 m1)

    let print ppf ({ monadic; comonadic } : t) =
      Format.fprintf ppf "%a;%a" Monadic.print monadic Comonadic.print comonadic

    let infer ~md_mode ~mode : t =
      let comonadic =
        Comonadic.infer ~md_mode:md_mode.comonadic ~mode:mode.comonadic
      in
      let monadic = Monadic.infer ~md_mode:md_mode.monadic ~mode:mode.monadic in
      { monadic; comonadic }

    let zap_to_id t =
      let { monadic; comonadic } = t in
      let comonadic = Comonadic.zap_to_id comonadic in
      let monadic = Monadic.zap_to_id monadic in
      { monadic; comonadic }

    let zap_to_floor t =
      let { monadic; comonadic } = t in
      let comonadic = Comonadic.zap_to_floor comonadic in
      let monadic = Monadic.zap_to_floor monadic in
      { monadic; comonadic }

    let to_const_opt t =
      let { monadic; comonadic } = t in
      Option.bind (Comonadic.to_const_opt comonadic) (fun comonadic ->
          Option.bind (Monadic.to_const_opt monadic) (fun monadic ->
              Some { monadic; comonadic }))

    let to_const_exn t = t |> to_const_opt |> Option.get

    let of_const { monadic; comonadic } =
      let comonadic = Comonadic.of_const comonadic in
      let monadic = Monadic.of_const monadic in
      { monadic; comonadic }

    let max =
      let monadic = Monadic.max in
      let comonadic = Comonadic.max in
      { monadic; comonadic }
  end
end

module Crossing = struct
  (* The mode crossing capability of a type [t] is characterized by a monotone
     function [f] from modes to some lattice [L], in the following way:

     To check [e : t @ m0 <= m1], we should instead check [f m0 <= f m1] to
     allow more programs.

     For example, if [f] is the identity function, then [t] does not cross modes
     at all. If [f] maps to the unit lattice (containing only one element), [f
     m0 <= f m1] always succeeds, which means [t] crosses modes fully.

     In practice, during mode checking we usually have either [m0] or [m1], but
     not both. In order to perform mode crossing one-sided, we require [f] to
     have left adjoint [fl] and right adjoint [fr], which gives:

     [f m0 <= f m1] is equivalent to [fl (f m0) <= m1] is equivalent to [m0 <=
     fr (f m1)]

     Therefore, we can perform any of the following for mode crossing:
     - Apply [f] on both [m0] and [m1]
     - Apply [fl ∘ f] on [m0]
     - Apply [fr ∘ f] on [m1]

     Mode crossing forms a lattice: [f0 <= f1] iff [f0] allows more mode
     crossing than [f1]. Concretely:

     [f0 <= f1] iff, for any [m0, m1], if [f1 m0 <= f1 m1],
     then [f0 m0 <= f0 m1].
  *)

  module Monadic = struct
    module Modality = Modality.Monadic.Const
    module Mode = Value.Monadic

    type t = Modality.t

    let of_bounds c : t = Join_const c

    let modality m t = Modality.concat ~then_:t m

    let apply_left : t -> _ -> _ = function
      | Join_const c -> fun m -> Mode.subtract c (Mode.join_const c m)

    let apply_right : t -> _ -> _ = function
      | Join_const c ->
        fun m ->
          (* The right adjoint of join is a restriction of identity *)
          Mode.join_const c m

    let le (t0 : t) (t1 : t) =
      match t0, t1 with Join_const c0, Join_const c1 -> Mode.Const.le c1 c0

    let top : t = Join_const Mode.Const.min

    let bot : t = Join_const Mode.Const.max
  end

  module Comonadic = struct
    module Modality = Modality.Comonadic.Const
    module Mode = Value.Comonadic

    type t = Modality.t

    let of_bounds c : t =
      let c = C.apply Mode.Obj.obj (Map_comonadic Locality_as_regionality) c in
      Meet_const c

    let modality m t = Modality.concat ~then_:t m

    let apply_left : t -> _ -> _ = function
      | Meet_const c ->
        fun m ->
          (* The left adjoint of meet is a restriction of identity *)
          Mode.meet_const c m

    let apply_right : t -> _ -> _ = function
      | Meet_const c -> fun m -> Mode.imply c (Mode.meet_const c m)

    let le (t0 : t) (t1 : t) =
      match t0, t1 with Meet_const c0, Meet_const c1 -> Mode.Const.le c0 c1

    let top : t = Meet_const Mode.Const.max

    let bot : t = Meet_const Mode.Const.min
  end

  type t = (Monadic.t, Comonadic.t) monadic_comonadic

  let of_bounds { monadic; comonadic } =
    let monadic = Monadic.of_bounds monadic in
    let comonadic = Comonadic.of_bounds comonadic in
    { monadic; comonadic }

  let modality m { monadic; comonadic } =
    let monadic = Monadic.modality m.monadic monadic in
    let comonadic = Comonadic.modality m.comonadic comonadic in
    { monadic; comonadic }

  let apply_left t { monadic; comonadic } =
    let monadic = Monadic.apply_left t.monadic monadic in
    let comonadic = Comonadic.apply_left t.comonadic comonadic in
    { monadic; comonadic }

  let apply_right t { monadic; comonadic } =
    let monadic = Monadic.apply_right t.monadic monadic in
    let comonadic = Comonadic.apply_right t.comonadic comonadic in
    { monadic; comonadic }

  (* Our mode crossing is for [Value] modes, but can be extended to [Alloc]
     modes via [alloc_as_value], defined as follows:

     Given a mode crossing [f] for [Value], and we are to check [Alloc] submoding
     [m0 <= m1], we will instead check
     [f (alloc_as_value m0) <= f (alloc_as_value m1)].

     By adjunction tricks, this is equivalent to
     - [ m0 <= regional_to_global ∘ fr ∘ f ∘ alloc_as_value m1 ]
     - [ regional_to_local ∘ fl ∘ f ∘ alloc_as_value m0 <= m1 ]
     where [regional_to_global] is the right adjoint of [alloc_as_value], and
     [regional_to_local] the left adjoint. *)

  let apply_left_alloc t m =
    m |> alloc_as_value |> apply_left t |> value_to_alloc_r2l

  let apply_right_alloc t m =
    m |> alloc_as_value |> apply_right t |> value_to_alloc_r2g

  let apply_left_right_alloc t { monadic; comonadic } =
    let monadic = Monadic.apply_right t.monadic monadic in
    let comonadic =
      comonadic |> comonadic_locality_as_regionality
      |> Comonadic.apply_left t.comonadic
      |> comonadic_regional_to_local
      (* the left adjoint of [locality_as_regionality]*)
    in
    { monadic; comonadic }

  let le t0 t1 =
    Monadic.le t0.monadic t1.monadic && Comonadic.le t0.comonadic t1.comonadic

  let top = { monadic = Monadic.top; comonadic = Comonadic.top }

  let bot = { monadic = Monadic.bot; comonadic = Comonadic.bot }

  let print ppf t =
    let print_atom ppf = function
      | Modality.Atom (ax, Join_with c) -> C.print (Value.proj_obj ax) ppf c
      | Modality.Atom (ax, Meet_with c) -> C.print (Value.proj_obj ax) ppf c
    in
    let l =
      List.filter_map
        (fun (Value.Axis.P ax) ->
          let a = Modality.Value.Const.proj ax t in
          let a = Modality.Atom (ax, a) in
          if Modality.is_id a then None else Some a)
        Value.Axis.all
    in
    Format.(pp_print_list ~pp_sep:pp_print_space print_atom ppf l)
end
