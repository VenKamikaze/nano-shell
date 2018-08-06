#!/bin/bash
#

HOST="127.0.0.1:55000"
DEBUG=${DEBUG:-0}

check_dependencies() {
  which bc
  [[ $? -eq 1 ]] && echo "bc not found." >&2 && return 1
  which curl
  [[ $? -eq 1 ]] && echo "cURL not found." >&2 && return 2
  which cut
  [[ $? -eq 1 ]] && echo "cut not found." >&2 && return 3
  which grep
  [[ $? -eq 1 ]] && echo "grep not found." >&2 && return 4
  which mktemp
  [[ $? -eq 1 ]] && echo "mktemp not found." >&2 && return 5
}

unregex() {
  # This is a function because dealing with quotes is a pain.
  # http://stackoverflow.com/a/2705678/120999
  sed -e 's/[]\/()$*.^|[]/\\&/g' <<< "${1:-}"
}

debug() {
  if [[ 1 -eq ${DEBUG} ]]; then
    echo "$@"
  fi
}

#######################################
# Query commands
#######################################

block_count() {
  curl -g -d '{ "action": "block_count" }' "${HOST}"
}

nano_version() {
  curl -g -d '{ "action": "version" }' "${HOST}"
}

nano_statistics() {
  curl -g -d '{ "action": "stats", "type": "counters" }' "${HOST}"
}

get_account_info() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${HOST}" )
  echo $RET
}

get_frontier_hash_from_account() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${HOST}" | grep frontier | cut -d'"' -f4)
  echo $RET
}

get_balance_from_account() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${HOST}" | grep balance | cut -d'"' -f4)
  echo $RET
}

get_account_representative() {
  local ACCOUNT=${1:-}
  local RET=$(curl -g -d '{ "action": "account_representative", "account": "'${ACCOUNT}'" }' "${HOST}" )
  echo $RET
}

wallet_contains() {
  local WALLET=${1:-}
  local ACCOUNT=${2:-}
  local RET=$(curl -g -d '{ "action": "wallet_contains", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'" }' "${HOST}" | grep exists | cut -d'"' -f4)
  echo $RET
}

wallet_frontiers() {
  local WALLET=${1:-}
  local RET=$(curl -g -d '{ "action": "wallet_frontiers", "wallet": "'${WALLET}'" }' "${HOST}" )
  echo $RET
}

wallet_balances() {
  local WALLET=${1:-}
  local RET=$(curl -g -d '{ "action": "wallet_balances", "wallet": "'${WALLET}'" }' "${HOST}" )
  echo $RET
}

pending_exists() {
  local HASH=${1:-}
  local RET=$(curl -g -d '{ "action": "pending_exists", "hash": "'${HASH}'" }' "${HOST}" | grep exists | cut -d'"' -f4 )
  echo $RET
}

search_pending() {
  local WALLET=${1:-}
  local RET=$(curl -g -d '{ "action": "search_pending", "wallet": "'${WALLET}'" }' "${HOST}" | grep started | cut -d'"' -f4 )
  echo $RET
}

block_info() {
  local HASH=${1:-}
  local RET=$(curl -g -d '{ "action": "block", "hash": "'${HASH}'" }' "${HOST}")
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
    local ACCOUNT_BALANCE=$(echo "$FULL_INFO" | grep balance | grep -oP 'balance\\":\s\\"(.*?)\\"' | cut -d'"' -f3 | grep -oP '[0-9]+')
    echo $ACCOUNT_BALANCE
  else
    local ACCOUNT_BALANCE=$(echo "$FULL_INFO" | grep balance | grep -oP 'balance\\":\s\\"(.*?)\\"' | cut -d'"' -f3 | grep -oP '[0-9]+')
    ACCOUNT_BALANCE=$(echo "ibase=16; $BALANCE" | bc)
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
    # is a send
    local AMOUNT=$(echo "${ACCOUNT_BALANCE_PREV} - ${ACCOUNT_BALANCE_NOW}" | bc)
    echo $AMOUNT
  elif [[ $IS_EQUAL -eq 1 ]]; then
    echo 0
  else
    # is a receive
    local AMOUNT=$(echo "${ACCOUNT_BALANCE_NOW} - ${ACCOUNT_BALANCE_PREV}" | bc)
    echo $AMOUNT
  fi
}

block_info_amount_mrai() {
  local HASH=${1:-}
  local RAW_AMOUNT=$(block_info_amount "${HASH}")

  local RET=$(curl -g -d '{ "action": "mrai_from_raw", "amount": "'${RAW_AMOUNT}'" }' "${HOST}" | grep amount | cut -d'"' -f4)
  echo $RET
}

#######################################
# Wallet commands
#######################################

# All of these commands require a special environment variable to be set before they will function
#   This is just a very small safety check to make sure we don't accidentally run anything we don't want to do.

allow_unsafe_commands() {
  [[ 1 -eq ${NANO_UNSAFE_COMMANDS:-0} ]] && echo 1 || (echo "NANO_UNSAFE_COMMANDS is not set to 1. Ignoring all unsafe commands" >&2 && echo 0)
}

wallet_create() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local RET=$(curl -g -d '{ "action": "wallet_create" }' "${HOST}" | grep wallet | cut -d'"' -f4)
  echo $RET
}

