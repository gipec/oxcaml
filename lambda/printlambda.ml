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

open Format
open Asttypes
open Primitive
open Types
open Lambda

let unboxed_integer_suffix = function
  | Unboxed_int8 -> "unboxed_int8"
  | Unboxed_int16 -> "unboxed_int16"
  | Unboxed_nativeint -> "nativeint"
  | Unboxed_int32 -> "int32"
  | Unboxed_int64 -> "int64"

let unboxed_float_suffix = function
  | Unboxed_float64 -> "float"
  | Unboxed_float32 -> "float32"

let unboxed_vector_suffix = function
  | Unboxed_vec128 -> "vec128"
  | Unboxed_vec256 -> "vec256"
  | Unboxed_vec512 -> "vec512"

(* Uses in most contexts get the "unboxed_" prefix *)
let unboxed_integer ui = "unboxed_" ^ unboxed_integer_suffix ui
let unboxed_float uf = "unboxed_" ^ unboxed_float_suffix uf
let unboxed_vector uv = "unboxed_" ^ unboxed_vector_suffix uv

(* As a layout it's just the name *)
let unboxed_integer_layout = unboxed_integer_suffix
let unboxed_float_layout = unboxed_float_suffix
let unboxed_vector_layout = unboxed_vector_suffix

let boxed_integer = function
  | Boxed_nativeint -> "nativeint"
  | Boxed_int32 -> "int32"
  | Boxed_int64 -> "int64"

let boxed_float = function
  | Boxed_float64 -> "float"
  | Boxed_float32 -> "float32"

let boxed_vector = function
  | Boxed_vec128 -> "vec128"
  | Boxed_vec256 -> "vec256"
  | Boxed_vec512 -> "vec512"

let vector_width = function
  | Boxed_vec128 -> "128"
  | Boxed_vec256 -> "256"
  | Boxed_vec512 -> "512"

let rec scannable_product_element_kinds kinds =
  "[" ^ String.concat "; " (List.map scannable_product_element_kind kinds) ^ "]"

and scannable_product_element_kind = function
  | Pint_scannable -> "int"
  | Paddr_scannable -> "addr"
  | Pproduct_scannable kinds -> scannable_product_element_kinds kinds

let rec ignorable_product_element_kinds kinds =
  "[" ^ String.concat "; " (List.map ignorable_product_element_kind kinds) ^ "]"

and ignorable_product_element_kind = function
  | Pint_ignorable -> "int"
  | Punboxedfloat_ignorable f -> unboxed_float f
  | Punboxedint_ignorable i -> unboxed_integer i
  | Pproduct_ignorable kinds -> ignorable_product_element_kinds kinds

let array_kind = function
  | Pgenarray -> "gen"
  | Paddrarray -> "addr"
  | Pintarray -> "int"
  | Pfloatarray -> "float"
  | Punboxedfloatarray f -> unboxed_float f
  | Punboxedintarray i -> unboxed_integer i
  | Punboxedvectorarray v -> unboxed_vector v
  | Pgcscannableproductarray kinds ->
    "scannableproduct " ^ scannable_product_element_kinds kinds
  | Pgcignorableproductarray kinds ->
    "ignorableproduct " ^ ignorable_product_element_kinds kinds

let array_mut = function
  | Mutable -> "array"
  | Immutable | Immutable_unique -> "iarray"

let array_ref_kind ppf k =
  let pp_mode ppf = function
    | Alloc_heap -> ()
    | Alloc_local -> fprintf ppf "(local)"
  in
  match k with
  | Pgenarray_ref mode -> fprintf ppf "gen%a" pp_mode mode
  | Paddrarray_ref -> fprintf ppf "addr"
  | Pintarray_ref -> fprintf ppf "int"
  | Pfloatarray_ref mode -> fprintf ppf "float%a" pp_mode mode
  | Punboxedfloatarray_ref Unboxed_float64 -> fprintf ppf "unboxed_float"
  | Punboxedfloatarray_ref Unboxed_float32 -> fprintf ppf "unboxed_float32"
  | Punboxedintarray_ref i -> pp_print_string ppf (unboxed_integer i)
  | Punboxedvectorarray_ref Unboxed_vec128 -> fprintf ppf "unboxed_vec128"
  | Punboxedvectorarray_ref Unboxed_vec256 -> fprintf ppf "unboxed_vec256"
  | Punboxedvectorarray_ref Unboxed_vec512 -> fprintf ppf "unboxed_vec512"
  | Pgcscannableproductarray_ref kinds ->
    fprintf ppf "scannableproduct %s" (scannable_product_element_kinds kinds)
  | Pgcignorableproductarray_ref kinds ->
    fprintf ppf "ignorableproduct %s" (ignorable_product_element_kinds kinds)

let array_index_kind ppf k =
  match k with
  | Ptagged_int_index -> fprintf ppf "int"
  | Punboxed_int_index i -> pp_print_string ppf (unboxed_integer i)

let array_set_kind ppf k =
  let pp_mode ppf = function
    | Modify_heap -> ()
    | Modify_maybe_stack -> fprintf ppf "(local)"
  in
  match k with
  | Pgenarray_set mode -> fprintf ppf "gen%a" pp_mode mode
  | Paddrarray_set mode -> fprintf ppf "addr%a" pp_mode mode
  | Pintarray_set -> fprintf ppf "int"
  | Pfloatarray_set -> fprintf ppf "float"
  | Punboxedfloatarray_set Unboxed_float64 -> fprintf ppf "unboxed_float"
  | Punboxedfloatarray_set Unboxed_float32 -> fprintf ppf "unboxed_float32"
  | Punboxedintarray_set i -> pp_print_string ppf (unboxed_integer i)
  | Punboxedvectorarray_set Unboxed_vec128 -> fprintf ppf "unboxed_vec128"
  | Punboxedvectorarray_set Unboxed_vec256 -> fprintf ppf "unboxed_vec256"
  | Punboxedvectorarray_set Unboxed_vec512 -> fprintf ppf "unboxed_vec512"
  | Pgcscannableproductarray_set (mode, kinds) ->
    fprintf ppf "scannableproduct%a %s" pp_mode mode
      (scannable_product_element_kinds kinds)
  | Pgcignorableproductarray_set kinds ->
    fprintf ppf "ignorableproduct %s" (ignorable_product_element_kinds kinds)

let locality_mode_if_local = function
  | Alloc_heap -> ""
  | Alloc_local -> "local"

let locality_mode ppf = function
  | Alloc_heap -> fprintf ppf "heap"
  | Alloc_local -> fprintf ppf "local"

let rec mixed_block_element print_value_kind ppf el =
  match el with
  | Value vk -> print_value_kind ppf vk
  | Float_boxed _ -> fprintf ppf "float"
  | Float32 -> fprintf ppf "float32"
  | Float64 -> fprintf ppf "float64"
  | Bits8 -> fprintf ppf "bits8"
  | Bits16 -> fprintf ppf "bits16"
  | Bits32 -> fprintf ppf "bits32"
  | Bits64 -> fprintf ppf "bits64"
  | Vec128 -> fprintf ppf "vec128"
  | Vec256 -> fprintf ppf "vec256"
  | Vec512 -> fprintf ppf "vec512"
  | Word -> fprintf ppf "word"
  | Product shape ->
    fprintf ppf "product %a"
      (Format.pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ",@ ")
         (mixed_block_element print_value_kind)) (Array.to_list shape)

let constructor_shape print_value_kind ppf shape =
  match shape with
  | Constructor_uniform fields ->
     Format.pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ",@ ")
       print_value_kind ppf fields
  | Constructor_mixed shape->
    fprintf ppf "%a"
      (Format.pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ",@ ")
         (mixed_block_element print_value_kind)) (Array.to_list shape)

let tag_and_constructor_shape print_value_kind ppf (tag, shape) =
  fprintf ppf "@[<hov 1>[%d:@ %a]@]"
    tag
    (constructor_shape print_value_kind)
    shape

let variant_kind print_value_kind ppf ~consts ~non_consts =
  fprintf ppf "@[<hov 1>(consts (%a))@ (non_consts (%a))@]"
    (Format.pp_print_list ~pp_sep:Format.pp_print_space Format.pp_print_int)
    consts
    (Format.pp_print_list ~pp_sep:Format.pp_print_space
      (tag_and_constructor_shape print_value_kind))
    non_consts

let or_null_suffix ppf nullable =
  match nullable with
  | Non_nullable -> ()
  | Nullable -> fprintf ppf "_or_null"

let rec raw_value_kind ppf rk =
  match rk with
  | Pgenval -> fprintf ppf "value"
  | Pintval -> fprintf ppf "int"
  | Pboxedfloatval bf -> fprintf ppf "%s" (boxed_float bf)
  | Parrayval elt_kind -> fprintf ppf "%sarray" (array_kind elt_kind)
  | Pboxedintval bi -> fprintf ppf "%s" (boxed_integer bi)
  | Pboxedvectorval bv -> fprintf ppf "%s" (boxed_vector bv)
  | Pvariant { consts; non_consts; } ->
    variant_kind value_kind ppf ~consts ~non_consts

