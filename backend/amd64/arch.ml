(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2000 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)
[@@@ocaml.warning "+a-40-41-42"]

open! Int_replace_polymorphic_compare

module Extension = struct
  module T = struct
    type t =
      | POPCNT
      | PREFETCHW
      | PREFETCHWT1
      | SSE3
      | SSSE3
      | SSE4_1
      | SSE4_2
      | CLMUL
      | LZCNT
      | BMI
      | BMI2
      | AVX
      | AVX2
      | AVX512F

    let rank = function
      | POPCNT -> 0
      | PREFETCHW -> 1
      | PREFETCHWT1 -> 2
      | SSE3 -> 3
      | SSSE3 -> 4
      | SSE4_1 -> 5
      | SSE4_2 -> 6
      | CLMUL -> 7
      | LZCNT -> 8
      | BMI -> 9
      | BMI2 -> 10
      | AVX -> 11
      | AVX2 -> 12
      | AVX512F -> 13

    let compare left right = Int.compare (rank left) (rank right)
  end

  include T
  module Set = Set.Make(T)

  let name = function
    | POPCNT -> "POPCNT"
    | PREFETCHW -> "PREFETCHW"
    | PREFETCHWT1 -> "PREFETCHWT1"
    | SSE3 -> "SSE3"
    | SSSE3 -> "SSSE3"
    | SSE4_1 -> "SSE41"
    | SSE4_2 -> "SSE42"
    | CLMUL -> "CLMUL"
    | LZCNT -> "LZCNT"
    | BMI -> "BMI"
    | BMI2 -> "BMI2"
    | AVX -> "AVX"
    | AVX2 -> "AVX2"
    | AVX512F -> "AVX512F"

  let generation = function
    | POPCNT -> "Nehalem+"
    | PREFETCHW -> "Broadwell+"
    | PREFETCHWT1 -> "Xeon Phi"
    | SSE3 -> "Prescott+"
    | SSSE3 -> "Core+"
    | SSE4_1 -> "Penryn+"
    | SSE4_2 -> "Nehalem+"
    | CLMUL -> "Westmere+"
    | LZCNT -> "Haswell+"
    | BMI -> "Haswell+"
    | BMI2 -> "Haswell+"
    | AVX -> "Sandybridge+"
    | AVX2 -> "Haswell+"
    | AVX512F -> "SkylakeXeon+"

  let enabled_by_default = function
    (* We enable all Haswell extensions by default, unless the compiler
       was configured on a CPU without support. Note SSE/SSE2 cannot be
       disabled as they are included in baseline x86_64. *)
    | POPCNT -> Config.has_popcnt
    | CLMUL -> Config.has_pclmul
    | LZCNT -> false (* Config.has_lzcnt *)
    | SSE3 -> Config.has_sse3
    | SSSE3 -> Config.has_ssse3
    | SSE4_1 -> Config.has_sse4_1
    | SSE4_2 -> Config.has_sse4_2
    | BMI -> false (*Config.has_bmi*)
    | BMI2 -> false (*Config.has_bmi2*)
    | AVX -> Config.has_avx
    | AVX2 -> false (*Config.has_avx2*)
    | PREFETCHW | PREFETCHWT1 | AVX512F -> false

  let all =
    Set.of_list
      [ POPCNT; PREFETCHW; PREFETCHWT1; SSE3; SSSE3; SSE4_1; SSE4_2; CLMUL;
        LZCNT; BMI; BMI2; AVX; AVX2; AVX512F ]

  let directly_implied_by e1 e2 =
    match e1, e2 with
    | SSE3, SSSE3
    | SSSE3, SSE4_1
    | SSE4_1, SSE4_2
    | SSE4_2, AVX
    | AVX, AVX2
    | AVX2, AVX512F
    | BMI, BMI2 -> true
    | (POPCNT | PREFETCHW | PREFETCHWT1 | SSE3 | SSSE3 | SSE4_1
      | SSE4_2 | CLMUL | LZCNT | BMI | BMI2 | AVX | AVX2 | AVX512F), _ -> false

  let rec fix set less =
    let closure =
      Set.filter (fun ext -> Set.exists (less ext) set) all
      |> Set.union set
    in
    if Set.equal closure set then set
    else fix closure less

  let implication ext =
    let set = Set.singleton ext in
    let implies = fix set directly_implied_by in
    let implied_by = fix set (fun e1 e2 -> directly_implied_by e2 e1) in
    implies, implied_by

  let config =
    let default = Set.filter enabled_by_default all in
    ref (fix default directly_implied_by)

  let enabled t = Set.mem t !config
  let disabled t = not (enabled t)

  let args =
    let y t = "-f" ^ (name t |> String.lowercase_ascii) in
    let n t = "-fno-" ^ (name t |> String.lowercase_ascii) in
    Set.fold (fun t acc ->
      let print_default b = if b then " (default)" else "" in
      let yd = print_default (enabled t) in
      let nd = print_default (disabled t) in
      let implies, implied_by = implication t in
      (y t, Arg.Unit (fun () ->
        config := Set.union !config implies),
        Printf.sprintf "Enable %s instructions (%s)%s" (name t) (generation t) yd) ::
      (n t, Arg.Unit (fun () ->
        config := Set.diff !config implied_by),
        Printf.sprintf "Disable %s instructions (%s)%s" (name t) (generation t) nd) :: acc)
    all []

  let available () = Set.fold (fun t acc -> t :: acc) !config []

  let enabled_vec256 () = enabled AVX
  let enabled_vec512 () = enabled AVX512F

  let require_vec256 () =
    if not (enabled AVX) then Misc.fatal_error
      "Using 256-bit registers requires AVX, which is not enabled."

  let require_vec512 () =
    if not (enabled AVX512F) then Misc.fatal_error
      "Using 512-bit registers requires AVX512F, which is not enabled."

  let require_instruction (instr : Amd64_simd_instrs.instr) =
    let enabled : Amd64_simd_defs.ext -> bool = function
      | SSE | SSE2 -> true
      | SSE3 -> enabled SSE3
      | SSSE3 -> enabled SSSE3
      | SSE4_1 -> enabled SSE4_1
      | SSE4_2 -> enabled SSE4_2
      | PCLMULQDQ -> enabled CLMUL
      | BMI2 -> enabled BMI2
      | AVX -> enabled AVX
      | AVX2 -> enabled AVX2
    in
    if not (Array.for_all enabled instr.ext)
    then Misc.fatal_errorf "Emitted %s, which is not enabled." instr.mnemonic
