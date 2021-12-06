# set homebrew path
#set -gx HOMEBREW_PREFIX "/opt/homebrew";
#set -gx HOMEBREW_CELLAR "/opt/homebrew/Cellar";
#set -gx HOMEBREW_REPOSITORY "/opt/homebrew";
#set -q PATH; or set PATH ''; set -gx PATH "/opt/homebrew/bin" "/opt/homebrew/sbin" $PATH;
#set -q MANPATH; or set MANPATH ''; set -gx MANPATH "/opt/homebrew/share/man" $MANPATH;
#set -q INFOPATH; or set INFOPATH ''; set -gx INFOPATH "/opt/homebrew/share/info" $INFOPATH;

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

starship init fish | source
zoxide init fish | source

source ~/.config/fish/aliases.fish
