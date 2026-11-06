{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "newrelic-cli";
  version = "0.115.8";

  src = fetchFromGitHub {
    owner = "newrelic";
    repo = "newrelic-cli";
    rev = "v${version}";
    hash = "sha256-ZlyRZs3AAKmcWteAzsmy+MrFvuokkxpSGhL9RkVVcEQ=";
  };

  vendorHash = "sha256-jvs/dQf5+TTajksz7n1J86ZpXhGkSxT96bTLxwrT8UM=";

  subPackages = [ "cmd/newrelic" ];

  env.CGO_ENABLED = 0;

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
    "-X main.appName=newrelic"
    "-X github.com/newrelic/newrelic-cli/internal/cli.version=${version}"
  ];

  # Tests call the New Relic API, which doesn't work in Nix sandbox
  doCheck = false;

  meta = {
    description = "The New Relic Command Line Interface";
    homepage = "https://github.com/newrelic/newrelic-cli";
    license = lib.licenses.asl20;
    maintainers = [ ];
    mainProgram = "newrelic";
    platforms = lib.platforms.unix;
  };
}
