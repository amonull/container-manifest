#!/bin/bash


###########################################
################## UTILS ##################
###########################################

help() {
    printf "  usage: manifest.sh --manifest ./manifest-file.yaml [option(s)]

    Options:
    -m, --manifest <file>
        the manifest file to use to build image and container
    -B, --ignore-build
        do not build container image (assumes image already exists)
    -F, --ignore-build-files
        do not create the build files in the tmp dir
    -D, --ignore-container
        do not create a container (assumes container already exists)
    -P, --ignore-pre
        does not run pre commands
    -R, --ignore-peri
        does not run peri commands
    -T, --ignore-post
        does not run post commands
    -I, --ignore-import
        does not import packages to container
    -E, --ignore-export
        does not export packages from container
    -K, --keep-tmp
        does not delete tmp files under /tmp/tmp.XXXXXXXXXXX (one for image build another for container build)
    -h, --help
        print this screen\n"
}

# remove starting and ending single or double quotes
sanitizeString() {
    local string="$1"
    sed -e "s|^[ \t]*[\"'][ \t]*||" -e "s|[ \t]*[\"'][ \t]*$||" <<< "$string"
}

##########################################
################## YAML ##################
##########################################

yaml_getName() {
    __runYamlFilter '.container.name'
}

yaml_getHome() {
    __runYamlFilter '.container.home'
}

yaml_getImage() {
    __runYamlFilter '.container.image'
}

yaml_getCreateArgsLength() {
    __listGetLength '.container.createArgs'
}

yaml_getExportsLength() {
    __listGetLength '.container.export'
}

yaml_getImportsLength() {
    __listGetLength '.container.import'
}

# func used by passing ref
# shellcheck disable=SC2329
yaml_getScriptsPreLength() {
    __listGetLength '.container.scripts.pre'
}

# func used by passing ref
# shellcheck disable=SC2329
yaml_getScriptsPeriLength() {
    __listGetLength '.container.scripts.peri'
}

# func used by passing ref
# shellcheck disable=SC2329
yaml_getScriptsPostLength() {
    __listGetLength '.container.scripts.post'
}

yaml_getCreateArgsIndexed() {
    local index=$1
    __runYamlFilter ".container.createArgs[$index]"
}

yaml_getExportsIndexed() {
    local index=$1
    __runYamlFilter ".container.export[$index]"
}

yaml_getImportsIndexed() {
    local index=$1
    __runYamlFilter ".container.import[$index]"
}

# func used by passing ref
# shellcheck disable=SC2329
yaml_getScriptsPreIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.pre[$index]"
}

# func used by passing ref
# shellcheck disable=SC2329
yaml_getScriptsPeriIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.peri[$index]"
}

# func used by passing ref
# shellcheck disable=SC2329
yaml_getScriptsPostIndexed() {
    local index=$1
    __runYamlFilter ".container.scripts.post[$index]"
}

yaml_getAutoStartLogin() {
    __runYamlFilter '.container.autostart.login'
}

