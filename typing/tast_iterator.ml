(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                          Isaac "Izzy" Avram                            *)
(*                                                                        *)
(*   Copyright 2019 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Asttypes
open Typedtree

type iterator =
  {
    attribute: iterator -> attribute -> unit;
    attributes: iterator -> attributes -> unit;
    binding_op: iterator -> binding_op -> unit;
    case: 'k . iterator -> 'k case -> unit;
    class_declaration: iterator -> class_declaration -> unit;
    class_description: iterator -> class_description -> unit;
    class_expr: iterator -> class_expr -> unit;
    class_field: iterator -> class_field -> unit;
    class_signature: iterator -> class_signature -> unit;
    class_structure: iterator -> class_structure -> unit;
    class_type: iterator -> class_type -> unit;
    class_type_declaration: iterator -> class_type_declaration -> unit;
    class_type_field: iterator -> class_type_field -> unit;
    env: iterator -> Env.t -> unit;
    expr: iterator -> expression -> unit;
    extension_constructor: iterator -> extension_constructor -> unit;
    jkind_annotation: iterator -> Parsetree.jkind_annotation -> unit;
    location: iterator -> Location.t -> unit;
    module_binding: iterator -> module_binding -> unit;
    module_coercion: iterator -> module_coercion -> unit;
    module_declaration: iterator -> module_declaration -> unit;
    module_substitution: iterator -> module_substitution -> unit;
    module_expr: iterator -> module_expr -> unit;
    module_type: iterator -> module_type -> unit;
    module_type_declaration: iterator -> module_type_declaration -> unit;
    package_type: iterator -> package_type -> unit;
    pat: 'k . iterator -> 'k general_pattern -> unit;
    row_field: iterator -> row_field -> unit;
    object_field: iterator -> object_field -> unit;
    open_declaration: iterator -> open_declaration -> unit;
    open_description: iterator -> open_description -> unit;
    signature: iterator -> signature -> unit;
    signature_item: iterator -> signature_item -> unit;
    structure: iterator -> structure -> unit;
    structure_item: iterator -> structure_item -> unit;
    typ: iterator -> core_type -> unit;
    type_declaration: iterator -> type_declaration -> unit;
    type_declarations: iterator -> (rec_flag * type_declaration list) -> unit;
    type_extension: iterator -> type_extension -> unit;
    type_exception: iterator -> type_exception -> unit;
    type_kind: iterator -> type_kind -> unit;
    value_binding: iterator -> value_binding -> unit;
    value_bindings: iterator -> (rec_flag * value_binding list) -> unit;
    value_description: iterator -> value_description -> unit;
    with_constraint: iterator -> with_constraint -> unit;
    item_declaration: iterator -> item_declaration -> unit;
  }

let iter_snd f (_, y) = f y
let iter_loc sub {loc; _} = sub.location sub loc

let location _sub _l = ()

let attribute sub x =
  let iterator = {
    Ast_iterator.default_iterator
    with location = fun _this x -> sub.location sub x
  } in
  iter_loc sub x.Parsetree.attr_name;
  iterator.payload iterator x.Parsetree.attr_payload;
  sub.location sub x.Parsetree.attr_loc

let attributes sub l = List.iter (attribute sub) l

let structure sub {str_items; str_final_env; _} =
  List.iter (sub.structure_item sub) str_items;
  sub.env sub str_final_env

let class_infos sub f x =
  sub.location sub x.ci_loc;
  sub.attributes sub x.ci_attributes;
  iter_loc sub x.ci_id_name;
  List.iter (fun (ct, _) -> sub.typ sub ct) x.ci_params;
  f x.ci_expr

let module_type_declaration sub x =
  sub.item_declaration sub (Module_type x);
  sub.location sub x.mtd_loc;
  sub.attributes sub x.mtd_attributes;
  iter_loc sub x.mtd_name;
  Option.iter (sub.module_type sub) x.mtd_type

let module_declaration sub md =
  let {md_loc; md_name; md_type; md_attributes; _} = md in
  sub.item_declaration sub (Module md);
  sub.location sub md_loc;
  sub.attributes sub md_attributes;
  iter_loc sub md_name;
  sub.module_type sub md_type

let module_substitution sub ms =
  let {ms_loc; ms_name; ms_txt; ms_attributes; _} = ms in
  sub.item_declaration sub (Module_substitution ms);
  sub.location sub ms_loc;
  sub.attributes sub ms_attributes;
  iter_loc sub ms_name;
  iter_loc sub ms_txt

let include_kind sub = function
  | Tincl_structure -> ()
  | Tincl_functor ccs ->
      List.iter (fun (_, cc) -> sub.module_coercion sub cc) ccs
  | Tincl_gen_functor ccs ->
      List.iter (fun (_, cc) -> sub.module_coercion sub cc) ccs

let str_include_infos sub {incl_loc; incl_mod; incl_attributes; incl_kind; _} =
  sub.location sub incl_loc;
  sub.attributes sub incl_attributes;
  sub.module_expr sub incl_mod;
  include_kind sub incl_kind

let class_type_declaration sub x =
  sub.item_declaration sub (Class_type x);
  class_infos sub (sub.class_type sub) x

let class_declaration sub x =
  sub.item_declaration sub (Class x);
  class_infos sub (sub.class_expr sub) x

let structure_item sub {str_loc; str_desc; str_env; _} =
  sub.location sub str_loc;
  sub.env sub str_env;
  match str_desc with
  | Tstr_eval   (exp, _, attrs) -> sub.expr sub exp; sub.attributes sub attrs
  | Tstr_value  (rec_flag, list) -> sub.value_bindings sub (rec_flag, list)
  | Tstr_primitive v -> sub.value_description sub v
  | Tstr_type (rec_flag, list) -> sub.type_declarations sub (rec_flag, list)
  | Tstr_typext te -> sub.type_extension sub te
  | Tstr_exception ext -> sub.type_exception sub ext
  | Tstr_module mb -> sub.module_binding sub mb
  | Tstr_recmodule list -> List.iter (sub.module_binding sub) list
  | Tstr_modtype x -> sub.module_type_declaration sub x
  | Tstr_class list ->
      List.iter (fun (cls,_) -> sub.class_declaration sub cls) list
  | Tstr_class_type list ->
      List.iter (fun (_, s, cltd) ->
        iter_loc sub s; sub.class_type_declaration sub cltd) list
  | Tstr_include incl -> str_include_infos sub incl
  | Tstr_open od -> sub.open_declaration sub od
  | Tstr_attribute attr -> sub.attribute sub attr

let value_description sub x =
  sub.item_declaration sub (Value x);
  sub.location sub x.val_loc;
  sub.attributes sub x.val_attributes;
  iter_loc sub x.val_name;
  sub.typ sub x.val_desc

let label_decl sub ({ld_loc; ld_name; ld_type; ld_attributes; ld_modalities = _} as ld) =
  sub.item_declaration sub (Label ld);
  sub.location sub ld_loc;
  sub.attributes sub ld_attributes;
  iter_loc sub ld_name;
  sub.typ sub ld_type

let field_decl sub {ca_loc; ca_type; ca_modalities = _} =
  sub.location sub ca_loc;
  sub.typ sub ca_type

let constructor_args sub = function
  | Cstr_tuple l -> List.iter (field_decl sub) l
  | Cstr_record l -> List.iter (label_decl sub) l

let constructor_decl sub x =
  sub.item_declaration sub (Constructor x);
  sub.location sub x.cd_loc;
  sub.attributes sub x.cd_attributes;
  iter_loc sub x.cd_name;
  constructor_args sub x.cd_args;
  Option.iter (sub.typ sub) x.cd_res

let type_kind sub = function
  | Ttype_abstract -> ()
  | Ttype_variant list -> List.iter (constructor_decl sub) list
  | Ttype_record list -> List.iter (label_decl sub) list
  | Ttype_record_unboxed_product list -> List.iter (label_decl sub) list
  | Ttype_open -> ()

let type_declaration sub x =
  sub.item_declaration sub (Type x);
  sub.location sub x.typ_loc;
  sub.attributes sub x.typ_attributes;
  iter_loc sub x.typ_name;
  List.iter
    (fun (c1, c2, loc) ->
      sub.typ sub c1;
      sub.typ sub c2;
      sub.location sub loc)
    x.typ_cstrs;
  sub.type_kind sub x.typ_kind;
  Option.iter (sub.typ sub) x.typ_manifest;
  List.iter (fun (c, _) -> sub.typ sub c) x.typ_params

let type_declarations sub (_, list) = List.iter (sub.type_declaration sub) list

let type_extension sub x =
  sub.location sub x.tyext_loc;
  sub.attributes sub x.tyext_attributes;
  iter_loc sub x.tyext_txt;
  List.iter (fun (c, _) -> sub.typ sub c) x.tyext_params;
  List.iter (sub.extension_constructor sub) x.tyext_constructors

let type_exception sub {tyexn_loc; tyexn_constructor; tyexn_attributes; _} =
  sub.location sub tyexn_loc;
  sub.attributes sub tyexn_attributes;
  sub.extension_constructor sub tyexn_constructor

let extension_constructor sub ec =
  let {ext_loc; ext_name; ext_kind; ext_attributes; _} = ec in
  sub.item_declaration sub (Extension_constructor ec);
  sub.location sub ext_loc;
  sub.attributes sub ext_attributes;
  iter_loc sub ext_name;
  match ext_kind with
  | Text_decl (_, ctl, cto) ->
      constructor_args sub ctl;
      Option.iter (sub.typ sub) cto
  | Text_rebind (_, lid) -> iter_loc sub lid

let pat_extra sub (e, loc, attrs) =
  sub.location sub loc;
  sub.attributes sub attrs;
  match e with
  | Tpat_type (_, lid) -> iter_loc sub lid
  | Tpat_unpack -> ()
  | Tpat_open (_, lid, env) -> iter_loc sub lid; sub.env sub env
  | Tpat_constraint ct -> sub.typ sub ct

let pat
  : type k . iterator -> k general_pattern -> unit
  = fun sub {pat_loc; pat_extra=extra; pat_desc; pat_env; pat_attributes; _} ->
  sub.location sub pat_loc;
  sub.attributes sub pat_attributes;
  sub.env sub pat_env;
  List.iter (pat_extra sub) extra;
  match pat_desc with
  | Tpat_any  -> ()
  | Tpat_var (_, s, _, _) -> iter_loc sub s
  | Tpat_constant _ -> ()
  | Tpat_tuple l -> List.iter (fun (_, p) -> sub.pat sub p) l
  | Tpat_unboxed_tuple l -> List.iter (fun (_, p, _) -> sub.pat sub p) l
  | Tpat_construct (lid, _, l, vto) ->
      iter_loc sub lid;
      List.iter (sub.pat sub) l;
      Option.iter (fun (vs, ct) ->
        List.iter
          (fun (v, jk) ->
             iter_loc sub v;
             Option.iter (sub.jkind_annotation sub) jk)
          vs;
        sub.typ sub ct) vto
  | Tpat_variant (_, po, _) -> Option.iter (sub.pat sub) po
  | Tpat_record (l, _) ->
      List.iter (fun (lid, _, i) -> iter_loc sub lid; sub.pat sub i) l
  | Tpat_record_unboxed_product (l, _) ->
      List.iter (fun (lid, _, i) -> iter_loc sub lid; sub.pat sub i) l
  | Tpat_array (_, _, l) -> List.iter (sub.pat sub) l
  | Tpat_alias (p, _, s, _, _, _) -> sub.pat sub p; iter_loc sub s
  | Tpat_lazy p -> sub.pat sub p
  | Tpat_value p -> sub.pat sub (p :> pattern)
  | Tpat_exception p -> sub.pat sub p
  | Tpat_or (p1, p2, _) ->
      sub.pat sub p1;
      sub.pat sub p2

let extra sub = function
  | Texp_constraint (cty) -> sub.typ sub cty
  | Texp_coerce (cty1, cty2) ->
      Option.iter (sub.typ sub) cty1;
      sub.typ sub cty2
  | Texp_newtype _ -> ()
  | Texp_poly cto -> Option.iter (sub.typ sub) cto
  | Texp_stack -> ()
  | Texp_mode _ -> ()

let function_param sub { fp_loc; fp_kind; fp_newtypes; _ } =
  sub.location sub fp_loc;
  List.iter
    (fun (_, var, annot, _) ->
       iter_loc sub var;
       Option.iter (sub.jkind_annotation sub) annot)
    fp_newtypes;
  match fp_kind with
  | Tparam_pat pat -> sub.pat sub pat
  | Tparam_optional_default (pat, default_arg, _) ->
      sub.pat sub pat;
      sub.expr sub default_arg

let function_body sub body =
  match[@warning "+9"] body with
  | Tfunction_body body ->
      sub.expr sub body
  | Tfunction_cases
      { fc_cases; fc_exp_extra; fc_loc; fc_attributes; fc_env;
        fc_arg_mode = _; fc_arg_sort = _; fc_ret_type = _;
        fc_partial = _; fc_param = _; fc_param_debug_uid = _;
      } ->
      List.iter (sub.case sub) fc_cases;
      Option.iter (extra sub) fc_exp_extra;
      sub.location sub fc_loc;
      sub.attributes sub fc_attributes;
      sub.env sub fc_env

let expr sub {exp_loc; exp_extra; exp_desc; exp_env; exp_attributes; _} =
  let extra x = extra sub x in
  sub.location sub exp_loc;
  sub.attributes sub exp_attributes;
  List.iter (fun (e, loc, _) -> extra e; sub.location sub loc) exp_extra;
  sub.env sub exp_env;
  let iter_fields fields =
    Array.iter (function
      | _, Kept _ -> ()
      | _, Overridden (lid, exp) -> iter_loc sub lid; sub.expr sub exp)
      fields
  in
  match exp_desc with
  | Texp_ident (_, lid, _, _, _)  -> iter_loc sub lid
  | Texp_constant _ -> ()
  | Texp_let (rec_flag, list, exp) ->
      sub.value_bindings sub (rec_flag, list);
      sub.expr sub exp
  | Texp_letmutable (vb, exp) ->
      sub.value_binding sub vb;
      sub.expr sub exp
  | Texp_function { params; body; _ } ->
      List.iter (function_param sub) params;
      function_body sub body
  | Texp_apply (exp, list, _, _, _) ->
      sub.expr sub exp;
      List.iter (function
        | (_, Arg (exp, _)) -> sub.expr sub exp
        | (_, Omitted _) -> ())
        list
  | Texp_match (exp, _, cases, _) ->
      sub.expr sub exp;
      List.iter (sub.case sub) cases
  | Texp_try (exp, cases) ->
      sub.expr sub exp;
      List.iter (sub.case sub) cases
  | Texp_tuple (list, _) -> List.iter (fun (_,e) -> sub.expr sub e) list
  | Texp_unboxed_tuple list -> List.iter (fun (_,e,_) -> sub.expr sub e) list
  | Texp_construct (lid, _, args, _) ->
      iter_loc sub lid;
      List.iter (sub.expr sub) args
  | Texp_variant (_, expo) ->
      Option.iter (fun (expr, _) -> sub.expr sub expr) expo
  | Texp_record { fields; extended_expression; _} ->
      iter_fields fields;
      Option.iter (fun (exp, _, _) -> sub.expr sub exp) extended_expression;
  | Texp_record_unboxed_product { fields; extended_expression; _} ->
      iter_fields fields;
      Option.iter (fun (exp, _) -> sub.expr sub exp) extended_expression;
  | Texp_field (exp, _, lid, _, _, _) ->
      iter_loc sub lid;
      sub.expr sub exp
  | Texp_unboxed_field (exp, _, lid, _, _) ->
      iter_loc sub lid;
      sub.expr sub exp
  | Texp_setfield (exp1, _, lid, _, exp2) ->
      iter_loc sub lid;
      sub.expr sub exp1;
      sub.expr sub exp2
  | Texp_array (_, _, list, _) -> List.iter (sub.expr sub) list
  | Texp_list_comprehension { comp_body; comp_clauses }
  | Texp_array_comprehension (_, _, { comp_body; comp_clauses }) ->
      sub.expr sub comp_body;
      List.iter
        (function
          | Texp_comp_for bindings ->
              List.iter
                (fun { comp_cb_iterator; comp_cb_attributes } ->
                   sub.attributes sub comp_cb_attributes;
                   match comp_cb_iterator with
                   | Texp_comp_range { ident = _; start; stop; direction = _ } ->
                       sub.expr sub start;
                       sub.expr sub stop
                   | Texp_comp_in { pattern; sequence } ->
                       sub.pat sub pattern;
                       sub.expr sub sequence)
                bindings
          | Texp_comp_when exp ->
            sub.expr sub exp)
        comp_clauses
  | Texp_ifthenelse (exp1, exp2, expo) ->
      sub.expr sub exp1;
      sub.expr sub exp2;
      Option.iter (sub.expr sub) expo
  | Texp_sequence (exp1, _, exp2) ->
      sub.expr sub exp1;
      sub.expr sub exp2
  | Texp_while { wh_cond; wh_body } ->
      sub.expr sub wh_cond;
      sub.expr sub wh_body
  | Texp_for {for_from; for_to; for_body} ->
      sub.expr sub for_from;
      sub.expr sub for_to;
      sub.expr sub for_body
  | Texp_send (exp, _, _) ->
      sub.expr sub exp
  | Texp_new (_, lid, _, _) -> iter_loc sub lid
  | Texp_instvar (_, _, s) -> iter_loc sub s
  | Texp_mutvar id -> iter_loc sub id
  | Texp_setinstvar (_, _, s, exp) ->
      iter_loc sub s;
      sub.expr sub exp
  | Texp_setmutvar (id, _, exp) ->
      iter_loc sub id;
      sub.expr sub exp
  | Texp_override (_, list) ->
      List.iter (fun (_, s, e) -> iter_loc sub s; sub.expr sub e) list
  | Texp_letmodule (_, s, _, mexpr, exp) ->
      iter_loc sub s;
      sub.module_expr sub mexpr;
      sub.expr sub exp
  | Texp_letexception (cd, exp) ->
      sub.extension_constructor sub cd;
      sub.expr sub exp
  | Texp_assert (exp, _) -> sub.expr sub exp
  | Texp_lazy exp -> sub.expr sub exp
  | Texp_object (cl, _) -> sub.class_structure sub cl
  | Texp_pack mexpr -> sub.module_expr sub mexpr
  | Texp_letop {let_ = l; ands; body; _} ->
      sub.binding_op sub l;
      List.iter (sub.binding_op sub) ands;
      sub.case sub body
  | Texp_unreachable -> ()
  | Texp_extension_constructor (lid, _) -> iter_loc sub lid
  | Texp_open (od, e) ->
      sub.open_declaration sub od;
      sub.expr sub e
  | Texp_probe {handler;_} -> sub.expr sub handler
  | Texp_probe_is_enabled _ -> ()
  | Texp_exclave exp -> sub.expr sub exp
  | Texp_src_pos -> ()
  | Texp_overwrite(exp1, exp2) ->
    sub.expr sub exp1;
    sub.expr sub exp2
  | Texp_hole _ -> ()


let package_type sub {pack_fields; pack_txt; _} =
  List.iter (fun (lid, p) -> iter_loc sub lid; sub.typ sub p) pack_fields;
  iter_loc sub pack_txt

let binding_op sub {bop_loc; bop_op_name; bop_exp; _} =
  sub.location sub bop_loc;
  iter_loc sub bop_op_name;
  sub.expr sub bop_exp

let signature sub {sig_items; sig_final_env; _} =
  sub.env sub sig_final_env;
  List.iter (sub.signature_item sub) sig_items

let sig_include_infos sub {incl_loc; incl_mod; incl_attributes; incl_kind; _} =
  sub.location sub incl_loc;
  sub.attributes sub incl_attributes;
  sub.module_type sub incl_mod;
  include_kind sub incl_kind

let signature_item sub {sig_loc; sig_desc; sig_env; _} =
  sub.location sub sig_loc;
  sub.env sub sig_env;
  match sig_desc with
  | Tsig_value v -> sub.value_description sub v
  | Tsig_type (rf, tdl)  -> sub.type_declarations sub (rf, tdl)
  | Tsig_typesubst list -> sub.type_declarations sub (Nonrecursive, list)
  | Tsig_typext te -> sub.type_extension sub te
  | Tsig_exception ext -> sub.type_exception sub ext
  | Tsig_module x -> sub.module_declaration sub x
  | Tsig_modsubst x -> sub.module_substitution sub x
  | Tsig_recmodule list -> List.iter (sub.module_declaration sub) list
  | Tsig_modtype x -> sub.module_type_declaration sub x
  | Tsig_modtypesubst x -> sub.module_type_declaration sub x
  | Tsig_include (incl, _) -> sig_include_infos sub incl
  | Tsig_class list -> List.iter (sub.class_description sub) list
  | Tsig_class_type list -> List.iter (sub.class_type_declaration sub) list
  | Tsig_open od -> sub.open_description sub od
  | Tsig_attribute _ -> ()

let class_description sub x =
  sub.item_declaration sub (Class_type x);
  class_infos sub (sub.class_type sub) x

let functor_parameter sub = function
  | Unit -> ()
  | Named (_, s, mtype) -> iter_loc sub s; sub.module_type sub mtype

let module_type sub {mty_loc; mty_desc; mty_env; mty_attributes; _} =
  sub.location sub mty_loc;
  sub.attributes sub mty_attributes;
  sub.env sub mty_env;
  match mty_desc with
  | Tmty_ident (_, lid) -> iter_loc sub lid
  | Tmty_alias (_, lid) -> iter_loc sub lid
  | Tmty_signature sg -> sub.signature sub sg
  | Tmty_functor (arg, mtype2) ->
      functor_parameter sub arg;
      sub.module_type sub mtype2
  | Tmty_with (mtype, list) ->
      sub.module_type sub mtype;
      List.iter (fun (_, lid, e) ->
        iter_loc sub lid; sub.with_constraint sub e) list
  | Tmty_typeof mexpr -> sub.module_expr sub mexpr
  | Tmty_strengthen (mtype, _, _) -> sub.module_type sub mtype

let with_constraint sub = function
  | Twith_type      decl -> sub.type_declaration sub decl
  | Twith_typesubst decl -> sub.type_declaration sub decl
  | Twith_module    (_, lid) -> iter_loc sub lid
  | Twith_modsubst  (_, lid) -> iter_loc sub lid
  | Twith_modtype      mty -> sub.module_type sub mty
  | Twith_modtypesubst mty -> sub.module_type sub mty


let open_description sub {open_loc; open_expr; open_env; open_attributes; _} =
  sub.location sub open_loc;
  sub.attributes sub open_attributes;
  iter_snd (iter_loc sub) open_expr;
  sub.env sub open_env

let open_declaration sub {open_loc; open_expr; open_env; open_attributes; _} =
  sub.location sub open_loc;
  sub.attributes sub open_attributes;
  sub.module_expr sub open_expr;
  sub.env sub open_env

let module_coercion sub = function
  | Tcoerce_none -> ()
  | Tcoerce_functor (c1,c2) ->
      sub.module_coercion sub c1;
      sub.module_coercion sub c2
  | Tcoerce_alias (env, _, c1) ->
      sub.env sub env;
      sub.module_coercion sub c1
  | Tcoerce_structure (l1, l2) ->
      List.iter (fun (_, c) -> sub.module_coercion sub c) l1;
      List.iter (fun (_, _ ,c) -> sub.module_coercion sub c) l2
  | Tcoerce_primitive {pc_loc; pc_env; _} ->
      sub.location sub pc_loc;
      sub.env sub pc_env

let module_expr sub {mod_loc; mod_desc; mod_env; mod_attributes; _} =
  sub.location sub mod_loc;
  sub.attributes sub mod_attributes;
  sub.env sub mod_env;
  match mod_desc with
  | Tmod_ident (_, lid) -> iter_loc sub lid
  | Tmod_structure st -> sub.structure sub st
  | Tmod_functor (arg, mexpr) ->
      functor_parameter sub arg;
      sub.module_expr sub mexpr
  | Tmod_apply (mexp1, mexp2, c) ->
      sub.module_expr sub mexp1;
      sub.module_expr sub mexp2;
      sub.module_coercion sub c
  | Tmod_apply_unit mexp1 ->
      sub.module_expr sub mexp1;
  | Tmod_constraint (mexpr, _, Tmodtype_implicit, c) ->
      sub.module_expr sub mexpr;
      sub.module_coercion sub c
  | Tmod_constraint (mexpr, _, Tmodtype_explicit mtype, c) ->
      sub.module_expr sub mexpr;
      sub.module_type sub mtype;
      sub.module_coercion sub c
  | Tmod_unpack (exp, _) -> sub.expr sub exp

let module_binding sub ({mb_loc; mb_name; mb_expr; mb_attributes; _} as mb) =
  sub.item_declaration sub (Module_binding mb);
  sub.location sub mb_loc;
  sub.attributes sub mb_attributes;
  iter_loc sub mb_name;
  sub.module_expr sub mb_expr

let class_expr sub {cl_loc; cl_desc; cl_env; cl_attributes; _} =
  sub.location sub cl_loc;
  sub.attributes sub cl_attributes;
  sub.env sub cl_env;
  match cl_desc with
  | Tcl_constraint (cl, clty, _, _, _) ->
      sub.class_expr sub cl;
      Option.iter (sub.class_type sub) clty
  | Tcl_structure clstr -> sub.class_structure sub clstr
  | Tcl_fun (_, pat, priv, cl, _) ->
      sub.pat sub pat;
      List.iter (fun (_, e) -> sub.expr sub e) priv;
      sub.class_expr sub cl
  | Tcl_apply (cl, args) ->
      sub.class_expr sub cl;
      List.iter (function
        | (_, Arg (exp, _)) -> sub.expr sub exp
        | (_, Omitted _) -> ())
        args
  | Tcl_let (rec_flag, value_bindings, ivars, cl) ->
      sub.value_bindings sub (rec_flag, value_bindings);
      List.iter (fun (_, e) -> sub.expr sub e) ivars;
      sub.class_expr sub cl
  | Tcl_ident (_, lid, tyl) ->
      iter_loc sub lid;
      List.iter (sub.typ sub) tyl
  | Tcl_open (od, e) ->
      sub.open_description sub od;
      sub.class_expr sub e

let class_type sub {cltyp_loc; cltyp_desc; cltyp_env; cltyp_attributes; _} =
  sub.location sub cltyp_loc;
  sub.attributes sub cltyp_attributes;
  sub.env sub cltyp_env;
  match cltyp_desc with
  | Tcty_signature csg -> sub.class_signature sub csg
  | Tcty_constr (_, lid, list) ->
      iter_loc sub lid;
      List.iter (sub.typ sub) list
  | Tcty_arrow (_, ct, cl) ->
      sub.typ sub ct;
      sub.class_type sub cl
  | Tcty_open (od, e) ->
      sub.open_description sub od;
      sub.class_type sub e

let class_signature sub {csig_self; csig_fields; _} =
  sub.typ sub csig_self;
  List.iter (sub.class_type_field sub) csig_fields

let class_type_field sub {ctf_loc; ctf_desc; ctf_attributes; _} =
  sub.location sub ctf_loc;
  sub.attributes sub ctf_attributes;
  match ctf_desc with
  | Tctf_inherit ct -> sub.class_type sub ct
  | Tctf_val (_, _, _, ct) ->  sub.typ sub ct
  | Tctf_method (_, _, _, ct) -> sub.typ sub ct
  | Tctf_constraint  (ct1, ct2) ->
      sub.typ sub ct1;
      sub.typ sub ct2
  | Tctf_attribute attr -> sub.attribute sub attr

let typ sub {ctyp_loc; ctyp_desc; ctyp_env; ctyp_attributes; _} =
  sub.location sub ctyp_loc;
  sub.attributes sub ctyp_attributes;
  sub.env sub ctyp_env;
  match ctyp_desc with
  | Ttyp_var (_, jkind) ->
      Option.iter (sub.jkind_annotation sub) jkind
  | Ttyp_arrow (_, ct1, ct2) ->
      sub.typ sub ct1;
      sub.typ sub ct2
  | Ttyp_tuple list -> List.iter (fun (_, t) -> sub.typ sub t) list
  | Ttyp_unboxed_tuple list -> List.iter (fun (_, t) -> sub.typ sub t) list
  | Ttyp_constr (_, lid, list) ->
      iter_loc sub lid;
      List.iter (sub.typ sub) list
  | Ttyp_object (list, _) -> List.iter (sub.object_field sub) list
  | Ttyp_class (_, lid, list) ->
      iter_loc sub lid;
      List.iter (sub.typ sub) list
  | Ttyp_alias (ct, _, jkind) ->
      sub.typ sub ct;
      Option.iter (sub.jkind_annotation sub) jkind
  | Ttyp_variant (list, _, _) -> List.iter (sub.row_field sub) list
  | Ttyp_poly (vars, ct) ->
      List.iter (fun (_, l) -> Option.iter (sub.jkind_annotation sub) l) vars;
      sub.typ sub ct
  | Ttyp_package pack -> sub.package_type sub pack
  | Ttyp_open (_, mod_ident, t) ->
      iter_loc sub mod_ident;
      sub.typ sub t
  | Ttyp_of_kind jkind -> sub.jkind_annotation sub jkind
  | Ttyp_call_pos -> ()

let class_structure sub {cstr_self; cstr_fields; _} =
  sub.pat sub cstr_self;
  List.iter (sub.class_field sub) cstr_fields

let row_field sub {rf_loc; rf_desc; rf_attributes; _} =
  sub.location sub rf_loc;
  sub.attributes sub rf_attributes;
  match rf_desc with
  | Ttag (s, _, list) -> iter_loc sub s; List.iter (sub.typ sub) list
  | Tinherit ct -> sub.typ sub ct

let object_field sub {of_loc; of_desc; of_attributes; _} =
  sub.location sub of_loc;
  sub.attributes sub of_attributes;
  match of_desc with
  | OTtag (s, ct) -> iter_loc sub s; sub.typ sub ct
  | OTinherit ct -> sub.typ sub ct

let class_field_kind sub = function
  | Tcfk_virtual ct -> sub.typ sub ct
  | Tcfk_concrete (_, e) -> sub.expr sub e

let class_field sub {cf_loc; cf_desc; cf_attributes; _} =
  sub.location sub cf_loc;
  sub.attributes sub cf_attributes;
  match cf_desc with
  | Tcf_inherit (_, cl, _, _, _) -> sub.class_expr sub cl
  | Tcf_constraint (cty1, cty2) ->
      sub.typ sub cty1;
      sub.typ sub cty2
  | Tcf_val (s, _, _, k, _) -> iter_loc sub s; class_field_kind sub k
  | Tcf_method (s, _, k) -> iter_loc sub s;class_field_kind sub k
  | Tcf_initializer exp -> sub.expr sub exp
  | Tcf_attribute attr -> sub.attribute sub attr

let value_bindings sub (_, list) = List.iter (sub.value_binding sub) list

let case sub {c_lhs; c_guard; c_rhs} =
  sub.pat sub c_lhs;
  Option.iter (sub.expr sub) c_guard;
  sub.expr sub c_rhs

let value_binding sub ({vb_loc; vb_pat; vb_expr; vb_attributes; _} as vb) =
  sub.item_declaration sub (Value_binding vb);
  sub.location sub vb_loc;
  sub.attributes sub vb_attributes;
  sub.pat sub vb_pat;
  sub.expr sub vb_expr

let env _sub _ = ()

let jkind_annotation sub l =
  (* iterate over locations contained within parsetree jkind annotation *)
  let ast_iterator =
    { Ast_iterator.default_iterator
      with location = (fun _this loc -> sub.location sub loc)
    }
  in
  ast_iterator.jkind_annotation ast_iterator l

let item_declaration _sub _ = ()

let default_iterator =
  {
    attribute;
    attributes;
    binding_op;
    case;
    class_declaration;
    class_description;
    class_expr;
    class_field;
    class_signature;
    class_structure;
    class_type;
    class_type_declaration;
    class_type_field;
    env;
    expr;
    extension_constructor;
    jkind_annotation;
    location;
    module_binding;
    module_coercion;
    module_declaration;
    module_substitution;
    module_expr;
    module_type;
    module_type_declaration;
    package_type;
    pat;
    row_field;
    object_field;
    open_declaration;
    open_description;
    signature;
    signature_item;
    structure;
    structure_item;
    typ;
    type_declaration;
    type_declarations;
    type_extension;
    type_exception;
    type_kind;
    value_binding;
    value_bindings;
    value_description;
    with_constraint;
    item_declaration;
  }