end

(* Emit elf notes with trap handling information. *)
let trap_notes = ref true

(* Emit extension symbols for CPUID startup check  *)
let arch_check_symbols = ref true

let is_asan_enabled = ref Config.with_address_sanitizer

(* Machine-specific command-line options *)

let command_line_options =
  [ "-fPIC", Arg.Set Clflags.pic_code,
      " Generate position-independent machine code (default)";
    "-fno-PIC", Arg.Clear Clflags.pic_code,
      " Generate position-dependent machine code";
    "-ftrap-notes", Arg.Set trap_notes,
      " Emit .note.ocaml_eh section with trap handling information (default)";
    "-fno-trap-notes", Arg.Clear trap_notes,
      " Do not emit .note.ocaml_eh section with trap handling information";
    "-fno-asan",
      Arg.Clear is_asan_enabled,
      " Disable AddressSanitizer. This is only meaningful if the compiler was \
       built with AddressSanitizer support enabled."
  ] @ Extension.args

(* Specific operations for the AMD64 processor *)

open Format

type sym_global = Global | Local

let equal_sym_global left right =
  match left, right with
  | Global, Global
  | Local, Local -> true
  | (Global | Local), _ -> false

type addressing_mode =
    Ibased of string * sym_global * int (* symbol + displ *)
  | Iindexed of int                     (* reg + displ *)
  | Iindexed2 of int                    (* reg + reg + displ *)
  | Iscaled of int * int                (* reg * scale + displ *)
  | Iindexed2scaled of int * int        (* reg + reg * scale + displ *)

