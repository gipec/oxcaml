(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*               Richard Eisenberg, Jane Street, New York                 *)
(*                                                                        *)
(*   Copyright 2024 Jane Street Group LLC                                 *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* This module contains definitions that we do not otherwise need to repeat
   between the various Jkind modules. See comment in jkind_types.mli. *)
module type Sort = sig
  (** A sort classifies how a type is represented at runtime. Every concrete
      jkind has a sort, and knowing the sort is sufficient for knowing the
      calling convention of values of a given type. *)
  type t

  (** These are the constant sorts -- fully determined and without variables *)
  type base =
    | Void  (** No run time representation at all *)
    | Value  (** Standard ocaml value representation *)
    | Float64  (** Unboxed 64-bit floats *)
    | Float32  (** Unboxed 32-bit floats *)
    | Word  (** Unboxed native-size integers *)
    | Bits8  (** Unboxed 8-bit integers *)
    | Bits16  (** Unboxed 16-bit integers *)
    | Bits32  (** Unboxed 32-bit integers *)
    | Bits64  (** Unboxed 64-bit integers *)
    | Vec128  (** Unboxed 128-bit simd vectors *)
    | Vec256  (** Unboxed 256-bit simd vectors *)
    | Vec512  (** Unboxed 512-bit simd vectors *)

  (** A sort variable that can be unified during type-checking. *)
  type var

  module Const : sig
    type t =
      | Base of base
      | Product of t list

    val equal : t -> t -> bool

    val format : Format.formatter -> t -> unit

    val all_void : t -> bool

    val value : t

    val void : t

    val float64 : t

    val float32 : t

    val word : t

    val bits8 : t

    val bits16 : t

    val bits32 : t

    val bits64 : t

    val vec128 : t

    val vec256 : t

    val vec512 : t

    module Debug_printers : sig
      val t : Format.formatter -> t -> unit
    end

    (* CR layouts: These are sorts for the types of ocaml expressions that are
       currently required to be values, but for which we expect to relax that
       restriction in versions 2 and beyond.  Naming them makes it easy to find
       where in the translation to lambda they are assume to be value. *)
    (* CR layouts: add similarly named jkinds and use those names everywhere (not
       just the translation to lambda) rather than writing specific jkinds and
       sorts in the code. *)
    val for_class_arg : t

    val for_instance_var : t

    val for_lazy_body : t

    val for_tuple_element : t

    val for_variant_arg : t

    val for_boxed_record : t

    val for_block_element : t

    val for_array_get_result : t

    val for_array_comprehension_element : t

    val for_list_element : t

    (** These are sorts for the types of ocaml expressions that we expect will
        always be "value".  These names are used in the translation to lambda to
        make the code clearer. *)
    val for_function : t

    val for_probe_body : t

    val for_poly_variant : t

    val for_object : t

    val for_initializer : t

    val for_method : t

    val for_module : t

    val for_predef_value : t (* Predefined value types, e.g. int and string *)

    val for_tuple : t
  end

  module Var : sig
    type id = private int
    (* the [private int] allows the debugger to print it *)

    (** Extract the unique id for a [var]; this should be used only
        for debugging or printing, not for decision making *)
    val get_id : var -> id

    (** Get the number of an [id], useful for printing. These numbers
        get allocated only when an [id] gets printed, and so they are
        less brittle than just printing the [id] itself. *)
    val get_print_number : id -> int

    (** These names are generated lazily and only when this function is called,
      and are not guaranteed to be efficient to create *)
    val name : var -> string
  end

  val void : t

  val value : t

  val float64 : t

  val float32 : t

  val word : t

  val bits32 : t

  val bits64 : t

  (** Create a new sort variable that can be unified. *)
  val new_var : unit -> t

  val of_base : base -> t

  val of_const : Const.t -> t

  val of_var : var -> t

  (** This checks for equality, and sets any variables to make two sorts
      equal, if possible *)
  val equate : t -> t -> bool

  val format : Format.formatter -> t -> unit

  (** Checks whether this sort is [void], defaulting to [value] if a sort
      variable is unfilled. *)
  val is_void_defaulting : t -> bool

  (** [default_to_value_and_get] extracts the sort as a `const`.  If it's a variable,
      it is set to [value] first. *)
  val default_to_value_and_get : t -> Const.t

  (* CR layouts v12: Default this to void. *)

  (** [default_for_transl_and_get] extracts the sort as a `const`.  If it's a variable,
      it is set to [value] first. After we have support for [void], this will default to
      [void] instead. *)
  val default_for_transl_and_get : t -> Const.t

  (** To record changes to sorts, for use with `Types.{snapshot, backtrack}` *)
  type change

  val undo_change : change -> unit

  module Debug_printers : sig
    val base : Format.formatter -> base -> unit

    val t : Format.formatter -> t -> unit

    val var : Format.formatter -> var -> unit
  end
end

