source <(kubectl completion zsh)
alias mk="minikube kubectl --"
alias k=kubectl
alias kubectl="minikube kubectl --"
autoload -Uz compinit
compinit
