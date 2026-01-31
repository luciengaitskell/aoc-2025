{
  description = "Hardcaml + SystemVerilog project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    opam-nix = {
      url = "github:luciengaitskell/opam-nix/fix/ocamlfind-patches";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    oxcaml-repository = {
      url = "github:oxcaml/opam-repository/535c466c935bb7076ff517e425cd08f8b2f6a356";
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
          ocaml-variant = "5.2.0+ox";
          opam-repositories = [
            on.opamRepository
            oxcaml-repository
          ];

          # build the OCaml project scope based on the .opam file
          scope =
            on.buildOpamProject
              {
                repos = opam-repositories;

                resolveArgs = {
                  with-test = true;
                  dev = true;
                };
              }
              projectName
              ./.
              {
                ocaml-variants = ocaml-variant;
              };

          toolScope =
            on.queryToScope
              {
                repos = opam-repositories;
              }
              {
                ocaml-lsp-server = "*";
                ocamlformat = "*";
                ocaml-variants = ocaml-variant;
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
            # oxcaml_effect was renamed to handled_effect, which breaks the hash
            # pinning to same version in oxcaml/opam-repository but with updated hash
            oxcaml_effect = prev.oxcaml_effect.overrideAttrs (_: {
              src = pkgs.fetchurl {
                url = "https://github.com/janestreet/handled_effect/archive/0216e836c8741c1fe9dd174f03c0cb384e8e0918.tar.gz";
                sha256 = "sha256-gJHPW/Ugu4zJgPysgKMceKr3F5viHX7QDlLpa/gwH8I=";
              };
            });
          };

          projectPackages = scope.overrideScope overlay;
          toolPackages = toolScope.overrideScope overlay;
        in
        {
          default = pkgs.mkShell {
            # pull in OCaml and dependencies from .opam file
            inputsFrom = [ projectPackages.${projectName} ];

            buildInputs = with pkgs; [
              uv

              # simulation
              verilator

              # synthesis
              yosys
              yosys-slang

              # ocaml dev tools
              toolPackages.ocaml-lsp-server
              toolPackages.ocamlformat
            ];
          };
        }
      );
    };
}