module History = struct
  (* For sort variables that are topmost on the jkind lattice. *)
  type concrete_creation_reason =
    | Match
    | Constructor_declaration of int
    | Label_declaration of Ident.t
    | Record_projection
    | Record_assignment
    | Record_functional_update
    | Let_binding
    | Function_argument
    | Function_result
    | Structure_item_expression
    | External_argument
    | External_result
    | Statement
    | Optional_arg_default
    | Layout_poly_in_external
    | Unboxed_tuple_element
    | Peek_or_poke
    | Mutable_var_assignment
    | Old_style_unboxed_type

  (* For sort variables that are in the "legacy" position
     on the jkind lattice, defaulting exactly to [value]. *)
  (* CR layouts v3: after implementing separability, [Array_element]
     should instead accept representable separable jkinds. *)
  type concrete_legacy_creation_reason =
    | Unannotated_type_parameter of Path.t
    | Wildcard
    | Unification_var
    | Array_element

  open Allowance

  type 'd annotation_context =
    | Type_declaration : Path.t -> (allowed * 'r) annotation_context
    | Type_parameter :
        Path.t * string option
        -> (allowed * allowed) annotation_context
    | Newtype_declaration : string -> (allowed * allowed) annotation_context
    | Constructor_type_parameter :
        Path.t * string
        -> (allowed * allowed) annotation_context
    | Existential_unpack : string -> (allowed * allowed) annotation_context
    | Univar : string -> (allowed * allowed) annotation_context
    | Type_variable : string -> (allowed * allowed) annotation_context
    | Type_wildcard : Location.t -> (allowed * allowed) annotation_context
    | Type_of_kind : Location.t -> (allowed * allowed) annotation_context
    | With_error_message :
        string * 'd annotation_context
        -> 'd annotation_context

  and annotation_context_l = (allowed * disallowed) annotation_context

  and annotation_context_r = (disallowed * allowed) annotation_context

  and annotation_context_lr = (allowed * allowed) annotation_context

  (* CR layouts v3: move some [value_creation_reason]s
     related to objects here. *)
  type value_or_null_creation_reason =
    | Primitive of Ident.t
    | Tuple_element
    | Separability_check
    | Polymorphic_variant_field
    | Structure_element
    | V1_safety_check
    | Probe
    | Captured_in_object
    | Let_rec_variable of Ident.t
    | Type_argument of
        { parent_path : Path.t;
          position : int;
          arity : int
        }

  type value_creation_reason =
    | Class_let_binding
    | Object
    | Instance_variable
    | Object_field
    | Class_field
    | Boxed_record
    | Boxed_variant
    | Extensible_variant
    | Primitive of Ident.t
    | Type_argument of
        { parent_path : Path.t;
          position : int;
          arity : int
        }
    (* [position] is 1-indexed *)
    | Tuple
    | Row_variable
    | Polymorphic_variant
    | Arrow
    | Tfield
    | Tnil
    | First_class_module
    | Univar
    | Default_type_jkind
    | Existential_type_variable
    | Array_comprehension_element
    | List_comprehension_iterator_element
    | Array_comprehension_iterator_element
    | Lazy_expression
    | Class_type_argument
    | Class_term_argument
    | Debug_printer_argument
    | Recmod_fun_arg
    | Array_type_kind
    | Unknown of string (* CR layouts: get rid of these *)

  type immediate_creation_reason =
    | Empty_record
    | Enumeration
    | Primitive of Ident.t
    | Immediate_polymorphic_variant

  type immediate_or_null_creation_reason = Primitive of Ident.t

  (* CR layouts v5: make new void_creation_reasons *)
  type void_creation_reason = |

  type any_creation_reason =
    | Missing_cmi of Path.t
    | Initial_typedecl_env
    | Dummy_jkind
      (* This is used when the jkind is about to get overwritten;
         key example: when creating a fresh tyvar that is immediately
         unified to correct levels *)
    | Type_expression_call
    | Inside_of_Tarrow
    | Wildcard
    | Unification_var
    | Array_type_argument

  type product_creation_reason =
    | Unboxed_tuple
    | Unboxed_record

  type creation_reason =
    | Annotated : ('l * 'r) annotation_context * Location.t -> creation_reason
    | Missing_cmi of Path.t
    | Value_or_null_creation of value_or_null_creation_reason
    | Value_creation of value_creation_reason
    | Immediate_creation of immediate_creation_reason
    | Immediate_or_null_creation of immediate_or_null_creation_reason
    | Void_creation of void_creation_reason
    | Any_creation of any_creation_reason
    | Product_creation of product_creation_reason
    | Concrete_creation of concrete_creation_reason
    | Concrete_legacy_creation of concrete_legacy_creation_reason
    | Primitive of Ident.t
    | Unboxed_primitive of Ident.t
    | Imported
    | Imported_type_argument of
        { parent_path : Path.t;
          position : int;
          arity : int
        }
    (* [position] is 1-indexed *)
    | Generalized of Ident.t option * Location.t
    (* See commentary on [Jkind.for_abbreviation] *)
    | Abbreviation

  type interact_reason =
    | Gadt_equation of Path.t
    | Tyvar_refinement_intersection
    (* CR layouts: this needs to carry a type_expr, but that's loopy *)
    | Subjkind
end