type prefetch_temporal_locality_hint = Nonlocal | Low | Moderate | High

type prefetch_info = {
  is_write: bool;
  locality: prefetch_temporal_locality_hint;
  addr: addressing_mode;
}

type bswap_bitwidth = Sixteen | Thirtytwo | Sixtyfour

type float_width = Cmm.float_width

(* Specific operations, including [Simd], must not raise. *)
type specific_operation =
    Ilea of addressing_mode            (* "lea" gives scaled adds *)
  | Istore_int of nativeint * addressing_mode * bool
                                       (* Store an integer constant *)
  | Ioffset_loc of int * addressing_mode
                                       (* Add a constant to a location *)
  | Ifloatarithmem of float_width * float_operation * addressing_mode
                                       (* Float arith operation with memory *)
  | Ibswap of { bitwidth: bswap_bitwidth; } (* endianness conversion *)
  | Isextend32                         (* 32 to 64 bit conversion with sign
                                          extension *)
  | Izextend32                         (* 32 to 64 bit conversion with zero
                                          extension *)
  | Irdtsc                             (* read timestamp *)
  | Irdpmc                             (* read performance counter *)
  | Ilfence                            (* load fence *)
  | Isfence                            (* store fence *)
  | Imfence                            (* memory fence *)
  | Ipackf32                           (* UNPCKLPS on registers; see Cpackf32 *)
  | Isimd of Simd.operation            (* SIMD instruction set operations *)
  | Isimd_mem of Simd.Mem.operation * addressing_mode
                                       (* SIMD instruction set operations
                                          with memory args *)
  | Icldemote of addressing_mode       (* hint to demote a cacheline to L3 *)
  | Iprefetch of                       (* memory prefetching hint *)
      { is_write: bool;
        locality: prefetch_temporal_locality_hint;
        addr: addressing_mode;
      }

and float_operation =
  | Ifloatadd
  | Ifloatsub
  | Ifloatmul
  | Ifloatdiv

(* Sizes, endianness *)

let big_endian = false

let size_addr = 8
let size_int = 8
let size_float = 8

let size_vec128 = 16
let size_vec256 = 32
let size_vec512 = 64

let allow_unaligned_access = true

(* Behavior of division *)

let division_crashes_on_overflow = true

(* Operations on addressing modes *)

let identity_addressing = Iindexed 0

let offset_addressing addr delta =
  match addr with
    Ibased(s, glob, n) -> Ibased(s, glob, n + delta)
  | Iindexed n -> Iindexed(n + delta)
  | Iindexed2 n -> Iindexed2(n + delta)
  | Iscaled(scale, n) -> Iscaled(scale, n + delta)
  | Iindexed2scaled(scale, n) -> Iindexed2scaled(scale, n + delta)

let num_args_addressing = function
    Ibased _ -> 0
  | Iindexed _ -> 1
  | Iindexed2 _ -> 2
  | Iscaled _ -> 1
  | Iindexed2scaled _ -> 2

let addressing_displacement_for_llvmize addr =
  if not !Clflags.llvm_backend
  then
    Misc.fatal_error
      "Arch.displacement_addressing_for_llvmize: should only be called with \
        -llvm-backend"
  else
    match addr with
    | Iindexed d -> d
    | Ibased _
    | Iindexed2 _
    | Iscaled _
    | Iindexed2scaled _ ->
      Misc.fatal_error
        "Arch.displacement_addressing_for_llvmize: unexpected addressing mode"

(* Printing operations and addressing modes *)

let string_of_prefetch_temporal_locality_hint = function
  | Nonlocal -> "nonlocal"
  | Low -> "low"
  | Moderate -> "moderate"
  | High -> "high"

let int_of_bswap_bitwidth = function
  | Sixteen -> 16
  | Thirtytwo -> 32
  | Sixtyfour -> 64

