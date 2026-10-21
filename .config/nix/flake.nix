{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix";
    ccsession.url = "github:sorafujitani/ccsession";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    # riita から呼び出されるようにする。private リポジトリなので ssh で取得する
    kamatte.url = "git+ssh://git@github.com/riita10069/kamatte";
    kamatte.inputs.nixpkgs.follows = "nixpkgs";
    # zsh の abbrev / fzf 補完プラグイン。flake ではないのでソースだけ取り込む
    zeno = {
      url = "github:yuki-yano/zeno.zsh";
      flake = false;
    };
    # Claude Code の応答が英語に切り替わったら日本語で書き直させる Stop hook。flake ではないのでソースだけ取り込む
    claude-code-japanese-guard = {
      url = "github:minorun365/claude-code-japanese-guard";
      flake = false;
    };
    # AI が書いた日本語を自然な日本語に推敲する Claude Code のスキル。flake ではないのでソースだけ取り込む
    yomiyasu = {
      url = "github:nanaism/yomiyasu";
      flake = false;
    };
    # 公開したくない設定 (sops で暗号化済み)。private リポジトリなので ssh で取得する
    nix-secrets = {
      url = "git+ssh://git@github.com/mozumasu/nix-secrets.git";
      flake = false;
    };
  };
  outputs =
    {
      nixpkgs,
      darwin,
      home-manager,
      nix-homebrew,
      treefmt-nix,
      llm-agents,
      ccsession,
      sops-nix,
      kamatte,
      zeno,
      claude-code-japanese-guard,
      yomiyasu,
      nix-secrets,
      ...
    }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in
    {
      # nix fmt / nix run .#formatterの実体
      formatter.aarch64-darwin = treefmtEval.config.build.wrapper;
      checks.aarch64-darwin.formatting = treefmtEval.config.build.check ./.;
      darwinConfigurations.arabica = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./darwin/system.nix
          {
            nix.settings.experimental-features = "nix-command flakes";
            system.primaryUser = "mozumasu";
            users.users."mozumasu".home = "/Users/mozumasu";

            nixpkgs.overlays = [
              llm-agents.overlays.shared-nixpkgs
              # nixpkgs にないパッケージ
              (final: prev: {
                skanehira-ghost = final.callPackage ./packages/ghost.nix { };
                portless = final.callPackage ./packages/portless.nix { };
                version-lsp = final.callPackage ./packages/version-lsp.nix { };
              })
            ];
          }
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {
                inherit
                  ccsession
                  zeno
                  claude-code-japanese-guard
                  yomiyasu
                  nix-secrets
                  ;
              };
              users."mozumasu" = import ./home-manager;
              sharedModules = [
                sops-nix.homeManagerModules.sops
                kamatte.homeManagerModules.default
              ];
            };
          }
          ./darwin/homebrew.nix
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = "mozumasu";
              autoMigrate = true;
            };
          }
        ];
      };
    };
}
