#!/bin/bash
#
# Description: Wraps the RPC of a nano node to allow ease of use from BASH shell command line
#
# WARNING: There are a number of functions in here that can wipe your wallet, so please be cautious when using this.
# There are also functions that take a seed or private key as plain text.
# Do not use these functions on a shared server as your seed/private key will be visible to others.
#
# Use this script at your own risk - I can take no responsibility for any loss or damage caused by use of this script. 
#
NANO_FUNCTIONS_VERSION=0.9301

# Version: 0.9301
#          - Bugfix
#                   - Fix resuming block generation when using generate_spam_sends_to_file, balance was wrong.
#                   - Fix is_local_and_remote_block_counts_similar - get 'count' from block_count
#
# Version: 0.93 (never released to 'master' branch)
#          - Feature
#                   - New generate_spam_and_broadcast_forever function to loop forever until interrupted
#                   - New get_account_pending function.
#                   - New available_supply function.
#                   - New is_node_up function.
#                   - New work peer functions: work_peer_list, work_peer_add, work_peer_clear_all functions.
#                   - New nano_version_number function (try to get node vendor version number)
#                   - With nano_version_number we can now introduce version compatibility with RPC, e.g.
#                       only set certain RPC options if the node version supports it.
#                   - Check if NODEHOST can be contacted on sourcing this script. Give a nice message if not.
#                   - Set an environment variable on sourcing this script that indicates 
#                       if we are on the BETA network, PROD network or OTHER network
#                   - remote_block_count available for BETA network (meltingice only for now)
#                   - Set use_peers to true by default in generate_work (can be overridden by an optional function parameter)
#                   - Allow resuming block generation from already pre-generated block lists, by re-using BLOCK_STORE file.
#          - Bugfix
#                   - Clean up remote_block_count error logging
#          - Refactor
#                   - Move around some functions so they are grouped a little better

# Last Changed By: M. Saunders
# -------------------------------
# Version: 0.9201
#          - Bugfix
#                   - generate_spam_and_broadcast was not passing down parameters to called 
#                       function. (Found by /u/Joohansson)
#                   - broadcast_block was failing in locating 'mktemp' in Windows 10 Ubuntu shell for at 
#                       least one user (Found by /u/Joohansson). This is likely also an issue in the version 
#                       of Ubuntu the Win10 shell is based off too.
#                   - Subsequently, remove all hard coded paths for executables used in here,
#                       our dependency_check should be enough for this, and users can add paths to 
#                       their $PATH if needed for programs.
#                   - Increase number of programs checked in dependency_check
#
# Version: 0.92
#          - Refactor
#                   - Make an open_block wrapper that passes to correct function based on parameters given
#                   - Make send_block and receive_block wrappers
#                   - Rename existing (non-state) 'send_nano' function to '__send_block_DEPRECATED'
#                   - Convert to MNano internally instead of using RPC
#          - Feature
#                   - Allow pulling down the latest in-development version from 'develop-next' branch
#                       via update_nano_functions
#                   - Add remote_block_count function to retrieve block counts from trusted remote nodes
#                   - Add get_account_public_key function
#                   - Add state block version of 'send_block'
#                   - Add state block version of 'receive_block'
#                   - Add generate_spam functions for stress testing
#          - Bugfix
#                   - Fix debug logging, write to a file (previously echoed to stdout which broke other functions)
#                   - Fix block_info_balance related commands for non-state blocks.
#
# Version: 0.91
#          - Bugfix
#                   - Rename and enable update_nano_functions
#
# Version: 0.9
#          - Initial release and upload to github.
#

NODEHOST="127.0.0.1:55000"
DEBUG=${DEBUG:-0}
SCRIPT_FILENAME="$(basename $(readlink -f ${BASH_SOURCE[0]}))"
SCRIPT_FILENAME="${SCRIPT_FILENAME%.*}"
DEBUGLOG="${DEBUGLOG:-$(dirname $(readlink -f ${BASH_SOURCE[0]}))/${SCRIPT_FILENAME}.log}"

NANO_FUNCTIONS_LOCATION=$(readlink -f ${BASH_SOURCE[0]})

ZEROES="0000000000000000000000000000000000000000000000000000000000000000"
ONE_MNANO="1000000000000000000000000000000"

# Expects values of either: PROD,BETA,OTHER
NANO_NETWORK_TYPE=

# Expects decimal value in form of MAJOR.MINOR. Impacts some RPC command parameters (e.g. work_generate)
NANO_NODE_VERSION=

NANO_NODE_VERSION_UNKNOWN=99.99

PROD_BURN_TX_HASH=ECCB8CB65CD3106EDA8CE9AA893FEAD497A91BCA903890CBD7A5C59F06AB9113
BETA_FAUCET_TX_HASH=23D26113B4E843D3A4CE318EF7D0F1B25D665D2FF164AE15B27804EA76826B23

check_dependencies() {
  which bc > /dev/null
  [[ $? -eq 1 ]] && echo "bc not found." >&2 && return 1
  which curl > /dev/null
  [[ $? -eq 1 ]] && echo "cURL not found." >&2 && return 2
  which cut > /dev/null
  [[ $? -eq 1 ]] && echo "cut not found." >&2 && return 3
  which grep > /dev/null
  [[ $? -eq 1 ]] && echo "grep not found." >&2 && return 4
  which mktemp > /dev/null
  [[ $? -eq 1 ]] && echo "mktemp not found." >&2 && return 5
  which md5sum > /dev/null
  [[ $? -eq 1 ]] && echo "md5sum not found." >&2 && return 6
  which sed > /dev/null
  [[ $? -eq 1 ]] && echo "sed not found." >&2 && return 7
  which rm > /dev/null
  [[ $? -eq 1 ]] && echo "rm not found." >&2 && return 8
  which tail > /dev/null
  [[ $? -eq 1 ]] && echo "tail not found." >&2 && return 8
  return 0
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer) 
#      0 means success (is an integer)
is_node_up() {
  local RET=$(block_count)
  [[ "${RET}" == *"count"* ]] && echo "Node is running" && return 0
  error "Your node does not appear to be running. Cannot reach ${NODEHOST}." && return 1
}

