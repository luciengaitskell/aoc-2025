{
  description = "SystemVerilog project with Yosys + yosys-slang + Verilator + SiliconCompiler + uv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
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
        in
        {
          default = pkgs.mkShell {
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
