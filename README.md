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
4. 非公開設定 (nix-secrets) を取得・復号できるようにする
   - GitHub に SSH で接続できるようにする (private リポジトリを ssh で取得するため)
   - sops の age 鍵を `~/.config/sops/age/keys.txt` に置く
5. 反映する

   ```sh
   sudo nix run nix-darwin -- switch --flake ~/dotfiles/.config/nix#arabica
   ```

   2 回目以降は `sudo darwin-rebuild switch --flake ~/dotfiles/.config/nix#arabica`
