#!/bin/bash

source $__SCRIPT_ROOT/utils/read-yaml.sh

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
