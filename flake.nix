{
  description = "SystemVerilog project with Yosys + yosys-slang + Verilator + SiliconCompiler + uv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      # Portable: works on any system automatically
      pkgs = import nixpkgs {
        system = pkgs.system;
        overlays = [
          (import ./nix/overlay-yosys-slang.nix nixpkgs.legacyPackages.${pkgs.system})
        ];
      };
    in
    {
      devShells.${pkgs.system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          uv

          # simulation
          verilator

          # synthesis
          yosys
          yosys-slang
        ];
      };
    };
}
