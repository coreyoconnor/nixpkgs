{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  SDL2,
  aubio,
  boost,
  cmake,
  ffmpeg,
  fmt,
  gettext,
  glew,
  glibmm,
  glm,
  icu,
  libepoxy,
  librsvg,
  libxmlxx,
  nlohmann_json,
  pango,
  pkg-config,
  portaudio,
}:

stdenv.mkDerivation rec {
  pname = "performous";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "performous";
    repo = "performous";
    tag = version;
    hash = "sha256-f70IHA8LqIlkMRwJqSmszx3keStSx50nKcEWLGEjc3g=";
  };

  cedSrc = fetchFromGitHub {
    owner = "performous";
    repo = "compact_enc_det";
    rev = "9ca1351fe0b1e85992a407b0fc54a63e9b3adc6e";
    hash = "sha256-ztfeblR4YnB5+lb+rwOQJjogl+C9vtPH9IVnYO7oxec=";
  };

  patches = [
    ./performous-cmake.patch
    ./performous-fftw.patch
    (fetchpatch {
      name = "performous-ffmpeg.patch";
      url = "https://github.com/performous/performous/commit/f26c27bf74b85fa3e3b150682ab9ecf9aecb3c50.patch";
      excludes = [ ".github/workflows/macos.yml" ];
      hash = "sha256-cQVelET/g2Kx2PlV3pspjEoNIwwn5Yz6enYl5vCMMKo=";
    })
  ];

  postPatch = ''
    mkdir ced-src
    cp -R ${cedSrc}/* ced-src

    substituteInPlace data/CMakeLists.txt \
      --replace "/usr" "$out"
  '';

  nativeBuildInputs = [
    cmake
    gettext
    pkg-config
  ];

  buildInputs = [
    SDL2
    aubio
    boost
    ffmpeg
    fmt
    glew
    glibmm
    glm
    icu
    libepoxy
    librsvg
    libxmlxx
    nlohmann_json
    pango
    portaudio
  ];

  meta = with lib; {
    description = "Karaoke, band and dancing game";
    mainProgram = "performous";
    homepage = "https://performous.org/";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ wegank ];
    platforms = platforms.linux;
  };
}
