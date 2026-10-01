alias ll='ls -l'

# dotfiles/.config/zsh/functions の関数を必要になった時に読み込む
fpath=("$ZDOTDIR/functions" $fpath)
autoload -Uz aws-profile


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
