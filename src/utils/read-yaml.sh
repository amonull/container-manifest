#!/bin/bash

source $__SCRIPT_ROOT/utils/log.sh

# WARNING: readme for later remove this comment
# use ...Indexed() funcs inside loops such as
# for ((index=0; index <= $(getExportsLength); index++)); do
#     export=$(getExportsIndexed $index)
#     ... process export
# done

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
