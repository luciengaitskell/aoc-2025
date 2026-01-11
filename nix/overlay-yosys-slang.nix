# Temporary overlay until yosys-slang lands in nixpkgs
# https://github.com/NixOS/nixpkgs/pull/472800

final: prev: {
  yosys-slang = prev.stdenv.mkDerivation rec {
    pname = "yosys-slang";
    version = "git-2024-02-02";

    src = prev.fetchFromGitHub {
      owner = "povik";
      repo = "yosys-slang";
      rev = "64b44616a3798f07453b14ea03e4ac8a16b77313";
      hash = "sha256-kfu59/M3+IM+5ZMd+Oy4IZf4JWuVtPDlkHprk0FB8t4=";
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
