#!/bin/bash
set -e

GENERATE_QR_FOR_USER=""
CLIENT_NAME=""

FORCE_ADD=false
DELETE_PEER=""
DELETE_CONF=""
SHOW_CONF=""

readonly ROOT_DIR=$(dirname $(readlink -f $0))

function create_default_rc() {
    local rc_file=$1
    echo "WG_CLIENTS_DIR=$HOME/wgclients" >> $rc_file
    echo "SERVER_PUB_KEY=" >> $rc_file
    echo "SERVER_ADDRESS=" >> $rc_file
    echo "BASE_IP=127.0.0" >> $rc_file

}

function usage() {
    echo "Usage: $1 <client-name>"
    echo -e "\t-g <client-name> - Generate QR code"
    echo -e "\t-a - Add user"
    echo -e "\t-f - Force add client"
    echo -e "\t-d - Delete peer"
    echo -e "\t-D - Delete peer and configuration"
    echo -e "\t-s - Show config"
    exit 1
}

function parse_args() {
    local parsed_args
    parsed_args=$(getopt -o a:g:d:D:fs: -- "$@")
    local invalid_args=$?
    if [[ "$invalid_args" != "0" ]];then
        usage
    fi

    eval set -- "$parsed_args"
    while true; do

        case "$1" in
            -a) CLIENT_NAME=$2; shift 2;;
            -g) GENERATE_QR_FOR_USER=$2; shift 2 ;;
            -f) FORCE_ADD=true; shift ;;
            -d) DELETE_PEER=$2; shift 2;;
            -D) DELETE_CONF=$2; shift 2;;
            -s) SHOW_CONF=$2; shift 2;;
            --) shift; break;;
            *) echo "Unknown option: $1"
                usage;;
        esac
    done
}

function get_client_ip() {
    local used=$(find $WG_CLIENTS_DIR -name '*.conf' \
        -exec sed -n 's/Address.*\.\([0-9]\{3\}\)\/32/\1/p' {} \;)

    local count=$(echo $used | wc -w)
    ((count+=101))
    local cons=$(seq 101 $count)
    local free_ip=$(echo "$used $cons" | tr ' ' '\n' | sort | uniq -u | head -1)
    echo "${BASE_IP}.$free_ip"
}

function generate_config() {
    local client_name=$1
    local client_dir=$WG_CLIENTS_DIR/$client_name

    if [[ -d $client_dir ]];then
        if ! $FORCE_ADD; then
            echo "Client $client_dir already exists"
            exit 3
        fi
    fi

    mkdir -p $client_dir
    local priv_key_file=$client_dir/${client_name}.key
    local pub_key_file=$client_dir/${client_name}.key.pub
    local pub_key
    pub_key=$(wg genkey | tee $priv_key_file | wg pubkey | tee $pub_key_file)

    local priv_key=$(cat $priv_key_file)
    local client_ip=$(get_client_ip)

    local priv_key=$(cat $priv_key_file)
    cat $ROOT_DIR/wg.client.template.conf | sed \
        -e "s#:CLIENT_IP:#$client_ip#" \
        -e "s#:CLIENT_KEY:#$priv_key#" \
        -e "s#:SERVER_PUB_KEY:#$SERVER_PUB_KEY#" \
        -e "s#:SERVER_ADDRESS:#$SERVER_ADDRESS#" \
        > $client_dir/wg.$client_name.conf

    sudo wg set wg0 peer $pub_key allowed-ips $client_ip/32
    generate_qr $client_name
}

function generate_qr() {
    local client_name=$1
    local qr_encode=/usr/bin/qrencode
    local conf_file=$WG_CLIENTS_DIR/${client_name}/wg.${client_name}.conf
    if [[ ! -x $qr_encode ]];then
        cat $conf_file
        return 0
    fi
    $qr_encode -r $conf_file -o - -t UTF8
}

function show_config() {
    local client_name=$1
    local conf_file=$WG_CLIENTS_DIR/${client_name}/wg.${client_name}.conf

    cat $conf_file
}

function delete_peer() {
    local client_name=$1
    local pub_key_file=$WG_CLIENTS_DIR/${client_name}/${client_name}.key.pub
    
    if [[ ! -f $pub_key_file ]];then
        return 0
    fi
    local pub_key=$(cat $pub_key_file)
    echo "Remove peer $pub_key"
    sudo wg set wg0 peer $pub_key remove
}

function delete_conf() {
    local client_name=$1
    
    if [[ -z $client_name ]];then
        return 0
    fi
    rm -rf $WG_CLIENTS_DIR/${client_name}
}

function main() {

    parse_args "$@"

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

    if [[ -n $SHOW_CONF ]];then
        show_config $SHOW_CONF
        return 0
    fi

    if [[ -n $DELETE_PEER ]];then
        delete_peer $DELETE_PEER
        return 0
    fi

    if [[ -n $DELETE_CONF ]];then
        delete_peer $DELETE_CONF
        delete_conf $DELETE_CONF
        return 0
    fi

    if [[ -n $GENERATE_QR_FOR_USER ]];then
        generate_qr $GENERATE_QR_FOR_USER
        return 0
    fi
    if [[ -n $CLIENT_NAME ]];then
        generate_config $CLIENT_NAME
        return 0
    fi

    usage

}

main "$@"
