# Manifest Structure

## Image
The format of image has two main sections a Containerfile section and a files section, the container file is obviously the container file used to build the image and it can reference files declared under the files section. The image section relies on [name](#name) being defined under container and it cannot be separated from it.

### Containerfile
```yaml
image:
    Containerfile: |
        FROM docker.io/library/ubuntu:latest
        LABEL name="dev-box" \
            version="latest" \
            usage="This image is meant to be used with a container manager like distrobox or toolbx" \
            summary="Custom image load with all of my dev tools"
        COPY pkgs.txt /tmp/pkgs.txt
        COPY testing/doc.md /opt/testing/
        RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install $(cat /tmp/pkgs.txt | xargs)
```

For above example the file declared pkgs.txt is defined under the files section, the file read from Containerfile will be written to a tmp file and the usage of `: |` affects its formatting, you may try different things to adjust its formatting as you see fit ive just found that `: |` worked best when i tested this and kept the file looking identical

### Files
```yaml
image:
    files:
    - pkgs.txt: |
        vim
        git
    - testing/doc.md: this is en example file
```

Files are a list of uniquely keyed values and the usage of `/` aids in giving dir support so that files are not the only files written to the tmp dir if this is something the user wishes to do so but do be careful with it as using `../../` or any other similar path will result in writing outside the given tmp dir.
These files/dirs will be written into the root of the tmp dir with the exact name that they are declared with and can be used inside the container file as if they already exist and are normal files (see usage in [Containerfile](#containerfile)).

## Container
The container section holds all information required to create and setup a container using distrobox.

### name
```yaml
container:
    name: testing
```

Gives the container a name this is a required section it is also used to give the built image from podman a name.

### home
```yaml
container:
    home: /home/.container/testing
```

An optional section it declares a home space to use for the container (passes -H arg to distrobox during create)

### export
```yaml
container:
    export:
    - vim
    - git
```

An optional section it declares packages and/or apps to export out of the container into host (uses distrobox-export command inside the container)

### import
```yaml
container:
    export:
    - nano
    - fish
```

An optional section it declares packages and/or apps to import into the container from host.

NOTE: it can only handle binaries and not .desktop files

### scripts
A very large section responsible for the majority of setup done for the container, there are in total three sub-sections declared for scripts which are: pre, peri, post.

#### pre
```yaml
container:
    scripts:
        pre:
        - echo "this is a test"
        - |
            set -e
            echo "so is this also a test"
            cat /tmp/foobar
            mkdir -p /tmp/something
```

pre scripts run before the container is started and is meant to be responsible for setting up the container space like setting up its home and config files used by apps that are installed by the container. Pre scripts are given a natural order from their indexing the first item declared on the list is given the name 0.sh and the second is given the name 1.sh this results in the first item to run before the second.
All of the scripts for pre run using hosts bash and can run practically anything so be careful on what you do here to avoid breaking your system or doing something irreversible.

#### peri
```yaml
container:
    scripts:
        pre:
        - echo "this is a test in peri"
        - |
            set -e
            echo "so is this also a test in peri"
            cat /tmp/foobar/cat\ file
            mkdir -p /tmp/something/foobar
```

peri scripts run inside the created container after it is booted for the first time ever, just like pre scripts are given a natural order but are executed inside the container using the containers bash instead, all of the commands ran there should be running inside the container and be using its home. After it has finished the container is stopped

#### post
```yaml
container:
    scripts:
        post:
        - echo "this is a test in post"
        - |
            set -e
            echo "so is this also a test in post"
            cat /tmp/foobar/blabla
            mkdir -p /tmp/foobar/foo/bar
```

just like peri post scripts run inside the created container but it is ran after peri stops the container and just like pre the scripts are given a natural order and just like peri the scripts are ran inside the container using its bash. Virtually theres no difference between post and peri other than the fact that one is ran after the other and one is ran at second boot instead of first boot. Just like peri the container will be stopped after this is finished running.

# Full example
Below is an example container file ive created and have used to setup my dev container. This file may be outdated it was created in 28/02/25 and worked at that time.

```yaml
container:
    name: dev
    home: /home/.containers/dev
    export:
    - git
    - yq
    - jetbrains-toolbox.desktop
    scripts:
        pre:
        - |
            set -e
            __CONTAINER_NAME="$1"
            __CONTAINER_HOME="$2"
            # setup dirs
            [ -d "$__CONTAINER_HOME" ] || mkdir -p "$__CONTAINER_HOME"
            mkdir -p "$__CONTAINER_HOME/Documents"
            # link dirs
            ln -s "$HOME/Documents/Programming/" "$__CONTAINER_HOME/Documents/Programming"
            ln -s "$HOME/.gitconfig" "$__CONTAINER_HOME/.gitconfig"
            exit 0
        peri:
        - |
            curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_GHC_VERSION=latest BOOTSTRAP_HASKELL_CABAL_VERSION=latest BOOTSTRAP_HASKELL_INSTALL_STACK=1 BOOTSTRAP_HASKELL_INSTALL_HLS=1 BOOTSTRAP_HASKELL_ADJUST_BASHRC=A sh
            echo '. $HOME/.ghcup/env' >> $HOME/.bashrc
        - |
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh
            chmod +x /tmp/rustup.sh
            /tmp/rustup.sh -y
        - curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash
        - |
            NVM_VERSION=$(curl -s "https://github.com/nvm-sh/nvm/tags" | grep "Link--primary Link" | awk -F '</a>' '{print $1}' | awk -F '>' '{print $NF}' | head -n 1)
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash
        - |
            curl -fsSL https://pyenv.run | bash
            echo 'export PYENV_ROOT="$HOME/.pyenv"' >> $HOME/.bashrc
            echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"' >> $HOME/.bashrc
            echo 'eval "$(pyenv init - bash)"' >> $HOME/.bashrc
        - curl -s "https://get.sdkman.io" | bash
        - |
            LUAVER_VERSION=$(curl -s "https://github.com/DhavalKapil/luaver/releases/tag/v1.1.0" | grep "Link--primary Link" | awk -F '</a>' '{print $1}' | awk -F '>' '{print $NF}' | head -n 1)
            curl -fsSL https://raw.githubusercontent.com/dhavalkapil/luaver/master/install.sh | sh -s - -r ${LUAVER_VERSION}
        - |
            curl -L https://install.perlbrew.pl | bash
            echo "source ~/perl5/perlbrew/etc/bashrc" >> ~/.bashrc
        - |
            JETBRAINS_TOOLBOX_VERSION="2.5.2.35332"
            wget -q -O- https://download.jetbrains.com/toolbox/jetbrains-toolbox-${JETBRAINS_TOOLBOX_VERSION}.tar.gz | tar -xz -C /tmp
            /tmp/jetbrains-toolbox-${JETBRAINS_TOOLBOX_VERSION}/jetbrains-toolbox &
            bg_pid=$! # get above bg process pid to kill later
            sleep 2
            pgrep $bg_pid && pkill $bg_pid
        # - eval "$(curl https://get.x-cmd.com)"
        post:
        - |
            # NOTE: repeating all steps in bashrc instead of sourcing bashrc as that didnt work
            [[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"
            export NVM_DIR="$HOME/.config/nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
            export PYENV_ROOT="$HOME/.pyenv"
            [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
            eval "$(pyenv init - bash)"            
            export SDKMAN_DIR="$HOME/.sdkman"
            [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
            [ -s ~/.luaver/luaver ] && . ~/.luaver/luaver
            source ~/perl5/perlbrew/etc/bashrc
            
            GO_VER=$(gvm listall | grep "go[0-9]*\.[0-9]*\.[0-9]*" | tail -n -1)
            LUA_VER="$(luaver list -r | tail -n -1)"

            gvm install $GO_VER -B
            gvm use $GO_VER
            nvm install --lts
            pyenv install 3
            pyenv global 3
            sdk install java
            sdk install maven
            sdk install gradle
            printf "%s\\n" yes | luaver install $LUA_VER
            perlbrew install --notest stable
image:
    Containerfile: |
        FROM docker.io/library/ubuntu:latest
        LABEL name="dev-box" \
            version="latest" \
            usage="This image is meant to be used with a container manager like distrobox or toolbx" \
            summary="Custom image load with all of my dev tools"
        COPY pkgs.txt /tmp/pkgs.txt
        RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install $(cat /tmp/pkgs.txt | xargs)

    files:
    - pkgs.txt: |
        fuse
        libfuse2
        libxi6
        libxrender1
        libxtst6
        mesa-utils
        libfontconfig
        libgtk-3-bin
        tar
        dbus-user-session
        socat
        bison
        binutils
        libnss3
        libasound2-dev
        build-essential
        curl
        libffi-dev
        libffi8
        libgmp-dev
        libgmp10
        libncurses-dev
        pkg-config
        libssl-dev
        zlib1g-dev
        libbz2-dev
        libreadline-dev
        libsqlite3-dev
        libncursesw5-dev
        xz-utils
        tk-dev
        libxml2-dev
        libxmlsec1-dev
        liblzma-dev
        llvm
        git
        vim
        clang
        gcc
        gdb
        nasm
        yq
```