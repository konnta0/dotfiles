if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

alias f='fzf'
alias ll='ls -alG'
alias tm='tmux -u'
alias cd-dev='cd ${HOME}/dev'
alias op='open'
alias lg='lazygit'
export PATH="$PATH":"$HOME/.pub-cache/bin"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ -d ~/.zsh/config ] && while read x; do source $x; done < <(find ~/.zsh/config -type f)
