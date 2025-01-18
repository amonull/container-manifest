#!/bin/bash

source $__SCRIPT_ROOT/utils/log.sh

# NOTE: runs a single command (preferebly a full path to the cmd), opts cannot be supplied
distrobox-run() {
    # TODO: find a way to force bash to make a distinction between $2 and $3 inside $@
    # currently when 'bash' '-c' 'echo hello world' is pushed inside of $@ it becomes a
    # single string instead of a list of strings
    /usr/bin/distrobox-enter --name $__CONTAINER_NAME -- "$@"
}

# NOTE: this will run a script only in bash, bash is supplied the flag '-c'
distrobox-run-cmd() {
    /usr/bin/distrobox-enter --name $__CONTAINER_NAME -- '/usr/bin/bash' '-c' "$@"
}

distrobox-export() {
    local pathToBinOrApp=$1
    local isBinaryOrApp=""

    if [[ "$pathToBinOrApp" == "*.desktop" ]]; then
        debug "app detected in export $pathToBinOrApp"

        isBinaryOrApp="-a"

        [[ -f $pathToBinOrApp ]] || pathToBinOrApp="$__CONTAINER_HOME/.local/share/applications/$pathToBinOrApp"
    else
        debug "binary detected in export $pathToBinOrApp"

        isBinaryOrApp="-b"

        # assumes just name is given
        [[ -x $pathToBinOrApp ]] || pathToBinOrApp="$(which $pathToBinOrApp)"
    fi

    [[ -f "$pathToBinOrApp" ]] || fatal 1 "could not find bin or app to export: $pathToBinOrApp"

    [[ "$isBinaryOrApp" == "-b" && -x "$pathToBinOrApp" ]] || fatal 1 "$pathToBinOrApp is not an executable"

    distrobox-run-cmd "distrobox-export $isBinaryOrApp $pathToBinOrApp"
}

# NOTE: this only works with binary apps or apps that are meant to be moved into ~/.local/bin/
# and ideally a full path should be supplied
# NOTE: this function does not run inside the container so container_home is used
distrobox-import() {
    local import=$1

    debug "importing $import to"

    mkdir -p $__CONTAINER_HOME/.local/bin

    cat << EOF > $__CONTAINER_HOME/.local/bin/$(basename $import)
#!/bin/sh

distrobox-host-exec $1 # WARNING: this will not work as it is in cat <<< EOF str
EOF
}
