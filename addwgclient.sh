#!/bin/bash
set -e

GENERATE_QR_FOR_USER=""
USERS=()

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
    exit 1
}



function parse_args() {
    local parsed_args
    parsed_args=$(getopt -o g: -- "$@")
    local invalid_args=$?
    if [[ "$invalid_args" != "0" ]];then
        usage
    fi

    eval set -- "$parsed_args"
    while true; do

        case "$1" in
            -g) GENERATE_QR_FOR_USER=$2; shift 2 ;;
            --) shift; break;;
            *) echo "Unknown option: $1"
                usage;;
        esac
    done
    USERS=($@)
    if [[ ${#USERS[@]} -eq 0 ]];then
        if [[ -z $GENERATE_QR_FOR_USER ]]; then
            usage
        fi
    fi
#    echo "Parameters remaining are: $@"
}

function get_client_ip() {
    local count=$(ls -1 $WG_CLIENTS_DIR | wc -l)
    let end_ip=$count+100
    echo "${BASE_IP}.$end_ip"
}

function generate_config() {
    local client_name=$1
    local client_dir=$WG_CLIENTS_DIR/$client_name

#    if [[ -d $client_dir ]];then
#        echo "Client $client_dir already exists"
#        exit 3
#    fi

    mkdir -p $client_dir
    local priv_key_file=$client_dir/${client_name}.key
    local pub_key_file=$client_dir/${client_name}.key.pub
    local pub_key
    pub_key=$(wg genkey | tee $priv_key_file | wg pubkey | tee $pub_key_file)

    local priv_key=$(cat $priv_key_file)
    local client_ip=$(get_client_ip)

#    declare -A values
#    local values

#    values[:CLIENT_IP:]="$client_ip"
#    values[:CLIENT_KEY:]="$pub_key"
#    values[:SERVER_PUB_KEY:]="$SERVER_PUB_KEY"
#    values[:SERVER_ADDRESS:]="$SERVER_ADDRESS"

#    for key in ${!values[@]}; do
#        echo "$key => ${values[$key]}"
#        sed -e "'s/$key/${values[$key]}/'"
#    done
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
    
    local conf_file=$WG_CLIENTS_DIR/${client_name}/wg.${client_name}.conf
    qrencode -r $conf_file -o - -t UTF8
}

function main() {

    parse_args "$@"

#    for u in ${USERS[@]}; do
#        echo $u
#    done
#    exit 0

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

    if [[ -n $GENERATE_QR_FOR_USER ]];then
        generate_qr $GENERATE_QR_FOR_USER
        return 0
    fi
    for user in ${USERS[@]}; do
        generate_config $user
    done

}

main "$@"
