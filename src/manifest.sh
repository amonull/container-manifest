#!/bin/bash


##########################################
################## YAML ##################
##########################################

yaml_getName() {
    __runYamlFilter '.container.name'
}

yaml_getHome() {
    __runYamlFilter '.container.home'
}

yaml_getExportsLength() {
    __listGetLength '.container.exports'
}

yaml_getImportsLength() {
    __listGetLength '.container.imports'
}

yaml_getScriptsPreLength() {
    __listGetLength '.container.scripts.pre'
}

yaml_getScriptsPeriLength() {
    __listGetLength '.container.scripts.peri'
}

yaml_getScriptsPostLength() {
    __listGetLength '.container.scripts.post'
}

yaml_getExportsIndexed() {
    local index=$1
    __runYamlFilter ".container.exports[$index]"
}

yaml_getImportsIndexed() {
    local index=$1
    __runYamlFilter ".container.imports[$index]"
}

yaml_getScriptsPreIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.pre[$index]"
}

yaml_getScriptsPeriIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.peri[$index]"
}

yaml_getScriptsPostIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.post[$index]"
}

yaml_getContainerFile() {
    __runYamlFilter '.image.Containerfile'
}

yaml_getImageFilesLength() {
    __listGetLength '.image.files'
}

yaml_getImageFilesIndexedName() {
    local index=$1
    # yq returns "- fileName" cut used to remove "- "
    cut -c3- <<< "$(__runYamlFilter ".image.files[$index] | keys")"
}

yaml_getImageFilesIndexed() {
    local index=$1
    local fileName=$2
    __runYamlFilter ".image.files[$index].\"$fileName\""
}

__listGetLength() {
    local filter=$1

    local result=$(__runYamlFilter "$filter | length")

    if [[ -z "$result" ]]; then
        echo -n '0'
    else
        echo -n $result
    fi
}

__runYamlFilter() {
    local filter=$1
    local result="$(yq eval "$filter" "$__MANIFEST_FILE" || echo "")"

    if [[ "$result" == "null" ]]; then
        result=""
    fi

    echo -n "$result"
}


##########################################
############### DISTROBOX ################
##########################################

# NOTE: runs a single command (preferably a full path to the cmd), opts cannot be supplied
distrobox_run() {
    # TODO: find a way to force bash to make a distinction between $2 and $3 inside $@
    # currently when 'bash' '-c' 'echo hello world' is pushed inside of $@ it becomes a
    # single string instead of a list of strings
    /usr/bin/distrobox-enter --name $__CONTAINER_NAME -- "$@"
}

# NOTE: this will run a script only in bash, bash is supplied the flag '-c'
distrobox_run-cmd() {
    /usr/bin/distrobox-enter --name $__CONTAINER_NAME -- '/usr/bin/bash' '-c' "$@"
}

distrobox_export() {
    local pathToBinOrApp=$1
    local isBinaryOrApp=""

    if [[ "$pathToBinOrApp" == "*.desktop" ]]; then
        isBinaryOrApp="-a"

        [[ -f $pathToBinOrApp ]] || pathToBinOrApp="$__CONTAINER_HOME/.local/share/applications/$pathToBinOrApp"
    else
        isBinaryOrApp="-b"

        # assumes just name is given
        [[ -x $pathToBinOrApp ]] || pathToBinOrApp="$(which $pathToBinOrApp)"
    fi

    [[ -f "$pathToBinOrApp" ]] || exit 1

    [[ "$isBinaryOrApp" == "-b" && -x "$pathToBinOrApp" ]] || exit 1

    distrobox_run-cmd "distrobox-export $isBinaryOrApp $pathToBinOrApp"
}

# NOTE: this only works with binary apps or apps that are meant to be moved into ~/.local/bin/
# and ideally a full path should be supplied
# NOTE: this function does not run inside the container so container_home is used
distrobox_import() {
    local import=$1

    mkdir -p $__CONTAINER_HOME/.local/bin

    cat << EOF > $__CONTAINER_HOME/.local/bin/$(basename $import)
#!/bin/sh

distrobox-host-exec $1 # WARNING: this will not work as it is in cat <<< EOF str
EOF
}

