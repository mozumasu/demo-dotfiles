{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "version-lsp";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "skanehira";
    repo = "version-lsp";
    rev = "v${version}";
    hash = "sha256-fG7Al1Z/BqYVXT2Nug1JesytAGIdb/8NPZTqAm4D2ko=";
  };

  cargoHash = "sha256-v1aVcuKKzV3WPXOHHz74WaeAIvz3ADPuvpVkeHXOKkc=";

  # Tests fetch versions from package registries, which doesn't work in Nix sandbox
  doCheck = false;

  meta = {
    description = "LSP server that provides version checking diagnostics for package dependency files";
    homepage = "https://github.com/skanehira/version-lsp";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "version-lsp";
    platforms = lib.platforms.unix;
  };
}
