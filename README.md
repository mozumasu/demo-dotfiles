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
   - SSH 鍵を作り、GitHub に Authentication key と Signing key の両方として登録する。nix-secrets と kamatte は private リポジトリなので ssh で取得し、Signing key はコミットの署名に使う (git.nix)。gh はまだ入っていないので nix shell で使う

     ```sh
     ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
     nix --extra-experimental-features "nix-command flakes" shell nixpkgs#gh -c sh -c '
       gh auth login --git-protocol https --scopes admin:public_key,admin:ssh_signing_key
       gh ssh-key add ~/.ssh/id_ed25519.pub --title "<設定名>" --type authentication
       gh ssh-key add ~/.ssh/id_ed25519.pub --title "<設定名>" --type signing
     '
     ssh -T git@github.com
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

   ```sh
   sudo nix run \
     --extra-experimental-features nix-command \
     --extra-experimental-features flakes \
     nix-darwin -- switch --flake "$HOME/dotfiles/.config/nix#<設定名>"
   ```

   設定名は `flake.nix` の `darwinConfigurations` にある Mac の名前 (arabica / robusta)。1 回目の反映でホスト名が設定名に変わるので、
   2 回目以降は `sudo darwin-rebuild switch --flake ~/dotfiles/.config/nix` で `#<設定名>` を省ける
