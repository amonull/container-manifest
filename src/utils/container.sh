#!/bin/bash

source $__SCRIPT_ROOT/utils/read-yaml.sh

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
