{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  libxml2,
  gtk2,
}:

stdenv.mkDerivation rec {
  version = "2.1.11";
  pname = "ggobi";

  src = fetchurl {
    url = "http://www.ggobi.org/downloads/ggobi-${version}.tar.bz2";
    sha256 = "2c4ddc3ab71877ba184523e47b0637526e6f3701bd9afb6472e6dfc25646aed7";
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    libxml2
    gtk2
  ];

  configureFlags = [ "--with-all-plugins" ];

  hardeningDisable = [ "format" ];

  meta = with lib; {
    broken = true;
    description = "Visualization program for exploring high-dimensional data";
    homepage = "http://www.ggobi.org/";
    license = licenses.cpl10;
    platforms = platforms.linux;
    maintainers = [ maintainers.michelk ];
    mainProgram = "ggobi";
  };
}
