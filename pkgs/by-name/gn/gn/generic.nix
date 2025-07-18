{
  stdenv,
  lib,
  fetchgit,
  fetchpatch,
  cctools,
  writeText,
  ninja,
  python3,
  ...
}:

{
  rev,
  revNum,
  version,
  sha256,
}:

let
  revShort = builtins.substring 0 7 rev;
  lastCommitPosition = writeText "last_commit_position.h" ''
    #ifndef OUT_LAST_COMMIT_POSITION_H_
    #define OUT_LAST_COMMIT_POSITION_H_

    #define LAST_COMMIT_POSITION_NUM ${revNum}
    #define LAST_COMMIT_POSITION "${revNum} (${revShort})"

    #endif  // OUT_LAST_COMMIT_POSITION_H_
  '';

in
stdenv.mkDerivation {
  pname = "gn-unstable";
  inherit version;

  src = fetchgit {
    # Note: The TAR-Archives (+archive/${rev}.tar.gz) are not deterministic!
    url = "https://gn.googlesource.com/gn";
    inherit rev sha256;
  };

  patches = lib.optionals (lib.versionOlder revNum "2233") [
    (fetchpatch {
      name = "LFS64.patch";
      url = "https://gn.googlesource.com/gn/+/b5ff50936a726ff3c8d4dfe2a0ae120e6ce1350d%5E%21/?format=TEXT";
      decode = "base64 -d";
      hash = "sha256-/kh8t/Ip1EG2OIhydS//st/C80KJ4P31vGx7j8QpFh0=";
    })
  ];

  nativeBuildInputs = [
    ninja
    python3
  ];
  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    cctools
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error";
  # Relax hardening as otherwise gn unstable 2024-06-06 and later fail with:
  # cc1plus: error: '-Wformat-security' ignored without '-Wformat' [-Werror=format-security]
  ${if (lib.versionAtLeast revNum "2233") then "hardeningDisable" else null} = [ "format" ];

  buildPhase = ''
    python build/gen.py --no-last-commit-position
    ln -s ${lastCommitPosition} out/last_commit_position.h
    ninja -j $NIX_BUILD_CORES -C out gn
  '';

  installPhase = ''
    install -vD out/gn "$out/bin/gn"
  '';

  setupHook = ./setup-hook.sh;

  meta = with lib; {
    description = "Meta-build system that generates build files for Ninja";
    mainProgram = "gn";
    homepage = "https://gn.googlesource.com/gn";
    license = licenses.bsd3;
    platforms = platforms.unix;
    maintainers = with maintainers; [
      stesie
      matthewbauer
      primeos
    ];
  };
}
