/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*              Damien Doligez, projet Para, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 1996 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/

/* Allocation macros and functions */

#ifndef CAML_MEMORY_H
#define CAML_MEMORY_H

#include "config.h"
#ifdef CAML_INTERNALS
#include "gc.h"
#include "major_gc.h"
#include "minor_gc.h"
#endif /* CAML_INTERNALS */
#include "domain.h"
#include "misc.h"
#include "mlvalues.h"
#include "signals.h"

#ifdef __cplusplus
extern "C" {
#endif

CAMLextern value caml_alloc_shr (mlsize_t wosize, tag_t);
CAMLextern value caml_alloc_shr_noexc(mlsize_t wosize, tag_t);
CAMLextern value caml_alloc_shr_reserved (mlsize_t, tag_t, reserved_t);
CAMLextern value caml_alloc_local(mlsize_t, tag_t);
CAMLextern value caml_alloc_local_reserved(mlsize_t, tag_t, reserved_t);

CAMLextern void caml_adjust_gc_speed (mlsize_t, mlsize_t);
CAMLextern void caml_adjust_minor_gc_speed (mlsize_t, mlsize_t);
CAMLextern void caml_alloc_dependent_memory (value v, mlsize_t bsz);
CAMLextern void caml_free_dependent_memory (value v, mlsize_t bsz);
CAMLextern void caml_modify (volatile value *, value);
CAMLextern void caml_modify_local (value obj, intnat i, value val);
CAMLextern void caml_initialize (volatile value *, value);
CAMLextern value caml_atomic_cas_field (value, value, value, value);
CAMLextern value caml_check_urgent_gc (value);
#ifdef CAML_INTERNALS
CAMLextern char *caml_alloc_for_heap (asize_t request);   /* Size in bytes. */
CAMLextern void caml_free_for_heap (char *mem);
CAMLextern int caml_add_to_heap (char *mem);
#endif /* CAML_INTERNALS */


/* [caml_stat_*] functions below provide an interface to the static memory
   manager built into the runtime, which can be used for managing static
   (that is, non-moving) blocks of heap memory.

   Function arguments that have type [caml_stat_block] must always be pointers
   to blocks returned by the [caml_stat_*] functions below. Attempting to use
   these functions on memory blocks allocated by a different memory manager
   (e.g. the one from the C runtime) will cause undefined behaviour.
*/
typedef void* caml_stat_block;

#ifdef CAML_INTERNALS

/* The pool must be initialized with a call to [caml_stat_create_pool]
   before it is possible to use any of the [caml_stat_*] functions below.

   If the pool is not initialized, [caml_stat_*] functions will still work in
   backward compatibility mode, becoming thin wrappers around [malloc] family
   of functions. In this case, calling [caml_stat_destroy_pool] will not free
   the claimed heap memory, resulting in leaks.
*/
CAMLextern void caml_stat_create_pool(void);

/* [caml_stat_destroy_pool] frees all the heap memory claimed by the pool.

   Once the pool is destroyed, [caml_stat_*] functions will continue to work
   in backward compatibility mode, becoming thin wrappers around [malloc]
   family of functions.
*/
CAMLextern void caml_stat_destroy_pool(void);

#endif /* CAML_INTERNALS */

/* [caml_stat_alloc(size)] allocates a memory block of the requested [size]
   (in bytes) and returns a pointer to it. It throws an OCaml exception in case
   the request fails, and so requires the runtime lock to be held.
*/
CAMLextern caml_stat_block caml_stat_alloc(asize_t);

/* [caml_stat_alloc_noexc(size)] allocates a memory block of the requested
   [size] (in bytes) and returns a pointer to it, or NULL in case the request
   fails.
*/
CAMLextern caml_stat_block caml_stat_alloc_noexc(asize_t);

/* [caml_stat_alloc_aligned(size, modulo, block*)] allocates a memory block of
   the requested [size] (in bytes), the starting address of which is aligned to
   the provided [modulo] value. The function returns the aligned address, as
   well as the unaligned [block] (as an output parameter). It throws an OCaml
   exception in case the request fails, and so requires the runtime lock.
*/
CAMLextern void* caml_stat_alloc_aligned(asize_t, int modulo, caml_stat_block*);

/* [caml_stat_alloc_aligned_noexc] is a variant of [caml_stat_alloc_aligned]
   that returns NULL in case the request fails, and doesn't require the runtime
   lock to be held.
*/
CAMLextern void* caml_stat_alloc_aligned_noexc(asize_t, int modulo,
                                               caml_stat_block*);

/* [caml_stat_calloc_noexc(num, size)] allocates a block of memory for an array
   of [num] elements, each of them [size] bytes long, and initializes all its
   bits to zero, effectively allocating a zero-initialized memory block of
   [num * size] bytes. It returns NULL in case the request fails.
*/
CAMLextern caml_stat_block caml_stat_calloc_noexc(asize_t, asize_t);

/* [caml_stat_free(block)] deallocates the provided [block]. */
CAMLextern void caml_stat_free(caml_stat_block);

/* [caml_stat_resize(block, size)] changes the size of the provided [block] to
   [size] bytes. The function may move the memory block to a new location (whose
   address is returned by the function). The content of the [block] is preserved
   up to the smaller of the new and old sizes, even if the block is moved to a
   new location. If the new size is larger, the value of the newly allocated
   portion is indeterminate. The function throws an OCaml exception in case the
   request fails, and so requires the runtime lock to be held.
*/
CAMLextern caml_stat_block caml_stat_resize(caml_stat_block, asize_t);

/* [caml_stat_resize_noexc] is a variant of [caml_stat_resize] that returns NULL
   in case the request fails, and doesn't require the runtime lock.
*/
CAMLextern caml_stat_block caml_stat_resize_noexc(caml_stat_block, asize_t);


/* A [caml_stat_block] containing a NULL-terminated string */
typedef char* caml_stat_string;

/* [caml_stat_strdup(s)] returns a pointer to a heap-allocated string which is a
   copy of the NULL-terminated string [s]. It throws an OCaml exception in case
   the request fails, and so requires the runtime lock to be held.
*/
CAMLextern caml_stat_string caml_stat_strdup(const char *s);

/* [caml_stat_strdup_noexc] is a variant of [caml_stat_strdup] that returns NULL
   in case the request fails, and doesn't require the runtime lock.
*/
CAMLextern caml_stat_string caml_stat_strdup_noexc(const char *s);

#ifdef _WIN32
/* On Windows, [caml_stat_wcsdup] and [caml_stat_wcsdup_noexc] are the
 * obvious equivalents of [caml_stat_strdup] and
 * [caml_stat_strdup_noexc] for wide characters.
 */
CAMLextern wchar_t* caml_stat_wcsdup(const wchar_t *s);
CAMLextern wchar_t* caml_stat_wcsdup_noexc(const wchar_t *s);
#endif

/* [caml_stat_strconcat(nargs, strings)] concatenates null-terminated [strings]
   (an array of [char*] of size [nargs]) into a new string, dropping all NULs,
   except for the very last one. It throws an OCaml exception in case the
   request fails, and so requires the runtime lock to be held.
*/
CAMLextern caml_stat_string caml_stat_strconcat(int n, ...);
#ifdef _WIN32
CAMLextern wchar_t* caml_stat_wcsconcat(int n, ...);
#endif

CAMLextern int caml_is_stack(value);

/* void caml_shrink_heap (char *);        Only used in compact.c */

#ifdef CAML_INTERNALS

#ifdef HAS_HUGE_PAGES
#include <sys/mman.h>
#define Heap_page_size HUGE_PAGE_SIZE
#define Round_mmap_size(x)                                      \
    (((x) + (Heap_page_size - 1)) & ~ (Heap_page_size - 1))
#endif

#ifdef DEBUG
Caml_inline void DEBUG_clear(value result, mlsize_t wosize) {
  for (mlsize_t i=0; i<wosize; ++i) {
    CAMLassert(Field(result, i) == Debug_free_minor);
    Field(result, i) = Debug_uninit_minor;
  }
}
#else
#define DEBUG_clear(result, wosize)
#endif

enum caml_alloc_small_flags {
  CAML_DONT_TRACK = 0, CAML_DO_TRACK = 1, // call memprof
  CAML_FROM_C = 0,     CAML_FROM_CAML = 2 // call async callbacks
};

#define Alloc_small_enter_GC_flags(flags, dom_st, wosize) \
  caml_alloc_small_dispatch((dom_st), (wosize), (flags), 1, NULL);

// Do not call asynchronous callbacks from allocation functions
#define Alloc_small_enter_GC(dom_st, wosize)    \
  Alloc_small_enter_GC_flags(CAML_DO_TRACK | CAML_FROM_C, dom_st, wosize)

#define Alloc_small_enter_GC_no_track(dom_st, wosize)    \
  Alloc_small_enter_GC_flags(CAML_DONT_TRACK | CAML_FROM_C, dom_st, wosize)

#define Alloc_small_with_reserved(result, wosize, tag, GC, reserved) do{    \
                                                CAMLassert ((wosize) >= 1); \
                                          CAMLassert ((tag_t) (tag) < 256); \
                                 CAMLassert ((wosize) <= Max_young_wosize); \
  caml_domain_state* dom_st = Caml_state;                                   \
  dom_st->young_ptr -=  Whsize_wosize(wosize);                              \
  if (Caml_check_gc_interrupt(dom_st)) {                                    \
    GC(dom_st, wosize);                                                     \
  }                                                                         \
  Hd_hp (dom_st->young_ptr) =                                               \
    Make_header_with_reserved((wosize), (tag), 0, (reserved));              \
  (result) = Val_hp (dom_st->young_ptr);                                    \
  DEBUG_clear ((result), (wosize));                                         \
}while(0)

