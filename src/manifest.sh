#!/bin/bash

##########################################
################ GLOBALS #################
##########################################

# TODO: read cli args and set these values like that
__MANIFEST_FILE=""
__LOG_FILE="$HOME/.cache/container-builder-automation-tool/logs.log"
__IMAGE_BUILD_DIR="$(mktemp -d)"
__CONTAINER_SCRIPTS_TMP_DIR="$(mktemp -d)"
__CONTAINER_NAME="$(getName)"
__CONTAINER_HOME="$(getHome)"
__LOG_LEVEL="6"

##########################################
################ HELPERS #################
##########################################

##########################################
############### CONTAINER ################
##########################################

writeScriptsPreToTmp() {
    __writeScriptToTmp "pre" getScriptsPreLength getScriptsPreIndexed
}

writeScriptsPeriToTmp() {
    __writeScriptToTmp "peri" getScriptsPeriLength getScriptsPeriIndexed
}

writeScriptsPostToTmp() {
    __writeScriptToTmp "post" getScriptsPostLength getScriptsPostIndexed
}

__writeScriptToTmp() {
    local scriptStage=$1
    local stageGetListLengthCmd=$2
    local stageGetFileContentsCmd=$3

    for ((index=0; index <= $(stageGetListLengthCmd); index++)); do
        local fileName="$index.sh"
        local fileContent="$(stageGetFileContentsCmd $index)"

        trace "writing $scriptStage script $fileName to $__CONTAINER_SCRIPTS_TMP_DIR"

        install -m 777 <(echo $fileContent) "$__CONTAINER_SCRIPTS_TMP_DIR/$scriptStage/$fileName"
    done
}

##########################################
################## YAML ##################
##########################################

getName() {
    __runYamlFilter '.container.name'
}

getHome() {
    __runYamlFilter '.container.home'
}

getExportsLength() {
    __listGetLength '.container.exports'
}

getImportsLength() {
    __listGetLength '.container.imports'
}

getScriptsPreLength() {
    __listGetLength '.container.scripts.pre'
}

getScriptsPeriLength() {
    __listGetLength '.container.scripts.peri'
}

getScriptsPostLength() {
    __listGetLength '.container.scripts.post'
}

getExportsIndexed() {
    local index=$1
    __runYamlFilter ".container.exports[$index]"
}

getImportsIndexed() {
    local index=$1
    __runYamlFilter ".container.imports[$index]"
}

getScriptsPreIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.pre[$index]"
}

getScriptsPeriIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.peri[$index]"
}

getScriptsPostIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.post[$index]"
}

getContainerFile() {
    __runYamlFilter '.image.Containerfile'
}

getImageFilesLength() {
    __listGetLength '.image.files'
}

getImageFilesIndexedName() {
    local index=$1
    __runYamlFilter ".image.files[$index] | keys"
}

getImageFilesIndexed() {
    local index=$1
    __runYamlFilter ".image.files[$index]"
}

__listGetLength() {
    local filter=$1

    local result=$(__runYamlFilter "$filter | length")

    if [[ -z "$result" ]]; then
        trace "$filter is an empty list"

        echo -n '0'
    else
        echo -n $result
    fi
}

__runYamlFilter() {
    local filter=$1

    local result="$(yq $filter $__MANIFEST_FILE)"

    echo $filter

    debug "Ran $filter on $__MANIFEST_FILE"

    if [[ "$result" == "null" ]]; then
        result=""
        warn "$filter returned null"
    fi

    echo -n "$result"
}

##########################################
############### DISTROBOX ################
##########################################

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

##########################################
################# PODMAN #################
##########################################

buildImage() {
    podman build --tag $__CONTAINER_NAME $__IMAGE_BUILD_DIR
}

processContainerfile() {
    sed -i "s|{{\(.*\)}}|$__IMAGE_BUILD_DIR/\1|g" $__IMAGE_BUILD_DIR/Containerfile
}

writeFilesToTmp() {
    for ((index=0; index <= $(getImageFilesLength); index++)); do
        local fileName="$(getImageFilesIndexedName $index)"
        local fileContent="$(getImageFilesIndexed $index)"
        local fileParentDir="$(dirname $filename)"

        trace "writing image file $fileName to $__IMAGE_BUILD_DIR"

        if [[ -d "$fileParentDir" ]]; then
            mkdir -p "$fileParentDir"
        fi

        echo $fileContent > $__IMAGE_BUILD_DIR/$fileName
    done
}

##########################################
################ LOGGER ##################
##########################################

fatal() {
    local errCode=$1
    local msg=$2
    __writeMessage 0 $msg
    exit $errCode
}

err() {
    local msg=$1
    __writeMessage 1 $msg
}

warn() {
    local msg=$1
    __writeMessage 2 $msg
}

info() {
    local msg=$1
    __writeMessage 3 $msg
}

debug() {
    local msg=$1
    __writeMessage 4 $msg
}

trace() {
    local msg=$1
    __writeMessage 5 $msg
}

__writeMessage() {
    local level=$1
    local msg=$2
    local date="$(date +"%D %T")"

    if [[ "$level" -gt "$__LOG_LEVEL" ]]; then
        return
    fi

    echo "$date - [$(__logLevelToString $level)]: $msg" | tee -a $__LOG_FILE
}

__logLevelToString() {
    local level=$1

    case $level in
        0) echo -n "FATAL" ;;

        1) echo -n "ERR"   ;;

        2) echo -n "WARN"  ;;

        3) echo -n "INFO"  ;;

        4) echo -n "DEBUG" ;;

        5) echo -n "TRACE" ;;

        *) echo -n "UNKOWN";;
    esac
}
