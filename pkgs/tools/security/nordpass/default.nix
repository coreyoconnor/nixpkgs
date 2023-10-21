{ fetchurl, lib, stdenv, squashfsTools, xorg, alsa-lib, makeShellWrapper, wrapGAppsHook, openssl, freetype
, glib, pango, cairo, atk, gdk-pixbuf, gtk3, cups, nspr, nss_latest, libpng, libnotify
, libgcrypt, systemd, fontconfig, dbus, expat, curlWithGnuTls, zlib, gnome
, at-spi2-atk, at-spi2-core, libdrm, mesa, libxkbcommon
, harfbuzz, libsecret, buildFHSEnv
}:

let
  version = "5.15.28";

  deps = pkgs: [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curlWithGnuTls
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libdrm
    libgcrypt
    libnotify
    libpng
    libsecret
    libxkbcommon
    mesa
    nspr
    nss_latest
    pango
    stdenv.cc.cc
    systemd
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libxcb
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libxshmfence
    xorg.libXtst
    zlib
  ];

  thisPackage = stdenv.mkDerivation {
    pname = "nordpass";

    inherit version;

    # determine from
    # curl -H 'Snap-Device-Series: 16' http://api.snapcraft.io/v2/snaps/info/nordpass
    src = fetchurl {
      url = "https://api.snapcraft.io/api/v1/snaps/download/00CQ2MvSr0Ex7zwdGhCYTa0ZLMw3H6hf_180.snap";
      hash = "sha256-RbKq+nQpNOMw6hOjJK07CsPH+grT4MH0saBXGdNje34=";
    };

    nativeBuildInputs = [ squashfsTools ];

    dontStrip = true;
    dontPatchELF = true;

    unpackPhase = ''
      runHook preUnpack
      unsquashfs "$src"
      cd squashfs-root
      runHook postUnpack
    '';

    # Prevent double wrapping
    dontWrapGApps = true;

    installPhase =
      ''
        runHook preInstall

        mkdir -p "$out/opt/nordpass"
        cp -r . "$out/opt/nordpass/"

        mkdir -p $out/bin
        ln -s "$out/opt/nordpass/nordpass" "$out/bin/nordpass"

        # Desktop file
        mkdir -p "$out/share/applications/"
        cp "$out/opt/nordpass/meta/gui/nordpass.desktop" "$out/share/applications/"
        # Icon
        mkdir -p "$out/share/icons/hicolor/512x512/apps"
        cp "$out/opt/nordpass/meta/gui/icon.png" \
          "$out/share/icons/hicolor/512x512/apps/nordpass.png"

        sed -i -e "s#^Icon=.*\$#Icon=$out/share/icons/hicolor/512x512/apps/nordpass.png#" \
          "$out/share/applications/nordpass.desktop"

        runHook postInstall
      '';

    meta = with lib; {
      homepage = "https://nordpass.com/";
      description = "NordPass application re-packaged from the snap distribution";
      license = licenses.unfree;
      mainProgram = "nordpass";
      maintainers = with maintainers; [ coreyoconnor ];
      platforms = platforms.linux;
    };
  };
in

buildFHSEnv {
  name = "nordpass";
  targetPkgs = pkgs: (deps pkgs) ++ [ thisPackage ];
  runScript = "nordpass";

  extraInstallCommands = ''
    mkdir -p "$out/share"
    cp -r ${thisPackage}/share/* "$out/share/"
  '';
}

