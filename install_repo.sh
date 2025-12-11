#!/bin/bash
#
# install_repo.sh - part of the MiniArch project
# Copyright (C) 2024-2025, JustScott, development@justscott.me
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

STDOUT_LOG_PATH="/dev/null"
STDERR_LOG_PATH="/miniarcherrors.log"

SHARED_LIB_URL="https://raw.githubusercontent.com/JustScott/MiniArch/refs/heads/main/shared_lib"

REPO_URL="https://www.github.com/JustScott/MiniArch"
REPO_DIRECTORY="$(basename "$REPO_URL")"

printf "\n\e[36m%s\e[0m" "Download the shared_lib file..."
curl -LO $SHARED_LIB_URL >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH"
if [[ $? -ne 0 ]]
then
    printf "\r\n\e[31m%s %s\e[0m\n" \
        "[!] Failed to install the shared_lib file." \
        "Are you connected to the internet?"
    exit 1
fi

printf "\r\e[32m%s\e[0m %s\n" "[Success]" "Download the shared_lib file"

source ./shared_lib

wipe_pacman_keys() 
{
    {
        umount /etc/pacman.d/gnupg
        rm -rf /etc/pacman.d/gnupg
    } >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Wipe the faulty keyring"
    [[ $? -ne 0 ]] && return 1

    return 0
}

configure_pacman()
{
    pacman-key --init >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Ensure the keyring is properly initialized"
    [[ $? -ne 0 ]] && return 1

    pacman-key --populate archlinux >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Reload the default keys from the keyrings"
    [[ $? -ne 0 ]] && return 1

    pacman -Sy >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Update pacman's package database"
    [[ $? -ne 0 ]] && return 1

    pacman -S --noconfirm archlinux-keyring >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
    task_output $! "$STDERR_LOG_PATH" "Update pacman's keyring"
    [[ $? -ne 0 ]] && return 1

    return 0
}

if ! configure_pacman
then
    wipe_pacman_keys
    if ! configure_pacman
    then
        printf "\e[31m%s\n%s\n%s\e[0m" \
            "[!] Failed to configure pacman keys." \
            " - Likely your system time is off, or your network is having issues." \
            " - Check '$STDERR_LOG_PATH' for error logs."
        exit 1
    fi
fi

pacman -S --noconfirm git >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
task_output $! "$STDERR_LOG_PATH" "Install git"
[[ $? -ne 0 ]] && exit 1

# Clear the old repo if it exists
if [[ -d "$REPO_DIRECTORY" ]]
then
    rm -rf "$REPO_DIRECTORY" &>/dev/null
fi

# Clone the repo
git clone $REPO_URL \
    >>"$STDOUT_LOG_PATH" 2>>"$STDERR_LOG_PATH" &
task_output $! "$STDERR_LOG_PATH" "Clone the MiniArch repo"
[[ $? -ne 0 ]] && exit 1

# Run the install script
bash MiniArch/start_install.sh