and value_kind ppf vk =
  match vk with
  | { raw_kind = Pgenval; nullable = Non_nullable } -> fprintf ppf "*"
  | { raw_kind = Pgenval; nullable = Nullable } -> fprintf ppf "?"
  | { raw_kind; nullable } ->
    fprintf ppf "@[<hov 1>value%a<@,%a>@]"
      or_null_suffix nullable
      raw_value_kind raw_kind

let rec layout ppf layout_ =
  match layout_ with
  | Pvalue k -> value_kind ppf k
  | Ptop -> fprintf ppf "top"
  | Pbottom -> fprintf ppf "bottom"
  | Punboxed_float bf -> fprintf ppf "%s" (unboxed_float_layout bf)
  | Punboxed_int bi -> fprintf ppf "%s" (unboxed_integer_layout bi)
  | Punboxed_vector bv -> fprintf ppf "%s" (unboxed_vector_layout bv)
  | Punboxed_product layouts ->
    fprintf ppf "@[<hov 1>#(%a)@]"
      (pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ",@ ") layout)
      layouts

let layout_annotation ppf layout_ =
  match layout_ with
  | Pvalue { raw_kind = Pgenval; nullable = Non_nullable } -> ()
  | Pvalue { raw_kind = Pgenval; nullable = Nullable } ->
    fprintf ppf "?"
  | _ -> fprintf ppf "[%a]" layout layout_

let return_kind ppf (mode, kind) =
  let smode = locality_mode_if_local mode in
  match kind with
  | Pvalue { raw_kind; nullable } -> begin
    let or_null_suffix =
      match nullable with
      | Non_nullable -> ""
      | Nullable -> " or_null"
    in
    match raw_kind with
    | Pgenval when is_heap_mode mode -> ()
    | Pgenval -> fprintf ppf ": %s@ " smode
    | Pintval -> fprintf ppf ": int@ "
    | Pboxedfloatval bf ->
      fprintf ppf ": %s%s%s@ " smode (boxed_float bf) or_null_suffix
    | Parrayval elt_kind ->
      fprintf ppf ": %s%sarray%s@ " smode (array_kind elt_kind) or_null_suffix
    | Pboxedintval bi ->
      fprintf ppf ": %s%s%s@ " smode (boxed_integer bi) or_null_suffix
    | Pboxedvectorval bv ->
      fprintf ppf ": %s%s%s@ " smode (boxed_vector bv) or_null_suffix
    | Pvariant { consts; non_consts; } ->
      fprintf ppf ": %a@ "
        (fun ppf () -> variant_kind value_kind ppf ~consts ~non_consts) ()
  end
  | Punboxed_float bf -> fprintf ppf ": %s@ " (unboxed_float bf)
  | Punboxed_int bi -> fprintf ppf ": %s@ " (unboxed_integer bi)
  | Punboxed_vector bv -> fprintf ppf ": %s@ " (unboxed_vector bv)
  | Punboxed_product _ -> fprintf ppf ": %a@ " layout kind
  | Ptop -> fprintf ppf ": top@ "
  | Pbottom -> fprintf ppf ": bottom@ "

let field_kind = value_kind

let locality_kind = function
  | Alloc_heap -> ""
  | Alloc_local -> "[L]"

let print_boxed_integer_conversion ppf bi1 bi2 m =
  fprintf ppf "%s_of_%s%s" (boxed_integer bi2) (boxed_integer bi1)
    (locality_kind m)

let boxed_integer_mark name bi m =
  match bi with
  | Boxed_nativeint -> Printf.sprintf "Nativeint.%s%s" name (locality_kind m)
  | Boxed_int32 -> Printf.sprintf "Int32.%s%s" name (locality_kind m)
  | Boxed_int64 -> Printf.sprintf "Int64.%s%s" name (locality_kind m)

let print_boxed_integer name ppf bi m =
  fprintf ppf "%s" (boxed_integer_mark name bi m);;

let unboxed_integer_mark name bi m =
  match bi with
  | Unboxed_nativeint -> Printf.sprintf "Nativeint_u.%s%s" name (locality_kind m)
  | Unboxed_int8 -> Printf.sprintf "Int8_u.%s%s" name (locality_kind m)
  | Unboxed_int16 -> Printf.sprintf "Int16_u.%s%s" name (locality_kind m)
  | Unboxed_int32 -> Printf.sprintf "Int32_u.%s%s" name (locality_kind m)
  | Unboxed_int64 -> Printf.sprintf "Int64_u.%s%s" name (locality_kind m)

let print_unboxed_integer name ppf bi m =
  fprintf ppf "%s" (unboxed_integer_mark name bi m);;

let boxed_float_mark name bf m =
  match bf with
  | Boxed_float64 -> Printf.sprintf "Float.%s%s" name (locality_kind m)
  | Boxed_float32 -> Printf.sprintf "Float32.%s%s" name (locality_kind m)

let print_boxed_float name ppf bf m =
  fprintf ppf "%s" (boxed_float_mark name bf m);;

let unboxed_float_mark name bf m =
  match bf with
  | Unboxed_float64 -> Printf.sprintf "Float_u.%s%s" name (locality_kind m)
  | Unboxed_float32 -> Printf.sprintf "Float32_u.%s%s" name (locality_kind m)

let print_unboxed_float name ppf bf m =
  fprintf ppf "%s" (unboxed_float_mark name bf m);;

let print_bigarray name unsafe kind ppf layout =
  fprintf ppf "Bigarray.%s[%s,%s]"
    (if unsafe then "unsafe_"^ name else name)
    (match kind with
     | Pbigarray_unknown -> "generic"
     | Pbigarray_float16 -> "float16"
     | Pbigarray_float32 -> "float32"
     | Pbigarray_float32_t -> "float32_t"
     | Pbigarray_float64 -> "float64"
     | Pbigarray_sint8 -> "sint8"
     | Pbigarray_uint8 -> "uint8"
     | Pbigarray_sint16 -> "sint16"
     | Pbigarray_uint16 -> "uint16"
     | Pbigarray_int32 -> "int32"
     | Pbigarray_int64 -> "int64"
     | Pbigarray_caml_int -> "camlint"
     | Pbigarray_native_int -> "nativeint"
     | Pbigarray_complex32 -> "complex32"
     | Pbigarray_complex64 -> "complex64")
    (match layout with
    |  Pbigarray_unknown_layout -> "unknown"
     | Pbigarray_c_layout -> "C"
     | Pbigarray_fortran_layout -> "Fortran")

let record_rep ppf r = match r with
  | Record_unboxed -> fprintf ppf "unboxed"
  | Record_boxed _ -> fprintf ppf "boxed"
  | Record_inlined _ -> fprintf ppf "inlined"
  | Record_float -> fprintf ppf "float"
  | Record_ufloat -> fprintf ppf "ufloat"
  | Record_mixed _ -> fprintf ppf "mixed"

let block_shape ppf shape = match shape with
  | None | Some [] -> ()
  | Some l when List.for_all ((=) Lambda.generic_value) l -> ()
  | Some [elt] ->
      Format.fprintf ppf " (%a)" field_kind elt
  | Some (h :: t) ->
      Format.fprintf ppf " (%a" field_kind h;
      List.iter (fun elt ->
          Format.fprintf ppf ",%a" field_kind elt)
        t;
      Format.fprintf ppf ")"

let rec mixed_block_element
  : 'a. (_ -> 'a -> _) -> _ -> 'a mixed_block_element -> _ =
  fun print_mode ppf elt ->
  match elt with
  | Value vk -> value_kind ppf vk
  | Float_boxed param -> fprintf ppf "float_boxed(%a)" print_mode param
  | Float64 -> fprintf ppf "float64"
  | Float32 -> fprintf ppf "float32"
  | Bits8 -> fprintf ppf "bits8"
  | Bits16 -> fprintf ppf "bits16"
  | Bits32 -> fprintf ppf "bits32"
  | Bits64 -> fprintf ppf "bits64"
  | Vec128 -> fprintf ppf "vec128"
  | Vec256 -> fprintf ppf "vec256"
  | Vec512 -> fprintf ppf "vec512"
  | Word -> fprintf ppf "word"
  | Product shape ->
    fprintf ppf "product %a" (mixed_block_shape (fun _ _ -> ())) shape

and mixed_block_shape
  : 'a. (_ -> 'a -> _) -> _ -> 'a mixed_block_element array -> _
  = fun print_mode ppf shape ->
  match Array.length shape with
  | 0 -> ()
  | 1 -> fprintf ppf " (%a)" (mixed_block_element print_mode) shape.(0)
  | _ -> begin
    Array.iteri (fun i elt ->
      if i = 0 then
        fprintf ppf " (%a" (mixed_block_element print_mode) elt
      else
        fprintf ppf ",%a" (mixed_block_element print_mode) elt)
      shape;
    fprintf ppf ")"
  end