wallet_export() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  curl -g -d '{ "action": "wallet_export", "wallet": "'${WALLET}'" }' "${HOST}"
}

#######################################
# Accounts commands
#######################################

accounts_create() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  local COUNT=${2:-0}
  local WORKGEN=${3:-false}
  local RET=$(curl -g -d '{ "action": "accounts_create", "wallet": "'${WALLET}'", "count": "'${COUNT}'", "work": "'${WORKGEN}'" }' "${HOST}")
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
#   contains the SEED text. This command instead takes the SEED text which is REDICULOUSLY UNSAFE.
wallet_change_seed_UNSAFE() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  local SEED=${2:-}
  local RET=$(curl -g -d '{ "action": "wallet_change_seed", "wallet": "'${WALLET}'", "seed": "'${SEED}'" }' "${HOST}")
  echo $RET
}

wallet_change_seed() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  local SEED_FILE=${2:-}
  [[ ! -e "${SEED_FILE}" ]] && echo You must specify the filename containing your SEED as TEXT to use this function. && return 1
  local RET=$(curl -g -d '{ "action": "wallet_change_seed", "wallet": "'${WALLET}'", "seed": "'$(cat "${SEED_FILE}")'" }' "${HOST}" | grep success | cut -d'"' -f2)
  echo $RET
}

# Do not use this function, instead use wallet_change_seed, which takes a FILE as a parameter where the FILE
#   contains the SEED text. This command instead takes the SEED text which is REDICULOUSLY UNSAFE.
query_deterministic_keys_UNSAFE() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local SEED=${1:-}
  local INDEX=${2:-}
  echo SEED $SEED
  local RET=$(curl -g -d '{ "action": "deterministic_key", "seed": "'${SEED}'", "index": "'${INDEX}'" }' "${HOST}")
  echo $RET
}

query_deterministic_keys() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local SEED_FILE=${1:-}
  local INDEX=${2:-}
  [[ ! -e "${SEED_FILE}" ]] && echo You must specify the filename containing your SEED as TEXT to use this function. && return 1
  local RET=$(curl -g -d '{ "action": "deterministic_key", "seed": "'$(cat "${SEED_FILE}")'", "index": "'${INDEX}'" }' "${HOST}")
  echo $RET
}

#######################################
# Block generation commands
#######################################

generate_work() {
  local FRONTIER=${1:-}
  [[ -z "${FRONTIER}" ]] && echo Need a frontier && return 1
  local RET=$(curl -g -d '{ "action": "work_generate", "hash": "'${FRONTIER}'" }' "${HOST}" | grep work| cut -d'"' -f4)
  echo $RET
}

broadcast_block() {
  local BLOCK="${1:-}"
  [[ -z "${BLOCK}" ]] && echo Must provide the BLOCK && return 1
  PAYLOAD_JSON=$(/usr/bin/mktemp --tmpdir payload.XXXXX)
  echo '{ "action": "process", "block": "'${BLOCK}'" }' > $PAYLOAD_JSON
  local RET=$(curl -g -d @${PAYLOAD_JSON} "${HOST}")
  DEBUG_BROADCAST=$RET
  local HASH=$(echo "${RET}" | grep hash | cut -d'"' -f4)
  echo $HASH
}

