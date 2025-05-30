{
  lib,
  stdenv,
  fetchFromGitHub,
  zlib,
  protobufc,
  autoreconfHook,
}:

stdenv.mkDerivation rec {
  pname = "libgadu";
  version = "1.12.2";

  src = fetchFromGitHub {
    owner = "wojtekka";
    repo = pname;
    rev = version;
    sha256 = "1s16cripy5w9k12534qb012iwc5m9qcjyrywgsziyn3kl3i0aa8h";
  };

  propagatedBuildInputs = [ zlib ];
  buildInputs = [ protobufc ];
  nativeBuildInputs = [ autoreconfHook ];

  meta = {
    broken = true; # Unmaintained, will be removed in 25.11
    description = "Library to deal with gadu-gadu protocol (most popular polish IM protocol)";
    homepage = "https://libgadu.net/index.en.html";
    platforms = lib.platforms.linux;
    license = lib.licenses.lgpl21;
  };

}