let print_addressing printreg addr ppf arg =
  match addr with
  | Ibased(s, _glob, 0) ->
      fprintf ppf "\"%s\"" s
  | Ibased(s, _glob, n) ->
      fprintf ppf "\"%s\" + %i" s n
  | Iindexed n ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a%s" printreg arg.(0) idx
  | Iindexed2 n ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a + %a%s" printreg arg.(0) printreg arg.(1) idx
  | Iscaled(scale, n) ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a  * %i%s" printreg arg.(0) scale idx
  | Iindexed2scaled(scale, n) ->
      let idx = if n <> 0 then Printf.sprintf " + %i" n else "" in
      fprintf ppf "%a + %a * %i%s" printreg arg.(0) printreg arg.(1) scale idx

let floatartith_name (width : float_width) op =
  match width, op with
  | Float64, Ifloatadd -> "+f"
  | Float64, Ifloatsub -> "-f"
  | Float64, Ifloatmul -> "*f"
  | Float64, Ifloatdiv -> "/f"
  | Float32, Ifloatadd -> "+f32"
  | Float32, Ifloatsub -> "-f32"
  | Float32, Ifloatmul -> "*f32"
  | Float32, Ifloatdiv -> "/f32"

let print_specific_operation printreg op ppf arg =
  match op with
  | Ilea addr -> print_addressing printreg addr ppf arg
  | Istore_int(n, addr, is_assign) ->
      fprintf ppf "[%a] := %nd %s"
         (print_addressing printreg addr) arg n
         (if is_assign then "(assign)" else "(init)")
  | Ioffset_loc(n, addr) ->
      fprintf ppf "[%a] +:= %i" (print_addressing printreg addr) arg n
  | Ifloatarithmem(width, op, addr) ->
      let op_name = floatartith_name width op in
      fprintf ppf "%a %s float64[%a]" printreg arg.(0) op_name
                   (print_addressing printreg addr)
                   (Array.sub arg 1 (Array.length arg - 1))
  | Ibswap { bitwidth } ->
    fprintf ppf "bswap_%i %a" (int_of_bswap_bitwidth bitwidth) printreg arg.(0)
  | Isextend32 ->
      fprintf ppf "sextend32 %a" printreg arg.(0)
  | Izextend32 ->
      fprintf ppf "zextend32 %a" printreg arg.(0)
  | Irdtsc ->
      fprintf ppf "rdtsc"
  | Ilfence ->
      fprintf ppf "lfence"
  | Isfence ->
      fprintf ppf "sfence"
  | Imfence ->
      fprintf ppf "mfence"
  | Irdpmc ->
      fprintf ppf "rdpmc %a" printreg arg.(0)
  | Ipackf32 ->
      fprintf ppf "packf32 %a %a" printreg arg.(0) printreg arg.(1)
  | Isimd simd ->
      Simd.print_operation printreg simd ppf arg
  | Isimd_mem (simd, addr) ->
      Simd.Mem.print_operation printreg (print_addressing printreg addr) simd ppf arg
  | Icldemote _ ->
      fprintf ppf "cldemote %a" printreg arg.(0)
  | Iprefetch { is_write; locality; _ } ->
      fprintf ppf "prefetch is_write=%b prefetch_temporal_locality_hint=%s %a"
        is_write (string_of_prefetch_temporal_locality_hint locality)
        printreg arg.(0)

let specific_operation_name : specific_operation -> string = fun op ->
  match op with
  | Ilea _ -> "lea"
  | Istore_int (n,_addr,_is_assign) -> "store_int "^ (Nativeint.to_string n)
  | Ioffset_loc (n,_addr) -> "offset_loc "^(string_of_int n)
  | Ifloatarithmem (width, op, _addr) -> floatartith_name width op
  | Ibswap { bitwidth } ->
      "bswap " ^ (bitwidth |> int_of_bswap_bitwidth |> string_of_int)
  | Isextend32 -> "sextend32"
  | Izextend32 -> "zextend32"
  | Irdtsc -> "rdtsc"
  | Ilfence -> "lfence"
  | Isfence -> "sfence"
  | Imfence -> "mfence"
  | Irdpmc -> "rdpmc"
  | Ipackf32 -> "packf32"
  | Isimd _simd -> "simd"
  | Isimd_mem (_simd,_addr) -> "simd_mem"
  | Icldemote _ -> "cldemote"
  | Iprefetch _ -> "prefetch"

