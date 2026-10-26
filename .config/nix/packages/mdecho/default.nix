{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

# npm の配布物はビルド済みだが依存はバンドルされていない。lockfile が同梱されないので、
# devDependencies を除いた package.json から生成した lockfile を同梱する
buildNpmPackage rec {
  pname = "mdecho";
  version = "1.0.5";

  src = fetchurl {
    url = "https://registry.npmjs.org/mdecho/-/mdecho-${version}.tgz";
    hash = "sha512-2+D0XHIYUlM1eWSaLvqPwaIzrVSGMt+oaS0Vnz9/HNSCrj4zHgcN90kOM18u4Nr3HTCtTDE9prvTml9Xd1HrjA==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe jq} 'del(.devDependencies, .scripts)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  npmDepsHash = "sha256-KqMjqpWubwcKwGGgGaWyBCw6yEYlE3Qw8Mp50bDzUKA=";

  dontNpmBuild = true;

  meta = {
    description = "Review AI-generated Markdown in the browser and reply to it";
    homepage = "https://github.com/eetann/mdecho";
    license = lib.licenses.mit;
    mainProgram = "mdecho";
    platforms = lib.platforms.unix;
  };
}