determine_network() {
  local BLOCK_HASH=$(block_info_previous_hash "ECCB8CB65CD3106EDA8CE9AA893FEAD497A91BCA903890CBD7A5C59F06AB9113" 2>/dev/null)
  [[ ${#BLOCK_HASH} -eq 64 ]] && echo "PROD" && return 0

  BLOCK_HASH=$(block_info_previous_hash "23D26113B4E843D3A4CE318EF7D0F1B25D665D2FF164AE15B27804EA76826B23" 2>/dev/null)
  [[ ${#BLOCK_HASH} -eq 64 ]] && echo "BETA" && return 1

  echo "OTHER" && return 2
}

print_warning() {
  echo "Please do NOT use this script on the LIVE nano network."
  echo "It is strictly for testing purposes, and is only for the BETA and TEST nano networks"
}

# Many of the functions in this script require a special environment variable to be set before they will function
#   This is just a very small safety check to make sure people think about what they are trying to do.

allow_unsafe_commands() {
  [[ 1 -eq ${NANO_UNSAFE_COMMANDS:-0} ]] && echo 1 || (echo "NANO_UNSAFE_COMMANDS is not set to 1. Ignoring all unsafe commands" >&2 && echo 0)
}

debug() {
  if [[ 1 -eq ${DEBUG} && -w "${DEBUGLOG}" ]]; then
    echo -n " ? ${FUNCNAME[1]:-#SHELL#}: " >> "${DEBUGLOG}"
    echo " $@" >> "${DEBUGLOG}"
  fi
}

error() {
  echo " ! ${FUNCNAME[1]:-#SHELL#}: " >&2
  echo " !! $@" >&2
}

#######################################
# Query commands
#######################################

available_supply() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "available_supply" }' "${NODEHOST}" | grep available | cut -d'"' -f4)
  echo $RET
}

block_count() {
  curl -g -d '{ "action": "block_count" }' "${NODEHOST}"
}

remote_block_count_nanonodeninja() {
  local RET=
  if [[ "${NANO_NETWORK_TYPE:-}" == "PROD" ]]; then
    RET=$(curl -m5 -g "https://nanonode.ninja/api/blockcount" | grep -oP '\"count\"\:\"[0-9]+\"' | cut -d'"' -f4)
  else
    error "Network type ("${NANO_NETWORK_TYPE}") has no known block explorer at nanonodeninja. Cannot determine remote block count."
  fi

  [[ ${#RET} -ne 0 ]] && echo $RET || ( echo 0 && return 1 )
}

remote_block_count_nanomeltingice() {
  local RET=
  if [[ "${NANO_NETWORK_TYPE:-}" == "PROD" ]]; then
    RET=$(curl -m5 -g "https://nano-api.meltingice.net/block_count" | grep -oP '\"count\"\:\"[0-9]+\"' | cut -d'"' -f4)
  elif [[ "${NANO_NETWORK_TYPE:-}" == "BETA" ]]; then
    RET=$(curl -m5 -g "https://beta.nano-api.meltingice.net/block_count" | grep -oP '\"count\"\:\"[0-9]+\"' | cut -d'"' -f4)
  else
    error "Network type ("${NANO_NETWORK_TYPE}") has no known block explorer at meltingice. Cannot determine remote block count."
  fi

  [[ ${#RET} -ne 0 ]] && echo $RET || ( echo 0 && return 1 )
}

remote_block_count_nanowatch() {
  local RET=
  if [[ "${NANO_NETWORK_TYPE:-}" == "PROD" ]]; then
    RET=$(curl -m5 -g "https://api.nanowat.ch/blocks/count" | grep -oP '\"count\"\:\"[0-9]+\"' | cut -d'"' -f4)
  else
    error "Network type ("${NANO_NETWORK_TYPE}") has no known block explorer at nanowatch. Cannot determine remote block count."
  fi

  [[ ${#RET} -ne 0 ]] && echo $RET || ( echo 0 && return 1 )
}

remote_block_count() {
  let GOT_RESULTS=3
  local COUNT1=$(remote_block_count_nanonodeninja 2>/dev/null)
  [[ $COUNT1 -eq 0 ]] && let GOT_RESULTS=$GOT_RESULTS-1
  local COUNT2=$(remote_block_count_nanowatch 2>/dev/null)
  [[ $COUNT2 -eq 0 ]] && let GOT_RESULTS=$GOT_RESULTS-1
  local COUNT3=$(remote_block_count_nanomeltingice 2>/dev/null)
  [[ $COUNT3 -eq 0 ]] && let GOT_RESULTS=$GOT_RESULTS-1
  
  if [[ 0 -eq $GOT_RESULTS ]]; then
    error "Unable to retrieve a remote block count from a reliable source. Is your network connection OK?"
    return 1
  fi

  debug "Got $GOT_RESULTS results when attempting to retrieve remote block counts"
  debug "(${COUNT1:-0}+${COUNT2:-0}+${COUNT3:-0})/${GOT_RESULTS}"
  let AVG=$(echo "(${COUNT1:-0}+${COUNT2:-0}+${COUNT3:-0})/${GOT_RESULTS}" | bc)
  echo $AVG
}

is_local_and_remote_block_counts_similar() {
  local WITHIN_AMOUNT=${1:-15}
  
  local REMOTE_COUNT=$(remote_block_count | grep count | cut -d'"' -f4)
  local LOCAL_COUNT=$(block_count | grep count | cut -d'"' -f4)

  local LOCAL_LOWER=$(echo "${LOCAL_COUNT} - ${WITHIN_AMOUNT}" | bc)
  local LOCAL_UPPER=$(echo "${LOCAL_COUNT} + ${WITHIN_AMOUNT}" | bc)
  
  debug "LL=${LOCAL_LOWER}, LU=${LOCAL_UPPER}"

  local IS_WITHIN=$(echo "${REMOTE_COUNT} >= ${LOCAL_LOWER} && ${REMOTE_COUNT} <= ${LOCAL_UPPER}" | bc)
  echo $IS_WITHIN
}

nano_version() {
  curl -g -d '{ "action": "version" }' "${NODEHOST}"
}

nano_version_number() {
  local RET=$(nano_version | grep node_vendor | cut -d'"' -f4 2>/dev/null)
  local FULL_VERSION_STRING=
  local MAJOR_VERSION=
  local MINOR_VERSION=
  if [[ -n "${RET}" ]]; then
    FULL_VERSION_STRING=$(echo "${RET}" | grep -oP '[0-9\.]+')
    if [[ "${FULL_VERSION_STRING}" == *\.* ]]; then
      MAJOR_VERSION=$(echo "${FULL_VERSION_STRING}" | cut -d'.' -f1)
      MINOR_VERSION=$( (echo "${FULL_VERSION_STRING}" | cut -d'.' -f2) && (echo "${FULL_VERSION_STRING}" | cut -d'.' -f3) ) # just incase an extra decimal appears
    else
      MAJOR_VERSION="${FULL_VERSION_STRING}"
      MINOR_VERSION=0
    fi
  else
    debug "Unable to determine nano node version, empty response from nano_version RPC"
    echo "${NANO_NODE_VERSION_UNKNOWN}" && return 1
  fi
  debug "node_vendor: ${RET}. Version string: ${FULL_VERSION_STRING}. Major: ${MAJOR_VERSION}. Minor: ${MINOR_VERSION}"
  echo "${MAJOR_VERSION}.${MINOR_VERSION}"
}

nano_statistics() {
  curl -g -d '{ "action": "stats", "type": "counters" }' "${NODEHOST}"
}

get_account_info() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${NODEHOST}" )
  echo $RET
}

get_frontier_hash_from_account() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${NODEHOST}" | grep frontier | cut -d'"' -f4)
  echo $RET
}

get_balance_from_account() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${NODEHOST}" | grep balance | cut -d'"' -f4)
  echo $RET
}

get_account_pending() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_balance", "account": "'${ACCOUNT}'", "count": 1 }' "${NODEHOST}" | grep pending | cut -d'"' -f4)
  echo $RET
}

get_account_representative() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_representative", "account": "'${ACCOUNT}'" }' "${NODEHOST}" | grep representative | cut -d'"' -f4)
  echo $RET
}

get_account_public_key() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_key", "account": "'${ACCOUNT}'" }' "${NODEHOST}" | grep key | cut -d'"' -f4)
  echo $RET
}

wallet_contains() {
  local WALLET=${1:-}
  local ACCOUNT=${2:-}
  local RET=$(curl -g -d '{ "action": "wallet_contains", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'" }' "${NODEHOST}" | grep exists | cut -d'"' -f4)
  echo $RET
}

wallet_frontiers() {
  local WALLET=${1:-}
  local RET=$(curl -g -d '{ "action": "wallet_frontiers", "wallet": "'${WALLET}'" }' "${NODEHOST}" )
  echo $RET
}

wallet_balances() {
  local WALLET=${1:-}
  local RET=$(curl -g -d '{ "action": "wallet_balances", "wallet": "'${WALLET}'" }' "${NODEHOST}" )
  echo $RET
}

pending_exists() {
  local HASH=${1:-}
  local RET=$(curl -g -d '{ "action": "pending_exists", "hash": "'${HASH}'" }' "${NODEHOST}" | grep exists | cut -d'"' -f4 )
  echo $RET
}

search_pending() {
  local WALLET=${1:-}
  local RET=$(curl -g -d '{ "action": "search_pending", "wallet": "'${WALLET}'" }' "${NODEHOST}" | grep started | cut -d'"' -f4 )
  echo $RET
}

block_info() {
  local HASH=${1:-}
  local RET=$(curl -g -d '{ "action": "block", "hash": "'${HASH}'" }' "${NODEHOST}")
  echo $RET
}

block_info_previous_hash() {
  local HASH=${1:-}
  local FULL_INFO=$(block_info "${HASH}")
  local PREV_HASH=$(echo "$FULL_INFO" | grep previous | grep -oP 'previous\\":\s\\"(.*?)\\"' | cut -d'"' -f3 | grep -oP '[A-F0-9]+')
  echo $PREV_HASH
}

# Get the balance of the account that published block with $HASH (not the amount being sent/received in the block)
block_info_account_balance() {
  local HASH=${1:-}
  local FULL_INFO=$(block_info "${HASH}")
  echo "$FULL_INFO" | grep type | grep state > /dev/null 2>&1
  local IS_STATE=$?
  [[ 0 -eq $IS_STATE ]] && IS_STATE="Y" || IS_STATE="N"
  if [[ "Y" == "$IS_STATE" ]]; then
    debug "state block"
    local ACCOUNT_BALANCE=$(echo "$FULL_INFO" | grep balance | grep -oP 'balance\\":\s\\"(.*?)\\"' | cut -d'"' -f3 | grep -oP '[0-9]+')
    debug "ACCOUNT_BALANCE (dec): ${ACCOUNT_BALANCE}"
    echo $ACCOUNT_BALANCE
  else
    debug "older, non-state block"
    local ACCOUNT_BALANCE=$(echo "$FULL_INFO" | grep balance | grep -oP 'balance\\":\s\\"(.*?)\\"' | cut -d'"' -f3 | grep -oP '[A-F0-9]+')
    debug "ACCOUNT_BALANCE (hex): ${ACCOUNT_BALANCE}"
    ACCOUNT_BALANCE=$(echo "ibase=16; $ACCOUNT_BALANCE" | bc)
    echo $ACCOUNT_BALANCE
  fi
}

block_info_amount() {
  local HASH=${1:-}
  local PREV_HASH=$(block_info_previous_hash "${HASH}")

  local ACCOUNT_BALANCE_NOW=$(block_info_account_balance "${HASH}")
  local ACCOUNT_BALANCE_PREV=$(block_info_account_balance "${PREV_HASH}")

  local IS_SEND=$(echo "${ACCOUNT_BALANCE_NOW} < ${ACCOUNT_BALANCE_PREV}" | bc)
  local IS_EQUAL=$(echo "${ACCOUNT_BALANCE_NOW} < ${ACCOUNT_BALANCE_PREV}" | bc)
  if [[ $IS_SEND -eq 1 ]]; then
    debug "this block is a send"
    local AMOUNT=$(echo "${ACCOUNT_BALANCE_PREV} - ${ACCOUNT_BALANCE_NOW}" | bc)
    echo $AMOUNT
  elif [[ $IS_EQUAL -eq 1 ]]; then
    debug "this block is neither a send nor a receive"
    echo 0
  else
    debug "this block is a receive"
    local AMOUNT=$(echo "${ACCOUNT_BALANCE_NOW} - ${ACCOUNT_BALANCE_PREV}" | bc)
    echo $AMOUNT
  fi
}

block_info_amount_mnano() {
  local HASH=${1:-}
  local RAW_AMOUNT=$(block_info_amount "${HASH}")

  echo $(raw_to_mnano ${RAW_AMOUNT})
  #local RET=$(curl -g -d '{ "action": "mrai_from_raw", "amount": "'${RAW_AMOUNT}'" }' "${NODEHOST}" | grep amount | cut -d'"' -f4)
}

#######################################
# Wallet commands
#######################################


wallet_create() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local RET=$(curl -g -d '{ "action": "wallet_create" }' "${NODEHOST}" | grep wallet | cut -d'"' -f4)
  echo $RET
}

wallet_export() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  curl -g -d '{ "action": "wallet_export", "wallet": "'${WALLET}'" }' "${NODEHOST}"
}

#######################################
# Accounts commands
#######################################

accounts_create() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  local COUNT=${2:-0}
  local WORKGEN=${3:-false}
  local RET=$(curl -g -d '{ "action": "accounts_create", "wallet": "'${WALLET}'", "count": "'${COUNT}'", "work": "'${WORKGEN}'" }' "${NODEHOST}")
  echo $RET

}

account_create() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  echo $(accounts_create "${WALLET}" "1" "true")
}


#######################################
# SEED commands
#######################################

# All of these commands require a special environment variable to be set before they will function
#   This is just a very small safety check to make sure we don't accidentally run anything we don't want to do.

# NOTE: any functions that take a SEED or PRIVATE KEY are especially UNSAFE
#       These functions can expose your SEED or PRIVATE KEY to OTHER USERS of the system, or ANY user if exploits
#         exist in any applications running on here exposed to the internet.

# Do not use this function, instead use wallet_change_seed, which takes a FILE as a parameter where the FILE
#   contains the SEED text. This command instead takes the SEED text which is UNSAFE.
wallet_change_seed_UNSAFE() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: WALLETUUID SEED"
    return 9
  fi

  local WALLET=${1:-}
  local SEED=${2:-}
  local RET=$(curl -g -d '{ "action": "wallet_change_seed", "wallet": "'${WALLET}'", "seed": "'${SEED}'" }' "${NODEHOST}")
  echo $RET
}

wallet_change_seed() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: WALLETUUID SEED_FILE"
    return 9
  fi

  local WALLET=${1:-}
  local SEED_FILE=${2:-}
  [[ ! -e "${SEED_FILE}" ]] && echo You must specify the filename containing your SEED as TEXT to use this function. && return 1
  local RET=$(curl -g -d '{ "action": "wallet_change_seed", "wallet": "'${WALLET}'", "seed": "'$(cat "${SEED_FILE}")'" }' "${NODEHOST}" | grep success | cut -d'"' -f2)
  echo $RET
}

# Do not use this function, instead use query_deterministic_keys, which takes a FILE as a parameter where the FILE
#   contains the SEED text. This command instead takes the SEED text which is UNSAFE.
query_deterministic_keys_UNSAFE() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: SEED INDEX"
    return 9
  fi

  local SEED=${1:-}
  local INDEX=${2:-}
  echo SEED $SEED
  local RET=$(curl -g -d '{ "action": "deterministic_key", "seed": "'${SEED}'", "index": "'${INDEX}'" }' "${NODEHOST}")
  echo $RET
}

query_deterministic_keys() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: SEED_FILE INDEX"
    return 9
  fi

  local SEED_FILE=${1:-}
  local INDEX=${2:-}
  [[ ! -e "${SEED_FILE}" ]] && echo You must specify the filename containing your SEED as TEXT to use this function. && return 1
  local RET=$(curl -g -d '{ "action": "deterministic_key", "seed": "'$(cat "${SEED_FILE}")'", "index": "'${INDEX}'" }' "${NODEHOST}")
  echo $RET
}

