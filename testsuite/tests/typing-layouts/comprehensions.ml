(* TEST
 include stdlib_upstream_compatible;
 {
   flags = "-extension comprehensions";
   expect;
 }
*)

open Stdlib_upstream_compatible

(* Unboxed types are banned in comprehensions: The output array must contain
   things of layout value, as must any arrays you iterate over. *)

let unbox_array x = [| Float_u.of_float a for a in x |]
[%%expect{|
Line 6, characters 23-41:
6 | let unbox_array x = [| Float_u.of_float a for a in x |]
                           ^^^^^^^^^^^^^^^^^^
Error: This expression has type "Stdlib_upstream_compatible.Float_u.t" = "float#"
       but an expression was expected of type "('a : value)"
       The layout of Stdlib_upstream_compatible.Float_u.t is float64.
       But the layout of Stdlib_upstream_compatible.Float_u.t must be a sublayout of
         value
         because it's the element type of array comprehension.
|}]

let box_array x = [| Float_u.to_float a for a in x |]
[%%expect{|
Line 1, characters 38-39:
1 | let box_array x = [| Float_u.to_float a for a in x |]
                                          ^
Error: This expression has type "('a : value)"
       but an expression was expected of type
         "Stdlib_upstream_compatible.Float_u.t" = "float#"
       The layout of Stdlib_upstream_compatible.Float_u.t is float64.
       But the layout of Stdlib_upstream_compatible.Float_u.t must be a sublayout of
         value
         because it's the element type of an array that is iterated over in a comprehension.
|}]

(* List cases are less interesting because we don't allow unboxed types in lists
   at all.  These tests are here just so we remember to think about
   comprehensions when that changes. *)
let unbox_list x = [ Float_u.of_float a for a in x ]
[%%expect{|
Line 1, characters 21-39:
1 | let unbox_list x = [ Float_u.of_float a for a in x ]
                         ^^^^^^^^^^^^^^^^^^
Error: This expression has type "Stdlib_upstream_compatible.Float_u.t" = "float#"
       but an expression was expected of type "('a : value_or_null)"
       The layout of Stdlib_upstream_compatible.Float_u.t is float64.
       But the layout of Stdlib_upstream_compatible.Float_u.t must be a sublayout of
         value
         because the type argument of list has layout value_or_null.
|}]

let box_list x = [ Float_u.to_float a for a in x ]
[%%expect{|
Line 1, characters 36-37:
1 | let box_list x = [ Float_u.to_float a for a in x ]
                                        ^
Error: This expression has type "('a : value)"
       but an expression was expected of type
         "Stdlib_upstream_compatible.Float_u.t" = "float#"
       The layout of Stdlib_upstream_compatible.Float_u.t is float64.
       But the layout of Stdlib_upstream_compatible.Float_u.t must be a sublayout of
         value
         because it's the element type of a list that is iterated over in a comprehension.
|}]
