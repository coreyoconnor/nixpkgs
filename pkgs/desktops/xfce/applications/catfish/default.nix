{
  lib,
  fetchFromGitLab,
  gitUpdater,
  file,
  which,
  intltool,
  gobject-introspection,
  findutils,
  xdg-utils,
  dconf,
  gtk3,
  python3Packages,
  xfconf,
  wrapGAppsHook3,
}:

python3Packages.buildPythonApplication rec {
  pname = "catfish";
  version = "4.18.0";

  src = fetchFromGitLab {
    domain = "gitlab.xfce.org";
    owner = "apps";
    repo = pname;
    rev = "${pname}-${version}";
    sha256 = "sha256-hfbIgSFn48++eGrJXzhXRxhWkrjgTYsr7BX/n0EXhGo=";
  };

  nativeBuildInputs = [
    python3Packages.distutils-extra
    file
    which
    intltool
    gobject-introspection # for setup hook populating GI_TYPELIB_PATH
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    dconf
    python3Packages.pyxdg
    python3Packages.ptyprocess
    python3Packages.pycairo
  ];

  propagatedBuildInputs = [
    python3Packages.dbus-python
    python3Packages.pygobject3
    python3Packages.pexpect
    xdg-utils
    findutils
    xfconf
  ];

  # Explicitly set the prefix dir in "setup.py" because setuptools is
  # not using "$out" as the prefix when installing catfish data. In
  # particular the variable "__catfish_data_directory__" in
  # "catfishconfig.py" is being set to a subdirectory in the python
  # path in the store.
  postPatch = ''
    sed -i "/^        if self.root/i\\        self.prefix = \"$out\"" setup.py
  '';

  # Disable check because there is no test in the source distribution
  doCheck = false;

  dontWrapGApps = true;

  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  passthru.updateScript = gitUpdater { rev-prefix = "${pname}-"; };

  meta = with lib; {
    homepage = "https://docs.xfce.org/apps/catfish/start";
    description = "Handy file search tool";
    mainProgram = "catfish";
    longDescription = ''
      Catfish is a handy file searching tool. The interface is
      intentionally lightweight and simple, using only GTK 3.
      You can configure it to your needs by using several command line
      options.
    '';
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ] ++ teams.xfce.members;
  };
}