#######################################
# Broadcast & PoW commands
#######################################

generate_work() {
  local FRONTIER=${1:-}
  [[ -z "${FRONTIER}" ]] && echo Need a frontier && return 1
  local TRY_TO_USE_WORK_PEERS=${2:-1}  #on by default, can be disabled by passing '0' to this function
  local USE_PEERS=
  if [[ $(is_version_equal_or_greater 14 0) == "true" && 1 -eq ${TRY_TO_USE_WORK_PEERS} ]]; then
    USE_PEERS=", \"use_peers\": \"true\""
  fi
  local RET=$(curl -g -d '{ "action": "work_generate", "hash": "'${FRONTIER}'" '${USE_PEERS}' }' "${NODEHOST}" | grep work| cut -d'"' -f4)
  echo $RET
}

broadcast_block() {
  local BLOCK="${1:-}"
  [[ -z "${BLOCK}" ]] && echo Must provide the BLOCK && return 1
  PAYLOAD_JSON=$(mktemp --tmpdir payload.XXXXX)
  echo '{ "action": "process", "block": "'${BLOCK}'" }' > $PAYLOAD_JSON
  local RET=$(curl -g -d @${PAYLOAD_JSON} "${NODEHOST}")
  DEBUG_BROADCAST=$RET
  [[ ${DEBUG} -eq 0 ]] && rm -f "${PAYLOAD_JSON}"
  local HASH=$(echo "${RET}" | grep hash | cut -d'"' -f4)
  echo $HASH
}

