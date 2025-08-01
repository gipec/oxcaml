(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Pierre Weis && Damien Doligez, INRIA Rocquencourt          *)
(*                                                                        *)
(*   Copyright 1998 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Warning definitions

  {b Warning:} this module is unstable and part of
  {{!Compiler_libs}compiler-libs}.

*)

type loc = {
  loc_start: Lexing.position;
  loc_end: Lexing.position;
  loc_ghost: bool;
}

val ghost_loc_in_file : string -> loc
(** Return an empty ghost range located in a given file *)

type field_usage_warning =
  | Unused
  | Not_read
  | Not_mutated

type constructor_usage_warning =
  | Unused
  | Not_constructed
  | Only_exported_private

type upstream_compat_warning =
  | Immediate_erasure of string
  | Non_value_sort of string
  | Unboxed_attribute of string
  | Immediate_void_variant

type name_out_of_scope_warning =
  | Name of string
  | Fields of { record_form : string ; fields : string list }

type t =
  | Comment_start                           (*  1 *)
  | Comment_not_end                         (*  2 *)
(*| Deprecated --> alert "deprecated" *)    (*  3 *)
  | Fragile_match of string                 (*  4 *)
  | Ignored_partial_application             (*  5 *)
  | Labels_omitted of string list           (*  6 *)
  | Method_override of string list          (*  7 *)
  | Partial_match of string                 (*  8 *)
  | Missing_record_field_pattern of { form : string ; unbound : string } (* 9 *)
  | Non_unit_statement                      (* 10 *)
  | Redundant_case                          (* 11 *)
  | Redundant_subpat                        (* 12 *)
  | Instance_variable_override of string list (* 13 *)
  | Illegal_backslash                       (* 14 *)
  | Implicit_public_methods of string list  (* 15 *)
  | Unerasable_optional_argument            (* 16 *)
  | Undeclared_virtual_method of string     (* 17 *)
  | Not_principal of string                 (* 18 *)
  | Non_principal_labels of string          (* 19 *)
  | Ignored_extra_argument                  (* 20 *)
  | Nonreturning_statement                  (* 21 *)
  | Preprocessor of string                  (* 22 *)
  | Useless_record_with of string           (* 23 *)
  | Bad_module_name of string               (* 24 *)
  | All_clauses_guarded                     (* 8, used to be 25 *)
  | Unused_var of { name : string ; mutated : bool } (* 26
    [mutated] is set if the variable was mutated ([x <- 5]), allowing for a
    more helpful error message. *)
  | Unused_var_strict of { name : string ; mutated : bool } (* 27 *)
  | Wildcard_arg_to_constant_constr         (* 28 *)
  | Eol_in_string                           (* 29
      Note: since OCaml 5.2, the lexer normalizes \r\n sequences in
      the source file to a single \n character, so the behavior of
      newlines in string literals is portable. This warning is
      never emitted anymore. *)
  | Duplicate_definitions of string * string * string * string (* 30 *)
  | Unused_value_declaration of string      (* 32 *)
  | Unused_open of string                   (* 33 *)
  | Unused_type_declaration of string       (* 34 *)
  | Unused_for_index of string              (* 35 *)
  | Unused_ancestor of string               (* 36 *)
  | Unused_constructor of string * constructor_usage_warning (* 37 *)
  | Unused_extension of string * bool * constructor_usage_warning (* 38 *)
  | Unused_rec_flag                         (* 39 *)
  | Name_out_of_scope of string * name_out_of_scope_warning (* 40
      Tuple of (the type name, the name/fields out of scope) *)
  | Ambiguous_name of string list * string list * bool * string (* 41 *)
  | Disambiguated_name of string            (* 42 *)
  | Nonoptional_label of string             (* 43 *)
  | Open_shadow_identifier of string * string (* 44 *)
  | Open_shadow_label_constructor of string * string (* 45 *)
  | Bad_env_variable of string * string     (* 46 *)
  | Attribute_payload of string * string    (* 47 *)
  | Eliminated_optional_arguments of string list (* 48 *)
  | No_cmi_file of string * string option   (* 49 *)
  | Unexpected_docstring of bool            (* 50 *)
  | Wrong_tailcall_expectation of bool      (* 51 *)
  | Fragile_literal_pattern                 (* 52 *)
  | Misplaced_attribute of string           (* 53 *)
  | Duplicated_attribute of string          (* 54 *)
  | Inlining_impossible of string           (* 55 *)
  | Unreachable_case                        (* 56 *)
  | Ambiguous_var_in_pattern_guard of string list (* 57 *)
  | No_cmx_file of string                   (* 58 *)
  | Flambda_assignment_to_non_mutable_value (* 59 *)
  | Unused_module of string                 (* 60 *)
  | Unboxable_type_in_prim_decl of string   (* 61 *)
  | Constraint_on_gadt                      (* 62 *)
  | Erroneous_printed_signature of string   (* 63 *)
  | Unsafe_array_syntax_without_parsing     (* 64 *)
  | Redefining_unit of string               (* 65 *)
  | Unused_open_bang of string              (* 66 *)
  | Unused_functor_parameter of string      (* 67 *)
  | Match_on_mutable_state_prevent_uncurry  (* 68 *)
  | Unused_field of
      { form : string; field : string; complaint : field_usage_warning }(* 69 *)
  | Missing_mli                             (* 70 *)
  | Unused_tmc_attribute                    (* 71 *)
  | Tmc_breaks_tailcall                     (* 72 *)
  | Generative_application_expects_unit     (* 73 *)
(* Oxcaml specific warnings: numbers should go down from 199 *)
  | Unmutated_mutable of string             (* 186 *)
  | Incompatible_with_upstream of upstream_compat_warning (* 187 *)
  | Unerasable_position_argument            (* 188 *)
  | Unnecessarily_partial_tuple_pattern     (* 189 *)
  | Probe_name_too_long of string           (* 190 *)
  | Zero_alloc_all_hidden_arrow of string   (* 198 *)
  | Unchecked_zero_alloc_attribute          (* 199 *)
  | Unboxing_impossible                     (* 210 *)
  | Mod_by_top of string                    (* 211 *)
  | Modal_axis_specified_twice of {
      axis : string;
      overriden_by : string;
    }                                       (* 213 *)

type alert = {kind:string; message:string; def:loc; use:loc}

val parse_options : bool -> string -> alert option

val parse_alert_option: string -> unit
  (** Disable/enable alerts based on the parameter to the -alert
      command-line option.  Raises [Arg.Bad] if the string is not a
      valid specification.
  *)

val without_warnings : (unit -> 'a) -> 'a
  (** Run the thunk with all warnings and alerts disabled. *)

val is_active : t -> bool
val is_error : t -> bool

val defaults_w : string
val defaults_warn_error : string

type reporting_information =
  { id : string
  ; message : string
  ; is_error : bool
  ; sub_locs : (loc * string) list;
  }

val report : t -> [ `Active of reporting_information | `Inactive ]
val report_alert : alert -> [ `Active of reporting_information | `Inactive ]

exception Errors

val check_fatal : unit -> unit
val reset_fatal: unit -> unit

val help_warnings: unit -> unit

type state
val backup: unit -> state
val restore: state -> unit
val with_state : state -> (unit -> 'a) -> 'a
val mk_lazy: (unit -> 'a) -> 'a Lazy.t
    (** Like [Lazy.of_fun], but the function is applied with
        the warning/alert settings at the time [mk_lazy] is called. *)

type description =
  { number : int;
    names : string list;
    description : string;
    since : Sys.ocaml_release_info option; }

val descriptions : description list

val parsed_ocamlparam : string ref
