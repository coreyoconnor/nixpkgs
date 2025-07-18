{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  git,
  qt6Packages,
  openal,
  glew,
  vulkan-headers,
  vulkan-loader,
  libpng,
  libSM,
  ffmpeg,
  libevdev,
  libusb1,
  zlib,
  curl,
  wolfssl,
  python3,
  pugixml,
  flatbuffers,
  llvm_18,
  cubeb,
  opencv,
  enableDiscordRpc ? false,
  faudioSupport ? true,
  faudio,
  SDL2,
  sdl3,
  waylandSupport ? true,
  wayland,
  wrapGAppsHook3,
}:

let
  # Keep these separate so the update script can regex them
  rpcs3GitVersion = "17736-c86a25079";
  rpcs3Version = "0.0.36-17736-c86a25079";
  rpcs3Revision = "c86a25079518032d73395a79979970acb2581a91";
  rpcs3Hash = "sha256-e+mT3qn1oz1fh2bqu5YM+m774Can34If57Kd1T1EGbk=";

  inherit (qt6Packages)
    qtbase
    qtmultimedia
    wrapQtAppsHook
    qtwayland
    ;
in
stdenv.mkDerivation {
  pname = "rpcs3";
  version = rpcs3Version;

  src = fetchFromGitHub {
    owner = "RPCS3";
    repo = "rpcs3";
    rev = rpcs3Revision;
    fetchSubmodules = true;
    hash = rpcs3Hash;
  };

  patches = [
    # Modified from https://github.com/RPCS3/rpcs3/pull/17009; doesn't apply cleanly due to intermediate commits
    ./fix-qt6.9-compilation.patch
  ];

  passthru.updateScript = ./update.sh;

  preConfigure = ''
    cat > ./rpcs3/git-version.h <<EOF
    #define RPCS3_GIT_VERSION "${rpcs3GitVersion}"
    #define RPCS3_GIT_FULL_BRANCH "RPCS3/rpcs3/master"
    #define RPCS3_GIT_BRANCH "HEAD"
    #define RPCS3_GIT_VERSION_NO_UPDATE 1
    EOF
  '';

  cmakeFlags = [
    (lib.cmakeBool "USE_SYSTEM_ZLIB" true)
    (lib.cmakeBool "USE_SYSTEM_LIBUSB" true)
    (lib.cmakeBool "USE_SYSTEM_LIBPNG" true)
    (lib.cmakeBool "USE_SYSTEM_FFMPEG" true)
    (lib.cmakeBool "USE_SYSTEM_CURL" true)
    (lib.cmakeBool "USE_SYSTEM_WOLFSSL" true)
    (lib.cmakeBool "USE_SYSTEM_FAUDIO" true)
    (lib.cmakeBool "USE_SYSTEM_OPENAL" true)
    (lib.cmakeBool "USE_SYSTEM_PUGIXML" true)
    (lib.cmakeBool "USE_SYSTEM_FLATBUFFERS" true)
    (lib.cmakeBool "USE_SYSTEM_SDL" true)
    (lib.cmakeBool "USE_SYSTEM_OPENCV" true)
    (lib.cmakeBool "USE_SDL" true)
    (lib.cmakeBool "WITH_LLVM" true)
    (lib.cmakeBool "BUILD_LLVM" false)
    (lib.cmakeBool "USE_NATIVE_INSTRUCTIONS" false)
    (lib.cmakeBool "USE_DISCORD_RPC" enableDiscordRpc)
    (lib.cmakeBool "USE_FAUDIO" faudioSupport)
  ];

  dontWrapGApps = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    git
    wrapQtAppsHook
    wrapGAppsHook3
  ];

  buildInputs =
    [
      qtbase
      qtmultimedia
      openal
      glew
      vulkan-headers
      vulkan-loader
      libpng
      ffmpeg
      libevdev
      zlib
      libusb1
      curl
      wolfssl
      python3
      pugixml
      SDL2 # Still needed by FAudio's CMake
      sdl3
      flatbuffers
      llvm_18
      libSM
      opencv.cxxdev
    ]
    ++ cubeb.passthru.backendLibs
    ++ lib.optional faudioSupport faudio
    ++ lib.optionals waylandSupport [
      wayland
      qtwayland
    ];

  preFixup = ''
    qtWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  postInstall = ''
    # Taken from https://wiki.rpcs3.net/index.php?title=Help:Controller_Configuration
    install -D ${./99-ds3-controllers.rules} $out/etc/udev/rules.d/99-ds3-controllers.rules
    install -D ${./99-ds4-controllers.rules} $out/etc/udev/rules.d/99-ds4-controllers.rules
    install -D ${./99-dualsense-controllers.rules} $out/etc/udev/rules.d/99-dualsense-controllers.rules
  '';

  meta = with lib; {
    description = "PS3 emulator/debugger";
    homepage = "https://rpcs3.net/";
    maintainers = with maintainers; [
      abbradar
      neonfuz
      ilian
      zane
    ];
    license = licenses.gpl2Only;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "rpcs3";
  };
}