#define Alloc_small(result, wosize, tag, GC) \
  Alloc_small_with_reserved(result, wosize, tag, GC, (uintnat)0)

// Retrieve the local arenas for the given stack.
// If the stack is the current stack, the copy of [local_sp] at the
// root of [Caml_state] is saved in the current [stack_info]
// structure, as it may have been updated by OCaml code.
CAMLextern caml_local_arenas* caml_refresh_locals(struct stack_info*);

// Update the local arenas in [Caml_state].
CAMLextern void caml_use_local_arenas(caml_local_arenas* s, uintnat local_sp);

// Free local arenas, if any exist. Does nothing if s is NULL.
// Should only be called when a fiber is being destroyed.
CAMLextern void caml_free_local_arenas(caml_local_arenas* s);

#endif /* CAML_INTERNALS */

struct caml__roots_block {
  struct caml__roots_block *next;
  intnat ntables;
  intnat nitems;
  value *tables [5];
};

#define CAML_LOCAL_ROOTS (Caml_state->local_roots)

/* Emit a call to `Caml_check_caml_state`, but only for user
   programs. */
#ifdef CAML_INTERNALS
#define DO_CHECK_CAML_STATE 0
#else
#define DO_CHECK_CAML_STATE 1
#endif

/* The following macros are used to declare C local variables and
   function parameters of type [value].

   The function body must start with one of the [CAMLparam] macros.
   If the function has no parameter of type [value], use [CAMLparam0].
   If the function has 1 to 5 [value] parameters, use the corresponding
   [CAMLparam] with the parameters as arguments.
   If the function has more than 5 [value] parameters, use [CAMLparam5]
   for the first 5 parameters, and one or more calls to the [CAMLxparam]
   macros for the others.
   If the function takes an array of [value]s as argument, use
   [CAMLparamN] to declare it (or [CAMLxparamN] if you already have a
   call to [CAMLparam] for some other arguments).

   If you need local variables of type [value], declare them with one
   or more calls to the [CAMLlocal] macros at the beginning of the
   function, after the call to CAMLparam.  Use [CAMLlocalN] (at the
   beginning of the function) to declare an array of [value]s.

   Your function may raise an exception or return a [value] with the
   [CAMLreturn] macro.  Its argument is simply the [value] returned by
   your function.  Do NOT directly return a [value] with the [return]
   keyword.  If your function returns void, use [CAMLreturn0]. If you
   un-register the local roots (i.e. undo the effects of the [CAMLparam*]
   and [CAMLlocal] macros) without returning immediately, use [CAMLdrop].

   All the identifiers beginning with "caml__" are reserved by OCaml.
   Do not use them for anything (local or global variables, struct or
   union tags, macros, etc.)
*/

