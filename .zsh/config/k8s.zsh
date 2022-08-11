source <(kubectl completion zsh)
alias mk="minikube kubectl --"
alias k=kubectl
autoload -Uz compinit
compinit
