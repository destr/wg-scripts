#!/bin/bash

function create_default_rc() {
    local rc_file=$1
    echo "WG_CLIENTS_DIR=$HOME/wgclients" >> $rc_file
    echo "SERVER_PUB_KEY=" >> $rc_file
    echo "SERVER_ADDRESS=" >> $rc_file

}

function usage() {
    echo "Usage: $1 <client-name>"
}

function main() {

    if [[ "$#" -ne 1 ]];then
        usage $0
        exit 2
    fi

    local rc_file=$HOME/.wgscriptsrc
    if [[ ! -f $HOME/.wgscriptsrc ]];then
        echo "Not found rc file ${rc_file}. Created defaulted. FILL VALUES"
        create_default_rc $rc_file
        exit 1
    fi
    source $rc_file

    readonly WG_CLIENTS_DIR
    readonly SERVER_PUB_KEY
    readonly SERVER_ADDRESS

    local client_name=$1
    local client_dir=$WG_CLIENTS_DIR/$client_name

    if [[ -d $client_dir ]];then
        echo "Client $client_dir already exists"
        exit 3
    fi

    mkdir -p $client_dir
    wg genkey | tee $client_dir/${client_name}.key | \
        wg pubkey | tee $client_dir/${client_name}.key.pub

}

main "$@"
