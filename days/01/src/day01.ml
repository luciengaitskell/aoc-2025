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
    ; through_zero_count : 'a With_valid.t [@bits count_bits]
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
  let%hw_var through_zero_count = Variable.reg spec ~width:count_bits in
  let count_valid = Variable.wire ~default:gnd () in
  let truncate_position_count position count =
    let truncated = position >=:. 100 in
    mux2 truncated (count +:. 1) count, mux2 truncated (position -:. 100) position
  in
  let truncate_position position =
    let _, position = truncate_position_count position (zero count_bits) in
    position
  in
  let truncations, distance_mod =
    let truncations = zero count_bits in
    (* mod-ish (I'm sure there's a better way to do this) *)
    let truncations, dist_tmp0 = truncate_position_count rotation_distance truncations in
    let truncations, dist_tmp1 = truncate_position_count dist_tmp0 truncations in
    let truncations, dist_tmp2 = truncate_position_count dist_tmp1 truncations in
    let truncations, dist_tmp3 = truncate_position_count dist_tmp2 truncations in
    let truncations, dist_tmp4 = truncate_position_count dist_tmp3 truncations in
    let truncations, dist_tmp5 = truncate_position_count dist_tmp4 truncations in
    let truncations, dist_tmp6 = truncate_position_count dist_tmp5 truncations in
    let truncations, dist_tmp7 = truncate_position_count dist_tmp6 truncations in
    let truncations, dist_tmp8 = truncate_position_count dist_tmp7 truncations in
    truncations, uresize ~width:position_intermediate_bits dist_tmp8
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
  let zero_crossings =
    let crossings_left =
      mux2
        (position.value <: new_pos)
        (of_int_trunc ~width:count_bits 1)
        (of_int_trunc ~width:count_bits 0)
    in
    let crossings_right =
      mux2
        (new_pos <: position.value)
        (of_int_trunc ~width:count_bits 1)
        (of_int_trunc ~width:count_bits 0)
    in
    mux2
      (position.value ==:. 0)
      (of_int_trunc ~width:count_bits 0)
      (mux2
         (new_pos ==:. 0)
         (of_int_trunc ~width:count_bits 1)
         (mux2 (rotation_direction ==:. 0) crossings_left crossings_right))
    +: truncations
  in
  compile
    [ sm.switch
        [ ( Idle
          , [ when_
                start
                [ position <-- of_int_trunc ~width:position_bits 50
                ; zero_count <-- zero count_bits
                ; through_zero_count <-- zero count_bits
                ; sm.set_next Processing
                ]
            ] )
        ; ( Processing
          , [ when_
                rotation_valid
                [ position <-- new_pos
                ; when_ (new_pos ==:. 0) [ zero_count <-- zero_count.value +:. 1 ]
                ; through_zero_count <-- through_zero_count.value +: zero_crossings
                ]
            ; when_ finish [ sm.set_next Done ]
            ] )
        ; Done, [ count_valid <-- vdd ]
        ]
    ];
  { zero_count = { value = zero_count.value; valid = count_valid.value }
  ; through_zero_count = { value = through_zero_count.value; valid = count_valid.value }
  ; current_position = position.value
  }
;;

let hierarchical scope =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~scope ~name:"day01" create
;;