(* Are we using the Windows 64-bit ABI? *)
let win64 =
  match Config.system with
  | "win64" | "mingw64" | "cygwin" -> true
  | _                   -> false


(* Specific operations that are pure *)
(* Keep in sync with [Vectorize_specific] *)
let operation_is_pure = function
  | Ilea _ | Ibswap _ | Isextend32 | Izextend32
  | Ifloatarithmem _  -> true
  | Irdtsc | Irdpmc
  | Ilfence | Isfence | Imfence
  | Istore_int (_, _, _) | Ioffset_loc (_, _)
  | Icldemote _ | Iprefetch _ -> false
  | Ipackf32 -> true
  | Isimd op -> Simd.is_pure_operation op
  | Isimd_mem (op, _addr) -> Simd.Mem.is_pure_operation op

(* Keep in sync with [Vectorize_specific] *)
let operation_allocates = function
  | Ilea _ | Ibswap _ | Isextend32 | Izextend32
  | Ifloatarithmem _
  | Irdtsc | Irdpmc  | Ipackf32
  | Isimd _ | Isimd_mem _
  | Ilfence | Isfence | Imfence
  | Istore_int (_, _, _) | Ioffset_loc (_, _)
  | Icldemote _ | Iprefetch _ -> false

open X86_ast

(* Certain float conditions aren't represented directly in the opcode for
   float comparison, so we have to swap the arguments. The swap information
   is also needed downstream because one of the arguments is clobbered. *)
let float_cond_and_need_swap cond =
  match (cond : Lambda.float_comparison) with
  | CFeq  -> EQf,  false
  | CFneq -> NEQf, false
  | CFlt  -> LTf,  false
  | CFnlt -> NLTf, false
  | CFgt  -> LTf,  true
  | CFngt -> NLTf, true
  | CFle  -> LEf,  false
  | CFnle -> NLEf, false
  | CFge  -> LEf,  true
  | CFnge -> NLEf, true


let equal_addressing_mode left right =
  match left, right with
  | Ibased (left_sym, left_glob, left_displ), Ibased (right_sym, right_glob, right_displ) ->
    String.equal left_sym right_sym && equal_sym_global left_glob right_glob && Int.equal left_displ right_displ
  | Iindexed left_displ, Iindexed right_displ ->
    Int.equal left_displ right_displ
  | Iindexed2 left_displ, Iindexed2 right_displ ->
    Int.equal left_displ right_displ
  | Iscaled (left_scale, left_displ), Iscaled (right_scale, right_displ) ->
    Int.equal left_scale right_scale && Int.equal left_displ right_displ
  | Iindexed2scaled (left_scale, left_displ), Iindexed2scaled (right_scale, right_displ) ->
    Int.equal left_scale right_scale && Int.equal left_displ right_displ
  | (Ibased _ | Iindexed _ | Iindexed2 _ | Iscaled _ | Iindexed2scaled _), _ ->
    false

let equal_prefetch_temporal_locality_hint left right =
  match left, right with
  | Nonlocal, Nonlocal -> true
  | Low, Low -> true
  | Moderate, Moderate -> true
  | High, High -> true
  | (Nonlocal | Low | Moderate | High), _ -> false

let equal_float_operation left right =
  match left, right with
  | Ifloatadd, Ifloatadd
  | Ifloatsub, Ifloatsub
  | Ifloatmul, Ifloatmul
  | Ifloatdiv, Ifloatdiv -> true
  | (Ifloatadd | Ifloatsub | Ifloatmul | Ifloatdiv), _ -> false

