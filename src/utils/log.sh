#!/bin/bash

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
