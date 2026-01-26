open! Core
open! Hardcaml
open! Hardcaml_test_harness
module Day01 = Aoc2025_day01.Day01
module Harness = Cyclesim_harness.Make (Day01.I) (Day01.O)

let ( <--. ) = Bits.( <--. )

let parse_rotation line =
  let direction = String.get line 0 in
  let distance = String.sub line ~pos:1 ~len:(String.length line - 1) |> Int.of_string in
  direction, distance
;;

let solve_day01 rotations =
  let testbench ~inputs ~outputs (sim : Harness.Sim.t) =
    let cycle ?n () = Cyclesim.cycle ?n sim in
    let rotation_count = ref 0 in
    let feed_rotation (dir, dist) =
      inputs.Day01.I.rotation_direction
      := if Char.equal dir 'L' then Bits.gnd else Bits.vdd;
      inputs.Day01.I.rotation_distance <--. dist;
      inputs.Day01.I.rotation_valid := Bits.vdd;
      cycle ();
      incr rotation_count;
      let current_zero_count = Bits.to_unsigned_int !(outputs.Day01.O.zero_count.value) in
      let pos = Bits.to_unsigned_int !(outputs.Day01.O.current_position) in
      (* Log first few rotations *)
      if !rotation_count <= 150
      then
        printf
          "%4d: %c%-3d -> pos=%2d  zc=%d%s\n%!"
          !rotation_count
          dir
          dist
          pos
          current_zero_count
          (if pos = 0 then " **ZERO**" else "");
      inputs.Day01.I.rotation_valid := Bits.gnd
      (* cycle () *)
    in
    (* Reset *)
    inputs.Day01.I.clear := Bits.vdd;
    cycle ();
    inputs.Day01.I.clear := Bits.gnd;
    cycle ();
    (* Start *)
    inputs.Day01.I.start := Bits.vdd;
    cycle ();
    inputs.Day01.I.start := Bits.gnd;
    (* Send in rotations *)
    List.iter rotations ~f:feed_rotation;
    (* Finish *)
    inputs.Day01.I.finish := Bits.vdd;
    cycle ();
    inputs.Day01.I.finish := Bits.gnd;
    cycle ();
    (* Wait for result *)
    while not (Bits.to_bool !(outputs.Day01.O.zero_count.valid)) do
      cycle ()
    done;
    let zero_count = Bits.to_unsigned_int !(outputs.Day01.O.zero_count.value) in
    let final_position = Bits.to_unsigned_int !(outputs.Day01.O.current_position) in
    zero_count, final_position
  in
  Harness.run ~create:Day01.hierarchical testbench
;;

let solve_command =
  Command.basic
    ~summary:"Solve with input file"
    [%map_open.Command
      let input_file = anon ("INPUT_FILE_NAME" %: string) in
      fun () ->
        let rotations = In_channel.read_lines input_file |> List.map ~f:parse_rotation in
        printf "Processing %d rotations...\n" (List.length rotations);
        let zero_count, final_position = solve_day01 rotations in
        print_s [%message "Solution" (zero_count : int) (final_position : int)]]
;;

let () = Command_unix.run (Command.group ~summary:"" [ "day01", solve_command ])
