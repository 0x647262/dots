#!/usr/bin/env bash

# Treat  unset  variables and parameters other than the special parameters "@"
# and "*" as an error when performing parameter expansion.  If expansion is
# attempted on an unset variable or parameter, the shell prints an error
# message, and, if not interactive, exits with a non-zero status.
#set -o nounset

# If set, the return value of a pipeline is the value of the last (rightmost)
# command to exit with a non-zero status, or zero if all commands in the
# pipeline exit successfully. This option is disabled by default.
set -o pipefail

# If set, a command name that is the name of a directory is executed as if it
# were the argument to the cd command. This option is only used by interactive
# shells.
shopt -s autocd

# If set, minor errors in the spelling of a directory component in a cd command
# will be corrected. The errors checked for are transposed characters, a
# missing character, and one character too many. If a correction is found, the
# corrected file name is printed, and the command proceeds. This option is only
# used by interactive shells.
shopt -s cdspell

# If set, bash lists the status of any stopped and running jobs before exiting
# an interactive shell. If any jobs are running, this causes the exit to be
# deferred until a second exit is attempted without an intervening command (see
# JOB CONTROL above). The shell always postpones exiting if any jobs are
# stopped.
shopt -s checkjobs

# If set, the pattern ** used in a pathname expansion context will match a
# files and zero or more directories and subdirectories. If the pattern is
# followed by a /, only directories and subdirectories match.
shopt -s globstar

# If set, the history list is appended to the file named by the value of the
# HISTFILE variable when the shell exits, rather than overwriting the file.
shopt -s histappend

# If set, and readline is being used, a user is given the opportunity to
# re-edit a failed history substitution.
shopt -s histreedit

# If set, and readline is being used, the results of history substitution are
# not immediately passed to the shell parser. Instead, the resulting line is
# loaded into the readline editing buffer, allowing further modification.
shopt -s histverify

# If set, bash matches filenames in a case-insensitive fashion when performing
# pathname expansion (see Pathname Expansion above).
shopt -s nocaseglob

PATH="$HOME/.local/bin:$PATH"

export EDITOR='nvim'
export HISTCONTROL='ignoredups:erasedupes'
export HISTTIMEFORMAT='%FT%H:%M:%S '
export HISTSIZE='100000'
export PATH
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export WEECHAT_HOME="${XDG_CONFIG_HOME}/weechat"

alias cp='cp -rv'
alias ls='ls -lah --color=auto'
alias mkdir='mkdir -pv'
alias mv='mv -v'
alias printenv='printenv | sort'
alias rm='rm -rvi'

# If an instance of ssh-agent is not running for $USER, start one:
if ! pgrep -u "${USER}" ssh-agent > /dev/null; then
  # TODO: Handle $XDG_RUNTIME_DIR being unset
  ssh-agent | grep -v 'echo' > "${XDG_RUNTIME_DIR}/ssh-agent.env"
fi

# If $SSH_AUTH_SOCK is not set, eval its environment file:
if [[ ! "${SSH_AUTH_SOCK}" ]]; then
  eval "$(<"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.env")"
fi

# You should always add the following lines to your .bashrc or whatever
# initialization file is used for all shell invocations (GPG-AGENT(1)):
GPG_TTY="$(tty)"
export GPG_TTY

# Note: in case the gpg-agent receives a signature request, the user might need
# to be prompted for a passphrase, which is necessary for decrypting the stored
# key. Since the ssh-agent protocol does not contain a mechanism for telling
# the agent on which display/terminal it is running, gpg-agent's ssh-support
# will use the TTY or X display where gpg-agent has been started. To switch
# this display to the current one, the following command may be used:
gpg-connect-agent updatestartuptty /bye >/dev/null

function dots() {
  git --git-dir="$HOME/Git/dots" "${@}"
}

function prompt_command() {
  local -r exit_status="$?"
  local -r host='\\h'
  local -r time='\\t'
  local -r user='\\u'
  local -r bold_red="\[\e[31;1m\]"
  local -r bold_green="\[\e[32;1m\]"
  local -r bold_blue="\[\e[34;1m\]"
  local -r bold_white="\[\e[37;1m\]"
  local -r normal="\[\e[0m\]"

  local -r user_color="$bold_green"

  if [[ -n "$IN_NIX_SHELL" ]]; then
    if [[ "$IN_NIX_SHELL" == 'pure' ]]; then
      local -r nix_status_color="$bold_green"
    else
      local -r nix_status_color="$bold_red"
    fi

    local -r nix_shell_status="${nix_status_color}$IN_NIX_SHELL${normal}"
    local -r nix_shell="(${bold_white}nix-shell:${normal} $nix_shell_status) "
  fi

  # Check the exit status of the last command captured by $exit_status:
  if [[ "$exit_status" -eq 0 ]]; then
    # For commands that return an exit status of zero, set the exit status's
    # notifier to green:
    local -r exit_status_color="$bold_green"
  else
    # For commands that return a non-zero exit status, set the exit status's
    # notifier to red:
    local -r exit_status_color="$bold_red"
  fi

  # Check whether or not $SSH_TTY is set:
  if [[ -z "${SSH_TTY:-}" ]]; then
    # For local hosts, set the host's prompt color to blue:
    local -r host_color="$bold_blue"
  else
    # For remote hosts, set the host's prompt color to red:
    local -r host_color="$bold_red"
  fi

  # Check whether or not the current directory is a git repository:
  if git status &> /dev/null; then
    # Check whether the current branch is dirty or not:
    if git diff --quiet; then
      # Clean:
      local -r git_status_color="$bold_green"
    else
      # Dirty:
      local -r git_status_color="$bold_red"
    fi
    # Stylize the current branch:
    local -r git_branch="$(git branch --show-current)"
    local -r git_status=" (${git_status_color}${git_branch}${normal})"
  fi


  # Base prompt:
  #
  #   line of useful information
  #    +
  #
  PS1="$(
    echo -ne "${bold_white}${time} "
    echo -ne "${nix_shell}"
    echo -ne "${user_color}${user}${bold_white}"
    echo -ne "@${host_color}${host}"
    echo -ne "${bold_white}:${normal}${PWD}"
    echo -e "${git_status:-}"
    echo -e "${exit_status_color} +${normal} "
  )"

  # Multi-line prompt:
  #
  #   + $foo # '+' === $PS1
  #   | $bar # '|' === $PS2
  #   | $baz # '|' === $PS2
  #
  PS2="$(
    echo -e "${exit_status_color} |${normal} "
  )"
}

PROMPT_COMMAND=prompt_command

# vim: sw=2 ts=2 et:
