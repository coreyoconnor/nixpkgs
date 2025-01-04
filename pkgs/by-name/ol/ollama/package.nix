{
  lib,
  buildGoModule,
  fetchFromGitHub,
  buildEnv,
  overrideCC,
  makeWrapper,
  stdenv,
  addDriverRunpath,
  nix-update-script,

  cmake,
  gcc-unwrapped,
  gcc12,
  gitMinimal,
  clblast,
  libdrm,
  rocmPackages,
  cudaPackages,
  darwin,
  autoAddDriverRunpath,
  autoPatchelfHook,

  nixosTests,
  testers,
  ollama,
  ollama-rocm,
  ollama-cuda,

  config,
  # one of `[ null false "rocm" "cuda" ]`
  acceleration ? null,
}:

assert builtins.elem acceleration [
  null
  false
  "rocm"
  "cuda"
];

let
  pname = "ollama";
  # don't forget to invalidate all hashes each update
  version = "0.5.4";

  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    rev = "v${version}";
    hash = "sha256-JyP7A1+u9Vs6ynOKDwun1qLBsjN+CVHIv39Hh2TYa2U=";
    fetchSubmodules = true;
  };

  vendorHash = "sha256-xz9v91Im6xTLPzmYoVecdF7XiPKBZk3qou1SGokgPXQ=";

  validateFallback = lib.warnIf (config.rocmSupport && config.cudaSupport) (lib.concatStrings [
    "both `nixpkgs.config.rocmSupport` and `nixpkgs.config.cudaSupport` are enabled, "
    "but they are mutually exclusive; falling back to cpu"
  ]) (!(config.rocmSupport && config.cudaSupport));
  shouldEnable =
    mode: fallback: (acceleration == mode) || (fallback && acceleration == null && validateFallback);

  rocmRequested = shouldEnable "rocm" config.rocmSupport;
  cudaRequested = shouldEnable "cuda" config.cudaSupport;

  enableRocm = rocmRequested && stdenv.hostPlatform.isLinux;
  enableCuda = cudaRequested && stdenv.hostPlatform.isLinux;

  rocmLibs = [
    rocmPackages.clr
    rocmPackages.hipblas-common
    rocmPackages.hipblas
    rocmPackages.rocblas
    rocmPackages.rocsolver
    rocmPackages.rocsparse
    rocmPackages.rocm-device-libs
    rocmPackages.rocm-smi
  ];
  rocmPath = buildEnv {
    name = "rocm-path";
    paths = rocmLibs;
  };

  cudaLibs = [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
    cudaPackages.cuda_cccl
  ];

  # Extract the major version of CUDA. e.g. 11 12
  cudaMajorVersion = lib.versions.major cudaPackages.cuda_cudart.version;

  cudaToolkit = buildEnv {
    # ollama hardcodes the major version in the Makefile to support different variants.
    # - https://github.com/ollama/ollama/blob/v0.4.4/llama/Makefile#L17-L18
    name = "cuda-merged-${cudaMajorVersion}";
    paths = map lib.getLib cudaLibs ++ [
      (lib.getOutput "static" cudaPackages.cuda_cudart)
      (lib.getBin (cudaPackages.cuda_nvcc.__spliced.buildHost or cudaPackages.cuda_nvcc))
    ];
  };

  cudaPath = lib.removeSuffix "-${cudaMajorVersion}" cudaToolkit;

  metalFrameworks = with darwin.apple_sdk_11_0.frameworks; [
    Accelerate
    Metal
    MetalKit
    MetalPerformanceShaders
  ];

  wrapperOptions =
    [
      # ollama embeds llama-cpp binaries which actually run the ai models
      # these llama-cpp binaries are unaffected by the ollama binary's DT_RUNPATH
      # LD_LIBRARY_PATH is temporarily required to use the gpu
      # until these llama-cpp binaries can have their runpath patched
      "--suffix LD_LIBRARY_PATH : '${addDriverRunpath.driverLink}/lib'"
    ]
    ++ lib.optionals enableRocm [
      "--suffix LD_LIBRARY_PATH : '${rocmPath}/lib'"
      "--set-default HIP_PATH '${rocmPath}'"
    ]
    ++ lib.optionals enableCuda [
      "--suffix LD_LIBRARY_PATH : '${lib.makeLibraryPath (map lib.getLib cudaLibs)}'"
    ];
  wrapperArgs = builtins.concatStringsSep " " wrapperOptions;

  goBuild =
    if enableCuda then buildGoModule.override { stdenv = overrideCC stdenv gcc12; } else buildGoModule;
  inherit (lib) licenses platforms maintainers;