let integer_comparison ppf = function
  | Ceq -> fprintf ppf "=="
  | Cne -> fprintf ppf "!="
  | Clt -> fprintf ppf "<"
  | Cle -> fprintf ppf "<="
  | Cgt -> fprintf ppf ">"
  | Cge -> fprintf ppf ">="

let float_comparison = function
  | CFeq -> "=="
  | CFneq -> "!="
  | CFlt -> "<"
  | CFnlt -> "!<"
  | CFle -> "<="
  | CFnle -> "!<="
  | CFgt -> ">"
  | CFngt -> "!>"
  | CFge -> ">="
  | CFnge -> "!>="

let field_read_semantics ppf sem =
  match sem with
  | Reads_agree -> ()
  | Reads_vary -> fprintf ppf "_mut"

let peek_or_poke ppf (pp : peek_or_poke) =
  match pp with
  | Ppp_tagged_immediate -> fprintf ppf "tagged_immediate"
  | Ppp_unboxed_float32 -> fprintf ppf "unboxed_float32"
  | Ppp_unboxed_float -> fprintf ppf "unboxed_float"
  | Ppp_unboxed_int8 -> fprintf ppf "unboxed_int8"
  | Ppp_unboxed_int16 -> fprintf ppf "unboxed_int16"
  | Ppp_unboxed_int32 -> fprintf ppf "unboxed_int32"
  | Ppp_unboxed_int64 -> fprintf ppf "unboxed_int64"
  | Ppp_unboxed_nativeint -> fprintf ppf "unboxed_nativeint"

