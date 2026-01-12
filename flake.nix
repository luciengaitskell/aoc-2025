{
  description = "Hardcaml + SystemVerilog project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    opam-nix = {
      url = "github:tweag/opam-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oxcaml-repository = {
      url = "github:oxcaml/opam-repository";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      opam-nix,
      oxcaml-repository,
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
          scope =
            on.buildOpamProject
              {
                repos = [
                  oxcaml-repository
                  on.opamRepository
                ];

                resolveArgs = {
                  with-test = true;
                };
              }
              projectName
              ./.
              {
                ocaml-variants = "5.2.0+ox";
              };

          overlay = final: prev: {
            ocaml-variants = prev.ocaml-variants.overrideAttrs (old: {
              nativeBuildInputs =
                (old.nativeBuildInputs or [ ])
                ++ [
                  pkgs.rsync # fix for install phase
                ]
                ++ (
                  # https://github.com/tweag/opam-nix/issues/146
                  # fix for macOS build
                  if pkgs.stdenv.isDarwin then [ pkgs.darwin.cctools ] else [ ]
                );
            });
          };

          devPackages = scope.overrideScope overlay;
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