in
goBuild {
  inherit
    pname
    version
    src
    vendorHash
    ;

  env =
    lib.optionalAttrs enableRocm {
      ROCM_PATH = rocmPath;
      CLBlast_DIR = "${clblast}/lib/cmake/CLBlast";
      HIP_PATH = rocmPath;
      CFLAGS = "-Wno-c++17-extensions -I${rocmPath}/include";
      CXXFLAGS = "-Wno-c++17-extensions -I${rocmPath}/include";
    }
    // lib.optionalAttrs (enableRocm && (rocmPackages.clr.localGpuTargets or false) != false) {
      # If rocm CLR is set to build for an exact set of targets reuse that target list,
      # otherwise let ollama use its builtin defaults
      HIP_ARCHS = lib.concatStringsSep ";" rocmPackages.clr.localGpuTargets;
    }
    // lib.optionalAttrs enableCuda {
      CUDA_PATH = cudaPath;
    };

  nativeBuildInputs =
    [
      cmake
      gitMinimal
      # rpaths of runners end up wrong without this
      autoPatchelfHook
    ]
    ++ lib.optionals enableRocm [
      rocmPackages.llvm.bintools
      rocmLibs
    ]
    ++ lib.optionals enableCuda [ cudaPackages.cuda_nvcc ]
    ++ lib.optionals (enableRocm || enableCuda) [
      makeWrapper
      autoAddDriverRunpath
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin metalFrameworks;

  buildInputs =
    [ gcc-unwrapped.lib ]
    ++ lib.optionals enableRocm (rocmLibs ++ [ libdrm ])
    ++ lib.optionals enableCuda cudaLibs
    ++ lib.optionals stdenv.hostPlatform.isDarwin metalFrameworks;

  postPatch = ''
    # replace inaccurate version number with actual release version
    substituteInPlace version/version.go --replace-fail 0.0.0 '${version}'
  '';

  overrideModAttrs = (
    finalAttrs: prevAttrs: {
      # don't run llama.cpp build in the module fetch phase
      preBuild = "";
    }
  );

  preBuild = ''
    # build llama.cpp libraries for ollama
    make -j $NIX_BUILD_CORES
  '';

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    # copy runner folders into $out/lib/ollama/runners/
    # end result should be multiple folders inside runners/ each with their own ollama_llama_server binary
    mkdir -p $out/lib/ollama/runners
    cp -r llama/build/*/runners/* $out/lib/ollama/runners/
  '';

  postFixup =
    ''
      # the app doesn't appear functional at the moment, so hide it
      mv "$out/bin/app" "$out/bin/.ollama-app"
    ''
    + lib.optionalString (enableRocm || enableCuda) ''
      # expose runtime libraries necessary to use the gpu
      wrapProgram "$out/bin/ollama" ${wrapperArgs}
    '';

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/ollama/ollama/version.Version=${version}"
    "-X=github.com/ollama/ollama/server.mode=release"
  ];

  passthru = {
    tests =
      {
        inherit ollama;
        version = testers.testVersion {
          inherit version;
          package = ollama;
        };
      }
      // lib.optionalAttrs stdenv.hostPlatform.isLinux {
        inherit ollama-rocm ollama-cuda;
        service = nixosTests.ollama;
        service-cuda = nixosTests.ollama-cuda;
        service-rocm = nixosTests.ollama-rocm;
      };
  } // lib.optionalAttrs (!enableRocm && !enableCuda) { updateScript = nix-update-script { }; };

  meta = {
    description =
      "Get up and running with large language models locally"
      + lib.optionalString rocmRequested ", using ROCm for AMD GPU acceleration"
      + lib.optionalString cudaRequested ", using CUDA for NVIDIA GPU acceleration";
    homepage = "https://github.com/ollama/ollama";
    changelog = "https://github.com/ollama/ollama/releases/tag/v${version}";
    license = licenses.mit;
    platforms = if (rocmRequested || cudaRequested) then platforms.linux else platforms.unix;
    mainProgram = "ollama";
    maintainers = with maintainers; [
      abysssol
      dit7ya
      elohmeier
      roydubnium
    ];
  };
}