let primitive ppf = function
  | Pbytes_to_string -> fprintf ppf "bytes_to_string"
  | Pbytes_of_string -> fprintf ppf "bytes_of_string"
  | Pignore -> fprintf ppf "ignore"
  | Pgetglobal cu -> fprintf ppf "global %a!" Compilation_unit.print cu
  | Psetglobal cu -> fprintf ppf "setglobal %a!" Compilation_unit.print cu
  | Pgetpredef id -> fprintf ppf "getpredef %a!" Ident.print id
  | Pmakeblock(tag, Immutable, shape, mode) ->
      fprintf ppf "make%sblock %i%a"
        (locality_mode_if_local mode) tag block_shape shape
  | Pmakeblock(tag, Immutable_unique, shape, mode) ->
      fprintf ppf "make%sblock_unique %i%a"
        (locality_mode_if_local mode) tag block_shape shape
  | Pmakeblock(tag, Mutable, shape, mode) ->
      fprintf ppf "make%smutable %i%a"
        (locality_mode_if_local mode) tag block_shape shape
  | Pmakefloatblock (Immutable, mode) ->
      fprintf ppf "make%sfloatblock Immutable"
        (locality_mode_if_local mode)
  | Pmakefloatblock (Immutable_unique, mode) ->
     fprintf ppf "make%sfloatblock Immutable_unique"
        (locality_mode_if_local mode)
  | Pmakefloatblock (Mutable, mode) ->
     fprintf ppf "make%sfloatblock Mutable"
        (locality_mode_if_local mode)
  | Pmakeufloatblock (Immutable, mode) ->
      fprintf ppf "make%sufloatblock Immutable"
        (locality_mode_if_local mode)
  | Pmakeufloatblock (Immutable_unique, mode) ->
     fprintf ppf "make%sufloatblock Immutable_unique"
        (locality_mode_if_local mode)
  | Pmakeufloatblock (Mutable, mode) ->
     fprintf ppf "make%sufloatblock Mutable"
        (locality_mode_if_local mode)
  | Pmakemixedblock (tag, Immutable, abs, mode) ->
      fprintf ppf "make%amixedblock %i Immutable%a"
        locality_mode mode tag (mixed_block_shape (fun _ _ -> ())) abs
  | Pmakemixedblock (tag, Immutable_unique, abs, mode) ->
     fprintf ppf "make%amixedblock %i Immutable_unique%a"
        locality_mode mode tag (mixed_block_shape (fun _ _ -> ())) abs
  | Pmakemixedblock (tag, Mutable, abs, mode) ->
     fprintf ppf "make%amixedblock %i Mutable%a"
        locality_mode mode tag (mixed_block_shape (fun _ _ -> ())) abs
  | Pmakelazyblock Lazy_tag ->
      fprintf ppf "makelazyblock"
  | Pmakelazyblock Forward_tag ->
      fprintf ppf "makeforwardblock"
  | Pfield (n, ptr, sem) ->
      let instr =
        match ptr, sem with
        | Immediate, _ -> "field_int"
        | Pointer, Reads_vary -> "field_mut"
        | Pointer, Reads_agree -> "field_imm"
      in
      fprintf ppf "%s %i" instr n
  | Pfield_computed sem ->
      fprintf ppf "field_computed%a" field_read_semantics sem
  | Psetfield(n, ptr, init) ->
      let instr =
        match ptr with
        | Pointer -> "ptr"
        | Immediate -> "imm"
      in
      let init =
        match init with
        | Heap_initialization -> "(heap-init)"
        | Root_initialization -> "(root-init)"
        | Assignment Modify_heap -> ""
        | Assignment Modify_maybe_stack -> "(maybe-stack)"
      in
      fprintf ppf "setfield_%s%s %i" instr init n
  | Psetfield_computed (ptr, init) ->
      let instr =
        match ptr with
        | Pointer -> "ptr"
        | Immediate -> "imm"
      in
      let init =
        match init with
        | Heap_initialization -> "(heap-init)"
        | Root_initialization -> "(root-init)"
        | Assignment Modify_heap -> ""
        | Assignment Modify_maybe_stack -> "(maybe-stack)"
      in
      fprintf ppf "setfield_%s%s_computed" instr init
  | Pfloatfield (n, sem, mode) ->
      fprintf ppf "floatfield%a%s %i"
        field_read_semantics sem (locality_mode_if_local mode) n
  | Pufloatfield (n, sem) ->
      fprintf ppf "ufloatfield%a %i"
        field_read_semantics sem n
  | Pmixedfield (n, shape, sem) ->
      fprintf ppf "mixedfield%a %a %a"
        field_read_semantics sem
        (pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ",") pp_print_int) n
        (mixed_block_shape
          (fun ppf mode -> fprintf ppf "%s" (locality_mode_if_local mode)))
        shape
  | Psetfloatfield (n, init) ->
      let init =
        match init with
        | Heap_initialization -> "(heap-init)"
        | Root_initialization -> "(root-init)"
        | Assignment Modify_heap -> ""
        | Assignment Modify_maybe_stack -> "(maybe-stack)"
      in
      fprintf ppf "setfloatfield%s %i" init n
  | Psetufloatfield (n, init) ->
      let init =
        match init with
        | Heap_initialization -> "(heap-init)"
        | Root_initialization -> "(root-init)"
        | Assignment Modify_heap -> ""
        | Assignment Modify_maybe_stack -> "(maybe-stack)"
      in
      fprintf ppf "setufloatfield%s %i" init n
  | Psetmixedfield (n, shape, init) ->
      let init =
        match init with
        | Heap_initialization -> "(heap-init)"
        | Root_initialization -> "(root-init)"
        | Assignment Modify_heap -> ""
        | Assignment Modify_maybe_stack -> "(maybe-stack)"
      in
      fprintf ppf "setmixedfield%s %a %a"
        init
        (pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ",") pp_print_int) n
        (mixed_block_shape (fun _ _ -> ())) shape
  | Pduprecord (rep, size) -> fprintf ppf "duprecord %a %i" record_rep rep size
  | Prunstack -> fprintf ppf "runstack"
  | Pperform -> fprintf ppf "perform"
  | Presume -> fprintf ppf "resume"
  | Preperform -> fprintf ppf "reperform"
  | Pmake_unboxed_product layouts ->
      fprintf ppf "make_unboxed_product #(%a)"
        (pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ", ") layout)
        layouts
  | Punboxed_product_field (n, layouts) ->
      fprintf ppf "unboxed_product_field %d #(%a)" n
        (pp_print_list ~pp_sep:(fun ppf () -> fprintf ppf ", ") layout)
        layouts
  | Parray_element_size_in_bytes ak ->
      fprintf ppf "array_element_size_in_bytes (%s)" (array_kind ak)
  | Pccall p -> fprintf ppf "%s" p.prim_name
  | Praise k -> fprintf ppf "%s" (Lambda.raise_kind k)
  | Psequand -> fprintf ppf "&&"
  | Psequor -> fprintf ppf "||"
  | Pnot -> fprintf ppf "not"
  | Pnegint -> fprintf ppf "~"
  | Paddint -> fprintf ppf "+"
  | Psubint -> fprintf ppf "-"
  | Pmulint -> fprintf ppf "*"
  | Pdivint Safe -> fprintf ppf "/"
  | Pdivint Unsafe -> fprintf ppf "/u"
  | Pmodint Safe -> fprintf ppf "mod"
  | Pmodint Unsafe -> fprintf ppf "mod_unsafe"
  | Pandint -> fprintf ppf "and"
  | Porint -> fprintf ppf "or"
  | Pxorint -> fprintf ppf "xor"
  | Plslint -> fprintf ppf "lsl"
  | Plsrint -> fprintf ppf "lsr"
  | Pasrint -> fprintf ppf "asr"
  | Pintcomp(cmp) -> integer_comparison ppf cmp
  | Pcompare_ints -> fprintf ppf "compare_ints"
  | Pcompare_floats bf -> fprintf ppf "compare_floats %s" (boxed_float bf)
  | Pcompare_bints bi -> fprintf ppf "compare_bints %s" (boxed_integer bi)
  | Poffsetint n -> fprintf ppf "%i+" n
  | Poffsetref n -> fprintf ppf "+:=%i"n
  | Pfloatoffloat32 m ->
    print_boxed_float "float_of_float32" ppf Boxed_float32 m
  | Pfloat32offloat m ->
    print_boxed_float "float32_of_float" ppf Boxed_float64 m
  | Pintoffloat bf -> fprintf ppf "int_of_%s" (boxed_float bf)
  | Pfloatofint (bf,m) ->
      fprintf ppf "%s_of_int%s" (boxed_float bf) (locality_kind m)
  | Pabsfloat (bf,m) -> print_boxed_float "abs" ppf bf m
  | Pnegfloat (bf,m) -> print_boxed_float "neg" ppf bf m
  | Paddfloat (bf,m) -> print_boxed_float "add" ppf bf m
  | Psubfloat (bf,m) -> print_boxed_float "sub" ppf bf m
  | Pmulfloat (bf,m) -> print_boxed_float "mul" ppf bf m
  | Pdivfloat (bf,m) -> print_boxed_float "div" ppf bf m
  | Pfloatcomp (bf,cmp) ->
      print_boxed_float (float_comparison cmp) ppf bf alloc_heap
  | Punboxed_float_comp (bf,cmp) ->
      print_unboxed_float (float_comparison cmp) ppf bf alloc_heap
  | Pstringlength -> fprintf ppf "string.length"
  | Pstringrefu -> fprintf ppf "string.unsafe_get"
  | Pstringrefs -> fprintf ppf "string.get"
  | Pbyteslength -> fprintf ppf "bytes.length"
  | Pbytesrefu -> fprintf ppf "bytes.unsafe_get"
  | Pbytessetu -> fprintf ppf "bytes.unsafe_set"
  | Pbytesrefs -> fprintf ppf "bytes.get"
  | Pbytessets -> fprintf ppf "bytes.set"

  | Parraylength k -> fprintf ppf "array.length[%s]" (array_kind k)
  | Pmakearray (k, Mutable, mode) ->
     fprintf ppf "make%sarray[%s]" (locality_mode_if_local mode) (array_kind k)
  | Pmakearray (k, Immutable, mode) ->
     fprintf ppf "make%sarray_imm[%s]" (locality_mode_if_local mode) (array_kind k)
  | Pmakearray (k, Immutable_unique, mode) ->
      fprintf ppf "make%sarray_unique[%s]" (locality_mode_if_local mode)
        (array_kind k)
  | Pmakearray_dynamic (k, mode, has_init) ->
      fprintf ppf "make%sarray_any[%s]%s" (locality_mode_if_local mode)
        (array_kind k)
        (match has_init with
         | With_initializer -> ""
         | Uninitialized -> "[uninit]")
  | Pduparray (k, Mutable) -> fprintf ppf "duparray[%s]" (array_kind k)
  | Pduparray (k, Immutable) -> fprintf ppf "duparray_imm[%s]" (array_kind k)
  | Pduparray (k, Immutable_unique) ->
      fprintf ppf "duparray_unique[%s]" (array_kind k)
  | Parrayblit { src_mutability; dst_array_set_kind } ->
      fprintf ppf "arrayblit[%s -> %a]"
        (array_mut src_mutability)
        array_set_kind dst_array_set_kind
  | Parrayrefu (rk, idx, mut) -> fprintf ppf "%s.unsafe_get[%a indexed by %a]"
                                 (array_mut mut)
                                 array_ref_kind rk
                                 array_index_kind idx
  | Parraysetu (sk, idx) -> fprintf ppf "array.unsafe_set[%a indexed by %a]"
                              array_set_kind sk
                              array_index_kind idx
  | Parrayrefs (rk, idx, mut) -> fprintf ppf "%s.get[%a indexed by %a]"
                                 (array_mut mut)
                                 array_ref_kind rk
                                 array_index_kind idx
  | Parraysets (sk, idx) -> fprintf ppf "array.set[%a indexed by %a]"
                              array_set_kind sk
                              array_index_kind idx
  | Pctconst c ->
     let const_name = match c with
       | Big_endian -> "big_endian"
       | Word_size -> "word_size"
       | Int_size -> "int_size"
       | Max_wosize -> "max_wosize"
       | Ostype_unix -> "ostype_unix"
       | Ostype_win32 -> "ostype_win32"
       | Ostype_cygwin -> "ostype_cygwin"
       | Backend_type -> "backend_type"
       | Runtime5 -> "runtime5" in
     fprintf ppf "sys.constant_%s" const_name
  | Pisint { variant_only } ->
      fprintf ppf (if variant_only then "isint" else "obj_is_int")
  | Pisnull -> fprintf ppf "isnull"
  | Pisout -> fprintf ppf "isout"
  | Pbintofint (bi,m) -> print_boxed_integer "of_int" ppf bi m
  | Pintofbint bi -> print_boxed_integer "to_int" ppf bi alloc_heap
  | Pcvtbint (bi1, bi2, m) -> print_boxed_integer_conversion ppf bi1 bi2 m
  | Pnegbint (bi,m) -> print_boxed_integer "neg" ppf bi m
  | Paddbint (bi,m) -> print_boxed_integer "add" ppf bi m
  | Psubbint (bi,m) -> print_boxed_integer "sub" ppf bi m
  | Pmulbint (bi,m) -> print_boxed_integer "mul" ppf bi m
  | Pdivbint { size; is_safe = Safe; mode } ->
      print_boxed_integer "div" ppf size mode
  | Pdivbint { size; is_safe = Unsafe; mode } ->
      print_boxed_integer "div_unsafe" ppf size mode
  | Pmodbint { size; is_safe = Safe; mode } ->
      print_boxed_integer "mod" ppf size mode
  | Pmodbint { size; is_safe = Unsafe; mode } ->
      print_boxed_integer "mod_unsafe" ppf size mode
  | Pandbint (bi,m) -> print_boxed_integer "and" ppf bi m
  | Porbint (bi,m) -> print_boxed_integer "or" ppf bi m
  | Pxorbint (bi,m) -> print_boxed_integer "xor" ppf bi m
  | Plslbint (bi,m) -> print_boxed_integer "lsl" ppf bi m
  | Plsrbint (bi,m) -> print_boxed_integer "lsr" ppf bi m
  | Pasrbint (bi,m) -> print_boxed_integer "asr" ppf bi m
  | Pbintcomp(bi, Ceq) -> print_boxed_integer "==" ppf bi alloc_heap
  | Pbintcomp(bi, Cne) -> print_boxed_integer "!=" ppf bi alloc_heap
  | Pbintcomp(bi, Clt) -> print_boxed_integer "<" ppf bi alloc_heap
  | Pbintcomp(bi, Cgt) -> print_boxed_integer ">" ppf bi alloc_heap
  | Pbintcomp(bi, Cle) -> print_boxed_integer "<=" ppf bi alloc_heap
  | Pbintcomp(bi, Cge) -> print_boxed_integer ">=" ppf bi alloc_heap
  | Punboxed_int_comp(bi, Ceq) -> print_unboxed_integer "==" ppf bi alloc_heap
  | Punboxed_int_comp(bi, Cne) -> print_unboxed_integer "!=" ppf bi alloc_heap
  | Punboxed_int_comp(bi, Clt) -> print_unboxed_integer "<" ppf bi alloc_heap
  | Punboxed_int_comp(bi, Cgt) -> print_unboxed_integer ">" ppf bi alloc_heap
  | Punboxed_int_comp(bi, Cle) -> print_unboxed_integer "<=" ppf bi alloc_heap
  | Punboxed_int_comp(bi, Cge) -> print_unboxed_integer ">=" ppf bi alloc_heap
  | Pbigarrayref(unsafe, _n, kind, layout) ->
      print_bigarray "get" unsafe kind ppf layout
  | Pbigarrayset(unsafe, _n, kind, layout) ->
      print_bigarray "set" unsafe kind ppf layout
  | Pbigarraydim(n) -> fprintf ppf "Bigarray.dim_%i" n
  | Pstring_load_16 {unsafe; index_kind} ->
     fprintf ppf "string.%sget16[indexed by %a]" (if unsafe then "unsafe_" else "")
       array_index_kind index_kind
  | Pstring_load_32 {unsafe; index_kind; mode; boxed} ->
     fprintf ppf "string.%sget32%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pstring_load_f32{unsafe; index_kind; mode; boxed} ->
     fprintf ppf "string.%sgetf32%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pstring_load_64{unsafe; index_kind; mode; boxed} ->
     fprintf ppf "string.%sget64%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pstring_load_vec {size; unsafe; index_kind; mode; boxed} ->
     fprintf ppf "string.%sunaligned_get%s%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (vector_width size)
       (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbytes_load_16 {unsafe; index_kind} ->
     fprintf ppf "bytes.%sget16[indexed by %a]" (if unsafe then "unsafe_" else "")
       array_index_kind index_kind
  | Pbytes_load_32 {unsafe; index_kind; mode; boxed} ->
     fprintf ppf "bytes.%sget32%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbytes_load_f32{unsafe; index_kind; mode; boxed} ->
     fprintf ppf "bytes.%sgetf32%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbytes_load_64{unsafe; index_kind; mode; boxed} ->
     fprintf ppf "bytes.%sget64%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbytes_load_vec {size; unsafe; index_kind; mode; boxed} ->
     fprintf ppf "bytes.%sunaligned_get%s%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (vector_width size)
       (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbytes_set_16 {unsafe; index_kind} ->
     fprintf ppf "bytes.%sset16[indexed by %a]" (if unsafe then "unsafe_" else "")
       array_index_kind index_kind
  | Pbytes_set_32 {unsafe; index_kind; boxed} ->
     fprintf ppf "bytes.%sset32%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       array_index_kind index_kind
  | Pbytes_set_f32{unsafe; index_kind; boxed} ->
     fprintf ppf "bytes.%ssetf32%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       array_index_kind index_kind
  | Pbytes_set_64{unsafe; index_kind; boxed} ->
     fprintf ppf "bytes.%sset64%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       array_index_kind index_kind
  | Pbytes_set_vec { size; unsafe; boxed; index_kind } ->
     fprintf ppf "bytes.%sunaligned_set%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (vector_width size)
       (if boxed then "" else "#") array_index_kind index_kind
  | Pbigstring_load_16 { unsafe; index_kind } ->
     fprintf ppf "bigarray.array1.%sget16[indexed by %a]"
       (if unsafe then "unsafe_" else "") array_index_kind index_kind
  | Pbigstring_load_32 { unsafe; mode; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%sget32%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbigstring_load_f32 { unsafe; mode; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%sgetf32%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbigstring_load_64 { unsafe; mode; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%sget64%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       (locality_kind mode) array_index_kind index_kind
  | Pbigstring_load_vec { size; unsafe; aligned; mode; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%s%sget%s%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "")
       (if aligned then "aligned_" else "unaligned_")
       (vector_width size)
       (if boxed then "" else "#") (locality_kind mode) array_index_kind index_kind
  | Pbigstring_set_16 { unsafe; index_kind } ->
     fprintf ppf "bigarray.array1.%sset16[indexed by %a]"
       (if unsafe then "unsafe_" else "") array_index_kind index_kind
  | Pbigstring_set_32 { unsafe; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%sset32%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       array_index_kind index_kind
  | Pbigstring_set_f32 { unsafe; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%ssetf32%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       array_index_kind index_kind
  | Pbigstring_set_64 { unsafe; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%sset64%s[indexed by %a]"
       (if unsafe then "unsafe_" else "") (if boxed then "" else "#")
       array_index_kind index_kind
  | Pbigstring_set_vec { size; unsafe; aligned; boxed; index_kind } ->
     fprintf ppf "bigarray.array1.%s%sset%s%s[indexed by %a]"
       (if unsafe then "unsafe_" else "")
       (if aligned then "aligned_" else "unaligned_")
       (vector_width size)
       (if boxed then "" else "#") array_index_kind index_kind
  | Pfloatarray_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "floatarray.%sget%s%s%s"
       (if unsafe then "unsafe_" else "") (vector_width size)
       (if boxed then "" else "#") (locality_kind mode)
  | Pfloat_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "float_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Pint_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "int_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Punboxed_float_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "unboxed_float_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Punboxed_float32_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "unboxed_float32_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Punboxed_int32_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "unboxed_int32_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Punboxed_int64_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "unboxed_int64_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Punboxed_nativeint_array_load_vec {size; unsafe; mode; boxed} ->
     fprintf ppf "unboxed_nativeint_array.%sget%s%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#") (locality_kind mode)
  | Pfloatarray_set_vec {size; unsafe; boxed} ->
     fprintf ppf "floatarray.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Pfloat_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "float_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Pint_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "int_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Punboxed_float_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "unboxed_float_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Punboxed_float32_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "unboxed_float32_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Punboxed_int32_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "unboxed_int32_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Punboxed_int64_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "unboxed_int64_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Punboxed_nativeint_array_set_vec {size; unsafe; boxed} ->
     fprintf ppf "unboxed_nativeint_array.%sset%s%s"
      (if unsafe then "unsafe_" else "") (vector_width size)
      (if boxed then "" else "#")
  | Pbswap16 -> fprintf ppf "bswap16"
  | Pbbswap(bi,m) -> print_boxed_integer "bswap" ppf bi m
  | Pint_as_pointer m -> fprintf ppf "int_as_pointer%s" (locality_kind m)
  | Patomic_load_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> fprintf ppf "atomic_load_field_imm"
        | Pointer -> fprintf ppf "atomic_load_field_ptr")
  | Patomic_set_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> fprintf ppf "atomic_set_field_imm"
        | Pointer -> fprintf ppf "atomic_set_field_ptr")
  | Patomic_exchange_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> fprintf ppf "atomic_exchange_field_imm"
        | Pointer -> fprintf ppf "atomic_exchange_field_ptr")
  | Patomic_compare_exchange_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> fprintf ppf "atomic_compare_exchange_field_imm"
        | Pointer -> fprintf ppf "atomic_compare_exchange_field_ptr")
  | Patomic_compare_set_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> fprintf ppf "atomic_compare_set_field_imm"
        | Pointer -> fprintf ppf "atomic_compare_set_field_ptr")
  | Patomic_fetch_add_field -> fprintf ppf "atomic_fetch_add_field"
  | Patomic_add_field -> fprintf ppf "atomic_add_field"
  | Patomic_sub_field -> fprintf ppf "atomic_sub_field"
  | Patomic_land_field -> fprintf ppf "atomic_land_field"
  | Patomic_lor_field -> fprintf ppf "atomic_lor_field"
  | Patomic_lxor_field -> fprintf ppf "atomic_lxor_field"
  | Popaque _ -> fprintf ppf "opaque"
  | Pdls_get -> fprintf ppf "dls_get"
  | Ppoll -> fprintf ppf "poll"
  | Pcpu_relax -> fprintf ppf "cpu_relax"
  | Pprobe_is_enabled {name} -> fprintf ppf "probe_is_enabled[%s]" name
  | Pobj_dup -> fprintf ppf "obj_dup"
  | Pobj_magic _ -> fprintf ppf "obj_magic"
  | Punbox_float bf -> fprintf ppf "unbox_%s" (boxed_float bf)
  | Pbox_float (bf,m) ->
      fprintf ppf "box_%s%s" (boxed_float bf) (locality_kind m)
  | Punbox_int bi -> fprintf ppf "unbox_%s" (boxed_integer bi)
  | Pbox_int (bi, m) ->
      fprintf ppf "box_%s%s" (boxed_integer bi) (locality_kind m)
  | Punbox_unit -> fprintf ppf "unbox_unit"
  | Puntag_int i -> fprintf ppf "untag_%s" (unboxed_integer i)
  | Ptag_int i -> fprintf ppf "tag_%s" (unboxed_integer i)
  | Punbox_vector bi -> fprintf ppf "unbox_%s" (boxed_vector bi)
  | Pbox_vector (bi, m) ->
      fprintf ppf "box_%s%s" (boxed_vector bi) (locality_kind m)
  | Parray_to_iarray -> fprintf ppf "array_to_iarray"
  | Parray_of_iarray -> fprintf ppf "array_of_iarray"
  | Pget_header m -> fprintf ppf "get_header%s" (locality_kind m)
  | Preinterpret_tagged_int63_as_unboxed_int64 ->
      fprintf ppf "reinterpret_tagged_int63_as_unboxed_int64"
  | Preinterpret_unboxed_int64_as_tagged_int63 ->
      fprintf ppf "reinterpret_unboxed_int64_as_tagged_int63"
  | Ppeek layout ->
      fprintf ppf "(peek@ %a)"
        peek_or_poke layout
  | Ppoke layout ->
      fprintf ppf "(poke@ %a)"
        peek_or_poke layout

let name_of_primitive = function
  | Pbytes_of_string -> "Pbytes_of_string"
  | Pbytes_to_string -> "Pbytes_to_string"
  | Pignore -> "Pignore"
  | Pgetglobal _ -> "Pgetglobal"
  | Psetglobal _ -> "Psetglobal"
  | Pgetpredef _ -> "Pgetpredef"
  | Pmakeblock _ -> "Pmakeblock"
  | Pmakefloatblock _ -> "Pmakefloatblock"
  | Pmakeufloatblock _ -> "Pmakeufloatblock"
  | Pmakemixedblock _ -> "Pmakemixedblock"
  | Pmakelazyblock _ -> "Pmakelazyblock"
  | Pfield _ -> "Pfield"
  | Pfield_computed _ -> "Pfield_computed"
  | Psetfield _ -> "Psetfield"
  | Psetfield_computed _ -> "Psetfield_computed"
  | Pfloatfield _ -> "Pfloatfield"
  | Psetfloatfield _ -> "Psetfloatfield"
  | Pufloatfield _ -> "Pufloatfield"
  | Psetufloatfield _ -> "Psetufloatfield"
  | Pmixedfield _ -> "Pmixedfield"
  | Psetmixedfield _ -> "Psetmixedfield"
  | Pduprecord _ -> "Pduprecord"
  | Pmake_unboxed_product _ -> "Pmake_unboxed_product"
  | Punboxed_product_field _ -> "Punboxed_product_field"
  | Parray_element_size_in_bytes _ -> "Parray_element_size_in_bytes"
  | Pccall _ -> "Pccall"
  | Praise _ -> "Praise"
  | Psequand -> "Psequand"
  | Psequor -> "Psequor"
  | Pnot -> "Pnot"
  | Pnegint -> "Pnegint"
  | Paddint -> "Paddint"
  | Psubint -> "Psubint"
  | Pmulint -> "Pmulint"
  | Pdivint _ -> "Pdivint"
  | Pmodint _ -> "Pmodint"
  | Pandint -> "Pandint"
  | Porint -> "Porint"
  | Pxorint -> "Pxorint"
  | Plslint -> "Plslint"
  | Plsrint -> "Plsrint"
  | Pasrint -> "Pasrint"
  | Pintcomp _ -> "Pintcomp"
  | Pcompare_ints -> "Pcompare_ints"
  | Pcompare_floats _ -> "Pcompare_floats"
  | Pcompare_bints _ -> "Pcompare"
  | Poffsetint _ -> "Poffsetint"
  | Poffsetref _ -> "Poffsetref"
  | Pfloatoffloat32 _ -> "Pfloatoffloat32"
  | Pfloat32offloat _ -> "Pfloat32offloat"
  | Pintoffloat _ -> "Pintoffloat"
  | Pfloatofint (_, _) -> "Pfloatofint"
  | Pnegfloat (_, _) -> "Pnegfloat"
  | Pabsfloat (_, _) -> "Pabsfloat"
  | Paddfloat (_, _) -> "Paddfloat"
  | Psubfloat (_, _) -> "Psubfloat"
  | Pmulfloat (_, _) -> "Pmulfloat"
  | Pdivfloat (_, _) -> "Pdivfloat"
  | Pfloatcomp (_, _) -> "Pfloatcomp"
  | Punboxed_float_comp (_, _) -> "Punboxed_float_comp"
  | Pstringlength -> "Pstringlength"
  | Pstringrefu -> "Pstringrefu"
  | Pstringrefs -> "Pstringrefs"
  | Pbyteslength -> "Pbyteslength"
  | Pbytesrefu -> "Pbytesrefu"
  | Pbytessetu -> "Pbytessetu"
  | Pbytesrefs -> "Pbytesrefs"
  | Pbytessets -> "Pbytessets"
  | Parraylength _ -> "Parraylength"
  | Pmakearray _ -> "Pmakearray"
  | Pmakearray_dynamic _ -> "Pmakearray_dynamic"
  | Pduparray _ -> "Pduparray"
  | Parrayblit _ -> "Parrayblit"
  | Parrayrefu _ -> "Parrayrefu"
  | Parraysetu _ -> "Parraysetu"
  | Parrayrefs _ -> "Parrayrefs"
  | Parraysets _ -> "Parraysets"
  | Pctconst _ -> "Pctconst"
  | Pisint _ -> "Pisint"
  | Pisnull -> "Pisnull"
  | Pisout -> "Pisout"
  | Pbintofint _ -> "Pbintofint"
  | Pintofbint _ -> "Pintofbint"
  | Pcvtbint _ -> "Pcvtbint"
  | Pnegbint _ -> "Pnegbint"
  | Paddbint _ -> "Paddbint"
  | Psubbint _ -> "Psubbint"
  | Pmulbint _ -> "Pmulbint"
  | Pdivbint _ -> "Pdivbint"
  | Pmodbint _ -> "Pmodbint"
  | Pandbint _ -> "Pandbint"
  | Porbint _ -> "Porbint"
  | Pxorbint _ -> "Pxorbint"
  | Plslbint _ -> "Plslbint"
  | Plsrbint _ -> "Plsrbint"
  | Pasrbint _ -> "Pasrbint"
  | Pbintcomp _ -> "Pbintcomp"
  | Punboxed_int_comp _ -> "Punboxed_int_comp"
  | Pbigarrayref _ -> "Pbigarrayref"
  | Pbigarrayset _ -> "Pbigarrayset"
  | Pbigarraydim _ -> "Pbigarraydim"
  | Pstring_load_16 _ -> "Pstring_load_16"
  | Pstring_load_32 _ -> "Pstring_load_32"
  | Pstring_load_f32 _ -> "Pstring_load_f32"
  | Pstring_load_64 _ -> "Pstring_load_64"
  | Pstring_load_vec _ -> "Pstring_load_vec"
  | Pbytes_load_16 _ -> "Pbytes_load_16"
  | Pbytes_load_32 _ -> "Pbytes_load_32"
  | Pbytes_load_f32 _ -> "Pbytes_load_f32"
  | Pbytes_load_64 _ -> "Pbytes_load_64"
  | Pbytes_load_vec _ -> "Pbytes_load_vec"
  | Pbytes_set_16 _ -> "Pbytes_set_16"
  | Pbytes_set_32 _ -> "Pbytes_set_32"
  | Pbytes_set_f32 _ -> "Pbytes_set_f32"
  | Pbytes_set_64 _ -> "Pbytes_set_64"
  | Pbytes_set_vec _ -> "Pbytes_set_vec"
  | Pbigstring_load_16 _ -> "Pbigstring_load_16"
  | Pbigstring_load_32 _ -> "Pbigstring_load_32"
  | Pbigstring_load_f32 _ -> "Pbigstring_load_f32"
  | Pbigstring_load_64 _ -> "Pbigstring_load_64"
  | Pbigstring_load_vec _ -> "Pbigstring_load_vec"
  | Pbigstring_set_16 _ -> "Pbigstring_set_16"
  | Pbigstring_set_32 _ -> "Pbigstring_set_32"
  | Pbigstring_set_f32 _ -> "Pbigstring_set_f32"
  | Pbigstring_set_64 _ -> "Pbigstring_set_64"
  | Pbigstring_set_vec _ -> "Pbigstring_set_vec"
  | Pfloatarray_load_vec _ -> "Pfloatarray_load_vec"
  | Pfloat_array_load_vec _ -> "Pfloat_array_load_vec"
  | Pint_array_load_vec _ -> "Pint_array_load_vec"
  | Punboxed_float_array_load_vec _ -> "Punboxed_float_array_load_vec"
  | Punboxed_float32_array_load_vec _ -> "Punboxed_float32_array_load_vec"
  | Punboxed_int32_array_load_vec _ -> "Punboxed_int32_array_load_vec"
  | Punboxed_int64_array_load_vec _ -> "Punboxed_int64_array_load_vec"
  | Punboxed_nativeint_array_load_vec _ -> "Punboxed_nativeint_array_load_vec"
  | Pfloatarray_set_vec _ -> "Pfloatarray_set_vec"
  | Pfloat_array_set_vec _ -> "Pfloat_array_set_vec"
  | Pint_array_set_vec _ -> "Pint_array_set_vec"
  | Punboxed_float_array_set_vec _ -> "Punboxed_float_array_set_vec"
  | Punboxed_float32_array_set_vec _ -> "Punboxed_float32_array_set_vec"
  | Punboxed_int32_array_set_vec _ -> "Punboxed_int32_array_set_vec"
  | Punboxed_int64_array_set_vec _ -> "Punboxed_int64_array_set_vec"
  | Punboxed_nativeint_array_set_vec _ -> "Punboxed_nativeint_array_set_vec"
  | Pbswap16 -> "Pbswap16"
  | Pbbswap _ -> "Pbbswap"
  | Pint_as_pointer _ -> "Pint_as_pointer"
  | Patomic_load_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> "atomic_load_field_imm"
        | Pointer -> "atomic_load_field_ptr")
  | Patomic_set_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> "atomic_set_field_imm"
        | Pointer -> "atomic_set_field_ptr")
  | Patomic_exchange_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> "atomic_exchange_field_imm"
        | Pointer -> "atomic_exchange_field_ptr")
  | Patomic_compare_exchange_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> "atomic_compare_exchange_field_imm"
        | Pointer -> "atomic_compare_exchange_field_ptr")
  | Patomic_compare_set_field {immediate_or_pointer} ->
      (match immediate_or_pointer with
        | Immediate -> "atomic_compare_set_field_imm"
        | Pointer -> "atomic_compare_set_field_ptr")
  | Patomic_fetch_add_field -> "Patomic_fetch_add_field"
  | Patomic_add_field -> "Patomic_add_field"
  | Patomic_sub_field -> "Patomic_sub_field"
  | Patomic_land_field -> "Patomic_land_field"
  | Patomic_lor_field -> "Patomic_lor_field"
  | Patomic_lxor_field -> "Patomic_lxor_field"
  | Pcpu_relax -> "Pcpu_relax"
  | Popaque _ -> "Popaque"
  | Prunstack -> "Prunstack"
  | Presume -> "Presume"
  | Pperform -> "Pperform"
  | Preperform -> "Preperform"
  | Pdls_get -> "Pdls_get"
  | Ppoll -> "Ppoll"
  | Pprobe_is_enabled _ -> "Pprobe_is_enabled"
  | Pobj_dup -> "Pobj_dup"
  | Pobj_magic _ -> "Pobj_magic"
  | Punbox_float _ -> "Punbox_float"
  | Pbox_float (_, _) -> "Pbox_float"
  | Puntag_int _ -> "Puntag_int"
  | Ptag_int _ -> "Ptag_int"
  | Punbox_int _ -> "Punbox_int"
  | Pbox_int _ -> "Pbox_int"
  | Punbox_unit -> "Punbox_unit"
  | Punbox_vector _ -> "Punbox_vector"
  | Pbox_vector _ -> "Pbox_vector"
  | Parray_of_iarray -> "Parray_of_iarray"
  | Parray_to_iarray -> "Parray_to_iarray"
  | Pget_header _ -> "Pget_header"
  | Preinterpret_tagged_int63_as_unboxed_int64 ->
      "Preinterpret_tagged_int63_as_unboxed_int64"
  | Preinterpret_unboxed_int64_as_tagged_int63 ->
      "Preinterpret_unboxed_int64_as_tagged_int63"
  | Ppeek _ -> "Ppeek"
  | Ppoke _ -> "Ppoke"

