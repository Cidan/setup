#!/bin/bash
set -e

node_version="v8.10.0"

function join_by { local IFS="$1"; shift; echo "$*"; }

declare -a apt_packages=(
  "git"
  "wget"
  "build-essential"
  "cmake"
  "python-dev"
  "python3-dev"
  "openjdk-8-jdk-headless"
  "python-pip"
  "python3-pip"
  "htop"
  "iftop"
  "lib32stdc++6"
  "apt-transport-https"
  "ca-certificates"
  "curl"
  "software-properties-common"
  "fuse"
)

declare -a pip_packages=(
  "neovim"
)

declare -a desktop_packages=(
  "https://go.microsoft.com/fwlink/?LinkID=760868"
  "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
)

declare -a vscode_packages=(
  "auiworks.amvim"
  "fallenwood.viml"
  "robertohuertasm.vscode-icons"
  "redhat.java"
  "lukehoban.go"
  "ms-python.python"
  "alefragnani.project-manager"
  "Dart-Code.dart-code"
)

function install_apt {
  PK=$(join_by ' ' "${apt_packages[@]}")
  sudo apt-get update
  sudo apt-get install -y $PK
}

function install_pip {
  PK=$(join_by ' ' "${pip_packages[@]}")
  sudo pip install --upgrade $PK
}

function install_vscode_pkg {
  for i in ${vscode_packages[@]}; do
    code --install-extension $i
  done

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

  if [ ! -f ~/.config/Code/User/settings.json ]; then
    echo "Installing default vscode settings."
    curl -sfLo ~/.config/Code/User/settings.json --create-dirs \
      https://raw.githubusercontent.com/Cidan/setup/master/settings.json
  fi

  if [ ! -f !/.config/Code/User/keybindings.json ]; then
    echo "Installing default vscode key bindings."
    curl -sfLo ~/.config/Code/User/keybindings.json --create-dirs \
      https://raw.githubusercontent.com/Cidan/setup/master/keybindings.json
  fi
}

function install_docker {
  if [ "($command -v docker)" ]; then
    echo "Docker already installed, skipping."
    return
  fi

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
  
  sudo apt-get update
  sudo apt-get install -y docker-ce
  sudo adduser $USER docker

  sudo curl -sfLo /usr/local/bin/docker-compose \
    https://github.com/docker/compose/releases/download/1.19.0/docker-compose-Linux-x86_64
  sudo chmod +x /usr/local/bin/docker-compose
}

function install_flutter {
  mkdir -p ~/git/
  cd ~/git
  if [ ! -f ~/git/flutter/.git/config ]; then
    echo "Installing flutter"
    git clone -b beta https://github.com/flutter/flutter.git
    export PATH=`pwd`/flutter/bin:$PATH
  fi

  if ! grep -Fxq "flutter/bin" ~/.profile; then
    echo "Updating path for flutter"
    echo 'PATH=$PATH:~/git/flutter/bin' >> ~/.profile
  fi
}

function install_android_sdk {
  if [ -d ~/Android/Sdk ]; then
    return
  fi
  echo "Downloading Android Studio"
  curl -sfLo /tmp/android-tools.zip \
    https://dl.google.com/dl/android/studio/ide-zips/3.0.1.0/android-studio-ide-171.4443003-linux.zip
  echo "Installing Android Studio"
  mkdir -p ~/.android_studio
  cd ~/.android_studio
  unzip /tmp/android-tools.zip
}

function base_profile {
  if grep -Fxq "set meta-flag on" /etc/bash.bashrc; then
    return
  fi
  cat <<EOF > /tmp/profile.sh
force_color_prompt=yes
export EDITOR=vim
set meta-flag on
set input-meta on
set convert-meta off
set output-meta on
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

set show-all-if-ambiguous on
EOF
  cat /tmp/profile.sh | sudo tee -a /etc/bash.bashrc
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
  
  mkdir -p ~/.local/share/nvim/site/autoload/
  
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
      https://raw.githubusercontent.com/Cidan/setup/master/init.vim
    nvim +PlugInstall +qall
  fi

  if ! grep -Fxq "alias vim=nvim" /etc/bash.bashrc; then
    echo "Setting up vim alias"
    echo "alias vim=nvim" | sudo tee -a /etc/bash.bashrc
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
    echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
    . /etc/profile.d/go.sh
  fi
}

## Install Node
function install_node {
  echo "Installing Node"
  if [ -f /usr/local/node/bin/node ]; then
    echo "Node already installed, skipping."
  else
    curl -sfLo /tmp/node.tar.xz https://nodejs.org/dist/${node_version}/node-${node_version}-linux-x64.tar.xz
    cd /usr/local
    sudo tar -xf /tmp/node.tar.xz
    sudo mv node-${node_version}-linux-x64 node
  fi

  if [ -f /etc/profile.d/node.sh ]; then
    echo "Node profile already set, skipping."
  else
    echo "Setting up node profile"
    echo 'export PATH=$PATH:/usr/local/node/bin' | sudo tee /etc/profile.d/node.sh
    . /etc/profile.d/node.sh
  fi
}

mkdir -p /tmp/setup_packages/
rm -f /tmp/setup_packages/* || true

## Kick off our installs
u2f
install_apt
install_pip
install_docker
base_profile
cloud_sdk
github
install_go
install_node
install_vim

## Check for our desktop apps
if [[ "$1" == "--desktop" ]]; then
  install_desktop
  install_vscode_pkg
  install_flutter
  install_android_sdk
fi

echo -e "You're all set -- be sure to setup this key on GitHub:\n\n"

cat ~/.ssh/id_github.pub

exec -l $SHELL
