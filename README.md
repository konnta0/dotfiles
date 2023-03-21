# Note
Operation is not guaranteed!

## zshrc
```
cd ~/
ln -s /path/to/dotfiles/.zshrc
ln -s /path/to/dotfiles/.zsh
```

## zprezto

### require
https://github.com/sorin-ionescu/prezto

↑Check and run **Installation** 

```
cp -f .zprezto/modules/prompt/functions/prompt_sorin_setup ~/.zprezto/modules/prompt/functions/prompt_sorin_setup
```

Change .zpreztorc
```diff
@@ -38,7 +38,11 @@ zstyle ':prezto:load' pmodule \
   'spectrum' \
   'utility' \
   'completion' \
-  'prompt'
+  'prompt' \
+  'git' \
+  'syntax-highlighting' \
+  'history-substring-search' \
+  'autosuggestions' 
```


## tmux
```
cd ~
ln -s /path/to/dotfiles/.tmux.conf
```

## lazygit
### require
https://github.com/jesseduffield/lazygit

```
cp -f lazygit/config.yml ~/Library/Application\ Support/jesseduffield/lazygit/config.yml
```

### ref
https://github.com/jesseduffield/lazygit/blob/9df133ed8c3b1fc813dbee09a34455ef6be51680/docs/Config.md


## VisualStudio Code
GruvBox Theme

https://marketplace.visualstudio.com/items?itemName=jdinhlife.gruvbox

## Rider
GruvBox Theme

https://plugins.jetbrains.com/plugin/12310-gruvbox-theme


## For Windows
WIP

1. Install WSL
