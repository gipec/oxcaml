(* TEST
 flags += "-alert -do_not_spawn_domains -alert -unsafe_multidomain";
 poll-insertion;
 include unix;
 hasunix;
 runtime5;
 multidomain;
 {
   bytecode;
 }{
   native;
 }
*)

let continue = Atomic.make true

let rec loop () =
  if Atomic.get continue then loop ()

let rec repeat f = function
  | 0 -> ()
  | n -> f (); repeat f (n - 1)

let f () =
  Atomic.set continue true;
  let d = Domain.spawn loop in
  Unix.sleepf 5E-2;
  Gc.full_major();
  Atomic.set continue false;
  Domain.join d

let _ =
  repeat f 10 ;
  print_endline "OK"
