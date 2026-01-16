open! Core
open! Hardcaml
open! Hardcaml_waveterm
open! Hardcaml_test_harness
module Day01 = Aoc2025_day01.Day01
module Harness = Cyclesim_harness.Make (Day01.I) (Day01.O)

let ( <--. ) = Bits.( <--. )
let sample_input_values = [ 16; 67; 150; 4 ]

let simple_testbench (sim : Harness.Sim.t) =
  let inputs = Cyclesim.inputs sim in
  let outputs = Cyclesim.outputs sim in
  let cycle ?n () = Cyclesim.cycle ?n sim in
  (* Helper function for inputting one value *)
  let feed_input n =
    inputs.data_in <--. n;
    inputs.data_in_valid := Bits.vdd;
    cycle ();
    inputs.data_in_valid := Bits.gnd;
    cycle ()
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
  (* Input some data *)
  List.iter sample_input_values ~f:(fun x -> feed_input x);
  inputs.finish := Bits.vdd;
  cycle ();
  inputs.finish := Bits.gnd;
  cycle ();
  (* Wait for result to become valid *)
  while not (Bits.to_bool !(outputs.range.valid)) do
    cycle ()
  done;
  let range = Bits.to_unsigned_int !(outputs.range.value) in
  print_s [%message "Result" (range : int)];
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
  [%expect {| (Result (range 146)) |}]
;;

let%expect_test "Simple test with printing waveforms directly" =
  (* For simple tests, we can print the waveforms directly in an expect-test (and use the
     command [dune promote] to update it after the tests run). This is useful for quickly
     visualizing or documenting a simple circuit, but limits the amount of data that can
     be shown. *)
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
          (* [display_rules] is optional, if not specified, it will print all named
             signals in the design. *)
        ~signals_width:30
        ~display_width:92
        ~wave_width:1
        (* [wave_width] configures how many chars wide each clock cycle is *)
        waves)
    simple_testbench;
  [%expect
    {|
    (Result (range 146))
    ┌Signals─────────────────────┐┌Waves───────────────────────────────────────────────────────┐
    │day01$i$clear        ││────┐                                                       │
    │                            ││    └───────────────────────────────────────────────────────│
    │day01$i$clock        ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ │
    │                            ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─│
    │                            ││────────────┬───────┬───────┬───────┬───────────────────────│
    │day01$i$data_in      ││ 0          │16     │67     │150    │4                      │
    │                            ││────────────┴───────┴───────┴───────┴───────────────────────│
    │day01$i$data_in_valid││            ┌───┐   ┌───┐   ┌───┐   ┌───┐                   │
    │                            ││────────────┘   └───┘   └───┘   └───┘   └───────────────────│
    │day01$i$finish       ││                                            ┌───┐           │
    │                            ││────────────────────────────────────────────┘   └───────────│
    │day01$i$start        ││        ┌───┐                                               │
    │                            ││────────┘   └───────────────────────────────────────────────│
    │                            ││────────────────┬───────┬───────┬───────────────────────────│
    │day01$max            ││ 0              │16     │67     │150                        │
    │                            ││────────────────┴───────┴───────┴───────────────────────────│
    │                            ││────────────┬───┬───────────────────────┬───────────────────│
    │day01$min            ││ 0          │65.│16                     │4                  │
    │                            ││────────────┴───┴───────────────────────┴───────────────────│
    │day01$o$range$valid  ││                                                ┌───────────│
    │                            ││────────────────────────────────────────────────┘           │
    │                            ││────────────────────────────────────────────────┬───────────│
    │day01$o$range$value  ││ 0                                              │146        │
    │                            ││────────────────────────────────────────────────┴───────────│
    └────────────────────────────┘└────────────────────────────────────────────────────────────┘
    |}]
;;