yaml_getAutoStartAfterBuild() {
    __runYamlFilter '.container.autostart.afterBuild'
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
        echo -n "$result"
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

distrobox_run() {
    /usr/bin/distrobox-enter --name "$__CONTAINER_NAME" -- "$@"
}

distrobox_export() {
    local pathToBinOrApp=$1
    local isBinaryOrApp=""

    if [[ $pathToBinOrApp == *.desktop ]]; then
        local correctedPath=""
        isBinaryOrApp="-a"

        # attempt to set path to user applications
        [[ -f $pathToBinOrApp ]] || correctedPath="$__CONTAINER_HOME/.local/share/applications/$pathToBinOrApp"
        
        # attempt to set path to system applications (if fails again let distrobox handle it)
        [[ -f $correctedPath ]] || correctedPath="/usr/share/applications/$pathToBinOrApp"

        pathToBinOrApp="$correctedPath"
    else
        isBinaryOrApp="-b"

        # if pathToBinOrApp does not exist or is not exe on container try to find full path on it (assumes it just got the name)
        [[ -x "$pathToBinOrApp" ]] || pathToBinOrApp="$(distrobox_run '/usr/bin/which' "$pathToBinOrApp")"
    fi

    distrobox_run '/usr/bin/distrobox-export' "$isBinaryOrApp" "$pathToBinOrApp"
}

# This is a very hacky way to move files into root partition of a container but works
distrobox_import() {
    local import=$1
    local containerDest="/usr/local/bin/$(basename "$import")"
    local hostDest="$__CONTAINER_SCRIPTS_TMP_DIR/import/$(basename "$import")"

    [[ -d "$(dirname "$hostDest")" ]] || mkdir "$(dirname "$hostDest")"

    # find source for import (give priority to system/local install)
    if which "$import" &> /dev/null; then
        import="$(which "$import")"
    else
        if command -v "flatpak" &> /dev/null; then
            local appId="$(flatpak list | grep -i "$import" | awk '{print $2}')"
            if flatpak info "$appId" &> /dev/null; then
                import="flatpak run $appId"
            fi
        fi
    fi

    echo '#!/bin/sh' > "$hostDest"
    echo "distrobox-host-exec $import \"\$@\"" >> "$hostDest"
    chmod +x "$hostDest"

    distrobox_run '/usr/bin/sudo' 'cp' "/run/host/$hostDest" "$containerDest"
}

distrobox_create_pod() {
    local flags=(--name "$__CONTAINER_NAME")

    if [[ -n "$__CONTAINER_HOME" ]]; then
        flags=(--home "$__CONTAINER_HOME" "${flags[@]}")
    fi

    if [[ -n "$__CONTAINER_IMAGE" ]]; then
        flags=(--image "$__CONTAINER_IMAGE" "${flags[@]}")
    else
        flags=(--image "localhost/$__CONTAINER_NAME" "${flags[@]}")
    fi

    for ((index=0; index != $(yaml_getCreateArgsLength); index++)); do
        arg="$(yaml_getCreateArgsIndexed "$index")"

        # required to not be quoted to pass as arg correctly
        # shellcheck disable=SC2086
        argFlag=$(echo "$arg" | awk '{print $1}')
        
        argValue="$(echo "$arg" | awk '{for (i=2; i<=NF; i++) printf $i " "}')"
        flags=($argFlag "$(sanitizeString "$argValue")" "${flags[@]}")
    done

    distrobox create "${flags[@]}"
}

distrobox_stop_container() {
    distrobox stop --yes "$__CONTAINER_NAME"
}


##########################################
################# PODMAN #################
##########################################

podman_buildImage() {
    podman build --tag "$__CONTAINER_NAME" "$__IMAGE_BUILD_DIR"
}

podman_writeContainerFileToTmp() {
    local containerFile="$(yaml_getContainerFile)"
    echo -e "$containerFile" > "$__IMAGE_BUILD_DIR/Containerfile"
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
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--manifest)
            __MANIFEST_FILE="$2"
            shift
            ;;

        -B|--ignore-build)
            __OPT_IGNORE_BUILD=1
            ;;

        -F|--ignore-build-files)
            __OPT_IGNORE_BUILD_FILES=1
            ;;

        -D|--ignore-container)
            __OPT_IGNORE_CONTAINER=1
            ;;

        -P|--ignore-pre)
            __OPT_IGNORE_PRE=1
            ;;

        -R|--ignore-peri)
            __OPT_IGNORE_PERI=1
            ;;

        -T|--ignore-post)
            __OPT_IGNORE_POST=1
            ;;

        -I|--ignore-import)
            __OPT_IGNORE_IMPORT=1
            ;;

        -E|--ignore-export)
            __OPT_IGNORE_EXPORT=1
            ;;

        -K|--keep-tmp)
            __OPT_KEEP_TMP=1
            ;;


        -h|--help)
            help
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            help
            exit 1
            ;;
    esac
    shift
done

if [[ -z "${__MANIFEST_FILE+x}" ]]; then
    echo "-m, --manifest option MUST be set"

    help
    
    exit 1
