(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Stephen Dolan, University of Cambridge                     *)
(*                                                                        *)
(*   Copyright 2014 Stephen Dolan.                                        *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

let overhead block slot obj =
  1. -. float_of_int((block / slot) * obj) /. float_of_int block

let max_overhead = 0.101

(*
  Prevention of false sharing requires certain sizeclasses to be present. This
  ensures they are generated.

  Runtime has a constructor for atomics (`caml_atomic_make_contended`), which
  aligns them with cache lines to avoid false sharing. The implementation
  relies on the fact that pools are cache-aligned by design and slots of
  appropriate size maintain this property. To be precise, slots whose size is a
  multiple of cache line are laid out in such a way, that their boundaries
  coincide with boundaries between cache lines.
*)
let required_for_contended_atomic = function
  | 16 | 32 -> true
  | _ -> false

let rec blocksizes block slot = function
  | 0 -> []
  | obj ->
    if overhead block slot obj > max_overhead
      || required_for_contended_atomic obj
    then
      if overhead block obj obj < max_overhead then
        obj :: blocksizes block obj (obj - 1)
      else
        failwith (Format.sprintf
          "%d-word objects cannot fit in %d-word arena below %.1f%% overhead"
                                 obj block (100. *. max_overhead))
    else blocksizes block slot (obj - 1)

let rec findi_acc i p = function
  | [] -> raise Not_found
  | x :: xs -> if p x then i else findi_acc (i + 1) p xs
let findi = findi_acc 0

let arena = 4096
let header_size = 7
let max_slot = 128
let avail_arena = arena - header_size
let sizes = List.rev (blocksizes avail_arena max_int max_slot)

let rec size_slots n =
  if n > max_slot then
    []
  else
    findi (fun x -> n <= x) sizes :: size_slots (n + 1)

let rec wastage =
  sizes |> List.map (fun s -> avail_arena mod s)

open Format

let rec print_overheads n = function
  | [] -> ()
  | s :: ss when n > s -> print_overheads n ss
  | (s :: _) as ss  ->
     printf "%3d/%-3d: %.1f%%\n" n s (100. *. overhead avail_arena s n);
     print_overheads (n+1) ss

(* let () = print_overheads 1 sizes *)

let rec print_list ppf = function
  | [] -> ()
  | [x] -> fprintf ppf "%d" x
  | x :: xs -> fprintf ppf "%d,@ %a" x print_list xs

let _ =
  printf "/* This file is generated by tools/gen_sizeclasses.ml */\n";
  printf "#define POOL_WSIZE %d\n" arena;
  printf "#define POOL_HEADER_WSIZE %d\n" header_size;
  printf "#define SIZECLASS_MAX %d\n" max_slot;
  printf "#define NUM_SIZECLASSES %d\n" (List.length sizes);
  printf {|
typedef unsigned char sizeclass_t;
static_assert(NUM_SIZECLASSES < (1 << (CHAR_BIT * sizeof(sizeclass_t))), "");

/* The largest size for this size class.
   (A gap is left after smaller objects) */
static const unsigned int wsize_sizeclass[NUM_SIZECLASSES] =@[<2>{ %a };@]
|}
    print_list sizes;
  printf {|
/* The number of padding words to use, at the beginning of a pool
   of this sizeclass, to reach exactly POOL_WSIZE words. */
static const unsigned char wastage_sizeclass[NUM_SIZECLASSES] =@[<2>{ %a };@]
|}
    print_list wastage;
  printf {|
/* Map from (positive) object sizes to size classes. */
static const sizeclass_t sizeclass_wsize[SIZECLASS_MAX + 1] =@[<2>{ %a };@]
|}
    print_list (255 :: size_slots 1);