distrobox_create_pod() {
    local flags="--image localhost/$__CONTAINER_NAME --name $__CONTAINER_NAME"

    if [[ -n "$__CONTAINER_HOME" ]]; then
        flags="$flags --home $__CONTAINER_HOME"
    fi

    distrobox create $flags
}

distrobox_stop_container() {
    distrobox stop --yes "$__CONTAINER_NAME"
}


##########################################
################# PODMAN #################
##########################################

podman_buildImage() {
    podman build --tag $__CONTAINER_NAME $__IMAGE_BUILD_DIR
}

podman_writeContainerFileToTmp() {
    local containerFile="$(yaml_getContainerFile)"
    echo -e "$containerFile" > $__IMAGE_BUILD_DIR/Containerfile
}

podman_writeFilesToTmp() {
    for ((index=0; index != $(yaml_getImageFilesLength); index++)); do
        local fileName="$(yaml_getImageFilesIndexedName "$index")"
        local fileContent="$(yaml_getImageFilesIndexed "$index" "$fileName")"
        local fileParentDir="$(dirname "$filename")"

        if [[ -d "$fileParentDir" ]]; then
            mkdir -p "$fileParentDir"
        fi

        echo -e "$fileContent" > "$__IMAGE_BUILD_DIR/$fileName"
    done
}


##########################################
############### CONTAINER ################
##########################################

container_writeScriptsPreToTmp() {
    __writeScriptToTmp "pre" yaml_getScriptsPreLength yaml_getScriptsPreIndexed
}

container_writeScriptsPeriToTmp() {
    __writeScriptToTmp "peri" yaml_getScriptsPeriLength yaml_getScriptsPeriIndexed
}

container_writeScriptsPostToTmp() {
    __writeScriptToTmp "post" yaml_getScriptsPostLength yaml_getScriptsPostIndexed
}

__writeScriptToTmp() {
    local scriptStage=$1
    local stageGetListLengthCmd=$2
    local stageGetFileContentsCmd=$3

    for ((index=0; index != $($stageGetListLengthCmd); index++)); do
        local fileName="$index.sh"
        local fileContent="$($stageGetFileContentsCmd $index)"

        install -Dm 777 <(echo -e "$fileContent") "$__CONTAINER_SCRIPTS_TMP_DIR/$scriptStage/$fileName"
    done
}


##########################################
################## MAIN ##################
##########################################
__MANIFEST_FILE="$HOME/Documents/tmp/manifest.yaml"
__IMAGE_BUILD_DIR="$(mktemp -d)"
__CONTAINER_SCRIPTS_TMP_DIR="$(mktemp -d)"
__CONTAINER_NAME="$(yaml_getName)"
__CONTAINER_HOME="$(yaml_getHome)"

# [ write all files ]
podman_writeContainerFileToTmp
podman_writeFilesToTmp
container_writeScriptsPreToTmp
container_writeScriptsPeriToTmp
container_writeScriptsPostToTmp

# [ build image ]
podman_buildImage

[ exec pre scripts ]
for preScript in $__CONTAINER_SCRIPTS_TMP_DIR/pre/*; do
    if [[ -x "$preScript" ]]; then
        bash "$preScript" "$__CONTAINER_NAME" "$__CONTAINER_HOME"
    fi
done

# [ create container ]
distrobox_create_pod

# [ exec peri scripts ]
for script in $(distrobox_run-cmd "find /run/host/$__CONTAINER_SCRIPTS_TMP_DIR/peri/ -type f -executable -exec realpath {} \;"); do
    distrobox_run-cmd "$script"
done

# [ shut container down ]
distrobox_stop_container

# [ exec post scripts ]
for script in $(distrobox_run-cmd "find /run/host/$__CONTAINER_SCRIPTS_TMP_DIR/post/ -type f -executable -exec realpath {} \;"); do
    distrobox_run-cmd "$script"
done

# [ shut container down ]
distrobox_stop_container

# [ export apps ]
for ((index=0; index != yaml_getExportsLength; index++)); do
    local file="$(yaml_getExportsIndexed $index)"

    distrobox_export $file
done

# [ import apps ]
for ((index=0; index != yaml_getExportsLength; index++)); do
    local file="$(yaml_getExportsIndexed $index)"

    distrobox_import $file
done

# [ shut container down ]
distrobox_stop_container