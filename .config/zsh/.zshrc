alias ll='ls -l'

# 再ログイン後も古い SSH_AUTH_SOCK を引き継ぐことがあるので、ログイン時に張り直す固定パスを使う (home-manager の ssh-agent-socket-link)
# ssh でログインしたときは転送されてきた agent を使いたいので上書きしない
[[ -z $SSH_CONNECTION && -S ~/.ssh/agent.sock ]] && export SSH_AUTH_SOCK=~/.ssh/agent.sock

# fzf の入力欄を上に置き、候補を上から並べる (zeno の補完や zi なども同じ並びになる)
export FZF_DEFAULT_OPTS='--layout=reverse'

# dotfiles/.config/zsh/functions の関数を必要になった時に読み込む
fpath=("$ZDOTDIR/functions" $fpath)
autoload -Uz aws-profile cpath kube-clusters


autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats ' %F{yellow}(%b)%f'

# kubectl の操作対象 (current-context) のクラスタ名を表示する。prod は赤
# kubectl を起動せず kubeconfig を直接読むのでプロンプトが遅くならない
_kube_prompt() {
  kube_prompt=
  local cfg=${${KUBECONFIG:-$HOME/.kube/config}%%:*} line ctx
  [[ -r $cfg ]] || return
  for line in "${(@f)$(<$cfg)}"; do
    [[ $line == current-context:* ]] && { ctx=${${line#current-context:}// /}; break; }
  done
  [[ -n $ctx ]] || return
  local name=${ctx##*/}
  if [[ $name == prod* ]]; then
    kube_prompt=" %F{red}⎈ $name%f"
  else
    kube_prompt=" %F{cyan}⎈ $name%f"
  fi
}

# kubeswitch: switch は KUBECONFIG を書き換えるのでシェル関数として読み込む
if (( $+commands[switcher] )); then
  source <(switcher init zsh)
  compdef _switcher switch
fi

precmd() { vcs_info; _kube_prompt }
setopt PROMPT_SUBST
PROMPT='%F{blue}%~%f${vcs_info_msg_0_}${kube_prompt} '
PROMPT+='%(?.%F{green}.%F{red})❯%f '


# Esc→, で Esc→. の 1 つ手前の単語に差し替える
autoload -Uz copy-earlier-word
zle -N copy-earlier-word
bindkey '^[,' copy-earlier-word

# Esc→e で編集中のコマンドラインを $EDITOR で開く
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^[e' edit-command-line

# Esc→j で次の行を現在の行に連結する (デフォルトの C-x C-j は SKK に C-j を取られて使えない)
bindkey '^[j' vi-join

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
