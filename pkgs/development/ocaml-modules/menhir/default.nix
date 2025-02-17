{
  buildDunePackage,
  menhirLib,
  menhirSdk,
}:

buildDunePackage rec {
  pname = "menhir";

  minimalOCamlVersion = "4.03";

  inherit (menhirLib) version src;

  buildInputs = [
    menhirLib
    menhirSdk
  ];

  meta = menhirSdk.meta // {
    description = "LR(1) parser generator for OCaml";
    mainProgram = "menhir";
  };
}
