{
  stdenv,
  lib,
  nixosTests,
  fetchFromGitHub,
  fetchYarnDeps,
  applyPatches,
  bundlerEnv,
  defaultGemConfig,
  callPackage,
  writeText,
  procps,
  ruby,
  postgresql,
  imlib2,
  jq,
  moreutils,
  nodejs,
  yarn,
  yarn2nix-moretea,
  cacert,
  redis,
}:

let
  pname = "zammad";
  version = "6.3.1";

  src = applyPatches {

    src = fetchFromGitHub (lib.importJSON ./source.json);

    patches = [
      ./fix-sendmail-location.diff
    ];

    postPatch = ''
      sed -i -e "s|ruby '3.2.[0-9]\+'|ruby '${ruby.version}'|" Gemfile
      sed -i -e "s|ruby 3.2.[0-9]\+p[0-9]\+|ruby ${ruby.version}|" Gemfile.lock
      sed -i -e "s|3.2.[0-9]\+|${ruby.version}|" .ruby-version
      ${jq}/bin/jq '. += {name: "Zammad", version: "${version}"}' package.json | ${moreutils}/bin/sponge package.json
    '';
  };

  databaseConfig = writeText "database.yml" ''
    production:
      url: <%= ENV['DATABASE_URL'] %>
  '';

  secretsConfig = writeText "secrets.yml" ''
    production:
      secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
  '';

  rubyEnv = bundlerEnv {
    name = "${pname}-gems-${version}";
    inherit version;

    # Which ruby version to select:
    #   https://docs.zammad.org/en/latest/prerequisites/software.html#ruby-programming-language
    inherit ruby;

    gemdir = src;
    gemset = ./gemset.nix;
    groups = [
      "assets"
      "unicorn" # server
      "test"
      "mysql"
      "puma"
      "development"
      "postgres" # database
    ];
    gemConfig = defaultGemConfig // {
      pg = attrs: {
        buildFlags = [ "--with-pg-config=${lib.getDev postgresql}/bin/pg_config" ];
      };
      rszr = attrs: {
        buildInputs = [
          imlib2
          imlib2.dev
        ];
        buildFlags = [ "--without-imlib2-config" ];
      };
      mini_racer = attrs: {
        buildFlags = [
          "--with-v8-dir=\"${nodejs.libv8}\""
        ];
        dontBuild = false;
        postPatch = ''
          substituteInPlace ext/mini_racer_extension/extconf.rb \
            --replace Libv8.configure_makefile '$CPPFLAGS += " -x c++"; Libv8.configure_makefile'
        '';
      };
    };
  };

  yarnEnv = yarn2nix-moretea.mkYarnPackage {
    pname = "${pname}-node-modules";
    inherit version src;
    packageJSON = ./package.json;

    offlineCache = fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-3DuTirYd6lAQd5PRbdOa/6QaMknIqNMTVnxEESF0N/c=";
    };

    packageResolutions.minimatch = "9.0.3";

    yarnPreBuild = ''
      mkdir -p deps/Zammad
      cp -r ${src}/.eslint-plugin-zammad deps/Zammad/.eslint-plugin-zammad
      chmod -R +w deps/Zammad/.eslint-plugin-zammad
    '';
  };

in
stdenv.mkDerivation {
  inherit pname version src;

  buildInputs = [
    rubyEnv
    rubyEnv.wrappedRuby
    rubyEnv.bundler
    yarn
    nodejs
    procps
    cacert
  ];

  nativeBuildInputs = [
    redis
    postgresql
  ];

  RAILS_ENV = "production";

  buildPhase = ''
    node_modules=${yarnEnv}/libexec/Zammad/node_modules
    ${yarn2nix-moretea.linkNodeModulesHook}

    mkdir redis-work
    pushd redis-work
    redis-server &
    REDIS_PID=$!
    popd

    mkdir postgres-work
    initdb -D postgres-work --encoding=utf8
    pg_ctl start -D postgres-work -o "-k $PWD/postgres-work -h '''"
    createuser -h $PWD/postgres-work zammad -R -S
    createdb -h $PWD/postgres-work --encoding=utf8 --owner=zammad zammad

    rake DATABASE_URL="postgresql:///zammad?host=$PWD/postgres-work" assets:precompile

    kill $REDIS_PID
    pg_ctl stop -D postgres-work -m immediate
    rm -r redis-work postgres-work
  '';

  installPhase = ''
    cp -R . $out
    cp ${databaseConfig} $out/config/database.yml
    cp ${secretsConfig} $out/config/secrets.yml
    sed -i -e "s|info|debug|" $out/config/environments/production.rb
  '';

  passthru = {
    inherit rubyEnv yarnEnv;
    updateScript = [
      "${callPackage ./update.nix { }}/bin/update.sh"
      pname
      (toString ./.)
    ];
    tests = { inherit (nixosTests) zammad; };
  };

  meta = with lib; {
    description = "Zammad, a web-based, open source user support/ticketing solution";
    homepage = "https://zammad.org";
    license = licenses.agpl3Plus;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = with maintainers; [
      n0emis
      taeer
      netali
    ];
  };
}
