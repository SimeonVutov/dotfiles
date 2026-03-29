# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/dotfiles/.oh-my-zsh"
# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
export ZSH_CUSTOM="$HOME/manual_software"

plugins=(
    git
    archlinux
    zsh-autosuggestions
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

if [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then

  # 1) If no sessions → create "main"
  if ! tmux ls >/dev/null 2>&1; then
    tmux new -s main
  else
    # 2) Search for a session with 0 clients → attach to it
    FREE=$(tmux ls | cut -d: -f1 | while read -r s; do
      [ "$(tmux list-clients -t "$s" | wc -l)" -eq 0 ] && echo "$s" && break
    done)

    if [ -n "$FREE" ]; then
      tmux attach -t "$FREE"
    else
      # 3) All sessions occupied → create a new one with incrementing number
      NEXT=$(tmux ls | cut -d: -f1 | grep -Eo '[0-9]+$' | sort -n | tail -1)
      NEXT=$((NEXT+1))
      tmux new -s "session${NEXT}"
    fi
  fi

fi

# Fixes 'GPGME error: General error' when running pacman inside tmux
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null

# Refresh tmux environment variables before showing each prompt
refresh_tmux_env() {
  if [[ -n "$TMUX" ]]; then
    eval $(tmux show-env -s DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_RUNTIME_DIR 2>/dev/null)
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd refresh_tmux_env

# Always enforce thin beam cursor when returning to prompt
PROMPT=$'%{\e[6 q%}'$PROMPT

# fastfetch. Will be disabled if above colorscript was chosen to install
fastfetch -c $HOME/.config/fastfetch/config.jsonc

# Set-up icons for files/folders in terminal
alias ls='eza -a --icons'
alias ll='eza -al --icons'
alias lt='eza -a --tree --level=1 --icons'

# ==========================================
# power-mode Zsh Autocompletion
# ==========================================
_power_mode() {
  local -a commands

  # If the previous word is -gov, only suggest the two valid governors
  if [[ "${words[CURRENT-1]}" == "-gov" ]]; then
      _values 'governor' 'powersave' 'performance'
      return
  fi

  # If the previous word is -min or -max, just show a helpful hint (no autocomplete needed for numbers)
  if [[ "${words[CURRENT-1]}" == "-min" || "${words[CURRENT-1]}" == "-max" ]]; then
      _message "frequency in MHz (e.g., 415, 3000)"
      return
  fi

  # Default autocomplete options with helpful descriptions
  commands=(
    'ultimate:Activate the Ultimate preset (Full Power)'
    'balanced:Activate the Balanced preset (Power Saver)'
    '-min:Specify minimum frequency (MHz)'
    '-max:Specify maximum frequency (MHz)'
    '-gov:Specify CPU governor (powersave or performance)'
  )
  
  _describe -t commands 'power-mode options' commands
}

# Bind the function to our command
compdef _power_mode power-mode

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export QUESTASIM_HOME=$HOME/manual_software/questa_sim/installation/questasim
export PATH=$QUESTASIM_HOME/linux_x86_64:$PATH

export PICO_SDK_PATH="$HOME/manual_software/pico-sdk"

export Picotool_DIR="$HOME/manual_software/picotool/install/lib/cmake/picotool"

export PATH="$HOME/manual_software/picotool/install/bin:$PATH"