work_peer_list() {
  local RET=$(curl -g -d '{ "action": "work_peers" }' "${NODEHOST}")
  echo $RET
}

work_peer_add() {
  local ADDRESS="${1:-}"
  local PORT=${2:-}

  [[ $# -ne 2 ]] && error "Invalid parameters
    expected: ADDRESS PORT" && return 9
  [[ "false" == $(is_integer "${PORT}") ]] && error "Port must be an integer." && return 2

  local RET=$(curl -g -d '{ "action": "work_peer_add", "address": "'${ADDRESS}'", "port": "'${PORT}'" }' "${NODEHOST}")
  [[ $(echo "${RET}" | grep -o success) != "success" ]] && error "RPC failed to add work peer. Response was ${RET}" && return 1

  echo success
  return 0
}

work_peer_clear_all() {
  local RET=$(curl -g -d '{ "action": "work_peers_clear" }' "${NODEHOST}")
  [[ $(echo "${RET}" | grep -o success) != "success" ]] && error "RPC failed to clear all work peers. Response was ${RET}" && return 1

  echo success
  return 0

}
#######################################
# Convenience functions
#######################################

unregex() {
  # This is a function because dealing with quotes is a pain.
  # http://stackoverflow.com/a/2705678/120999
  sed -e 's/[]\/()$*.^|[]/\\&/g' <<< "${1:-}"
}

strip_block() {
  local TEMPV="${1:-}"
  #Strip ': "' from front and '"' from back.
  TEMPV="${TEMPV#\: \"}"
  TEMPV="${TEMPV%\"}"
  #Strip \n
  TEMPV="${TEMPV//\\\n/}"
  echo "$TEMPV"
}

# Assumes DECIMAL amount for RAW
raw_to_mnano() {
  local RAW_AMOUNT=${1:-}

  local RET=$(echo "scale=2; ${RAW_AMOUNT} / ${ONE_MNANO}" | bc)
  echo $RET
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer) 
#      0 means success (is an integer)
# Also add textual booleans for convenience
is_integer() {
  local INPUT="${1:-}"
  [[ -n ${INPUT//[0-9]/} ]] && echo "false" && return 1
  echo "true" && return 0
}

update_nano_functions() {
  local TESTING=${1:-}
  local BRANCH="master"
  [[ "${TESTING}" == "testing" ]] && BRANCH="develop"
  [[ "${TESTING}" == "bleeding" ]] && BRANCH="develop-next" && echo "WARNING: DO NOT USE THIS BRANCH ON THE LIVE NANO NETWORK. TESTING ONLY"
  local SOURCE_URL="https://raw.githubusercontent.com/VenKamikaze/nano-shell/${BRANCH}/nano-functions.bash"
  if [[ -n "${NANO_FUNCTIONS_LOCATION}" && -w "${NANO_FUNCTIONS_LOCATION}" ]]; then
    curl -o "${NANO_FUNCTIONS_LOCATION}.new" "${SOURCE_URL}"
    if [[ $? -eq 0 && -n $(grep NANO_FUNCTIONS_HASH "${NANO_FUNCTIONS_LOCATION}.new") ]]; then
      local OLD_SCRIPT_HASH="$(get_nano_functions_md5sum)"
      if [[ "${OLD_SCRIPT_HASH}" == "${NANO_FUNCTIONS_HASH}" ]]; then
        echo "Hash check for ${NANO_FUNCTIONS_LOCATION} succeeded and matched internal hash."
        echo "$(basename ${NANO_FUNCTIONS_LOCATION}) downloaded OK... renaming old script and replacing with new."
        mv -f "${NANO_FUNCTIONS_LOCATION}" "${NANO_FUNCTIONS_LOCATION}.old"
        mv -f "${NANO_FUNCTIONS_LOCATION}.new" "${NANO_FUNCTIONS_LOCATION}"
        echo "Script ${NANO_FUNCTIONS_LOCATION} has been replaced with the latest copy. If you have problems, you can find the previous version of the script here: ${NANO_FUNCTIONS_LOCATION}.old"
        [[ $? -eq 0 ]] && echo Sourcing updated script && source "${NANO_FUNCTIONS_LOCATION}"
      else
        echo "---------------------------------------------------------------------------------------"
        echo "Calculated hash for ${NANO_FUNCTIONS_LOCATION} did not match internal hash."
        echo "This means you have custom modifications to your nano-functions script."
        echo "We have downloaded the new version of nano-functions as ${NANO_FUNCTIONS_LOCATION}.new."
        echo "To protect your custom modifications, we are not automatically overwriting your copy."
        echo "You must manually replace your old script to complete your upgrade."
      fi
    else
      echo "Unable to download ${SOURCE_URL}. Failed to update." >&2 && return 1
    fi
  else
    echo "${NANO_FUNCTIONS_LOCATION} not writable or was not set. Failed to update." >&2 && return 1
  fi
}

get_nano_functions_md5sum() {
  local NANO_FUNCTIONS_HASH=$(grep -vE '^NANO_FUNCTIONS_HASH=.*$' ${NANO_FUNCTIONS_LOCATION} | md5sum)
  echo "${NANO_FUNCTIONS_HASH:0:32}"
}

get_nano_version_major() {
  echo "${NANO_NODE_VERSION}" | cut -d'.' -f1
}

get_nano_version_minor() {
  local RET=$(echo "${NANO_NODE_VERSION}" | cut -d'.' -f2)
  [[ -z "${RET}" ]] && echo 0
  echo "${RET}"
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer) 
#      0 means success (is an integer)
# Also add textual booleans for convenience
is_version_equal_or_greater() {
  local MAJOR="${1:-}"
  local MINOR="${2:-}"

  local OUR_MAJOR=$(get_nano_version_major)
  local OUR_MINOR=$(get_nano_version_minor)

  if [[ ${OUR_MAJOR} -gt ${MAJOR} ]]; then
    echo true
    return 0
  elif [[ ${OUR_MAJOR} -eq ${MAJOR} && ${OUR_MINOR} -ge ${MINOR} ]]; then
    echo true
    return 0
  else
    echo false
    return 1
  fi
}

#######################################
# Wrapper functions
#######################################

#Wrapper that calls the appropriate internal __open_block methods based on parameters passed in
open_block() {
  if [[ $# -eq 4 ]]; then
    __open_block_privkey $@
  elif [[ $# -eq 5 ]]; then
    __open_block_wallet $@
  else
    error "Invalid parameters
    expected: PRIVKEY SOURCE DESTACCOUNT REPRESENTATIVE
          or: WALLETUUID ACCOUNT SOURCE DESTACCOUNT REPRESENTATIVE"
    return 9
  fi
}

#Wrapper that calls the appropriate internal __create_send_block_.* methods based on parameters passed in
send_block() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -eq 4 ]]; then
    local NEWBLOCK=$(__create_send_block_privkey $@)
    broadcast_block "${NEWBLOCK}"
  elif [[ $# -eq 5 ]]; then
    error "NOT YET IMPLEMENTED"
    return 10
    #__send_block_wallet $@
  else
    error "Invalid parameters
    expected: PRIVKEY SOURCE DESTACCOUNT BALANCE_IN_MNANO
          or: WALLETUUID ACCOUNT SOURCE DESTACCOUNT BALANCE_IN_MNANO"
    return 9
  fi
}

#Wrapper that calls the appropriate internal __create_receive_block.* methods based on parameters passed in
receive_block() {
  if [[ $# -eq 3 ]]; then
    local NEWBLOCK=$(__create_receive_block_privkey $@)
    broadcast_block "${NEWBLOCK}"
  elif [[ $# -eq 4 ]]; then
    error "NOT YET IMPLEMENTED"
    return 10
    #__create_receive_block_wallet $@
  else
    error "Invalid parameters
    expected: PRIVKEY SOURCE DESTACCOUNT 
          or: WALLETUUID ACCOUNT SOURCE DESTACCOUNT"
    return 9
  fi
}


#######################################
# Stress-test functions
#######################################

# This function will loop forever until interrupted or until a failure occurs.
# It loops forever running the 'generate_spam_and_broadcast' function.
generate_spam_and_broadcast_until_stopped() {
  while true; do
    generate_spam_and_broadcast $@
    [[ $? -ne 0 ]] && error "Call to generate_spam_and_broadcast failed. Aborting infinite loop and exiting..." && return 1
  done
}

# This function generates BLOCKS_TO_CREATE blocks, and then immediately sends them
generate_spam_and_broadcast() {
  [[ $# -ne 3 ]] && error "Invalid parameters
                    expected: PRIVKEY SOURCE DESTACCOUNT" && return 9

  [[ -z "${BLOCKS_TO_CREATE}" || "false" == $(is_integer "${BLOCKS_TO_CREATE}") ]] && error "Please set the environment variable BLOCKS_TO_CREATE (integer) before calling this method." && return 3
  [[ -z "${BLOCK_STORE}" ]] && BLOCK_STORE=$(mktemp --tmpdir block_store_temp.XXXXX)

  generate_spam_sends_to_file $@
  [[ $? -ne 0 ]] && error "Error in function. Aborting and removing ${BLOCK_STORE}." && rm -f "${BLOCK_STORE}" && return 1

  send_pre-generated_blocks
  local RET=$?
  [[ -f "${BLOCK_STORE}.$(date +%F.%H.%M.%S)" ]] && rm -f "${BLOCK_STORE}.$(date +%F.%H.%M.%S)"
  [[ -f "${BLOCK_STORE}" ]] && rm -f "${BLOCK_STORE}"
  return $RET
}

# This function generates BLOCKS_TO_CREATE blocks, and writes them to file BLOCK_STORE
generate_spam_sends_to_file() {
  [[ $# -ne 3 ]] && error "Invalid parameters
                    expected: PRIVKEY SOURCE DESTACCOUNT" && return 9

  [[ -z "${BLOCK_STORE:-}" ]] && error "Please set the environment variable BLOCK_STORE before calling this method." && return 3
  [[ -z "${BLOCKS_TO_CREATE}" || "false" == $(is_integer "${BLOCKS_TO_CREATE}") ]] && error "Please set the environment variable BLOCKS_TO_CREATE (integer) before calling this method." && return 3

  local CURRENT_BALANCE=
  local PREVIOUS_BLOCK_HASH=
  if [[ -f "${BLOCK_STORE}" ]]; then
    if [[ -f "${BLOCK_STORE}.hash" ]]; then
      echo "File ${BLOCK_STORE} exists, and associated hash file exists. Getting last block hash, will continue generating from that point."
      PREVIOUS_BLOCK_HASH=$(tail -n1 "${BLOCK_STORE}.hash")
      CURRENT_BALANCE=$(tail -n1 "${BLOCK_STORE}" | grep -oP '\\"balance\\"\:\s{0,}\\"[0-9]+' | cut -d'"' -f4)
      [[ ${#PREVIOUS_BLOCK_HASH} -ne 64 ]] && error "Previous block hash from file ${BLOCK_STORE}.hash was not a valid hash" && return 4
      [[ -z ${CURRENT_BALANCE} ]] && error "Balance in last generated block in ${BLOCK_STORE} was not found." && return 5
    else
      error "File ${BLOCK_STORE} exists, but not associated hash file exists. You should remove ${BLOCK_STORE} before using this function." && return 6
    fi
  fi

  for ((idx=0; idx < ${BLOCKS_TO_CREATE}; idx++)); do

    local PREVIOUS="${PREVIOUS_BLOCK_HASH}"
    local IGNORE_BLOCK_COUNT_CHECK=1
    __generate_spam_send_to_file $@
    [[ $? -ne 0 ]] && error "Bombing out due to error in generate_spam_send_to_file" && return 1

    [[ "${PREVIOUS_BLOCK_HASH}" == "${BLOCK_HASH}" ]] && error "VALIDATION FAILED: Previously generated hash matches hash just generated." && return 2
    PREVIOUS_BLOCK_HASH="${BLOCK_HASH}"
  done
}

__generate_spam_send_to_file() {
  [[ -z "${BLOCK_STORE:-}" ]] && error "Please set the environment variable BLOCK_STORE before calling this method."

  if [[ $# -eq 3 ]]; then
    
    # Send one RAW
    __create_send_block_privkey $@ 1
    if [[ ${#BLOCK_HASH} -eq 64 ]]; then
      debug "Block generated, got hash ${BLOCK_HASH}. Storing block in ${BLOCK_STORE}."
      echo "${BLOCK}" >> "${BLOCK_STORE}"
      debug "Storing hash in ${BLOCK_STORE}.hash."
      echo "${BLOCK_HASH}" >> "${BLOCK_STORE}.hash"
      CURRENT_BALANCE=$(echo "${BLOCK}" | grep -oP '\\"balance\\"\:\s{0,}\\"[0-9]+' | cut -d'"' -f4)
      [[ "false" == $(is_integer ${CURRENT_BALANCE}) ]] && error "Unable to determine value in block just generated. Aborting..." && return 2
      debug "Holding balance value from block just generated as: ${CURRENT_BALANCE}"
    else
      error "Invalid block hash when creating send block. Got ${BLOCK_HASH:-EMPTY_HASH} Aborting..."
      debug "BLOCK FROM __create_send_block_privkey ON FAILURE: ${BLOCK:-EMPTY_BLOCK}"
      return 1
    fi
  else
    error "Invalid parameters
    expected: PRIVKEY SOURCE DESTACCOUNT"
    return 9
  fi
}

# This function broadcasts all blocks contained within file BLOCK_STORE
send_pre-generated_blocks() {
  [[ -z "${BLOCK_STORE:-}" ]] && error "Please set the environment variable BLOCK_STORE before calling this method."

  while read -r line; do
    broadcast_block "${line}"
  done < "${BLOCK_STORE}"

  debug "Finished broadcasting blocks in ${BLOCK_STORE}. Renaming file to ${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
  mv "${BLOCK_STORE}" "${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
  [[ -f "${BLOCK_STORE}.hash" ]] && mv "${BLOCK_STORE}.hash" "${BLOCK_STORE}.hash.$(date +%F.%H.%M.%S).sent"
}

#######################################
# Block generation functions
#######################################

__open_block_privkey() {
  local PRIVKEY=${1:-}
  local SOURCE=${2:-}
  local DESTACCOUNT=${3:-}
  local REPRESENTATIVE=${4:-}

  local PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ -z "$PREVIOUS" ]] && PREVIOUS=${ZEROES}
  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  if [[ -z "$CURRENT_BALANCE" ]]; then
    [[ "${PREVIOUS}" != "${ZEROES}" ]] && echo "VALIDATION FAILED: Balance for ${DESTACCOUNT} returned null, yet previous hash was non-zero." && return 4
    CURRENT_BALANCE=0
  fi

  local AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE}")

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | bc)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to open account $DESTACCOUNT with state block by receiving block $SOURCE"
  local RET=$(curl -g -d '{ "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }' "${NODEHOST}")
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"${DESTACCOUNT}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts new balance after pocketing open block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"${REPRESENTATIVE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  local BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
  broadcast_block "${BLOCK}"
}

# Expects WALLET and ACCOUNT params (did not work for me)
__open_block_wallet() {
  local WALLET=${1:-}
  local ACCOUNT=${2:-}
  local SOURCE=${3:-}
  local DESTACCOUNT=${4:-}
  local REPRESENTATIVE=${5:-}

  local PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ -z "$PREVIOUS" ]] && PREVIOUS=0
  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  [[ -z "$CURRENT_BALANCE" ]] && CURRENT_BALANCE=0

  local AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE}")

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | bc)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to open account $ACCOUNT with state block by receiving block $SOURCE"
  local RET=$(curl -g -d '{ "action": "block_create", "type": "state", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }' "${NODEHOST}")
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"${DESTACCOUNT}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts new balance after pocketing open block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"${REPRESENTATIVE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  local BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
  broadcast_block "${BLOCK}"
}

__create_send_block_privkey() {
  local PRIVKEY=${1:-}
  local SRCACCOUNT=${2:-}
  local DESTACCOUNT=${3:-}
  local AMOUNT_RAW=${4:-}
  local IGNORE_BLOCK_COUNT_CHECK=${IGNORE_BLOCK_COUNT_CHECK:-0}

  if [[ $IGNORE_BLOCK_COUNT_CHECK -eq 0 ]]; then
    [[ $(is_local_and_remote_block_counts_similar) -ne 1 ]] && error "VALIDATION FAILED: Local node block count and remote node block counts are out of sync. Please make sure your node is synchronised before using this function." && return 6
  fi  

  local PREVIOUS=${PREVIOUS:-$(get_frontier_hash_from_account ${SRCACCOUNT})}
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account sending funds had no previous block, or previous block hash is invalid." && return 5

  local CURRENT_BALANCE=${CURRENT_BALANCE:-$(get_balance_from_account ${SRCACCOUNT})}
  if [[ $(echo "${AMOUNT_RAW} != 0" | bc) -eq 1 && ( -z "$CURRENT_BALANCE" || $(echo "${CURRENT_BALANCE} == 0" | bc) -eq 1 ) ]]; then
    error "VALIDATION FAILED: Balance for ${SRCACCOUNT} returned null or zero, no funds are available to send." && return 4
  fi  

  if [[ $(echo "${AMOUNT_RAW} > ${CURRENT_BALANCE}" | bc) -eq 1 ]]; then
    error "VALIDATION FAILED: You are attempting to send an amount greater than the balance of $SRCACCOUNT." && return 7
  fi  

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} - ${AMOUNT_RAW}" | bc)
  if [[ $(echo "${NEW_BALANCE} > ${CURRENT_BALANCE}" | bc) -eq 1 ]]; then
    error "VALIDATION FAILED: Post send balance is greater than existing balance. Are you trying to send a negative amount?." && return 8
  fi  

  local REPRESENTATIVE=$(get_account_representative "${SRCACCOUNT}")
  [[ ${#REPRESENTATIVE} -ne 64 ]] && error "VALIDATION FAILED: Representative account for ${SRCACCOUNT} should be 64 characters. Got ${REPRESENTATIVE}" && return 11

  debug "Amount to send: ${AMOUNT_RAW} | Existing balance (${SRCACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "account": "'${SRCACCOUNT}'", "link": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'", "representative": "'${REPRESENTATIVE}'" }'

  local RET=$(curl -g -d '{ "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "account": "'${SRCACCOUNT}'", "link": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'", "representative": "'${REPRESENTATIVE}'"}' "${NODEHOST}")
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"link_as_account\\\": \\\"${DESTACCOUNT}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain destination account in link_as_account field: ${DESTACCOUNT}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain correct new balance after sending funds: ${NEW_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"${REPRESENTATIVE}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}"
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | grep hash | grep -oP ':(.*)' | cut -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}


__create_receive_block_privkey() {
  local PRIVKEY=${1:-}
  local SOURCE=${2:-}
  local DESTACCOUNT=${3:-}
  local REPRESENTATIVE=${4:-}
  local PREVIOUS=${PREVIOUS:-}

  [[ -z "$PREVIOUS" ]] && PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account receiving funds had no previous block, or previous block hash is invalid." && return 5

  [[ -z "${REPRESENTATIVE}" ]] && REPRESENTATIVE=$(get_account_representative "${DESTACCOUNT}")
  [[ ${#REPRESENTATIVE} -ne 64 ]] && error "VALIDATION FAILED: Representative account for ${DESTACCOUNT} should be 64 characters. Got ${REPRESENTATIVE}" && return 11

  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  if [[ -z "$CURRENT_BALANCE" ]]; then
    [[ "${PREVIOUS}" != "${ZEROES}" ]] && echo "VALIDATION FAILED: Balance for ${DESTACCOUNT} returned null, yet previous hash was non-zero." && return 4
    CURRENT_BALANCE=0
  fi

  local AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE}")

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | bc)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to generate state receive block for $DESTACCOUNT by receiving block $SOURCE"
  local RET=$(curl -g -d '{ "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }' "${NODEHOST}")
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"${DESTACCOUNT}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account new balance after pocketing receive block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"${REPRESENTATIVE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | grep hash | grep -oP ':(.*)' | cut -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}

stop_node() {
  local RET=$(curl -g -d '{ "action": "stop" }' "${NODEHOST}" | grep success | cut -d'"' -f2)
  echo $RET
}

check_dependencies
[[ $? -ne 0 ]] && echo "${BASH_SOURCE[0]} had dependency errors - this script may not function." || echo "${BASH_SOURCE[0]} sourced."

[[ 1 -eq ${DEBUG} && -w "$(dirname ${DEBUGLOG})" ]] && echo "---- ${NANO_FUNCTIONS_LOCATION} v${NANO_FUNCTIONS_VERSION} sourced: $(date '+%F %H:%M:%S.%3N')" >> "${DEBUGLOG}"

print_warning
[[ -z "${NANO_NETWORK_TYPE:-}" ]] && NANO_NETWORK_TYPE=$(determine_network)
if [[ "${NANO_NETWORK_TYPE}" == "OTHER" ]]; then
  error "WARNING: Could not determine what nano network your node is operating on. remote_block_count not available."
else
  [[ -z "${NANO_NODE_VERSION:-}" ]] && NANO_NODE_VERSION=$(nano_version_number)
  [[ "${NANO_NODE_VERSION}" == "${NANO_NODE_VERSION_UNKNOWN}" ]] && error "WARNING: Unable to determine node version. Assuming latest version and all functions are supported. This may impact the functionality of some RPC commands."
fi

NANO_FUNCTIONS_HASH=c27ac57f47d54b987800ddd621eae7d2
