# Temporary overlay until yosys-slang lands in nixpkgs
# https://github.com/NixOS/nixpkgs/pull/472800
{ pkgs }:

final: prev: {
  yosys-slang = prev.stdenv.mkDerivation rec {
    pname = "yosys-slang";
    version = "git-2024-02-02";

    src = prev.fetchFromGitHub {
      owner = "povik";
      repo = "yosys-slang";
      rev = "c23e0653c85f6ed4127e665a2529b069ce550e967";
      hash = "sha256-7axr4JyxTtnCbI6l23A9LoBco3b3bqEMKoTEc1KNOQI=";
      fetchSubmodules = true;
    };

    nativeBuildInputs = [
      prev.cmake
      prev.pkg-config
    ];
    buildInputs = [ prev.yosys ];

    buildPhase = ''
      make -j$NIX_BUILD_CORES
    '';

    installPhase = ''
      mkdir -p $out/share/yosys/plugins
      cp slang.so $out/share/yosys/plugins/slang.so
    '';
  };
}
