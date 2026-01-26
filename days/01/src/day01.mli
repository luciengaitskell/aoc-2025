open! Core
open! Hardcaml

val position_bits : int
val distance_bits : int
val count_bits : int

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; rotation_direction : 'a
    ; rotation_distance : 'a
    ; rotation_valid : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t =
    { zero_count : 'a With_valid.t
    ; current_position : 'a
    }
  [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
