open Core.Std
(*open Async.Std*)
(* This module contains basic functions and modules used through, with no
 * external dependances on any other modules *)


type role = Follower | Candidate | Leader with sexp
type 'a status = Live of 'a | Down of 'a | Notfound 
type failures = Wake | Kill

let string_of_role = function
  | Follower -> "Follower"
  | Candidate -> "Candidate"
  | Leader -> "Leader"

let string_of_option f = function 
  | None -> "none" 
  | Some x -> f x

module NumberGen = struct
  (* TODO: these are dealing with discite values but i think i need a seperate
   * ones for continous *)

  let () = Random.self_init ()
  let fixed x () =  x

  let uniform  min max () = (Random.float (max-.min) +. min)

  let exp lam () = 
    (* TODO fix this *)
    (-1.0 /. lam)*.log(Random.float Float.max_finite_value)

 let string_to_dist str =
   let flt = Float.of_string in
   printf " %s \n" str;
   match (String.split str ~on:'-') with
   | "Fixed"::value::_ -> fixed (flt value)
   | "Uniform"::min::max::[] -> uniform (flt min) (flt max)
   | "Exp"::lamda::[] -> exp (flt lamda)
   | er ->  eprintf "failure to parse: %s" (List.to_string ~f:(fun x -> x) er) ; exit 1

end

module type PARAMETERS = sig
  val timeout: unit -> role -> float
  val nodes: int
  val pkt_delay: unit -> float
  val termination: int
  val debug_mode: bool
  val nxt_failure: (unit -> float) option
  val nxt_recover: (unit -> float) option
end

module Index = struct
  type t = int with compare,sexp,bin_io
  let succ = succ
  let init () = 0
  (*TODO: consider is elections can start fast with randon inital value *)
  let to_string = string_of_int
end

module IntID  = struct
  type t = int with sexp,bin_io
  let from_int x = x
  let to_int x  = x
  let equal = Int.equal
  let to_string = string_of_int
end  


module ListLog = struct
  include List
  let init () = []
end 

(* This is no used but its too beautiful to delete 
module ListLog =
  functor (Entry: ENTRY) -> ( struct
  type entry = Entry.t
  type t = Entry.t list with bin_io,sexp
  let init () = []
  let append t x = x::t
  let to_string = List.to_string ~f:Entry.to_string
end : LOG)
*)

module Event = struct 
  (* TODO: make this much better and actually inforce use of state calls *)
  type ('a,'b,'c) t = E of ('a * 'b * ('a,'b,'c) event)
                    | N of ('a * 'b * failures)
  and ('a,'b,'c) event = ('c -> ('c * ('a,'b,'c) t list))

  let compare x y = match x,y with
  | (E (xt,_,_),E (yt,_,_)) 
  | (N (xt,_,_),N (yt,_,_)) 
  | (N (xt,_,_),E (yt,_,_)) 
  | (E (xt,_,_),N (yt,_,_)) 
  -> compare xt yt

  
end 


module EventList = struct

  type ('a,'b,'c) t = ('a,'b,'c) Event.t  list

  let from_list x = List.sort ~cmp:Event.compare x
  let to_list x = x

  let hd el = match el with
    | [] -> None 
    | x::xs -> Some(x,xs)

  let add a l = 
    List.merge l (from_list a) ~cmp:Event.compare
end