let zero_alloc_attribute ppf check =
  match check with
  | Default_zero_alloc -> ()
  | Assume {strict; never_returns_normally; loc = _} ->
    fprintf ppf "assume_zero_alloc%s%s@ "
      (if strict then "_strict" else "")
      (if never_returns_normally then "_never_returns_normally" else "")
  | Check {strict; loc = _; custom_error_msg; } ->
    fprintf ppf "assert_zero_alloc%s%s@ "
      (if strict then "_strict" else "")
      (match custom_error_msg with
       | None -> ""
       | Some msg -> Printf.sprintf " customer_error_message %S" msg)

let function_attribute ppf t =
  if t.is_a_functor then
    fprintf ppf "is_a_functor@ ";
  if t.stub then
    fprintf ppf "stub@ ";
  begin match t.inline with
  | Default_inline -> ()
  | Always_inline -> fprintf ppf "always_inline@ "
  | Available_inline -> fprintf ppf "available_inline@ "
  | Never_inline -> fprintf ppf "never_inline@ "
  | Unroll i -> fprintf ppf "unroll(%i)@ " i
  end;
  begin match t.specialise with
  | Default_specialise -> ()
  | Always_specialise -> fprintf ppf "always_specialise@ "
  | Never_specialise -> fprintf ppf "never_specialise@ "
  end;
  begin match t.local with
  | Default_local -> ()
  | Always_local -> fprintf ppf "always_local@ "
  | Never_local -> fprintf ppf "never_local@ "
  end;
  zero_alloc_attribute ppf t.zero_alloc;
  if t.tmc_candidate then
    fprintf ppf "tail_mod_cons@ ";
  begin match t.loop with
  | Default_loop -> ()
  | Always_loop -> fprintf ppf "always_loop@ "
  | Never_loop -> fprintf ppf "never_loop@ "
  end;
  begin match t.poll with
  | Default_poll -> ()
  | Error_poll -> fprintf ppf "error_poll@ "
  end

