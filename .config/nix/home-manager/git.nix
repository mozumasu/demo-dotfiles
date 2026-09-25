{ ... }:
{
  programs.git = {
    enable = true;
    # SSH 鍵でコミット署名。GitHub 側に同じ公開鍵を「Signing key」としても登録する (Authentication key とは別枠)
    signing = {
      format = "ssh";
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
    };
    settings = {
      user = {
        name = "mozumasu";
        email = "ouri1229@gmail.com";
      };
      alias = {
        ci = "commit";
        st = "status";
        br = "branch";
        co = "checkout";
        hist = "log --pretty=format:\"%Cgreen%h %Creset%cd %Cblue[%cn] %Creset%s%C(yellow)%d%C(reset)\" --graph --date=relative --decorate --all";
        df = "!git hist | fzf | awk '{print $2}' | xargs -I {} git diff {}^ {}";
      };
      init.defaultBranch = "main";
      # push -u を省略できる
      push.autoSetupRemote = true;
      branch.autoSetupMerge = "simple";
      merge.conflictStyle = "diff3";
      # https の URL を ssh に読み替える (clone 時に URL を書き換えなくて済む)
      url."git@github.com:".insteadOf = "https://github.com/";
      ghq = {
        root = "~/src";
        user = "mozumasu";
      };
      http.postBuffer = 524288000;
    };
    # 全リポジトリ共通の ignore (~/.config/git/ignore に書き出される)
    ignores = [
      ".DS_Store"
      "**/.claude/settings.local.json"
      "**/CLAUDE.local.md"
    ];
    # 仕事用メールなどマシン固有の差分は git 管理外のファイルに逃がす
    includes = [ { path = "~/.gitconfig.local"; } ];
  };
}
