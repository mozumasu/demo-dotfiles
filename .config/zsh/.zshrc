alias ll='ls -l'

# dotfiles/.config/zsh/functions の関数を必要になった時に読み込む
fpath=("$ZDOTDIR/functions" $fpath)
autoload -Uz aws-profile cpath


autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b)%f'
setopt PROMPT_SUBST
PROMPT='%F{blue}%~%f${vcs_info_msg_0_} '
PROMPT+='%(?.%F{green}.%F{red})❯%f '


# Esc→, で Esc→. の 1 つ手前の単語に差し替える
autoload -Uz copy-earlier-word
zle -N copy-earlier-word
bindkey '^[,' copy-earlier-word

# C-g で ghq 管理のリポジトリを fzf で選んで移動する
function ghq-fzf() {
  local src=$(ghq list | fzf --preview "bat --color=always --style=header,grid --line-range :80 $(ghq root)/{}/README.*")
  if [ -n "$src" ]; then
    BUFFER="cd $(ghq root)/$src"
    zle accept-line
  fi
  zle -R -c
}
zle -N ghq-fzf
bindkey '^g' ghq-fzf

# z でよく行くディレクトリに移動する (zi で fzf から選ぶ)
eval "$(zoxide init zsh)"

# zeno.zsh: abbrev スニペット展開と fzf 補完 (設定は ~/.config/zeno/config.yml)
export ZENO_HOME="$HOME/.config/zeno"
if [[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zeno/zeno.zsh" ]]; then
  source "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zeno/zeno.zsh"
fi
if [[ -n $ZENO_LOADED ]]; then
  bindkey ' ' zeno-auto-snippet
  bindkey '^m' zeno-auto-snippet-and-accept-line
  bindkey '^i' zeno-completion
  bindkey '^x ' zeno-insert-space
  bindkey '^xx' zeno-insert-snippet
  bindkey '^r' zeno-history-selection
fi

# zsh-autosuggestions: 履歴から入力候補を薄く表示する (→ か C-e で確定)
if [[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# direnv: ディレクトリの .envrc を読み込む (`use flake` で flake.nix の devShell に入る)
if (( $+commands[direnv] )); then
  eval "$(direnv hook zsh)"
fi