let apply_tailcall_attribute ppf = function
  | Default_tailcall -> ()
  | Tailcall_expectation true ->
    fprintf ppf " tailcall"
  | Tailcall_expectation false ->
    fprintf ppf " tailcall(false)"

let apply_inlined_attribute ppf = function
  | Default_inlined -> ()
  | Always_inlined -> fprintf ppf " always_inline"
  | Never_inlined -> fprintf ppf " never_inline"
  | Hint_inlined -> fprintf ppf " hint_inline"
  | Unroll i -> fprintf ppf " never_inline(%i)" i

let apply_specialised_attribute ppf = function
  | Default_specialise -> ()
  | Always_specialise -> fprintf ppf " always_specialise"
  | Never_specialise -> fprintf ppf " never_specialise"

let apply_probe ppf : probe -> unit = function
  | None -> ()
  | Some {name} -> fprintf ppf " (probe %s)" name

let apply_kind name pos mode =
  let name =
    match pos with
    | Rc_normal -> name
    | Rc_nontail -> name ^ "nontail"
    | Rc_close_at_apply -> name ^ "tail"
  in
  name ^ locality_kind mode

let debug_uid ppf duid =
  if !Clflags.dump_debug_uids then
    fprintf ppf "%@{%a}" Shape.Uid.print duid

