(* Advent of Code 2025 - Day 1
   based on the Hardcaml example design *)
open! Core
open! Hardcaml
open! Signal

let position_bits = Int.ceil_log2 100
let position_intermediate_bits = Int.ceil_log2 (100 + 100)
let distance_bits = Int.ceil_log2 1000
let count_bits = 16

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; rotation_direction : 'a (* 0 = Left, 1 = Right *)
    ; rotation_distance : 'a [@bits distance_bits]
    ; rotation_valid : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t =
    { zero_count : 'a With_valid.t [@bits count_bits]
    ; current_position : 'a [@bits position_bits]
    }
  [@@deriving hardcaml]
end

module States = struct
  type t =
    | Idle
    | Processing
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let create
  scope
  ({ clock; clear; start; finish; rotation_direction; rotation_distance; rotation_valid } :
    _ I.t)
  : _ O.t
  =
  let spec = Reg_spec.create ~clock ~clear () in
  let open Always in
  let sm = State_machine.create (module States) spec in
  let%hw_var position = Variable.reg spec ~width:position_bits in
  let%hw_var zero_count = Variable.reg spec ~width:count_bits in
  let count_valid = Variable.wire ~default:gnd () in
  let truncate_position position = mux2 (position >=:. 100) (position -:. 100) position in
  let distance_mod =
    (* mod-ish (I'm sure there's a better way to do this) *)
    let dist_tmp0 =
      mux2 (rotation_distance >=:. 100) (rotation_distance -:. 100) rotation_distance
    in
    let dist_tmp1 = truncate_position dist_tmp0 in
    let dist_tmp2 = truncate_position dist_tmp1 in
    let dist_tmp3 = truncate_position dist_tmp2 in
    let dist_tmp4 = truncate_position dist_tmp3 in
    let dist_tmp5 = truncate_position dist_tmp4 in
    let dist_tmp6 = truncate_position dist_tmp5 in
    let dist_tmp7 = truncate_position dist_tmp6 in
    let dist_tmp8 = truncate_position dist_tmp7 in
    uresize ~width:position_intermediate_bits dist_tmp8
  in
  let left_rotate_position_mod =
    let left_rotate_position =
      uresize ~width:position_intermediate_bits position.value
      +: (of_int_trunc ~width:position_intermediate_bits 100 -: distance_mod)
    in
    uresize ~width:position_bits (truncate_position left_rotate_position)
  in
  let right_rotate_position_mod =
    let right_rotate_position =
      uresize ~width:position_intermediate_bits position.value +: distance_mod
    in
    uresize ~width:position_bits (truncate_position right_rotate_position)
  in
  let new_pos =
    mux2 (rotation_direction ==:. 0) left_rotate_position_mod right_rotate_position_mod
  in
  compile
    [ sm.switch
        [ ( Idle
          , [ when_
                start
                [ position <-- of_int_trunc ~width:position_bits 50
                ; zero_count <-- zero count_bits
                ; sm.set_next Processing
                ]
            ] )
        ; ( Processing
          , [ when_
                rotation_valid
                [ position <-- new_pos
                ; when_ (new_pos ==:. 0) [ zero_count <-- zero_count.value +:. 1 ]
                ]
            ; when_ finish [ sm.set_next Done ]
            ] )
        ; Done, [ count_valid <-- vdd ]
        ]
    ];
  { zero_count = { value = zero_count.value; valid = count_valid.value }
  ; current_position = position.value
  }
;;

let hierarchical scope =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~scope ~name:"day01" create
;;
