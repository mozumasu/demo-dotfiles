# dotfiles

macOS の設定を nix-darwin と home-manager で管理する。

## セットアップ

1. コマンドラインデベロッパツール (CLT) を入れる。nix の管理外なので手で入れる

   ```sh
   xcode-select --install
   ```

   入れないと `make` や `swift` などを呼んだときに、インストールを求めるダイアログが出る。Homebrew も CLT を前提にしている

2. Nix を入れる
3. このリポジトリを `~/dotfiles` に clone する
4. 非公開設定 (nix-secrets と kamatte) を取得・復号できるようにする
   - SSH 鍵を作り、GitHub に登録する。nix-secrets と kamatte は private リポジトリなので ssh で取得する

     ```sh
     ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
     pbcopy < ~/.ssh/id_ed25519.pub
     ```

     GitHub の Settings > SSH and GPG keys で、同じ公開鍵を Authentication key と Signing key の両方に登録する (Signing key はコミットの署名に使う。git.nix)。`ssh -T git@github.com` で接続できるか確かめる
   - sops の age 鍵を、今使っている Mac の `~/.config/sops/age/keys.txt` から同じ場所にコピーする。新しく作ると、nix-secrets を暗号化し直し、kamatte の `age_recipients` も書き換えて deploy し直してもらう必要がある
5. 反映する

   ```sh
   sudo nix run nix-darwin -- switch --flake ~/dotfiles/.config/nix#<設定名>
   ```

   設定名は `flake.nix` の `darwinConfigurations` にある Mac の名前 (arabica / robusta)。1 回目の反映でホスト名が設定名に変わるので、
   2 回目以降は `sudo darwin-rebuild switch --flake ~/dotfiles/.config/nix` で `#<設定名>` を省ける