let rec struct_const ppf = function
  | Const_base(Const_int n) -> fprintf ppf "%i" n
  | Const_base(Const_char c) -> fprintf ppf "%C" c
  | Const_base(Const_string (s, _, _)) -> fprintf ppf "%S" s
  | Const_immstring s -> fprintf ppf "#%S" s
  | Const_base(Const_float f) -> fprintf ppf "%s" f
  | Const_base(Const_float32 f) -> fprintf ppf "%ss" f
  | Const_base(Const_unboxed_float f) ->
      fprintf ppf "%s" (Misc.format_as_unboxed_literal f)
  | Const_base(Const_unboxed_float32 f) ->
      fprintf ppf "%ss" (Misc.format_as_unboxed_literal f)
  | Const_base(Const_int32 n) -> fprintf ppf "%lil" n
  | Const_base(Const_int64 n) -> fprintf ppf "%LiL" n
  | Const_base(Const_nativeint n) -> fprintf ppf "%nin" n
  | Const_base(Const_unboxed_int32 i) ->
      fprintf ppf "%sl" (Misc.format_as_unboxed_literal (Int32.to_string i))
  | Const_base(Const_unboxed_int64 i) ->
      fprintf ppf "%sL" (Misc.format_as_unboxed_literal (Int64.to_string i))
  | Const_base(Const_unboxed_nativeint i) ->
      fprintf ppf "%sn" (Misc.format_as_unboxed_literal (Nativeint.to_string i))
  | Const_block(tag, []) ->
      fprintf ppf "[%i]" tag
  | Const_block(tag, hd::tl) ->
      fprintf ppf "@[<1>[%i:@ @[%a@]]@]" tag struct_consts (hd, tl)
  | Const_mixed_block(_, _, []) -> Misc.fatal_error "empty mixed block"
  | Const_mixed_block(tag, shape, hd::tl) ->
      fprintf ppf "@[<1>[%i mixed:@ (shape@ %a)@ @[%a@]]@]" tag
        (mixed_block_shape (fun _ _ -> ())) shape
        struct_consts (hd, tl)
  | Const_float_block [] ->
      fprintf ppf "[|b |]"
  | Const_float_block (f1 :: fl) ->
      let floats ppf fl =
        List.iter (fun f -> fprintf ppf "@ %s" f) fl in
      fprintf ppf "@[<1>[|b@[%s%a@]|]@]" f1 floats fl
  | Const_float_array [] ->
      fprintf ppf "[| |]"
  | Const_float_array (f1 :: fl) ->
      let floats ppf fl =
        List.iter (fun f -> fprintf ppf "@ %s" f) fl in
      fprintf ppf "@[<1>[|@[%s%a@]|]@]" f1 floats fl
  | Const_null -> fprintf ppf "<null>"

and struct_consts ppf (hd, tl) =
  let sconsts ppf scl =
    List.iter (fun sc -> fprintf ppf "@ %a" struct_const sc) scl
  in
  fprintf ppf "%a%a" struct_const hd sconsts tl

