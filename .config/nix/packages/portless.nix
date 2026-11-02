{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs_24,
  cacert,
}:

# npm の配布物は依存をバンドル済み (dependencies なし) なので、tarball を展開して node で起動する
stdenvNoCC.mkDerivation rec {
  pname = "portless";
  version = "0.15.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha512-fffMnzfwU/0chJmOMmeAOjFouRsZUmdJagxdqE4DATLw83ssAnHX4BzvNqOI5vBgsuvWLX5ZLg63bzs7zdVFNw==";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/portless
    cp -r . $out/lib/portless
    # engines.node は >=24
    # nixpkgs の nodejs_24 (24.21.0) の内蔵 CA は失効すべき emSign ECC Root CA - G3 を含むので、cacert を読ませる
    makeWrapper ${lib.getExe nodejs_24} $out/bin/portless \
      --set-default NIX_SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --add-flags $out/lib/portless/dist/cli.js
    runHook postInstall
  '';

  meta = {
    description = "Replace port numbers with stable, named local URLs";
    homepage = "https://github.com/vercel-labs/portless";
    license = lib.licenses.asl20;
    mainProgram = "portless";
    platforms = lib.platforms.unix;
  };
}
