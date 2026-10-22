{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
}:

# npm の配布物はビルド済みだが依存はバンドルされていない。lockfile が同梱されないので、
# devDependencies (monorepo 内の @repo/* を含む) を除いた package.json から生成した lockfile を同梱する
buildNpmPackage rec {
  pname = "bee";
  version = "1.1.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@nulab/bee/-/bee-${version}.tgz";
    hash = "sha512-c1RVAcxdv4eA+JiVqmlNFX7p5n3Y5BgKnLC0TTOUp4PGDOJ2OqTXnoW+uraBNcURLauiQDRIqP8kfJlNIfg0AQ==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe jq} 'del(.devDependencies, .scripts)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  npmDepsHash = "sha256-kT/dhyRc9BHmjpZU1nrycf6hnVBS4q86lE8gniDOuck=";

  dontNpmBuild = true;

  meta = {
    description = "Bring Backlog to your command line";
    homepage = "https://github.com/nulab/bee";
    license = lib.licenses.mit;
    mainProgram = "bee";
    platforms = lib.platforms.unix;
  };
}