let rec lam ppf = function
  | Lvar id ->
      Ident.print ppf id
  | Lmutvar id ->
      fprintf ppf "*%a" Ident.print id
  | Lconst cst ->
      struct_const ppf cst
  | Lapply ap ->
      let lams ppf largs =
        List.iter (fun l -> fprintf ppf "@ %a" lam l) largs in
      let form = apply_kind "apply" ap.ap_region_close ap.ap_mode in
      fprintf ppf "@[<2>(%s@ %a%a%a%a%a%a)@]" form
        lam ap.ap_func lams ap.ap_args
        apply_tailcall_attribute ap.ap_tailcall
        apply_inlined_attribute ap.ap_inlined
        apply_specialised_attribute ap.ap_specialised
        apply_probe ap.ap_probe
  | Lfunction lfun ->
      lfunction ppf lfun
  | Llet _ | Lmutlet _ as expr ->
      let let_kind = begin function
        | Llet(str,_,_,_,_,_) ->
           begin match str with
             Alias -> "a" | Strict -> "" | StrictOpt -> "o"
           end
        | Lmutlet _ -> "mut"
        | _ -> assert false
        end
      in
      let rec letbody ~sp = function
        | Llet(_, k, id, duid, arg, body)
        | Lmutlet(k, id, duid, arg, body) as l ->
           if sp then fprintf ppf "@ ";
           fprintf ppf "@[<2>%a%a =%s%a@ %a@]"
             Ident.print id debug_uid duid (let_kind l) layout_annotation k lam
             arg;
           letbody ~sp:true body
        | expr -> expr in
      fprintf ppf "@[<2>(let@ @[<hv 1>(";
      let expr = letbody ~sp:false expr in
      fprintf ppf ")@]@ %a)@]" lam expr
  | Lletrec(id_arg_list, body) ->
      let bindings ppf id_arg_list =
        let spc = ref false in
        List.iter
          (fun { id; debug_uid=duid; def } ->
            if !spc then fprintf ppf "@ " else spc := true;
            fprintf ppf "@[<2>%a%a@ %a@]"
              Ident.print id
              debug_uid duid
              lfunction def)
          id_arg_list in
      fprintf ppf
        "@[<2>(letrec@ (@[<hv 1>%a@])@ %a)@]" bindings id_arg_list lam body
  | Lprim(prim, largs, _) ->
      let lams ppf largs =
        List.iter (fun l -> fprintf ppf "@ %a" lam l) largs in
      fprintf ppf "@[<2>(%a%a)@]" primitive prim lams largs
  | Lswitch(larg, sw, _loc, _kind) ->
      let switch ppf sw =
        let spc = ref false in
        List.iter
         (fun (n, l) ->
           if !spc then fprintf ppf "@ " else spc := true;
           fprintf ppf "@[<hv 1>case int %i:@ %a@]" n lam l)
         sw.sw_consts;
        List.iter
          (fun (n, l) ->
            if !spc then fprintf ppf "@ " else spc := true;
            fprintf ppf "@[<hv 1>case tag %i:@ %a@]" n lam l)
          sw.sw_blocks ;
        begin match sw.sw_failaction with
        | None  -> ()
        | Some l ->
            if !spc then fprintf ppf "@ " else spc := true;
            fprintf ppf "@[<hv 1>default:@ %a@]" lam l
        end in
      fprintf ppf
       "@[<1>(%s %a@ @[<v 0>%a@])@]"
       (match sw.sw_failaction with None -> "switch*" | _ -> "switch")
       lam larg switch sw
  | Lstringswitch(arg, cases, default, _, _kind) ->
      let switch ppf cases =
        let spc = ref false in
        List.iter
         (fun (s, l) ->
           if !spc then fprintf ppf "@ " else spc := true;
           fprintf ppf "@[<hv 1>case \"%s\":@ %a@]" (String.escaped s) lam l)
          cases;
        begin match default with
        | Some default ->
            if !spc then fprintf ppf "@ " else spc := true;
            fprintf ppf "@[<hv 1>default:@ %a@]" lam default
        | None -> ()
        end in
      fprintf ppf
       "@[<1>(stringswitch %a@ @[<v 0>%a@])@]" lam arg switch cases
  | Lstaticraise (i, ls)  ->
      let lams ppf largs =
        List.iter (fun l -> fprintf ppf "@ %a" lam l) largs in
      fprintf ppf "@[<2>(exit@ %d%a)@]" i lams ls;
  | Lstaticcatch(lbody, (i, vars), lhandler, r, _kind) ->
      let excl =
        match r with
        | Popped_region -> " exclave"
        | Same_region -> ""
      in
      fprintf ppf "@[<2>(catch@ %a@;<1 -1>with (%d%a)%s@ %a)@]"
        lam lbody i
        (fun ppf vars ->
           List.iter
             (fun (x, duid, k) ->
                fprintf ppf " %a%a%a" Ident.print x debug_uid duid
                  layout_annotation k)
             vars
        )
        vars
        excl lam lhandler
  | Ltrywith(lbody, param, duid, lhandler, _kind) ->
      fprintf ppf "@[<2>(try@ %a@;<1 -1>with %a%a@ %a)@]"
        lam lbody Ident.print param debug_uid duid lam lhandler
  | Lifthenelse(lcond, lif, lelse, _kind) ->
      fprintf ppf "@[<2>(if@ %a@ %a@ %a)@]" lam lcond lam lif lam lelse
  | Lsequence(l1, l2) ->
      fprintf ppf "@[<2>(seq@ %a@ %a)@]" lam l1 sequence l2
  | Lwhile {wh_cond; wh_body} ->
      fprintf ppf "@[<2>(while@ %a@ %a)@]"
        lam wh_cond lam wh_body
  | Lfor {for_id; for_debug_uid; for_loc = _;
          for_from; for_to; for_dir; for_body} ->
      fprintf ppf "@[<2>(for %a%a@ %a@ %s@ %a@ %a)@]"
       Ident.print for_id debug_uid for_debug_uid lam for_from
       (match for_dir with Upto -> "to" | Downto -> "downto")
       lam for_to lam for_body
  | Lassign(id, expr) ->
      fprintf ppf "@[<2>(assign@ %a@ %a)@]" Ident.print id lam expr
  | Lsend (k, met, obj, largs, pos, reg, _, _) ->
      let args ppf largs =
        List.iter (fun l -> fprintf ppf "@ %a" lam l) largs in
      let kind =
        if k = Self then "self" else if k = Cached then "cache" else "" in
      let form = apply_kind "send" pos reg in
      fprintf ppf "@[<2>(%s%s@ %a@ %a%a)@]" form kind lam obj lam met args largs
  | Levent(expr, ev) ->
      let kind =
       match ev.lev_kind with
       | Lev_before -> "before"
       | Lev_after _  -> "after"
       | Lev_function -> "funct-body"
       | Lev_pseudo -> "pseudo"
      in
      (* -dno-locations also hides the placement of debug events;
         this is good for the readability of the resulting output (usually
         the end-user goal when using -dno-locations), as it strongly
         reduces the nesting level of subterms. *)
      if not !Clflags.locations then lam ppf expr
      else begin match ev.lev_loc with
      | Loc_unknown ->
        fprintf ppf "@[<2>(%s <unknown location>@ %a)@]" kind lam expr
      | Loc_known {scopes; loc} ->
        fprintf ppf "@[<2>(%s %s %s(%i)%s:%i-%i@ %a)@]" kind
                (Debuginfo.Scoped_location.string_of_scopes
                   ~include_zero_alloc:true scopes)
                loc.Location.loc_start.Lexing.pos_fname
                loc.Location.loc_start.Lexing.pos_lnum
                (if loc.Location.loc_ghost then "<ghost>" else "")
                loc.Location.loc_start.Lexing.pos_cnum
                loc.Location.loc_end.Lexing.pos_cnum
                lam expr
      end
  | Lifused(id, expr) ->
      fprintf ppf "@[<2>(ifused@ %a@ %a)@]" Ident.print id lam expr
  | Lregion (expr, _) ->
      fprintf ppf "@[<2>(region@ %a)@]" lam expr
  | Lexclave expr ->
      fprintf ppf "@[<2>(exclave@ %a)@]" lam expr

and sequence ppf = function
  | Lsequence(l1, l2) ->
      fprintf ppf "%a@ %a" sequence l1 sequence l2
  | l ->
      lam ppf l

and lfunction ppf {kind; params; return; body; attr; ret_mode; mode} =
  let pr_params ppf params =
    match kind with
    | Curried {nlocal} ->
        fprintf ppf "@ {nlocal = %d}" nlocal;
        List.iter (fun (p : Lambda.lparam) ->
            let { unbox_param } = p.attributes in
            fprintf ppf "@ %a%a%s%a%s"
              Ident.print p.name debug_uid p.debug_uid (locality_kind p.mode)
              layout_annotation p.layout
              (if unbox_param then "[@unboxable]" else "")
          ) params
    | Tupled ->
        fprintf ppf " (";
        let first = ref true in
        List.iter
          (fun (p : Lambda.lparam) ->
             let { unbox_param } = p.attributes in
             if !first then first := false else fprintf ppf ",@ ";
             Ident.print ppf p.name;
             debug_uid ppf p.debug_uid;
             Format.fprintf ppf "%s" (locality_kind p.mode);
             layout_annotation ppf p.layout;
             if unbox_param then Format.fprintf ppf "[@unboxable]"
          )
          params;
        fprintf ppf ")" in
  fprintf ppf "@[<2>(function%s%a@ %a%a%a)@]"
    (locality_kind mode) pr_params params
    function_attribute attr return_kind (ret_mode, return) lam body


let structured_constant = struct_const

let lambda = lam

let program ppf { code } = lambda ppf code