let equal_specific_operation left right =
  match left, right with
  | Ilea x, Ilea y -> equal_addressing_mode x y
  | Istore_int (x, x', x''), Istore_int (y, y', y'') ->
    Nativeint.equal x y && equal_addressing_mode x' y' && Bool.equal x'' y''
  | Ioffset_loc (x, x'), Ioffset_loc (y, y') ->
    Int.equal x y && equal_addressing_mode x' y'
  | Ifloatarithmem (xw, x, x'), Ifloatarithmem (yw, y, y') ->
    Cmm.equal_float_width xw yw &&
    equal_float_operation x y &&
    equal_addressing_mode x' y'
  | Ibswap { bitwidth = left }, Ibswap { bitwidth = right } ->
    Int.equal (int_of_bswap_bitwidth left) (int_of_bswap_bitwidth right)
  | Isextend32, Isextend32 ->
    true
  | Izextend32, Izextend32 ->
    true
  | Irdtsc, Irdtsc ->
    true
  | Irdpmc, Irdpmc ->
    true
  | Ilfence, Ilfence ->
    true
  | Isfence, Isfence ->
    true
  | Imfence, Imfence ->
    true
  | Ipackf32, Ipackf32 ->
    true
  | Icldemote x, Icldemote x' -> equal_addressing_mode x x'
  | Iprefetch { is_write = left_is_write; locality = left_locality; addr = left_addr; },
    Iprefetch { is_write = right_is_write; locality = right_locality; addr = right_addr; } ->
    Bool.equal left_is_write right_is_write
    && equal_prefetch_temporal_locality_hint left_locality right_locality
    && equal_addressing_mode left_addr right_addr
  | Isimd l, Isimd r ->
    Simd.equal_operation l r
  | Isimd_mem (l,al), Isimd_mem (r,ar) ->
    Simd.Mem.equal_operation l r && equal_addressing_mode al ar
  | (Ilea _ | Istore_int _ | Ioffset_loc _ | Ifloatarithmem _ | Ibswap _ |
     Isextend32 | Izextend32 | Irdtsc | Irdpmc | Ilfence | Isfence | Imfence |
      Ipackf32 | Isimd _ | Isimd_mem _ | Icldemote _ | Iprefetch _), _ ->
    false

(* addressing mode functions *)

let equal_addressing_mode_without_displ (addressing_mode_1: addressing_mode) (addressing_mode_2 : addressing_mode) =
  (* Ignores [displ] when comparing to show that it is possible to calculate the offset,
     see [addressing_offset_in_bytes]. *)
  match addressing_mode_1, addressing_mode_2 with
  | Ibased (symbol1, global1, _), Ibased (symbol2, global2, _) -> (
    match global1, global2 with
    | Global, Global | Local, Local ->
      String.equal symbol1 symbol2
    | (Global | Local), _ -> false)
  | Iindexed _, Iindexed _ -> true
  | Iindexed2 _, Iindexed2 _ -> true
  | Iscaled (scale1, _), Iscaled (scale2, _) -> Int.equal scale1 scale2
  | Iindexed2scaled (scale1, _), Iindexed2scaled (scale2, _) ->
    Int.equal scale1 scale2
  | (Ibased _ | Iindexed _ | Iindexed2 _ | Iscaled _ | Iindexed2scaled _), _ -> false

