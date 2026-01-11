{
  description = "Hardcaml + SystemVerilog project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    opam-nix = {
      url = "github:tweag/opam-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      opam-nix,
      ...
    }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (
          system: f system
        );
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ (import ./nix/overlay-yosys-slang.nix) ];
          };

          on = opam-nix.lib.${system};

          projectName = "aoc2025";

          # build the OCaml project scope based on the .opam file
          devPackages = on.buildOpamProject { } projectName ./. {
            # ocaml-base-compiler = "*";
          };
        in
        {
          default = pkgs.mkShell {
            # pull in OCaml and dependencies from .opam file
            inputsFrom = [ devPackages.${projectName} ];

            buildInputs = with pkgs; [
              uv

              # simulation
              verilator

              # synthesis
              yosys
              yosys-slang
            ];
          };
        }
      );
    };
}