receive() {
  local WALLET=${1:-} 
  local ACCOUNT=${2:-} 
  local BLOCK=${3:-} 
  local RET=$(curl -g -d '{ "action": "receive", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'", "block": "'${BLOCK}'" }' "${HOST}" | grep block| cut -d'"' -f4)
  echo $RET
}

#######################################
# Convenience functions
#######################################

strip_block() {
  local TEMPV="${1:-}"
  #Strip ': "' from front and '"' from back.
  TEMPV="${TEMPV#\: \"}"
  TEMPV="${TEMPV%\"}"
  #Strip \n
  TEMPV="${TEMPV//\\\n/}"
  echo "$TEMPV"
}

#Deprecated - use state block type now.
# Also, this never worked. Seems to want a key instead of wallet.
open_block_old() {
  local WALLET=${1:-}
  local ACCOUNT=${2:-}
  local BLOCK_TO_RECEIVE=${3:-}
  local REPRESENTATIVE=${4:-}

  echo About to open account $ACCOUNT by receiving block $BLOCK_TO_RECEIVE
  local RET=$(curl -g -d '{ "action": "block_create", "type": "open", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'", "representative": "'${REPRESENTATIVE}'", "source": "'${BLOCK_TO_RECEIVE}'" }' "${HOST}")
  echo UNPUBLISHED BLOCK FULL RESPONSE:
  echo ------------------
  echo $RET
  echo ------------------
  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  local BLOCK="${TEMPV:1:-1}"
  echo "$BLOCK"
  broadcast_block "${BLOCK}"
}

open_block() {
  local PRIVKEY=${1:-}
  local SOURCE=${2:-}
  local DESTACCOUNT=${3:-}
  local REPRESENTATIVE=${4:-}
  #local REPRESENTATIVE=$(get_account_representative "${DESTACCOUNT}")

  local PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ -z "$PREVIOUS" ]] && PREVIOUS="0000000000000000000000000000000000000000000000000000000000000000"
  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  [[ -z "$CURRENT_BALANCE" ]] && CURRENT_BALANCE=0

  local AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE}")

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | bc)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to open account $DESTACCOUNT with state block by receiving block $SOURCE"
  local RET=$(curl -g -d '{ "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }' "${HOST}")
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"${DESTACCOUNT}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts new balance after pocketing open block funds: ${NEW_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"${REPRESENTATIVE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}"
    return 3
  fi

  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  local BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
  broadcast_block "${BLOCK}"
}

# Expects WALLET and ACCOUNT params (did not work for me)
open_block_2() {
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

  echo About to open account $ACCOUNT with state block by receiving block $SOURCE
  local RET=$(curl -g -d '{ "action": "block_create", "type": "state", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }' "${HOST}")
  echo UNPUBLISHED BLOCK FULL RESPONSE:
  echo ------------------
  echo $RET
  echo ------------------
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"${DESTACCOUNT}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts new balance after pocketing open block funds: ${NEW_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"${REPRESENTATIVE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}"
    return 3
  fi

  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  local BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
  broadcast_block "${BLOCK}"
}


send_nano() {
  local KEY=${1:-}
  local ACCOUNT_FROM=${2:-}
  local ACCOUNT_TO=${3:-}
  local AMOUNT=${4:-}
  
  local PREVIOUS=$(get_frontier_hash_from_account ${ACCOUNT_FROM})
  local BALANCE=$(get_balance_from_account ${ACCOUNT_FROM})
  local WORK=$(generate_work ${PREVIOUS})

  echo About to send $AMOUNT from $ACCOUNT_FROM to $ACCOUNT_TO
  local RET=$(curl -g -d '{ "action": "block_create", "type": "send", "key": "'${KEY}'", "account": "'${ACCOUNT_FROM}'", "destination": "'${ACCOUNT_TO}'", "balance": "'${BALANCE}'", "amount": "'${AMOUNT}'", "previous": "'${PREVIOUS}'", "work": "'${WORK}'" }' "${HOST}")
  echo UNPUBLISHED BLOCK FULL RESPONSE:
  echo ------------------
  echo $RET
  echo ------------------
  local TEMPV=$(echo "${RET}" | grep block | grep -oP ':(.*)')
  local BLOCK="${TEMPV:1:-1}"
  echo "$BLOCK"
  broadcast_block "${BLOCK}"
}

stop_node() {
  local RET=$(/usr/bin/curl -g -d '{ "action": "stop" }' "${HOST}" | /usr/bin/grep success | /usr/bin/cut -d'"' -f2)
  echo $RET
}

