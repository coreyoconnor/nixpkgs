{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatch-vcs,
  hatchling,
  in-n-out,
  psygnal,
  pydantic,
  pydantic-compat,
  pytestCheckHook,
  pythonOlder,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "app-model";
  version = "0.3.0";
  pyproject = true;

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "pyapp-kit";
    repo = "app-model";
    tag = "v${version}";
    hash = "sha256-PvQ9l2sCi1NaF/SWApWqt6a5AHI5A+zmJRo8gR3ng6Y=";
  };

  build-system = [
    hatch-vcs
    hatchling
  ];

  dependencies = [
    psygnal
    pydantic
    pydantic-compat
    in-n-out
    typing-extensions
  ];

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "app_model" ];

  meta = with lib; {
    description = "Module to implement generic application schema";
    homepage = "https://github.com/pyapp-kit/app-model";
    changelog = "https://github.com/pyapp-kit/app-model/blob/v${version}/CHANGELOG.md";
    license = licenses.bsd3;
    maintainers = with maintainers; [ fab ];
  };
}
