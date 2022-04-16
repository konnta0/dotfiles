# https://www.pulumi.com/docs/reference/cli/#zsh
# pulumi gen-completion zsh 
fpath=(~/.zsh/function $fpath)
autoload -Uz compinit && compinit -i
