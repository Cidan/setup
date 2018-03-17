#!/bin/bash
set -e

function join_by { local IFS="$1"; shift; echo "$*"; }

declare -a apt_packages=(
  "git"
  "wget"
  "build-essential"
  "cmake"
  "python-dev"
  "python3-dev"
  "openjdk-9-jdk-headless"
  "python-pip"
  "python3-pip"
)

declare -a pip_packages=(
  "neovim"
)

declare -a desktop_packages=(
  "https://go.microsoft.com/fwlink/?LinkID=760868"
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
)

function install_apt {
  PK=$(join_by ' ' "${apt_packages[@]}")
  sudo apt-get update
  sudo apt-get install -y $PK
}

function install_desktop {
  echo -e "Installing desktop deps...\n"
  cd /tmp/setup_packages/

  for i in "${desktop_packages[@]}"; do
    echo "Downloading $i"
    curl -sOL $i
  done

  for i in `ls -1`; do
    echo "Installing $i"
    sudo dpkg -i $i || true
  done
  sudo apt-get install -f -y
}

function install_pip {
  PK=$(join_by ' ' "${pip_packages[@]}")
  sudo pip install --upgrade $PK
}

## Install u2f udev rules and reload
function u2f {
  if [ -f /etc/udev/rules.d/70-u2f.rules ]; then
    echo "U2F rules already installed, skipping."
    return
  fi
  echo "Installing U2F udev rules"
  echo '
ACTION!="add|change", GOTO="u2f_end"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0113|0114|0115|0116|0120|0200|0402|0403|0406|0407|0410", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2581", ATTRS{idProduct}=="f1d0", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1e0d", ATTRS{idProduct}=="f1d0|f1ae", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="096e|2ccf", ATTRS{idProduct}=="0880", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="096e", ATTRS{idProduct}=="0850|0852|0853|0854|0856|0858|085a|085b", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24dc", ATTRS{idProduct}=="0101", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="8acf", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1a44", ATTRS{idProduct}=="00bb", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2abe", ATTRS{idProduct}=="1002", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ea8", ATTRS{idProduct}=="f025", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="4287", TAG+="uaccess"
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="5026", TAG+="uaccess"
LABEL="u2f_end"' > /tmp/u2f.udev
  sudo mv /tmp/u2f.udev /etc/udev/rules.d/70-u2f.rules
  sudo udevadm control --reload-rules && sudo udevadm trigger
}

## Setup the Google Cloud SDK for all users
function cloud_sdk {
  echo "Checking for Google Cloud SDK"
  if [ "($command -v gcloud)" ]; then
    echo "Google Cloud SDK installed, skipping"
    return
  fi
  curl https://sdk.cloud.google.com > /tmp/setup_packages/sdk.sh
  sudo bash /tmp/setup_packages/sdk.sh --disable-prompts --install-dir=/usr/local/gcloud
  sudo ln -s /usr/local/gcloud/google-cloud-sdk/completion.bash.inc /etc/bash_completion.d/
  sudo ln -s /usr/local/gcloud/google-cloud-sdk/path.bash.inc /etc/profile.d/gcloud.sh
}

# Setup a new github key.
function github {
  mkdir -p ~/.ssh
  touch ~/.ssh/config

  if grep -Fxq "Host github.com" ~/.ssh/config; then
    echo "SSH entry for github found, skipping."
  else
    echo "Generating SSH config for github"
    echo '
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_github
' >> ~/.ssh/config
  fi

  if [ -f ~/.ssh/id_github ]; then
    echo "SSH key for github found, skipping."
  else
    echo "Generating SSH key for github"
    ssh-keygen -b 4096 -t RSA -f ~/.ssh/id_github -N ''
  fi
}

## Install vim and all packages
function install_vim {
  if [ -f /usr/local/bin/nvim ]; then
    echo "Neo Vim already installed, skipping."
  else
    sudo curl -fLo /usr/local/bin/nvim https://github.com/neovim/neovim/releases/download/v0.2.2/nvim.appimage
    sudo chmod +x /usr/local/bin/nvim
  fi

  if [ -f ~/.local/share/nvim/site/autoload/plug.vim ]; then
    echo "vim plug already installed, skipping."
  else
    curl -sfLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  fi

  mkdir -p ~/.config/nvim

  if [ -f ~/.config/nvim/init.vim ]; then
    echo "Neo Vim already configured, skipping."
  else
    echo "Installing Neo Vim config"
    curl -sfLo ~/.config/nvim/init.vim --create-dirs \
      https://raw.githubusercontent.com/Cidan/vim/master/init.vim
    nvim +PlugInstall +qall
  fi

  if [ ! -f /etc/profile.d/vim.sh ]; then
    echo "Setting up vim alias"
    echo '
alias vim=nvim
' >/tmp/vim.sh
    sudo mv /tmp/vim.sh /etc/profile.d/vim.sh
    . /etc/profile.d/vim.sh
  fi
}

## Install Golang
function install_go {
  echo "Installing go"
  if [ -f /usr/local/go/bin/go ]; then
    echo "Golang already installed, skipping."
  else
    curl -sfLo /tmp/go.tar.gz https://dl.google.com/go/go1.10.linux-amd64.tar.gz
    cd /usr/local/
    sudo tar -xzf /tmp/go.tar.gz
  fi

  if [ -f /etc/profile.d/go.sh ]; then
    echo "Go profile already set, skipping."
  else
    echo "Setting up go profile"
    echo '
export PATH=$PATH:/usr/local/go/bin
' > /tmp/go.sh
    sudo mv /tmp/go.sh /etc/profile.d/go.sh
    . /etc/profile.d/go.sh
  fi
}
mkdir -p /tmp/setup_packages/
rm -f /tmp/setup_packages/* || true

## Knock u2f out first
u2f
install_apt
install_pip

## Check for our desktop apps
if [[ "$1" == "--desktop" ]]; then
  install_desktop
fi

## Install everything else
cloud_sdk
github
install_go
## TODO: port to repo
install_vim

echo -e "You're all set -- be sure to setup this key on GitHub:\n\n"

cat ~/.ssh/id_github.pub