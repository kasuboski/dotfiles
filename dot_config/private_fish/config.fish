if test -d /opt/homebrew
  eval (/opt/homebrew/bin/brew shellenv)
end

if test -d /usr/local/bin/brew
  eval (/usr/local/bin/brew shellenv)
end

if test -d (brew --prefix)"/share/fish/completions"
  set -gp fish_complete_path (brew --prefix)/share/fish/completions
end

if test -d (brew --prefix)"/share/fish/vendor_completions.d"
  set -gp fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
end

fish_add_path -m ~/.local/bin
fish_add_path -m ~/.cargo/bin
fish_add_path -m "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fish_add_path -m /usr/local/go/bin
fish_add_path -m ~/.krew/bin

set -Ux PYENV_ROOT $HOME/.pyenv
fish_add_path -m $PYENV_ROOT/bin

status is-login; and pyenv init --path | source
status is-interactive; and pyenv init - | source

starship init fish | source
zoxide init fish | source

source ~/.config/fish/aliases.fish
