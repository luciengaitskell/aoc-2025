open! Core
open! Hardcaml
open! Aoc2025_day01

let generate_day01_rtl () =
  let module C = Circuit.With_interface (Day01.I) (Day01.O) in
  let scope = Scope.create ~auto_label_hierarchical_ports:true () in
  let circuit = C.create_exn ~name:"day01_top" (Day01.hierarchical scope) in
  let rtl_circuits =
    Rtl.create ~database:(Scope.circuit_database scope) Verilog [ circuit ]
  in
  let rtl = Rtl.full_hierarchy rtl_circuits |> Rope.to_string in
  print_endline rtl
;;

let day01_rtl_command =
  Command.basic
    ~summary:""
    [%map_open.Command
      let () = return () in
      fun () -> generate_day01_rtl ()]
;;

let () =
  Command_unix.run
    (Command.group ~summary:"" [ "range-finder", day01_rtl_command ])
;;