else
    __IMAGE_BUILD_DIR="$(mktemp -d)"
    __CONTAINER_SCRIPTS_TMP_DIR="$(mktemp -d)"
    __CONTAINER_NAME="$(yaml_getName)"
    __CONTAINER_HOME="$(yaml_getHome)"
    __CONTAINER_IMAGE="$(yaml_getImage)"
    __CONTAINER_AUTOSTART_LOGIN="$(yaml_getAutoStartLogin)"
    __CONTAINER_AUTOSTART_AFTER_BUILD="$(yaml_getAutoStartAfterBuild)"
fi

if [[ -z "${__OPT_IGNORE_BUILD+x}" ]] && [[ -z "${__CONTAINER_IMAGE+x}" ]]; then
    
    podman_writeContainerFileToTmp

    if [[ -z "${__OPT_IGNORE_BUILD_FILES+x}" ]]; then
        podman_writeFilesToTmp
    fi

    podman_buildImage
    
fi

if [[ -z "${__OPT_IGNORE_CONTAINER+x}" ]]; then
    distrobox_create_pod
fi

if [[ -z "${__OPT_IGNORE_PRE+x}" ]]; then
    container_writeScriptsPreToTmp

    for preScript in $__CONTAINER_SCRIPTS_TMP_DIR/pre/*; do
        if [[ -x "$preScript" ]]; then
            bash "$preScript" "$__CONTAINER_NAME" "$__CONTAINER_HOME"
        fi
    done

fi

if [[ -z "${__OPT_IGNORE_IMPORT+x}" ]]; then
    for ((index=0; index != $(yaml_getImportsLength); index++)); do
        file="$(yaml_getImportsIndexed $index)"

        distrobox_import "$file"
    done
fi

if [[ -z "${__OPT_IGNORE_PERI+x}" ]]; then
    container_writeScriptsPeriToTmp
    
    for script in $(distrobox_run '/usr/bin/bash' '-c' "find /run/host/$__CONTAINER_SCRIPTS_TMP_DIR/peri/ -type f -executable -exec realpath {} + | tac"); do
        distrobox_run '/usr/bin/bash' '-i' '-c' "$script"
    done

    distrobox_stop_container
fi

if [[ -z "${__OPT_IGNORE_POST+x}" ]]; then
    container_writeScriptsPostToTmp

    for script in $(distrobox_run '/usr/bin/bash' '-c' "find /run/host/$__CONTAINER_SCRIPTS_TMP_DIR/post/ -type f -executable -exec realpath {} + | tac"); do
        distrobox_run '/usr/bin/bash' '-i' '-c' "$script"
    done

    distrobox_stop_container
fi

if [[ -z "${__OPT_IGNORE_EXPORT+x}" ]]; then
    for ((index=0; index != $(yaml_getExportsLength); index++)); do
        file="$(yaml_getExportsIndexed $index)"

        distrobox_export "$file"
    done
fi

if [[ -z "${__OPT_KEEP_TMP+x}" ]]; then
    rm -rf "${__IMAGE_BUILD_DIR}"
    rm -rf "${__CONTAINER_SCRIPTS_TMP_DIR}"
fi

distrobox_stop_container

if [[ -n "${__CONTAINER_AUTOSTART_AFTER_BUILD+x}" ]] && [[ "${__CONTAINER_AUTOSTART_AFTER_BUILD}" -eq "true" ]]; then
    distrobox_run '/usr/bin/echo' 'Container Started'
fi

if [[ -n "${__CONTAINER_AUTOSTART_LOGIN+x}" ]] && [[ "${__CONTAINER_AUTOSTART_LOGIN}" -eq "true" ]]; then
    distrobox-generate-entry "$__CONTAINER_NAME)"
    
    [[ -f "$HOME/.config/autostart/$__CONTAINER_NAME.desktop" ]] || cp "$HOME/.local/share/applications/$__CONTAINER_NAME.desktop" "$HOME/.config/autostart/"
fi

exit 0