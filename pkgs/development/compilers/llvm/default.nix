{
  lib,
  callPackage,
  stdenvAdapters,
  buildPackages,
  targetPackages,
  stdenv,
  gcc12Stdenv,
  pkgs,
  # This is the default binutils, but with *this* version of LLD rather
  # than the default LLVM version's, if LLD is the choice. We use these for
  # the `useLLVM` bootstrapping below.
  bootBintoolsNoLibc ? if stdenv.targetPlatform.linker == "lld" then null else pkgs.bintoolsNoLibc,
  bootBintools ? if stdenv.targetPlatform.linker == "lld" then null else pkgs.bintools,
  llvmVersions ? { },
}:
let
  versions = {
    "13.0.1".officialRelease.sha256 = "06dv6h5dmvzdxbif2s8njki6h32796v368dyb5945x8gjj72xh7k";
    "14.0.6".officialRelease.sha256 = "sha256-vffu4HilvYwtzwgq+NlS26m65DGbp6OSSne2aje1yJE=";
    "15.0.7".officialRelease.sha256 = "sha256-wjuZQyXQ/jsmvy6y1aksCcEDXGBjuhpgngF3XQJ/T4s=";
    "16.0.6".officialRelease.sha256 = "sha256-fspqSReX+VD+Nl/Cfq+tDcdPtnQPV1IRopNDfd5VtUs=";
    "17.0.6".officialRelease.sha256 = "sha256-8MEDLLhocshmxoEBRSKlJ/GzJ8nfuzQ8qn0X/vLA+ag=";
    "18.1.8".officialRelease.sha256 = "sha256-iiZKMRo/WxJaBXct9GdAcAT3cz9d9pnAcO1mmR6oPNE=";
    "19.0.0-git".gitRelease = {
      rev = "cebf77fb936a7270c7e3fa5c4a7e76216321d385";
      rev-version = "19.0.0-unstable-2024-04-07";
      sha256 = "sha256-616tscgsiFgHQcXW4KzK5srrudYizQFnJVM6K0qRf+I=";
    };
  } // llvmVersions;

  mkPackage =
    {
      name ? null,
      officialRelease ? null,
      gitRelease ? null,
      monorepoSrc ? null,
      version ? null,
    }@args:
    let
      args' = {
        name = null;
        officialRelease = null;
        gitRelease = null;
        monorepoSrc = null;
        version = null;
      } // args;
      inherit
        (import ./common/common-let.nix {
          inherit lib;
          inherit (args') gitRelease officialRelease version;
        })
        releaseInfo
        ;
      inherit (releaseInfo) release_version;
      attrName =
        args.name or (if (gitRelease != null) then "git" else lib.versions.major release_version);
    in
    callPackage ./common {
      inherit (stdenvAdapters) overrideCC;
      buildLlvmTools = buildPackages."llvmPackages_${attrName}".tools;
      targetLlvmLibraries =
        targetPackages."llvmPackages_${attrName}".libraries or llvmPackages."${attrName}".libraries;
      targetLlvm = targetPackages."llvmPackages_${attrName}".llvm or llvmPackages."${attrName}".llvm;
      stdenv =
        if (lib.versions.major release_version == "13" && stdenv.cc.cc.isGNU or false) then
          gcc12Stdenv
        else
          stdenv; # does not build with gcc13
      inherit bootBintoolsNoLibc bootBintools;
      inherit (args')
        officialRelease
        gitRelease
        monorepoSrc
        version
        ;
    };

  llvmPackages = lib.mapAttrs' (
    version: args:
    lib.nameValuePair (if (args ? gitRelease) then "git" else lib.versions.major version) (
      mkPackage (args // { inherit version; })
    )
  ) versions;
in
llvmPackages