#define CAMLparam0()                                                    \
  int caml__missing_CAMLreturn = 0;                                     \
  struct caml__roots_block** caml_local_roots_ptr =                     \
    (DO_CHECK_CAML_STATE ? Caml_check_caml_state() : (void)0,           \
     &CAML_LOCAL_ROOTS);                                                \
  struct caml__roots_block *caml__frame = *caml_local_roots_ptr

#define CAMLparam1(x) \
  CAMLparam0 (); \
  CAMLxparam1 (x)

#define CAMLparam2(x, y) \
  CAMLparam0 (); \
  CAMLxparam2 (x, y)

#define CAMLparam3(x, y, z) \
  CAMLparam0 (); \
  CAMLxparam3 (x, y, z)

#define CAMLparam4(x, y, z, t) \
  CAMLparam0 (); \
  CAMLxparam4 (x, y, z, t)

#define CAMLparam5(x, y, z, t, u) \
  CAMLparam0 (); \
  CAMLxparam5 (x, y, z, t, u)

#define CAMLparamN(x, size) \
  CAMLparam0 (); \
  CAMLxparamN (x, (size))

#define CAMLxparam1(x) \
  struct caml__roots_block caml__roots_##x; \
  CAMLunused_start int caml__dummy_##x = ( \
    (caml__roots_##x.next = *caml_local_roots_ptr), \
    (*caml_local_roots_ptr = &caml__roots_##x), \
    (caml__roots_##x.nitems = 1), \
    (caml__roots_##x.ntables = 1), \
    (caml__roots_##x.tables [0] = &x), \
    0) \
   CAMLunused_end

#define CAMLxparam2(x, y) \
  struct caml__roots_block caml__roots_##x; \
  CAMLunused_start int caml__dummy_##x = ( \
    (caml__roots_##x.next = *caml_local_roots_ptr), \
    (*caml_local_roots_ptr = &caml__roots_##x), \
    (caml__roots_##x.nitems = 1), \
    (caml__roots_##x.ntables = 2), \
    (caml__roots_##x.tables [0] = &x), \
    (caml__roots_##x.tables [1] = &y), \
    0) \
   CAMLunused_end

#define CAMLxparam3(x, y, z) \
  struct caml__roots_block caml__roots_##x; \
  CAMLunused_start int caml__dummy_##x = ( \
    (caml__roots_##x.next = *caml_local_roots_ptr), \
    (*caml_local_roots_ptr = &caml__roots_##x), \
    (caml__roots_##x.nitems = 1), \
    (caml__roots_##x.ntables = 3), \
    (caml__roots_##x.tables [0] = &x), \
    (caml__roots_##x.tables [1] = &y), \
    (caml__roots_##x.tables [2] = &z), \
    0) \
  CAMLunused_end

#define CAMLxparam4(x, y, z, t) \
  struct caml__roots_block caml__roots_##x; \
  CAMLunused_start int caml__dummy_##x = ( \
    (caml__roots_##x.next = *caml_local_roots_ptr), \
    (*caml_local_roots_ptr = &caml__roots_##x), \
    (caml__roots_##x.nitems = 1), \
    (caml__roots_##x.ntables = 4), \
    (caml__roots_##x.tables [0] = &x), \
    (caml__roots_##x.tables [1] = &y), \
    (caml__roots_##x.tables [2] = &z), \
    (caml__roots_##x.tables [3] = &t), \
    0) \
  CAMLunused_end

#define CAMLxparam5(x, y, z, t, u) \
  struct caml__roots_block caml__roots_##x; \
  CAMLunused_start int caml__dummy_##x = ( \
    (caml__roots_##x.next = *caml_local_roots_ptr), \
    (*caml_local_roots_ptr = &caml__roots_##x), \
    (caml__roots_##x.nitems = 1), \
    (caml__roots_##x.ntables = 5), \
    (caml__roots_##x.tables [0] = &x), \
    (caml__roots_##x.tables [1] = &y), \
    (caml__roots_##x.tables [2] = &z), \
    (caml__roots_##x.tables [3] = &t), \
    (caml__roots_##x.tables [4] = &u), \
    0) \
  CAMLunused_end

#define CAMLxparamN(x, size) \
  struct caml__roots_block caml__roots_##x; \
  CAMLunused_start int caml__dummy_##x = ( \
    (caml__roots_##x.next = *caml_local_roots_ptr), \
    (*caml_local_roots_ptr = &caml__roots_##x), \
    (caml__roots_##x.nitems = (size)), \
    (caml__roots_##x.ntables = 1), \
    (caml__roots_##x.tables[0] = &(x[0])), \
    0) \
  CAMLunused_end

#define CAMLlocal1(x) \
  value x = Val_unit; \
  CAMLxparam1 (x)

#define CAMLlocal2(x, y) \
  value x = Val_unit, y = Val_unit; \
  CAMLxparam2 (x, y)

#define CAMLlocal3(x, y, z) \
  value x = Val_unit, y = Val_unit, z = Val_unit; \
  CAMLxparam3 (x, y, z)

#define CAMLlocal4(x, y, z, t) \
  value x = Val_unit, y = Val_unit, z = Val_unit, t = Val_unit; \
  CAMLxparam4 (x, y, z, t)

#define CAMLlocal5(x, y, z, t, u) \
  value x = Val_unit, y = Val_unit, z = Val_unit, t = Val_unit, u = Val_unit; \
  CAMLxparam5 (x, y, z, t, u)

#define CAMLlocalN(x, size) \
  value x [(size)]; \
  int caml__i_##x; \
  CAMLxparamN (x, (size)); \
  for (caml__i_##x = 0; caml__i_##x < size; caml__i_##x ++) { \
    x[caml__i_##x] = Val_unit; \
  }

#define CAMLdrop do{              \
  (void)caml__missing_CAMLreturn; \
  *caml_local_roots_ptr = caml__frame; \
}while (0)

#define CAMLreturn0 do{ \
  CAMLdrop; \
  return; \
}while (0)

#define CAMLreturnT(type, result) do{ \
  type caml__temp_result = (result); \
  CAMLdrop; \
  return (caml__temp_result); \
}while(0)

#define CAMLreturn(result) CAMLreturnT(value, result)

#define CAMLnoreturn ((void) caml__missing_CAMLreturn, (void) caml__frame)


/* convenience macro */
#define Store_field(block, offset, val) do{ \
  mlsize_t caml__temp_offset = (offset); \
  value caml__temp_val = (val); \
  caml_modify (&Field ((block), caml__temp_offset), caml__temp_val); \
}while(0)

/*
   NOTE: [Begin_roots] and [End_roots] are superseded by [CAMLparam]*,
   [CAMLxparam]*, [CAMLlocal]*, [CAMLreturn].

   [Begin_roots] and [End_roots] are used for C variables that are GC roots.
   It must contain all values in C local variables and function parameters
   at the time the minor GC is called.
   Usage:
   After initialising your local variables to legal OCaml values, but before
   calling allocation functions, insert [Begin_roots_n(v1, ... vn)], where
   v1 ... vn are your variables of type [value] that you want to be updated
   across allocations.
   At the end, insert [End_roots()].

   Note that [Begin_roots] opens a new block, and [End_roots] closes it.
   Thus they must occur in matching pairs at the same brace nesting level.

   You can use [Val_unit] as a dummy initial value for your variables.
*/

#define Begin_root Begin_roots1

#define Begin_roots1(r0) { \
  struct caml__roots_block caml__roots_block; \
  caml_domain_state* domain_state = Caml_state; \
  caml__roots_block.next = domain_state->local_roots; \
  domain_state->local_roots = &caml__roots_block; \
  caml__roots_block.nitems = 1; \
  caml__roots_block.ntables = 1; \
  caml__roots_block.tables[0] = &(r0);

#define Begin_roots2(r0, r1) { \
  struct caml__roots_block caml__roots_block; \
  caml_domain_state* domain_state = Caml_state; \
  caml__roots_block.next = domain_state->local_roots; \
  domain_state->local_roots = &caml__roots_block; \
  caml__roots_block.nitems = 1; \
  caml__roots_block.ntables = 2; \
  caml__roots_block.tables[0] = &(r0); \
  caml__roots_block.tables[1] = &(r1);

#define Begin_roots3(r0, r1, r2) { \
  struct caml__roots_block caml__roots_block; \
  caml_domain_state* domain_state = Caml_state; \
  caml__roots_block.next = domain_state->local_roots; \
  domain_state->local_roots = &caml__roots_block; \
  caml__roots_block.nitems = 1; \
  caml__roots_block.ntables = 3; \
  caml__roots_block.tables[0] = &(r0); \
  caml__roots_block.tables[1] = &(r1); \
  caml__roots_block.tables[2] = &(r2);

#define Begin_roots4(r0, r1, r2, r3) { \
  struct caml__roots_block caml__roots_block; \
  caml_domain_state* domain_state = Caml_state; \
  caml__roots_block.next = domain_state->local_roots; \
  domain_state->local_roots = &caml__roots_block; \
  caml__roots_block.nitems = 1; \
  caml__roots_block.ntables = 4; \
  caml__roots_block.tables[0] = &(r0); \
  caml__roots_block.tables[1] = &(r1); \
  caml__roots_block.tables[2] = &(r2); \
  caml__roots_block.tables[3] = &(r3);

#define Begin_roots5(r0, r1, r2, r3, r4) { \
  struct caml__roots_block caml__roots_block; \
  caml_domain_state* domain_state = Caml_state; \
  caml__roots_block.next = domain_state->local_roots; \
  domain_state->local_roots = &caml__roots_block; \
  caml__roots_block.nitems = 1; \
  caml__roots_block.ntables = 5; \
  caml__roots_block.tables[0] = &(r0); \
  caml__roots_block.tables[1] = &(r1); \
  caml__roots_block.tables[2] = &(r2); \
  caml__roots_block.tables[3] = &(r3); \
  caml__roots_block.tables[4] = &(r4);

#define Begin_roots_block(table, size) { \
  struct caml__roots_block caml__roots_block; \
  caml_domain_state* domain_state = Caml_state; \
  caml__roots_block.next = domain_state->local_roots; \
  domain_state->local_roots = &caml__roots_block; \
  caml__roots_block.nitems = (size); \
  caml__roots_block.ntables = 1; \
  caml__roots_block.tables[0] = (table);

#define End_roots() CAML_LOCAL_ROOTS = caml__roots_block.next; }


/* [caml_register_global_root] registers a global C variable as a memory root
   for the duration of the program, or until [caml_remove_global_root] is
   called. */

CAMLextern void caml_register_global_root (value *);

/* [caml_remove_global_root] removes a memory root registered on a global C
   variable with [caml_register_global_root]. */

CAMLextern void caml_remove_global_root (value *);

/* [caml_register_generational_global_root] registers a global C
   variable as a memory root for the duration of the program, or until
   [caml_remove_generational_global_root] is called.
   The program guarantees that the value contained in this variable
   will not be assigned directly.  If the program needs to change
   the value of this variable, it must do so by calling
   [caml_modify_generational_global_root].  The [value *] pointer
   passed to [caml_register_generational_global_root] must contain
   a valid OCaml value before the call.
   In return for these constraints, scanning of memory roots during
   minor collection is made more efficient. */

CAMLextern void caml_register_generational_global_root (value *);

/* [caml_remove_generational_global_root] removes a memory root
   registered on a global C variable with
   [caml_register_generational_global_root]. */

CAMLextern void caml_remove_generational_global_root (value *);

/* [caml_modify_generational_global_root(r, newval)]
   modifies the value contained in [r], storing [newval] inside.
   In other words, the assignment [*r = newval] is performed,
   but in a way that is compatible with the optimized scanning of
   generational global roots.  [r] must be a global memory root
   previously registered with [caml_register_generational_global_root]. */

CAMLextern void caml_modify_generational_global_root(value *r, value newval);

#ifdef __cplusplus
}
#endif

#endif /* CAML_MEMORY_H */
