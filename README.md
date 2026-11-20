# dotfiles

macOS の設定を nix-darwin と home-manager で管理する。

## セットアップ

1. コマンドラインデベロッパツール (CLT) を入れる。nix の管理外なので手で入れる

   ```sh
   xcode-select --install
   ```

   入れないと `make` や `swift` などを呼んだときに、インストールを求めるダイアログが出る。Homebrew も CLT を前提にしている

2. Nix を入れる

   ```sh
   sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
   ```

   入れたばかりの Nix では flakes が無効なので、nix-darwin を反映するまでは `nix` に `--extra-experimental-features "nix-command flakes"` を付ける。反映後は nix-darwin が有効にする

3. このリポジトリを `~/dotfiles` に clone する。git は 1 の CLT に入っている

   ```sh
   git clone https://github.com/mozumasu/demo-dotfiles ~/dotfiles
   ```
4. 非公開設定 (nix-secrets と kamatte) を取得・復号できるようにする
   - SSH 鍵を作り、GitHub に Authentication key と Signing key の両方として登録する。nix-secrets と kamatte は private リポジトリなので ssh で取得し、Signing key はコミットの署名に使う (git.nix)。gh はまだ入っていないので nix shell で使う。鍵は 5 の反映で root から使うので、ssh-agent に入れておく

     ```sh
     ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
     nix --extra-experimental-features "nix-command flakes" shell nixpkgs#gh -c sh -c '
       gh auth login --git-protocol https --scopes admin:public_key,admin:ssh_signing_key
       gh ssh-key add ~/.ssh/id_ed25519.pub --title "<設定名>" --type authentication
       gh ssh-key add ~/.ssh/id_ed25519.pub --title "<設定名>" --type signing
     '
     ssh -T git@github.com
     ssh-add ~/.ssh/id_ed25519
     ```

   - sops の age 鍵を、今使っている Mac の `~/.config/sops/age/keys.txt` から AirDrop で送り、同じ場所に置く。鍵は暗号化されずに入っているので、Slack やクラウドストレージは使わない。新しく作ると、nix-secrets を暗号化し直し、kamatte の `age_recipients` も書き換えて deploy し直してもらう必要がある

     ```sh
     # 今使っている Mac で、keys.txt を Finder に出して AirDrop で送る
     open -R ~/.config/sops/age/keys.txt
     # 新しい Mac で、受け取った keys.txt を置く
     mkdir -p ~/.config/sops/age
     mv ~/Downloads/keys.txt ~/.config/sops/age/keys.txt
     chmod 600 ~/.config/sops/age/keys.txt
     # 両方の Mac で同じ公開鍵 (age1...) が出れば正しくコピーできている
     nix --extra-experimental-features "nix-command flakes" shell nixpkgs#age -c age-keygen -y ~/.config/sops/age/keys.txt
     ```
5. 反映する

   sudo で動く nix は root の `~/.ssh` を使うので、そのままでは nix-secrets と kamatte を取得できない。4 で ssh-agent に入れた鍵とユーザーの known_hosts を使わせる

   ```sh
   sudo --preserve-env=SSH_AUTH_SOCK \
     GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=$HOME/.ssh/known_hosts" \
     nix run \
     --extra-experimental-features nix-command \
     --extra-experimental-features flakes \
     nix-darwin -- switch --flake "$HOME/dotfiles/.config/nix#<設定名>"
   ```

   設定名は `flake.nix` の `darwinConfigurations` にある Mac の名前 (arabica / robusta)。1 回目の反映でホスト名が設定名に変わるので、
   2 回目以降は `sudo darwin-rebuild switch --flake ~/dotfiles/.config/nix` で `#<設定名>` を省ける

6. Raycast を設定する。Raycast 本体と `~/.config/raycast/scripts` のリンクは 5 の反映で入るが、Raycast への登録は手でする
   - Script Commands は Raycast の Settings → Extensions → Script Commands → Add Directories で `~/.config/raycast/scripts` を登録する。1 回登録すれば、あとからフォルダに足したスクリプトも Raycast に出る
   - `.config/raycast/extensions-src` の自作の拡張は次のスクリプトでまとめてビルドして Raycast に入れる。npm は入れていないので、スクリプトの中で nix shell を使う。拡張の名前を渡すと、その拡張だけを入れる

     ```sh
     ~/dotfiles/.config/raycast/install-extensions.sh
     ```

   - AWS VPN Client を操作するスクリプト (aws-vpn-connect.sh など) を使うには、システム設定 → プライバシーとセキュリティ → アクセシビリティで Raycast を許可する

7. nb のノートを clone する。nb は `NB_DIR` (`~/src/github.com/mozumasu/nb`) の下のフォルダをノートブックとして扱い、既定のノートブックは `home` なので、`home` という名前で clone する

   ```sh
   mkdir -p ~/src/github.com/mozumasu/nb
   git clone https://github.com/mozumasu/nb-home ~/src/github.com/mozumasu/nb/home
   ```
