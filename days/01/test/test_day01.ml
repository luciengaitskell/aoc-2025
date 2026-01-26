open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Day01 = Aoc2025_day01.Day01
module Harness = Cyclesim_harness.Make (Day01.I) (Day01.O)

let ( <--. ) = Bits.( <--. )

(* From the AoC problem *)
let sample_rotations =
  [ 'L', 68
  ; 'L', 30
  ; 'R', 48
  ; 'L', 5
  ; 'R', 60
  ; 'L', 55
  ; 'L', 1
  ; 'L', 99
  ; 'R', 14
  ; 'L', 82
  ]
;;

let simple_testbench (sim : Harness.Sim.t) =
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let cycle ?n () = Cyclesim.cycle ?n sim in
  let feed_rotation (dir, dist) =
    inputs.rotation_direction := if Char.equal dir 'L' then Bits.gnd else Bits.vdd;
    inputs.rotation_distance <--. dist;
    inputs.rotation_valid := Bits.vdd;
    cycle ();
    inputs.rotation_valid := Bits.gnd
    (* cycle () *)
  in
  (* Reset the design *)
  inputs.clear := Bits.vdd;
  cycle ();
  inputs.clear := Bits.gnd;
  cycle ();
  (* Pulse the start signal *)
  inputs.start := Bits.vdd;
  cycle ();
  inputs.start := Bits.gnd;
  (* Input rotations *)
  List.iter sample_rotations ~f:(fun rotation -> feed_rotation rotation);
  inputs.finish := Bits.vdd;
  cycle ();
  inputs.finish := Bits.gnd;
  cycle ();
  (* Wait for result to become valid *)
  while not (Bits.to_bool !(outputs.zero_count.valid)) do
    cycle ()
  done;
  let zero_count = Bits.to_unsigned_int !(outputs.zero_count.value) in
  let final_position = Bits.to_unsigned_int !(outputs.current_position) in
  print_s [%message "Result" (zero_count : int) (final_position : int)];
  (* Show in the waveform that [valid] stays high. *)
  cycle ~n:2 ()
;;

(* The [waves_config] argument to [Harness.run] determines where and how to save waveforms
   for viewing later with a waveform viewer. The commented examples below show how to save
   a waveterm file or a VCD file. *)
let waves_config = Waves_config.no_waves

(* let waves_config = *)
(*   Waves_config.to_directory "/tmp/" *)
(*   |> Waves_config.as_wavefile_format ~format:Hardcamlwaveform *)
(* ;; *)

(* let waves_config = *)
(*   Waves_config.to_directory "/tmp/" *)
(*   |> Waves_config.as_wavefile_format ~format:Vcd *)
(* ;; *)

let%expect_test "Simple test, optionally saving waveforms to disk" =
  Harness.run_advanced ~waves_config ~create:Day01.hierarchical simple_testbench;
  [%expect {| (Result (zero_count 3) (final_position 32)) |}]
;;

let%expect_test "Simple test with printing waveforms directly" =
  let display_rules =
    [ Display_rule.port_name_matches
        ~wave_format:(Bit_or Unsigned_int)
        (Re.Glob.glob "day01*" |> Re.compile)
    ]
  in
  Harness.run_advanced
    ~create:Day01.hierarchical
    ~trace:`All_named
    ~print_waves_after_test:(fun waves ->
      Waveform.print
        ~display_rules
        ~signals_width:35
        ~display_width:100
        ~wave_width:2
        waves)
    simple_testbench;
  [%expect
    {|
    (Result (zero_count 3) (final_position 32))
    ┌Signals──────────────────────────┐┌Waves──────────────────────────────────────────────────────────┐
    │day01$i$clear                    ││──────┐                                                        │
    │                                 ││      └────────────────────────────────────────────────────────│
    │day01$i$clock                    ││┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──│
    │                                 ││   └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  │
    │day01$i$finish                   ││                                                               │
    │                                 ││───────────────────────────────────────────────────────────────│
    │day01$i$rotation_direction       ││                              ┌─────┐     ┌─────┐              │
    │                                 ││──────────────────────────────┘     └─────┘     └──────────────│
    │                                 ││──────────────────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬──│
    │day01$i$rotation_distance        ││ 0                │68   │30   │48   │5    │60   │55   │1    │99│
    │                                 ││──────────────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴──│
    │day01$i$rotation_valid           ││                  ┌────────────────────────────────────────────│
    │                                 ││──────────────────┘                                            │
    │day01$i$start                    ││            ┌─────┐                                            │
    │                                 ││────────────┘     └────────────────────────────────────────────│
    │                                 ││──────────────────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬──│
    │day01$o$current_position         ││ 0                │50   │82   │52   │0    │95   │55   │0    │99│
    │                                 ││──────────────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴──│
    │day01$o$zero_count$valid         ││                                                               │
    │                                 ││───────────────────────────────────────────────────────────────│
    │                                 ││────────────────────────────────────┬─────────────────┬────────│
    │day01$o$zero_count$value         ││ 0                                  │1                │2       │
    │                                 ││────────────────────────────────────┴─────────────────┴────────│
    │                                 ││──────────────────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┬──│
    │day01$position                   ││ 0                │50   │82   │52   │0    │95   │55   │0    │99│
    │                                 ││──────────────────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴──│
    │                                 ││────────────────────────────────────┬─────────────────┬────────│
    │day01$zero_count                 ││ 0                                  │1                │2       │
    │                                 ││────────────────────────────────────┴─────────────────┴────────│
    └─────────────────────────────────┘└───────────────────────────────────────────────────────────────┘
    |}]
;;