let addressing_offset_in_bytes
      (addressing_mode_1: addressing_mode)
      (addressing_mode_2 : addressing_mode)
      ~arg_offset_in_bytes
      args_1
      args_2
  =
  let address_arg_offset_in_bytes index =
    arg_offset_in_bytes args_1.(index) args_2.(index)
  in
  match addressing_mode_1, addressing_mode_2 with
  | Ibased (symbol1, global1, n1), Ibased (symbol2, global2, n2) ->
    (* symbol + displ *)
    (match global1, global2 with
     | Global, Global | Local, Local ->
       if String.equal symbol1 symbol2 then Some (n2 - n1) else None
     | Global, Local | Local, Global -> None)
  | Iindexed n1, Iindexed n2 ->
    (* reg + displ *)
    (match address_arg_offset_in_bytes 0 with
     | Some base_off -> Some (base_off + (n2 - n1))
     | None -> None)
  | Iindexed2 n1, Iindexed2 n2 ->
    (* reg + reg + displ *)
    (match address_arg_offset_in_bytes 0, address_arg_offset_in_bytes 1 with
     | Some arg0_offset, Some arg1_offset ->
       Some (arg0_offset + arg1_offset + (n2 - n1))
     | (None, _|Some _, _) -> None)
  | Iscaled (scale1, n1), Iscaled (scale2, n2) ->
    (* reg * scale + displ *)
    if not (Int.compare scale1 scale2 = 0) then None
    else
      (match address_arg_offset_in_bytes 0 with
       | Some offset -> Some ((offset * scale1) + (n2 - n1))
       | None -> None)
  | Iindexed2scaled (scale1, n1), Iindexed2scaled (scale2, n2) ->
    (* reg + reg * scale + displ *)
    if not (Int.compare scale1 scale2 = 0) then None else
      (match address_arg_offset_in_bytes 0, address_arg_offset_in_bytes 1 with
       | Some arg0_offset, Some arg1_offset ->
         Some (arg0_offset + (arg1_offset*scale1) + (n2 - n1))
       | (None, _|Some _, _) -> None)
  | Ibased _, _ -> None
  | Iindexed _, _ -> None
  | Iindexed2 _, _ -> None
  | Iscaled _, _ -> None
  | Iindexed2scaled _, _ -> None

let isomorphic_specific_operation op1 op2 =
  match op1, op2 with
  | Ilea a1, Ilea a2 -> equal_addressing_mode_without_displ a1 a2
  | Istore_int (_n1, a1, is_assign1), Istore_int (_n2, a2, is_assign2) ->
    equal_addressing_mode_without_displ a1 a2 && Bool.equal is_assign1 is_assign2
  | Ioffset_loc (_n1, a1), Ioffset_loc (_n2, a2) ->
    equal_addressing_mode_without_displ a1 a2
  | Ifloatarithmem (w1, o1, a1), Ifloatarithmem (w2, o2, a2) ->
    Cmm.equal_float_width w1 w2 &&
    equal_float_operation o1 o2 &&
    equal_addressing_mode_without_displ a1 a2
  | Ibswap { bitwidth = left }, Ibswap { bitwidth = right } ->
    Int.equal (int_of_bswap_bitwidth left) (int_of_bswap_bitwidth right)
  | Isextend32, Isextend32 ->
    true
  | Izextend32, Izextend32 ->
    true
  | Irdtsc, Irdtsc ->
    true
  | Irdpmc, Irdpmc ->
    true
  | Ilfence, Ilfence ->
    true
  | Isfence, Isfence ->
    true
  | Imfence, Imfence ->
    true
  | Ipackf32, Ipackf32 ->
    true
  | Icldemote x, Icldemote x' -> equal_addressing_mode_without_displ x x'
  | Iprefetch { is_write = left_is_write; locality = left_locality; addr = left_addr; },
    Iprefetch { is_write = right_is_write; locality = right_locality; addr = right_addr; } ->
    Bool.equal left_is_write right_is_write
    && equal_prefetch_temporal_locality_hint left_locality right_locality
    && equal_addressing_mode_without_displ left_addr right_addr
  | Isimd l, Isimd r ->
    Simd.equal_operation l r
  | Isimd_mem (l,al), Isimd_mem (r,ar) ->
    Simd.Mem.equal_operation l r && equal_addressing_mode_without_displ al ar
  | (Ilea _ | Istore_int _ | Ioffset_loc _ | Ifloatarithmem _ | Ibswap _ |
     Isextend32 | Izextend32 | Irdtsc | Irdpmc | Ilfence | Isfence | Imfence
    | Ipackf32 | Isimd _ | Isimd_mem _ | Icldemote _ | Iprefetch _), _ ->
    false
