{ pkgs, callPackage }:

with pkgs;

{
  cc-wrapper =
    with builtins;
    let
      pkgNames = (attrNames pkgs);
      llvmTests =
        let
          pkgSets = lib.pipe pkgNames [
            (filter (lib.hasPrefix "llvmPackages"))
            (filter (n: n != "rocmPackages.llvm"))
            # Are throw aliases.
            (filter (n: n != "llvmPackages_rocm"))
            (filter (n: n != "llvmPackages_latest"))
            (filter (n: n != "llvmPackages_6"))
            (filter (n: n != "llvmPackages_7"))
            (filter (n: n != "llvmPackages_8"))
            (filter (n: n != "llvmPackages_9"))
            (filter (n: n != "llvmPackages_10"))
            (filter (n: n != "llvmPackages_11"))
          ];
          tests = lib.genAttrs pkgSets (
            name:
            recurseIntoAttrs {
              clang = callPackage ./cc-wrapper { stdenv = pkgs.${name}.stdenv; };
              libcxx = callPackage ./cc-wrapper { stdenv = pkgs.${name}.libcxxStdenv; };
            }
          );
        in
        tests;
      gccTests =
        let
          pkgSets = lib.pipe (attrNames pkgs) (
            [
              (filter (lib.hasPrefix "gcc"))
              (filter (lib.hasSuffix "Stdenv"))
              (filter (n: n != "gccCrossLibcStdenv"))
              (filter (n: n != "gcc49Stdenv"))
              (filter (n: n != "gcc6Stdenv"))
            ]
            ++
              lib.optionals
                (
                  !(
                    (stdenv.buildPlatform.isLinux && stdenv.buildPlatform.isx86_64)
                    && (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64)
                  )
                )
                [
                  (filter (n: !lib.hasSuffix "MultiStdenv" n))
                ]
          );
        in
        lib.genAttrs pkgSets (name: callPackage ./cc-wrapper { stdenv = pkgs.${name}; });
    in
    recurseIntoAttrs {
      default = callPackage ./cc-wrapper { };

      supported = stdenv.mkDerivation {
        name = "cc-wrapper-supported";
        builtGCC =
          let
            inherit (lib) filterAttrs;
            sets = lib.pipe gccTests [
              (filterAttrs (_: v: lib.meta.availableOn stdenv.hostPlatform v.stdenv.cc))
              # Broken
              (filterAttrs (n: _: n != "gccMultiStdenv"))
            ];
          in
          toJSON sets;

        builtLLVM =
          let
            inherit (lib) filterAttrs;
            sets = lib.pipe llvmTests [
              (filterAttrs (_: v: lib.meta.availableOn stdenv.hostPlatform v.clang.stdenv.cc))
              (filterAttrs (_: v: lib.meta.availableOn stdenv.hostPlatform v.libcxx.stdenv.cc))
            ];
          in
          toJSON sets;
        buildCommand = ''
          touch $out
        '';
      };

      llvmTests = recurseIntoAttrs llvmTests;
      inherit gccTests;
    };

  devShellTools = callPackage ../build-support/dev-shell-tools/tests { };

  stdenv-inputs = callPackage ./stdenv-inputs { };
  stdenv = callPackage ./stdenv { };

  hardeningFlags = recurseIntoAttrs (callPackage ./cc-wrapper/hardening.nix { });
  hardeningFlags-gcc = recurseIntoAttrs (
    callPackage ./cc-wrapper/hardening.nix {
      stdenv = gccStdenv;
    }
  );
  hardeningFlags-clang = recurseIntoAttrs (
    callPackage ./cc-wrapper/hardening.nix {
      stdenv = llvmPackages.stdenv;
    }
  );

  config = callPackage ./config.nix { };

  top-level = callPackage ./top-level { };

  haskell = callPackage ./haskell { };

  hooks = callPackage ./hooks { };

  cc-multilib-gcc = callPackage ./cc-wrapper/multilib.nix { stdenv = gccMultiStdenv; };
  cc-multilib-clang = callPackage ./cc-wrapper/multilib.nix { stdenv = clangMultiStdenv; };

  compress-drv = callPackage ../build-support/compress-drv/test.nix { };

  fetchurl = callPackages ../build-support/fetchurl/tests.nix { };
  fetchtorrent = callPackages ../build-support/fetchtorrent/tests.nix { };
  fetchpatch = callPackages ../build-support/fetchpatch/tests.nix { };
  fetchpatch2 = callPackages ../build-support/fetchpatch/tests.nix { fetchpatch = fetchpatch2; };
  fetchDebianPatch = callPackages ../build-support/fetchdebianpatch/tests.nix { };
  fetchzip = callPackages ../build-support/fetchzip/tests.nix { };
  fetchgit = callPackages ../build-support/fetchgit/tests.nix { };
  fetchFirefoxAddon = callPackages ../build-support/fetchfirefoxaddon/tests.nix { };
  fetchPypiLegacy = callPackages ../build-support/fetchpypilegacy/tests.nix { };

  install-shell-files = callPackage ./install-shell-files { };

  checkpointBuildTools = callPackage ./checkpointBuild { };

  kernel-config = callPackage ./kernel.nix { };

  ld-library-path = callPackage ./ld-library-path { };

  cross = callPackage ./cross { } // {
    __attrsFailEvaluation = true;
  };

  php = recurseIntoAttrs (callPackages ./php { });

  pkg-config = recurseIntoAttrs (callPackage ../top-level/pkg-config/tests.nix { }) // {
    __recurseIntoDerivationForReleaseJobs = true;
  };

  buildRustCrate = callPackage ../build-support/rust/build-rust-crate/test { };
  importCargoLock = callPackage ../build-support/rust/test/import-cargo-lock { };

  vim = callPackage ./vim { };

  nixos-functions = callPackage ./nixos-functions { };

  nixosOptionsDoc = callPackage ../../nixos/lib/make-options-doc/tests.nix { };

  overriding = callPackage ./overriding.nix { };

  texlive = callPackage ./texlive { };

  cuda = callPackage ./cuda { };

  trivial-builders = callPackage ../build-support/trivial-builders/test/default.nix { };

  writers = callPackage ../build-support/writers/test.nix { };

  testers = callPackage ../build-support/testers/test/default.nix { };

  dhall = callPackage ./dhall { };

  cue-validation = callPackage ./cue { };

  coq = callPackage ./coq { };

  dotnet = recurseIntoAttrs (callPackages ./dotnet { });

  makeHardcodeGsettingsPatch = callPackage ./make-hardcode-gsettings-patch { };

  makeWrapper = callPackage ./make-wrapper { };
  makeBinaryWrapper = callPackage ./make-binary-wrapper {
    makeBinaryWrapper = pkgs.makeBinaryWrapper.override {
      # Enable sanitizers in the tests only, to avoid the performance cost in regular usage.
      # The sanitizers cause errors on aarch64-darwin, see https://github.com/NixOS/nixpkgs/pull/150079#issuecomment-994132734
      sanitizers =
        pkgs.lib.optionals (!(pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isAarch64))
          [
            "undefined"
            "address"
          ];
    };
  };

  pkgs-lib = recurseIntoAttrs (import ../pkgs-lib/tests { inherit pkgs; });

  buildFHSEnv = recurseIntoAttrs (callPackages ./buildFHSEnv { });

  nixpkgs-check-by-name = throw "tests.nixpkgs-check-by-name is now specified in a separate repository: https://github.com/NixOS/nixpkgs-check-by-name";

  auto-patchelf-hook = callPackage ./auto-patchelf-hook { };

  # Accumulate all passthru.tests from arrayUtilities into a single attribute set.
  arrayUtilities = recurseIntoAttrs (
    lib.concatMapAttrs (
      name: value:
      lib.optionalAttrs (value ? passthru.tests) {
        ${name} = value.passthru.tests;
      }
    ) arrayUtilities
  );

  srcOnly = callPackage ../build-support/src-only/tests.nix { };

  systemd = callPackage ./systemd { };

  replaceVars = recurseIntoAttrs (callPackage ./replace-vars { });

  substitute = recurseIntoAttrs (callPackage ./substitute { });

  build-environment-info = callPackage ./build-environment-info { };

  rust-hooks = recurseIntoAttrs (callPackages ../build-support/rust/hooks/test { });
}
