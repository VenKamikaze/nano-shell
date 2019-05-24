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
NANO_FUNCTIONS_VERSION=0.99

# Version: 0.99
#          - Feature
#                   - Adopt a naming standard for function names (WIP)
#                   - Add dynPoW 'difficulty' option to generate_work 
#                   - Add dynPoW 'work_value' option to create/send/receive/open block
#                   - Add parameter to generate_spam funcs for work difficulty
#                   - Add __create_send_block_wallet alternative function
#                   - Add __create_receive_block_wallet alternative function
#                   - Add __create_changerep_block_wallet alternative function
#                   - send_block wrapper can route to appropriate internal __create_send_block function
#                   - Add password_change_rpc, password_enter_rpc 
#                   - Add key_expand_text_rpc
#                   - Add work_validate_rpc (UNTESTED)
#                   - Add active_difficulty_rpc, active_difficulty_threshold, active_difficulty_active
#                   - Add optional 'subtype' field for process_rpc / broadcast_block
#                   - Use optional 'subtype' field for process_rpc / broadcast_block for most internal calls if node V18+
#          - Refactor
#                   - nanowat.ch has been shutdown - we no longer use it for remote_block_count
#                   - Change raw_to_mnano to show six decimal places
#          - Bugfix
#                   - Handle return of nano_ prefixed addresses in offline signing functions
#                   - Fix generate_spam_send_to_file function when empty block store exists already 
#                   - Fix parameter group parsing in nano_shell_help functions
#                   - Avoid swallowing node RPC output when there are errors - output to stderr instead.
#                   -   FIXME: This means doubling of errors from both stderr and stdout for some functions
#
# Last Changed By: M. Saunders

# -------------------------------
# Version: 0.951
#          - Bugfix
#                   - When performing block_info and related functions, make sure block exists.
#          - TODO
#                   - Check what happens when incorrect accounts etc are specified.
#
# Version: 0.95
#          - Feature
#                   - API documentation for functions. Access with nano_shell_help <funcname>
#                   - nanonodeninja -> My Nano Ninja (Thanks BitDesert)
#                   - update_nano_functions will now attempt to reset the NODEHOST variable
#          - Bugfix
#                   - send_block takes MNano parameter and converts to raw amount
#                   - Fix node version checking for RC releases.
#          - Refactor
#                   - Reduce dependence on environment vars for spam functions
#
# Version: 0.9401
#          - Bugfix
#                   - Update help text for send_block (thanks https://github.com/Laurentiu-Andronache)
#
# Version: 0.94
#          - Feature
#                   - Improve dependency checking
#                   - Add beta.api.nanowat.ch for remote_block_count
#                   - Minor performance improvement for broadcast_block (don't write to a file)
#                   - Improved error handling in send_pre-generated_blocks
#                   - Add simple counting indicator for send_pre-generated_blocks and generate_spam_sends_to_file 
#                   - Add changerep block creation and send functions
#          - Bugfix
#                   - Fix up hidden exit code from cURL command in broadcast_block and some other functions due to 'local'
#                   - Clearly mark variables that should be modified versus those that shouldn't
#                   - Hide cURL stderr output for cleaner parsing
#                   - Exclude NODEHOST and DEBUG from hash checking function
#                   - Change 'meltingice' to 'nanocrawler' in remote block count
#                   - Lighten up some of the scaremongering messages around using this on the production nano network.
#          - Refactor
#                   - Change internal create open block functions to not automatically broadcast the block
#                   - Check return values for internal state block creation functions
#
# Version: 0.9302
#          - Bugfix
#                   - Fix return value from spam function
#          - Feature
#                   - Add get_peers to show connected peers
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
#
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

# You can modify these two variables safely, and without affecting automatic updates of this script

NODEHOST="localhost.localdomain:55000"
DEBUG=${DEBUG:-0}

# Do not modify the following unless you know what you are doing.

SCRIPT_FILENAME="$(basename $(readlink -f ${BASH_SOURCE[0]}))"
SCRIPT_FILENAME="${SCRIPT_FILENAME%.*}"
DEBUGLOG="${DEBUGLOG:-$(dirname $(readlink -f ${BASH_SOURCE[0]}))/${SCRIPT_FILENAME}.log}"

NANO_FUNCTIONS_LOCATION=$(readlink -f ${BASH_SOURCE[0]})

ZEROES="0000000000000000000000000000000000000000000000000000000000000000"
ONE_MNANO="1000000000000000000000000000000"
BURN_ADDRESS="xrb_1111111111111111111111111111111111111111111111111111hifc8npp"
BURN_ADDRESS_NOPREFIX="${BURN_ADDRESS/xrb_/}"

# Binary dependencies required. Assumed to be on $PATH but will
#  try a few other locations and set the var appropriately if needed.
WHICH=which
BC=bc
CURL=curl
CUT=cut
GREP=grep
MKTEMP=mktemp
MD5SUM=md5sum
SED=sed
RM=rm
TAIL=tail
HEAD=head
PRINTF=printf
SEQ=seq
SORT=sort
WC=wc

# Expects values of either: PROD,BETA,OTHER
NANO_NETWORK_TYPE=

# Expects decimal value in form of MAJOR.MINOR. Impacts some RPC command parameters (e.g. work_generate)
NANO_NODE_VERSION=

NANO_NODE_VERSION_UNKNOWN=99.99

PROD_BURN_TX_HASH=ECCB8CB65CD3106EDA8CE9AA893FEAD497A91BCA903890CBD7A5C59F06AB9113
BETA_FAUCET_TX_HASH=23D26113B4E843D3A4CE318EF7D0F1B25D665D2FF164AE15B27804EA76826B23

DIFFICULTY_WEAK=ffffffb000000000
DIFFICULTY_NORMAL=ffffffc000000000 # 1x
DIFFICULTY_STRONG=ffffffcaaaaaa800 # 2x
DIFFICULTY_VERY_STRONG=ffffffdaaaaaa000

# Desc: (Internal function)
# Desc: Try to find $PROG on our $PATH, otherwise attempt to find
# Desc: it in a few common places before giving up...
# Desc: Will echo the pathfile of $PROG if found, or empty+non-zero return code
# P1m: <String, $binaryExecutable>
# P1Desc: Pass in the executable you wish to check the existence of.
# Returns: Text (path to binary executable if found) and return code (0 is success)
__find_dependency() {
  local PROG="${1:-}"
  [[ -z "$PROG" ]] && error "You must specify executable file to find"

  $WHICH "${PROG}" > /dev/null
  let RET=$?
  if [[ $RET -eq 1 ]]; then
    debug "${PROG} not on \$PATH. Trying to find it..."
    debug "Checking /usr/bin"
    [[ -x "/usr/bin/${PROG}" ]] && echo "/usr/bin/${PROG}" && return 0
    debug "Checking /bin"
    [[ -x "/bin/${PROG}" ]] && echo "/bin/${PROG}" && return 0
  elif [[ 0 -eq $RET ]]; then
    echo $($WHICH "${PROG}")
    return 0
  elif [[ 127 -eq $RET ]]; then
    WHICH=
    error "\'which\' not found on \$PATH. Checking other locations..."
    [[ -x "/usr/bin/which" ]] && debug "Found \'which\' at /usr/bin" && WHICH=/usr/bin/which
    [[ -z "$WHICH" && -x "/bin/which" ]] && debug "Found \'which\' at /bin" && WHICH=/bin/which
    if [[ "${PROG}" != "which" ]]; then
      __find_dependency "${PROG}"
    fi
  fi
  error "\'${PROG}\' not found"
  return 1
}

# TODO: fix this to output ALL dependencies missing, rather than bombing out
# TODO: on first one missing.
# Desc: Checks if dependencies required by nano-shell can be found
# Desc: If not, will echo to stderr a message indicating which dependency
# Desc: Could not be found, and returns a unique error code
# Returns: Text to stderr if dependency missing and return code (0 is success)
check_dependencies() {
  WHICH=$(__find_dependency $WHICH)
  if [[ $? -ne 0 ]]; then
    error "\$PATH does not contain 'which' and we could not find it."
    return 127
  fi

  BC=$(__find_dependency $BC)
  [[ $? -eq 1 ]] && echo "bc not found." >&2 && return 1
  CURL=$(__find_dependency $CURL)
  [[ $? -eq 1 ]] && echo "cURL not found." >&2 && return 2
  CUT=$(__find_dependency $CUT)
  [[ $? -eq 1 ]] && echo "cut not found." >&2 && return 3
  GREP=$(__find_dependency $GREP)
  [[ $? -eq 1 ]] && echo "grep not found." >&2 && return 4
  MKTEMP=$(__find_dependency $MKTEMP)
  [[ $? -eq 1 ]] && echo "mktemp not found." >&2 && return 5
  MD5SUM=$(__find_dependency $MD5SUM)
  [[ $? -eq 1 ]] && echo "md5sum not found." >&2 && return 6
  SED=$(__find_dependency $SED)
  [[ $? -eq 1 ]] && echo "sed not found." >&2 && return 7
  RM=$(__find_dependency $RM)
  [[ $? -eq 1 ]] && echo "rm not found." >&2 && return 8
  TAIL=$(__find_dependency $TAIL)
  [[ $? -eq 1 ]] && echo "tail not found." >&2 && return 9
  HEAD=$(__find_dependency $HEAD)
  [[ $? -eq 1 ]] && echo "head not found." >&2 && return 10
  PRINTF=$(__find_dependency $PRINTF)
  [[ $? -eq 1 ]] && echo "printf not found." >&2 && return 11
  SEQ=$(__find_dependency $SEQ)
  [[ $? -eq 1 ]] && echo "seq not found." >&2 && return 12
  SORT=$(__find_dependency $SORT)
  [[ $? -eq 1 ]] && echo "sort not found." >&2 && return 13
  WC=$(__find_dependency $WC)
  [[ $? -eq 1 ]] && echo "wc not found." >&2 && return 14
  return 0
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer) 
#      0 means success (is an integer)
# Desc: Checks if the node is running by executing a block_count RPC call
# Desc: Will echo 'Node is running' and returns 0 if UP
# Desc: Otherwise outputs an error message and returns 0 if DOWN
# Desc: (Note: swallows node RPC errors if any)
# RPC: block_count
# Returns: Text and return code (0 is UP, 1 is DOWN)
is_node_up() {
  local RET=$(block_count_rpc)
  [[ "${RET}" == *"count"* ]] && echo "Node is running" && return 0
  error "Your node does not appear to be running. Cannot reach ${NODEHOST}." && return 1
}

# Desc: Determines the network the node is operating
# Desc: within. It does this by looking for particular
# Desc: block hashes.
# Desc: (Note: swallows node RPC errors if any)
# RPC: block:hash
# Returns: Text (PROD,BETA,OTHER)
determine_network() {
  local BLOCK_HASH=$(block_info_previous_hash "ECCB8CB65CD3106EDA8CE9AA893FEAD497A91BCA903890CBD7A5C59F06AB9113" 2>/dev/null)
  [[ ${#BLOCK_HASH} -eq 64 ]] && echo "PROD" && return 0

  BLOCK_HASH=$(block_info_previous_hash "23D26113B4E843D3A4CE318EF7D0F1B25D665D2FF164AE15B27804EA76826B23" 2>/dev/null)
  [[ ${#BLOCK_HASH} -eq 64 ]] && echo "BETA" && return 1

  echo "OTHER" && return 2
}

# Desc: Prints a warning if using this script on the mainnet.
print_warning() {
  [[ "${NANO_NETWORK_TYPE}" == "PROD" ]] && echo "Please be cautious using this on the LIVE nano network. I cannot be held responsible for any loss of funds or damages through the use of this script."
  return 0
}

# Desc: Many of the functions in this script require a special environment
# Desc: variable to be set before they will function.
# Desc: Outputs '1' if NANO_UNSAFE_COMMANDS environment variable equals 1, otherwise outputs '0'
# Desc: If you wish to use commands that could cause loss of funds due to misuse
# Desc: then run 'export NANO_UNSAFE_COMMANDS=1' to enable these functions.
allow_unsafe_commands() {
  [[ 1 -eq ${NANO_UNSAFE_COMMANDS:-0} ]] && echo 1 || (echo "NANO_UNSAFE_COMMANDS is not set to 1. Ignoring all unsafe commands" >&2 && echo 0)
}

# Desc: If debug flag is enabled, will output logging and stdout where used.
debug() {
  if [[ 1 -eq ${DEBUG} && -w "${DEBUGLOG}" ]]; then
    echo -n " ? ${FUNCNAME[1]:-#SHELL#}: " >> "${DEBUGLOG}"
    echo " $@" >> "${DEBUGLOG}"
  fi
}

# Desc: Prints error messages
# P1m: <Unlimited length string>
# P1Desc: Pass in any message to print it to stderr, and also print the function caller
# Returns: Text to stderr
error() {
  echo " ! ${FUNCNAME[1]:-#SHELL#}: " >&2
  echo " !! $@" >&2
}

#######################################
# Node operation commands
#######################################

# Desc: Shuts down the nano node
# RPC: stop
# Returns: JSON from the node RPC
stop_node_rpc() {
  $CURL -sS -g -d '{ "action": "stop" }' "${NODEHOST}"
}

#######################################
# Help commands
#######################################

# Desc: Provides help for functions provided by nano-shell.
# Desc: If you provide no arguments to this function, it will return a summary list of all available functions
# Desc: Otherwise, you can provide one (1) optional argument.
# P1o: <list,$function_name>
# P1Desc: Specify a particular function_name to retrieve detailed help on using that function_name.
# P1Desc: If nothing is specified, this will default to showing a summary list of all available functions.
# Returns: Text
nano_shell_help() {
  local SEP_H="==========================================================="
  local SEP_B="-----------------------------------------------------------"
  local FUNCTIONAL_HELP=${1:-}
  if [[ -z "${FUNCTIONAL_HELP}" || "list" == "${FUNCTIONAL_HELP}" ]]; then
    echo "${SEP_H}"
    echo "The following functions are provided by ${NANO_FUNCTIONS_LOCATION}."
    echo "${SEP_H}"
    cat "${NANO_FUNCTIONS_LOCATION}" | $SED -n "s/^\([a-z0-9_]*\)\(()\s*{\)$/\1/p" | $SORT
    echo "${SEP_H}"
  else
    debug "Showing detailed help for function named: ${FUNCTIONAL_HELP}"
    local GENERALISED_BEFORE=$($GREP -B50 -E "^(${FUNCTIONAL_HELP})\(\)\s*.*$" "${NANO_FUNCTIONS_LOCATION}")
    [[ -z "${GENERALISED_BEFORE}" ]] && echo "No function matching ${FUNCTIONAL_HELP} found." && return 1
    local DETAIL=$(__nano_shell_help_detail "${GENERALISED_BEFORE}")
    debug "Got detail $DETAIL (END DETAIL)"
    echo "${SEP_H}"
    echo "Function Name: ${FUNCTIONAL_HELP}"
    echo "${SEP_B}"
    echo -n "Description:"
    echo "$DETAIL" | $SED -n "s/^#\sDesc:\s*\(.*\)/  \1/p"
    echo "${SEP_B}"
    local RPCINFO=$(echo "$DETAIL" | $SED -n "s/^#\sRPC:\s*\(.*\)/  \1/p")
    if [[ -n "${RPCINFO}" ]]; then 
      echo -n "RPC call(s) used:"
      echo "${RPCINFO}"
      echo "${SEP_B}"
    fi
    local DEPRECATED=$(echo "$DETAIL" | $SED -n "s/^#\sDEPRECATED:\s*\(.*\)/  \1/p")
    if [[ -n "${DEPRECATED}" ]]; then 
      echo -n "DEPRECATED FUNCTION:"
      echo "${DEPRECATED}"
      echo "${SEP_B}"
    fi
    local RETURNS=$(echo "$DETAIL" | $SED -n "s/^#\sReturns:\s*\(.*\)/  \1/p")
    if [[ -n "${RETURNS}" ]]; then 
      echo -n "Returns:"
      echo "${RETURNS}"
      echo "${SEP_B}"
    fi
    __nano_shell_help_parameters "${DETAIL}"
    echo "${SEP_H}"
  fi
}

# Desc: (Internal function)
# Desc: Gets the comments preceeding a function name for parsing by the help
# Desc:   functions.
__nano_shell_help_detail() {
  local NO_HELP_AVAILABLE="# Desc: No help available for this function."
  local LINES_BEFORE="${1:-}"
  let LINE_COUNT=$(echo "${LINES_BEFORE}" | $WC -l)-1 # remove the function name line.
  local ITERATOR=$($SEQ 1 ${LINE_COUNT} | $SORT -rn)
  echo "$ITERATOR" | while read l; do
    local CURRLINE=$(trim $(echo "${LINES_BEFORE}" | $SED -n "$l"p ))
    let NEXTNUM=$l+1
    local PREVLINE=$(trim $(echo "${LINES_BEFORE}" | $SED -n "$NEXTNUM"p))
    if [[ "${PREVLINE}" == \#* ]]; then
      if [[ -z "${CURRLINE}" ]]; then
        debug "Found end of help section for function. Index is $l out of line count $LINE_COUNT."
        echo "${LINES_BEFORE}" | $SED -n "${l},${LINE_COUNT}p" 
        return 0
      fi
    fi
    PREVLINE="${CURRLINE}"
    [[ $l -eq 1 ]] && return 1
  done
  [[ $? -ne 0 ]] && echo "${NO_HELP_AVAILABLE}" && return 1
  return 0
}

# Desc: (Internal function)
# Desc: Provides parsing of help documentation for function parameters
# Desc:   where function comments match expected format.
__nano_shell_help_parameters() {
  local DETAIL="${1:-}"
  local SEP_B="-----------------------------------------------------------"
  echo "Parameters:"
  local PARAM_GROUPS=$(echo "${DETAIL}" | $GREP -oE "^#\sg[0-9]P[0-9]")
  for PARAM_POS in $($SEQ 1 9); do
    local PARAM_IS_OPTIONAL
    local PARAM_VALUES
    local PARAM_DESC
    if [[ -n "${PARAM_GROUPS}" ]]; then
      echo " Group (${PARAM_POS}): "
      for PARAM_POS2 in $($SEQ 1 9); do
        PARAM_IS_OPTIONAL=$(echo "${DETAIL}" | $GREP -oE "^#\sg${PARAM_POS}P${PARAM_POS2}o")
        PARAM_VALUES=$(trim $(echo "${DETAIL}" | $SED -n "s/^#\sg${PARAM_POS}P${PARAM_POS2}[o]*:\s*\(.*\)/  \1/p"))
        [[ -z "${PARAM_VALUES}" ]] && break
        PARAM_DESC=$(echo "${DETAIL}" | $SED -n "s/^#\sg${PARAM_POS}P${PARAM_POS2}Desc:\s*\(.*\)/  \1/p")
        [[ -n "${PARAM_IS_OPTIONAL}" ]] && echo " (${PARAM_POS2}) Parameter is OPTIONAL" || echo " (${PARAM_POS2}) Parameter is MANDATORY"
        echo " (${PARAM_POS2}) Valid values: ${PARAM_VALUES} "
        echo " (${PARAM_POS2}) Description: "
        echo "${PARAM_DESC}"
      done
      echo "${SEP_B}"
      local NEXTGROUP=0
      let NEXTGROUP=$PARAM_POS+1
      local NEXT_GROUP_EXISTS=$(echo "${DETAIL}" | $GREP -oE "^#\sg${NEXTGROUP}P1")
      [[ -z "${NEXT_GROUP_EXISTS}" ]] && break
    else
       PARAM_IS_OPTIONAL=$(echo "${DETAIL}" | $GREP -oE "^#\sP${PARAM_POS}o")
       PARAM_VALUES=$(echo "${DETAIL}" | $SED -n "s/^#\sP${PARAM_POS}[o]*:\s*\(.*\)/  \1/p")
      [[ -z "${PARAM_VALUES}" ]] && break
       PARAM_DESC=$(echo "${DETAIL}" | $SED -n "s/^#\sP${PARAM_POS}Desc:\s*\(.*\)/  \1/p")
      [[ -n "${PARAM_IS_OPTIONAL}" ]] && echo " (${PARAM_POS}) Parameter is OPTIONAL" || echo " (${PARAM_POS}) Parameter is MANDATORY"
      echo " (${PARAM_POS}) Valid values: ${PARAM_VALUES} "
      echo " (${PARAM_POS}) Description: "
      echo "${PARAM_DESC}"
    fi
  done
  [[ 1 -eq ${PARAM_POS} && 1 -gt ${PARAM_POS2:-0} ]] && echo "None" || return 0
}

#######################################
# Query commands
#######################################

# Desc: Show the total circulating supply on the nano network
# RPC: available_supply
# Returns: JSON from the node RPC
available_supply_rpc() {
  $CURL -sS -g -d '{ "action": "available_supply" }' "${NODEHOST}"
}

# Desc: Show the total circulating supply on the nano network
# RPC: available_supply
# Returns: Number
available_supply() {
  local RET=$(available_supply_rpc | show_errors | $GREP available | $CUT -d'"' -f4)
  echo $RET
}

# Desc: Show the checked (valid or processed) and unchecked (invalid or queued) total blocks known to the node
# RPC: block_count
# Returns: JSON from the node RPC
block_count_rpc() {
  $CURL -sS -g -d '{ "action": "block_count" }' "${NODEHOST}"
}

# Desc: Shows bootstrap status
# Desc: (unstable RPC call - may not be
# Desc:  available in future version)
# RPC: bootstrap_status
# Returns: JSON from the node RPC
bootstrap_status_rpc() {
  if [[ $(is_version_equal_or_greater 17 0) != "true" ]]; then
    error "Node v17.0RC1 and above required to use this RPC call"
    return 1
  fi
  $CURL -sS -g -d '{ "action": "bootstrap_status" }' "${NODEHOST}"
}

# Desc: Initiates a lazy bootstrapping attempt
# RPC: bootstrap_lazy
# Returns: JSON from the node RPC
bootstrap_lazy_rpc() {
  if [[ $(is_version_equal_or_greater 17 0) != "true" ]]; then
    error "Node v17.0RC1 and above required to use this RPC call"
    return 1
  fi
  $CURL -sS -g -d '{ "action": "bootstrap_lazy" }' "${NODEHOST}"
}

# Desc: Query the public API at the given site to retrieve a block count
# Desc: Note: This call may break if the given site changes the format used
# Desc: Note:   to display blocks.
# Desc: Note: Only works with the LIVE (PROD) nano network - no BETA API known.
# RPC: (non nano-node, remote call to /api/blockcount)
# Returns: Number (processed blocks)
remote_block_count_mynanoninja() {
  local RET=
  if [[ "${NANO_NETWORK_TYPE:-}" == "PROD" ]]; then
    RET=$($CURL -sS -m5 -g "https://mynano.ninja/api/blockcount" | $GREP -oP '\"count\"\:\"[0-9]+\"' | $CUT -d'"' -f4)
  elif [[ "${NANO_NETWORK_TYPE:-}" == "BETA" ]]; then
    RET=$($CURL -sS -m5 -g "https://beta.mynano.ninja/api/blockcount" | $GREP -oP '\"count\"\:\"[0-9]+\"' | $CUT -d'"' -f4)
  else
    error "Network type ("${NANO_NETWORK_TYPE}") has no known block explorer at My Nano Ninja. Cannot determine remote block count."
  fi

  [[ ${#RET} -ne 0 ]] && echo $RET || ( echo 0 && return 1 )
}

# Desc: Query the public API at the given site to retrieve a block count
# Desc: Note: This call may break if the given site changes the format used
# Desc: Note:   to display blocks.
# RPC: (non nano-node, remote call to /block_count)
# Returns: Number (processed blocks)
# DEPRECATED: Use remote_block_count_mynanoninja instead.
remote_block_count_nanonodeninja() {
  remote_block_count_mynanoninja
}
# Desc: Query the public API at the given site to retrieve a block count
# Desc: Note: This call may break if the given site changes the format used
# Desc: Note:   to display blocks.
# RPC: (non nano-node, remote call to /block_count)
# Returns: Number (processed blocks)
remote_block_count_nanocrawler() {
  local RET
  if [[ "${NANO_NETWORK_TYPE:-}" == "PROD" ]]; then
    RET=$($CURL -sS -m5 -g "https://api.nanocrawler.cc/block_count" | $GREP -oP '\"count\"\:\"[0-9]+\"' | $CUT -d'"' -f4)
  elif [[ "${NANO_NETWORK_TYPE:-}" == "BETA" ]]; then
    RET=$($CURL -sS -m5 -g "https://beta.api.nanocrawler.cc/block_count" | $GREP -oP '\"count\"\:\"[0-9]+\"' | $CUT -d'"' -f4)
  else
    error "Network type ("${NANO_NETWORK_TYPE}") has no known block explorer at meltingice. Cannot determine remote block count."
  fi

  [[ ${#RET} -ne 0 ]] && echo $RET || ( echo 0 && return 1 )
}

# Desc: Query the public API at the given site to retrieve a block count
# Desc: Note: This call may break if the given site changes the format used
# Desc: Note:   to display blocks.
# RPC: (non nano-node, remote call to /block_count)
# Returns: Number (processed blocks)
# DEPRECATED: Use remote_block_count_nanocrawler instead.
remote_block_count_nanomeltingice() {
  remote_block_count_nanocrawler
}

# Desc: Query the public APIs at three different sites and averages the result
# Desc: Sites: Nano Crawler, My Nano Ninja
# Desc: Note: This call may break if the given site(s) change the format used
# Desc: Note:   to display blocks, or if they are offline.
# RPC: (non nano-node, remote calls to community run block explorers)
# Returns: Number (processed blocks average from remote APIs)
remote_block_count() {
  let GOT_RESULTS=2
  local COUNT1=$(remote_block_count_nanocrawler 2>/dev/null)
  [[ $COUNT1 -eq 0 ]] && let GOT_RESULTS=$GOT_RESULTS-1
  local COUNT2=$(remote_block_count_mynanoninja 2>/dev/null)
  [[ $COUNT2 -eq 0 ]] && let GOT_RESULTS=$GOT_RESULTS-1
  
  if [[ 0 -eq $GOT_RESULTS ]]; then
    error "Unable to retrieve a remote block count from a reliable source. Is your network connection OK?"
    return 1
  fi

  debug "Got $GOT_RESULTS results when attempting to retrieve remote block counts"
  debug "(${COUNT1:-0}+${COUNT2:-0})/${GOT_RESULTS}"
  let AVG=$(echo "(${COUNT1:-0}+${COUNT2:-0})/${GOT_RESULTS}" | $BC)
  echo $AVG
}

# Desc: Query public APIs to obtain average block count
# Desc: and then compare the result to our local block count.
# Desc: Sites: Nano Crawler, Nano Node Ninja, Nano Watch
# Desc: Note: This call may break if the given site(s) change the format used
# Desc: Note:   to display blocks.
# P1o: <$within_amount_blocks>
# P1Desc: Check if local block count from our node is within the number of blocks
# P1Desc:   specified by this parameter (positive or negative).
# P1Desc: If no value specified, defaults to 0.01% of remote_block_count average.
# RPC: (non nano-node, remote calls to community run block explorers)
# RPC: block_count
# Returns: Boolean as number (0 false, 1 true)
is_local_and_remote_block_counts_similar() {
  local WITHIN_AMOUNT=${1:-}
  
  local REMOTE_COUNT=$(remote_block_count | $GREP count | $CUT -d'"' -f4)
  local LOCAL_COUNT=$(block_count_rpc | $GREP count | $CUT -d'"' -f4)

  [[ -z "${WITHIN_AMOUNT}" ]] && WITHIN_AMOUNT=$(echo "scale=0; $REMOTE_COUNT / 10000" | $BC)

  local LOCAL_LOWER=$(echo "${LOCAL_COUNT} - ${WITHIN_AMOUNT}" | $BC)
  local LOCAL_UPPER=$(echo "${LOCAL_COUNT} + ${WITHIN_AMOUNT}" | $BC)
  
  debug "LL=${LOCAL_LOWER}, LU=${LOCAL_UPPER}"

  local IS_WITHIN=$(echo "${REMOTE_COUNT} >= ${LOCAL_LOWER} && ${REMOTE_COUNT} <= ${LOCAL_UPPER}" | $BC)
  echo $IS_WITHIN
}

# Desc: Query the node version and max compatible protocol version
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: version
# Returns: JSON from the node RPC
version_rpc() {
  $CURL -sS -g -d '{ "action": "version" }' "${NODEHOST}"
}

# Desc: Query the node version 
# Desc: Parses the result to only show version string as Major.Minor
# RPC: version
# Returns: Decimal version number (major.minor)
nano_version_number() {
  local RET=$(version_rpc 2>/dev/null | show_errors | $GREP node_vendor | $CUT -d'"' -f4)
  local FULL_VERSION_STRING=
  local MAJOR_VERSION=
  local MINOR_VERSION=
  if [[ -n "${RET}" ]]; then
    FULL_VERSION_STRING=$(echo "${RET}" | $GREP -oP '\d+(\.\d+)+')
    if [[ "${FULL_VERSION_STRING}" == *\.* ]]; then
      MAJOR_VERSION=$(echo "${FULL_VERSION_STRING}" | $CUT -d'.' -f1)
      MINOR_VERSION=$( (echo "${FULL_VERSION_STRING}" | $CUT -d'.' -f2) && (echo "${FULL_VERSION_STRING}" | $CUT -d'.' -f3) ) # just incase an extra decimal appears
    else
      MAJOR_VERSION="${FULL_VERSION_STRING}"
      MINOR_VERSION=0
    fi
  else
    debug "Unable to determine nano node version, empty response from version_rpc"
    echo "${NANO_NODE_VERSION_UNKNOWN}" && return 1
  fi
  debug "node_vendor: ${RET}. Version string: ${FULL_VERSION_STRING}. Major: ${MAJOR_VERSION}. Minor: ${MINOR_VERSION}"
  echo "${MAJOR_VERSION}.${MINOR_VERSION}"
}

# Desc: Query the node statistics, type: counters
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: stats:counters
# Returns: JSON from node RPC
stats_counters_rpc() {
  $CURL -sS -g -d '{ "action": "stats", "type": "counters" }' "${NODEHOST}"
}

# Desc: Query the nodes known peers
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: peers
# P1o: <$peer_details>
# P1Desc: Show additional peer details if 'peer_details' is passed in (V18+).
# Returns: JSON from the node RPC
peers_rpc() {
  local PEER_DETAILS="${1:-}"
  local PEER_DETAILS_PARAM=
  [[ -n "${PEER_DETAILS}" && "${PEER_DETAILS}" == "peer_details" && $(is_version_equal_or_greater 18 0) == "true" ]] && PEER_DETAILS_PARAM=", \"peer_details\": \"true\""

  $CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
{ "action": "peers" ${PEER_DETAILS_PARAM} }
JSON
}

#######################################
# Account RPC functions
#######################################

# Desc: Query the account information for the given nano account
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: account_info:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: JSON from the node RPC
account_info_rpc() {
  local ACCOUNT=${1:-}
  $CURL -sS -g -d '{ "action": "account_info", "account": "'${ACCOUNT}'", "count": 1 }' "${NODEHOST}"
}

# Desc: Query the account balance information for the given nano account
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: account_balance:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: JSON from the node RPC
account_balance_rpc() {
  local ACCOUNT=${1:-}
  $CURL -sS -g -d '{ "action": "account_balance", "account": "'${ACCOUNT}'", "count": 1 }' "${NODEHOST}"
}

# Desc: Query the given accounts representative information 
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: account_representative:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: JSON from the node RPC
account_representative_rpc() {
  local ACCOUNT=${1:-}
  $CURL -sS -g -d '{ "action": "account_representative", "account": "'${ACCOUNT}'" }' "${NODEHOST}"
}

# Desc: Query the given accounts public key information
# Desc: Returns JSON result directly from node, no parsing/formatting applied.
# RPC: account_key:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: JSON from the node RPC
account_key_rpc() {
  local ACCOUNT=${1:-}
  $CURL -sS -g -d '{ "action": "account_key", "account": "'${ACCOUNT}'" }' "${NODEHOST}"
}

# Desc: Adds given number of new accounts to wallet.
# Desc: This is generated in a deterministic way based on the 
# Desc: seed associated with your wallet.
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: accounts_create:wallet:count:work
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to create the accounts within
# P2: <$count>
# P2Desc: The number of new accounts to generate. Default is 0
# P3o: <$workgen_boolean>
# P3Desc: Set to true to enable work generation by default after
# P3Desc: creating accounts. Default is false.
# Returns: JSON from node RPC
accounts_create_rpc() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local WALLET=${1:-}
  local COUNT=${2:-0}
  local WORKGEN=${3:-false}
  $CURL -sS -g -d '{ "action": "accounts_create", "wallet": "'${WALLET}'", "count": "'${COUNT}'", "work": "'${WORKGEN}'" }' "${NODEHOST}"
}


#######################################
# Account wrapper functions
#######################################

# Desc: Query the frontier hash for the given nano account
# Desc: (e.g. the head block/the most recent transaction known)
# RPC: account_info:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: Hash
get_frontier_hash_from_account() {
  local ACCOUNT=${1:-}
  local RET=$(account_info_rpc "${ACCOUNT}" | show_errors | $GREP frontier | $CUT -d'"' -f4)
  echo $RET
}

# Desc: Query the balance for the given nano account
# Desc: but return only the balance of the account
# RPC: account_info:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: Number
get_balance_from_account() {
  local ACCOUNT=${1:-}
  local RET=$(account_info_rpc "${ACCOUNT}" | show_errors | $GREP balance | $CUT -d'"' -f4)
  echo $RET
}

# Desc: Query the pending (unpocketed) blocks raw value for the given nano account
# RPC: account_info:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: Number
get_account_pending() {
  local ACCOUNT=${1:-}
  local RET=$(account_balance_rpc "${ACCOUNT}" | show_errors | $GREP pending | $CUT -d'"' -f4)
  echo $RET
}

# Desc: Query who the representative is for the given nano account
# RPC: account_representative:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: Nano address
get_account_representative() {
  local ACCOUNT=${1:-}
  local RET=$(account_representative_rpc "${ACCOUNT}" | show_errors | $GREP representative | $CUT -d'"' -f4)
  echo $RET
}

# Desc: Show the public key for the given nano account
# RPC: account_key:account
# P1: <$nano_address>
# P1Desc: The nano account address to query
# Returns: Public key
get_account_public_key() {
  local ACCOUNT=${1:-}
  local RET=$(account_key_rpc "${ACCOUNT}" | show_errors | $GREP key | $CUT -d'"' -f4)
  echo $RET
}

# Desc: Create a single account in given wallet.
# Desc: Note: enables work generation by default.
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: accounts_create:wallet:count:work
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to create the account within
# Returns: JSON from node RPC
account_create() {
  local WALLET=${1:-}
  accounts_create_rpc "${WALLET}" "1" "true"
}

#######################################
# Wallet RPC functions
#######################################

# Desc: Does this particular wallet UUID contain the given nano account
# RPC: wallet_contains:wallet:account
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to check for the given nano account
# P2: <$nano_address>
# P2Desc: The nano account address
# Returns: JSON from the node RPC
wallet_contains_rpc() {
  local WALLET=${1:-}
  local ACCOUNT=${2:-}
  $CURL -sS -g -d '{ "action": "wallet_contains", "wallet": "'${WALLET}'", "account": "'${ACCOUNT}'" }' "${NODEHOST}"
}

# Desc: Show all known frontier (head blocks) hash 
# Desc: paired with account numbers for given wallet UUID
# RPC: wallet_frontiers:wallet
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to check for frontier-account pairs
# Returns: JSON from the node RPC
wallet_frontiers_rpc() {
  local WALLET=${1:-}
  $CURL -sS -g -d '{ "action": "wallet_frontiers", "wallet": "'${WALLET}'" }' "${NODEHOST}"
}

# Desc: Show all known pending and received balances on all accounts
# Desc: for given wallet UUID
# RPC: wallet_balances:wallet
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to check
# Returns: JSON from the node RPC
wallet_balances_rpc() {
  local WALLET=${1:-}
  $CURL -sS -g -d '{ "action": "wallet_balances", "wallet": "'${WALLET}'" }' "${NODEHOST}"
}

# Desc: Change the password for the wallet to password
# Desc: for given wallet UUID
# RPC: password_change:wallet:password
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to alter the password 
# P2: <$password_as_text>
# P2Desc: The password to set for $wallet_uuid
# Returns: JSON from the node RPC
password_change_rpc() {
  local WALLET=${1:-}
  local PASSWORD=${2:-}
  $CURL -sS -g -d '{ "action": "password_change", "wallet": "'${WALLET}'", "password": "'${PASSWORD}'" }' "${NODEHOST}"
}

# Desc: Unlock the wallet with the password 
# Desc: for given wallet UUID
# RPC: password_enter:wallet:password
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to unlock
# P2: <$password_as_text>
# P2Desc: The password to use to unlock $wallet_uuid
# Returns: JSON from the node RPC
password_enter_rpc() {
  local WALLET=${1:-}
  local PASSWORD=${2:-}
  $CURL -sS -g -d '{ "action": "password_enter", "wallet": "'${WALLET}'", "password": "'${PASSWORD}'" }' "${NODEHOST}"
}

# Desc: Creates a new random wallet
# RPC: wallet_create
# Returns: JSON from the node RPC
wallet_create_rpc() {
  $CURL -sS -g -d '{ "action": "wallet_create" }' "${NODEHOST}"
}

# Desc: Returns a JSON representation of given wallet
# RPC: wallet_export:wallet
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to export
# Returns: JSON from the node RPC
wallet_export_rpc() {
  local WALLET=${1:-}
  $CURL -sS -g -d '{ "action": "wallet_export", "wallet": "'${WALLET}'" }' "${NODEHOST}"
}

#######################################
# Wallet wrapper functions
#######################################

# Desc: Does this particular wallet UUID contain the given nano account
# RPC: wallet_contains:wallet:account
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID to check for the given nano account
# P2: <$nano_address>
# P2Desc: The nano account address
# Returns: Boolean as number (1 true, 0 false)
wallet_contains() {
  local WALLET=${1:-}
  local ACCOUNT=${2:-}
  wallet_contains_rpc "${WALLET}" "${ACCOUNT}" | show_errors | $GREP exists | $CUT -d'"' -f4
}

# Desc: Creates a new random wallet
# RPC: wallet_create
# Returns: Wallet UUID
wallet_create() {
  wallet_create_rpc | show_errors | $GREP wallet | $CUT -d'"' -f4
}

#######################################
# Block info RPC functions
#######################################

# Desc: Determine if block with given hash is pending
# RPC: pending_exists:hash
# P1: <$hash>
# P1Desc: The block hash to check
# Returns: JSON from the node RPC
pending_exists_rpc() {
  local HASH=${1:-}
  $CURL -sS -g -d '{ "action": "pending_exists", "hash": "'${HASH}'" }' "${NODEHOST}"
}

# Desc: Tells the node to search for any pending blocks for 
# Desc: any account within the given wallet
# RPC: search_pending:wallet
# P1: <$wallet_uuid>
# P1Desc: The wallet to scan
# Returns: JSON from the node RPC
search_pending_rpc() {
  local WALLET=${1:-}
  $CURL -sS -g -d '{ "action": "search_pending", "wallet": "'${WALLET}'" }' "${NODEHOST}"
}

# Desc: Get full block information for the given block hash
# RPC: block:hash
# P1: <$hash>
# P1Desc: The block hash to retrieve detail about
# Returns: JSON from the node RPC
# Returns: Also returns C style function return code
# Returns: Return code is 1 if error (block not found)
# Returns: or 0 if success (block found)
block_info_rpc() {
  local HASH=${1:-}
  local RET=
  RET=$($CURL -sS -g -d '{ "action": "block", "hash": "'${HASH}'" }' "${NODEHOST}" | show_errors)
  RETVAL=$?
  echo $RET
  return $RETVAL
}


#######################################
# Block info wrapper functions
#######################################

# Desc: Determine if block with given hash is pending
# RPC: pending_exists:hash
# P1: <$hash>
# P1Desc: The block hash to check
# Returns: Boolean as number (1 true, 0 false)
get_pending_exists() {
  local HASH=${1:-}
  local RET=$(pending_exists_rpc "${HASH}" | show_errors | $GREP exists | $CUT -d'"' -f4 )
  echo $RET
}

# Desc: Tells the node to search for any pending blocks for 
# Desc: any account within the given wallet
# RPC: search_pending:wallet
# P1: <$wallet_uuid>
# P1Desc: The wallet to scan
# Returns: Boolean as number (1 true, 0 false) indicating if searching has started
search_pending() {
  local WALLET=${1:-}
  local RET=$(search_pending_rpc "${WALLET}" | show_errors | $GREP started | $CUT -d'"' -f4 )
  echo $RET
}

# Desc: Get the block hash immediately before the given one
# RPC: block:hash
# P1: <$hash>
# P1Desc: The block hash to retrieve the predecessor for
# Returns: Hash
# Returns: Also returns C style function return code
# Returns: RETVAL is 1 if error (block not found)
# Returns: or 0 if success (block found)
block_info_previous_hash() {
  local HASH=${1:-}
  local FULL_INFO; local RETVAL
  FULL_INFO=$(block_info_rpc "${HASH}")
  RETVAL=$?
  [[ $RETVAL -ne 0 ]] && echo "$FULL_INFO" && return $RETVAL
  local PREV_HASH=$(echo "$FULL_INFO" | $GREP previous | $GREP -oP 'previous\\":\s\\"(.*?)\\"' | $CUT -d'"' -f3 | $GREP -oP '[A-F0-9]+')
  echo $PREV_HASH
  return 0
}

# Desc: Get the balance of the account that published block
# Desc: with the given hash
# Desc: after the balance would be added to the account
# RPC: block:hash
# P1: <$hash>
# P1Desc: The block hash to 
# Returns: Number (account balance)
# Returns: Also returns C style function return code
# Returns: RETVAL is 1 if error (block not found)
# Returns: or 0 if success (block found)
block_info_account_balance() {
  local HASH=${1:-}
  local FULL_INFO; local RETVAL
  FULL_INFO=$(block_info_rpc "${HASH}")
  RETVAL=$?
  [[ $RETVAL -ne 0 ]] && echo "$FULL_INFO" && return $RETVAL
  echo "$FULL_INFO" | $GREP type | $GREP state > /dev/null 2>&1
  local IS_STATE=$?
  [[ 0 -eq $IS_STATE ]] && IS_STATE="Y" || IS_STATE="N"
  if [[ "Y" == "$IS_STATE" ]]; then
    debug "state block"
    local ACCOUNT_BALANCE=$(echo "$FULL_INFO" | $GREP balance | $GREP -oP 'balance\\":\s\\"(.*?)\\"' | $CUT -d'"' -f3 | $GREP -oP '[0-9]+')
    debug "ACCOUNT_BALANCE (dec): ${ACCOUNT_BALANCE}"
    echo $ACCOUNT_BALANCE
  else
    debug "older, non-state block"
    local ACCOUNT_BALANCE=$(echo "$FULL_INFO" | $GREP balance | $GREP -oP 'balance\\":\s\\"(.*?)\\"' | $CUT -d'"' -f3 | $GREP -oP '[A-F0-9]+')
    debug "ACCOUNT_BALANCE (hex): ${ACCOUNT_BALANCE}"
    ACCOUNT_BALANCE=$(echo "ibase=16; $ACCOUNT_BALANCE" | $BC)
    echo $ACCOUNT_BALANCE
  fi
}

# Desc: Determines the balance being transferred in the
# Desc: given block hash
# RPC: block:hash
# P1: <$hash>
# P1Desc: The block hash to query
# Returns: Number (block balance in raw)
# Returns: Also returns C style function return code
# Returns: RETVAL is 1 if error (block not found)
# Returns: or 0 if success (block found)
block_info_amount() {
  local HASH=${1:-}
  local PREV_HASH; local RETVAL
  PREV_HASH=$(block_info_previous_hash "${HASH}")
  RETVAL=$?
  [[ $RETVAL -ne 0 ]] && echo "$PREV_HASH" && return $RETVAL

  local ACCOUNT_BALANCE_PREV
  if [[ -z "${PREV_HASH}" || "${ZEROES}" == "${PREV_HASH}" ]]; then
    ACCOUNT_BALANCE_PREV=0
  else
    ACCOUNT_BALANCE_PREV=$(block_info_account_balance "${PREV_HASH}")
  fi

  local ACCOUNT_BALANCE_NOW=$(block_info_account_balance "${HASH}")

  local IS_SEND=$(echo "${ACCOUNT_BALANCE_NOW} < ${ACCOUNT_BALANCE_PREV}" | $BC)
  local IS_EQUAL=$(echo "${ACCOUNT_BALANCE_NOW} < ${ACCOUNT_BALANCE_PREV}" | $BC)
  if [[ $IS_SEND -eq 1 ]]; then
    debug "this block is a send"
    local AMOUNT=$(echo "${ACCOUNT_BALANCE_PREV} - ${ACCOUNT_BALANCE_NOW}" | $BC)
    echo $AMOUNT
  elif [[ $IS_EQUAL -eq 1 ]]; then
    debug "this block is neither a send nor a receive"
    echo 0
  else
    debug "this block is a receive"
    local AMOUNT=$(echo "${ACCOUNT_BALANCE_NOW} - ${ACCOUNT_BALANCE_PREV}" | $BC)
    echo $AMOUNT
  fi
}

# Desc: Determines the balance being transferred in the
# Desc: given block hash
# RPC: block:hash
# P1: <$hash>
# P1Desc: The block hash to query
# Returns: Number (block balance in MNano)
# Returns: Also returns C style function return code
# Returns: RETVAL is 1 if error (block not found)
# Returns: or 0 if success (block found)
block_info_amount_mnano() {
  local HASH=${1:-}
  local RAW_AMOUNT;local RETVAL
  RAW_AMOUNT=$(block_info_amount "${HASH}")
  RETVAL=$?
  [[ $RETVAL -ne 0 ]] && echo "$RAW_AMOUNT" && return $RETVAL

  echo $(raw_to_mnano ${RAW_AMOUNT})
}

#######################################
# SEED commands
#######################################

# All of these commands require a special environment variable to be set before they will function
#   This is just a very small safety check to make sure we don't accidentally run anything we don't want to do.

# NOTE: any functions that take a SEED or PRIVATE KEY are especially UNSAFE
#       These functions can expose your SEED or PRIVATE KEY to OTHER USERS of the system, or ANY user if exploits
#         exist in any applications running on here exposed to the internet.

# If on a shared server, or
# on an untrusted environment, then it is not recommended to use ANY function below that takes a seed.
# Doing so may expose your seed, which could lead to loss of funds.

#######################################
# SEED RPC functions
#######################################

# Desc: Change the seed associated with the given wallet UUID
# Desc: into the given seed.
# Desc: WARNING: Do not use this function on a shared server
# Desc: your seed could be exposed.
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: wallet_change_seed:wallet:seed
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID you wish to associate with the seed
# P2: <$seed>
# P2Desc: The seed in plaintext. 
# Returns: JSON from the node RPC
wallet_change_seed_text_rpc() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: WALLETUUID SEED"
    return 9
  fi

  local WALLET=${1:-}
  local SEED=${2:-}
  local RET; local RETVAL
  RET=$($CURL -sS -g -d '{ "action": "wallet_change_seed", "wallet": "'${WALLET}'", "seed": "'${SEED}'" }' "${NODEHOST}" | show_errors)
  RETVAL=$?
  echo "${RET}"
  return $RETVAL
}

# Desc: Change the seed associated with the given wallet UUID
# Desc: into the given seed, sourced from a file.
# Desc: WARNING: Do not use this function on a shared server
# Desc: your seed could be exposed.
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: wallet_change_seed:wallet:seed
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID you wish to associate with the seed
# P2: <$seed_file>
# P2Desc: The file containing your plaintext seed. The
# P2Desc: file should consist of a single line with
# P2Desc: your seed in plaintext.
# Returns: JSON from the node RPC
wallet_change_seed() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: WALLETUUID SEED_FILE"
    return 9
  fi

  local RET; local RETVAL
  local WALLET=${1:-}
  local SEED_FILE=${2:-}
  [[ ! -e "${SEED_FILE}" ]] && echo You must specify the filename containing your SEED as TEXT to use this function. && return 1

  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
{ "action": "wallet_change_seed", "wallet": "${WALLET}", "seed": "$(cat ${SEED_FILE})" }
JSON
)
  RETVAL=$?
  echo "${RET}" | show_errors
  return $RETVAL
}

# Do not use this function, instead use query_deterministic_keys, which takes a FILE as a parameter where the FILE
#   contains the SEED text. This command instead takes the SEED text which is UNSAFE.

# Desc: For the given seed (in text) output the
# Desc: number of keys specified by index.
# Desc: This shows the first X number of accounts
# Desc: and their public/private keys on the seed.
# Desc: WARNING: Do not use this function on a shared server
# Desc: your seed could be exposed.
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: deterministic_key:seed:index
# P1: <$seed>
# P1Desc: The seed as text.
# P2: <$index>
# P2Desc: The number of accounts to show
# Returns: JSON from the node RPC
deterministic_keys_rpc_text() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: SEED INDEX"
    return 9
  fi

  local SEED=${1:-}
  local INDEX=${2:-}
  echo SEED $SEED
  local RET=$($CURL -sS -g -d '{ "action": "deterministic_key", "seed": "'${SEED}'", "index": "'${INDEX}'" }' "${NODEHOST}" | show_errors)
  echo $RET
}

# Desc: For the given seed (in file) output the
# Desc: number of keys specified by index.
# Desc: This shows the first X number of accounts
# Desc: and their public/private keys on the seed.
# Desc: WARNING: Do not use this function on a shared server
# Desc: your seed could be exposed.
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: deterministic_key:seed:index
# P1: <$seed_file>
# P1Desc: The file containing your plaintext seed. The
# P1Desc: file should consist of a single line with
# P1Desc: your seed in plaintext.
# P2: <$index>
# P2Desc: The number of accounts to show
# Returns: JSON from the node RPC
deterministic_keys_rpc() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 2 ]]; then
    error "Invalid parameters
    expected: SEED_FILE INDEX"
    return 9
  fi

  local RET; local RETVAL
  local SEED_FILE=${1:-}
  local INDEX=${2:-}
  [[ ! -e "${SEED_FILE}" ]] && echo You must specify the filename containing your SEED as TEXT to use this function. && return 1

  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
{ "action": "deterministic_key", "seed": "$(cat ${SEED_FILE})", "index": "${INDEX}" }
JSON
)
  RETVAL=$?
  echo "${RET}" | show_errors
  return $RETVAL
}

# Desc: Shows associated public key and account with given private key
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# RPC: key_expand
# P1: <$private_key>
# P1Desc: The private key to view account and public key.
# Returns: JSON from the node RPC
key_expand_rpc() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  if [[ $# -ne 1 ]]; then
    error "Invalid parameters
    expected: PRIVATE_KEY"
    return 9
  fi

  local RET; local RETVAL
  local KEY=${1:-}
  RET=$($CURL -sS -g -d '{ "action": "key_expand", "key": "'${KEY}'" }' "${NODEHOST}" | show_errors)
  RETVAL=$?
  echo $RET
  return $RETVAL
}

#######################################
# Broadcast & PoW commands
#######################################

# Desc: Generate the PoW for the given block hash
# RPC: work_generate:hash:use_peers
# P1: <$hash>
# P1Desc: The block hash to generate work for.
# P2o: <$use_peers>
# P2Desc: Can be set to 0 (false) to prevent farming
# P2Desc: off the work generation to any work peers
# P3o: <$difficulty_descriptive_text_or_hex>
# P3Desc: Set the PoW difficulty (V19+ only)
# P3Desc: You can either specify the value in hexadecimal
# P3Desc:   as per the normal node RPC
# P3Desc: OR you can use a built-in value from nano-shell, one of:
# P3Desc:   weak, normal, strong, very_strong
# P3Desc: Defaults to ffffffc000000000 or 'normal'
# Returns: Text (the work signature)
generate_work() {
  local RETVAL; local RET=
  RET=$(work_generate_rpc $@)
  RETVAL=$?
  debug 'Got back result: '"$RET"
  echo $RET | $GREP work | $CUT -d'"' -f4
  return $RETVAL
}

# Desc: Generate the PoW for the given block hash
# RPC: work_generate:hash:use_peers:difficulty
# P1: <$hash>
# P1Desc: The block hash to generate work for.
# P2o: <$use_peers>
# P2Desc: Can be set to 0 or false to prevent farming
# P2Desc: off the work generation to any work peers
# P2Desc: Defaults to 1 or true
# P3o: <$difficulty_descriptive_text_or_hex>
# P3Desc: Set the PoW difficulty (V19+ only)
# P3Desc: You can either specify the value in hexadecimal
# P3Desc:   as per the normal node RPC
# P3Desc: OR you can use a built-in value from nano-shell, one of:
# P3Desc:   weak, normal, strong, very_strong
# P3Desc: Defaults to ffffffc000000000 or 'normal'
# Returns: JSON from the node RPC.
work_generate_rpc() {
  local FRONTIER=${1:-}
  [[ -z "${FRONTIER}" ]] && echo Need a frontier && return 1
  local RET; local RETVAL
  local TRY_TO_USE_WORK_PEERS=${2:-1}  #on by default, can be disabled by passing '0' to this function
  local WORK_DIFFICULTY_VALUE="${3:-${DIFFICULTY_NORMAL}}"
  local USE_PEERS=
  local WORK_DIFFICULTY=
  if [[ $(is_version_equal_or_greater 14 0) == "true" && ( 1 -eq ${TRY_TO_USE_WORK_PEERS} || "true" == ${TRY_TO_USE_WORK_PEERS} ) ]]; then
    USE_PEERS=", \"use_peers\": \"true\""
  fi
  if [[ $(is_version_equal_or_greater 19 0) == "true" ]]; then
    if [[ ${#WORK_DIFFICULTY_VALUE} != 16 ]]; then
      if [[ "${WORK_DIFFICULTY_VALUE}" == "weak" ]]; then
        WORK_DIFFICULTY_VALUE="${DIFFICULTY_WEAK}"
        # "normal" is default, so do not include here
      elif [[ "${WORK_DIFFICULTY_VALUE}" == "strong" ]]; then
        WORK_DIFFICULTY_VALUE="${DIFFICULTY_STRONG}"
      elif [[ "${WORK_DIFFICULTY_VALUE}" == "very_strong" ]]; then
        WORK_DIFFICULTY_VALUE="${DIFFICULTY_VERY_STRONG}"
      else
        error "Difficulty value ${WORK_DIFFICULTY_VALUE} is not a valid value. Ignoring"
      fi
    fi
    WORK_DIFFICULTY=", \"difficulty\": \"${WORK_DIFFICULTY_VALUE}\""
  fi

  debug 'work_generate'
  debug '{ "action": "work_generate", "hash": "'${FRONTIER}'" '${USE_PEERS}' '${WORK_DIFFICULTY}' }'
  local RETVAL; local RET=
#  RET=$($CURL -sS -g -d '{ "action": "work_generate", "hash": "'${FRONTIER}'" "'${USE_PEERS}'" '${WORK_DIFFICULTY}' }' "${NODEHOST}" | $GREP work| $CUT -d'"' -f4)
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
{ "action": "work_generate", "hash": "${FRONTIER}" ${USE_PEERS} ${WORK_DIFFICULTY} }
JSON
)
  RETVAL=$?
  debug 'Got back result: '"$RET"
  if [[ 0 -eq $RETVAL ]]; then
    echo $RET | show_errors
    return $?
  fi
  echo $RET
  return $RETVAL
}

# Desc: Validate the work associated with the given block hash
# Desc: V19RC2+ will also show the work difficulty value.
# RPC: work_validate:work:hash:difficulty
# P1: <$work_value>
# P1Desc: The work signature hash to validate
# P2: <$block_hash>
# P2Desc: The block hash to verify the work signature on
# P3o: <$difficulty> (node V19+ only)
# P3Desc: The hexadecimal difficulty string to use as part of the 
# P3Desc:   work validation. Optional param (if standard difficulty).
# Returns: JSON from the node RPC.
work_validate_rpc() {
  local WORK_VALUE="${1:-}"
  local BLOCK_HASH="${2:-}"
  local DIFFICULTY_PARAM; local DIFFICULTY_HEX="${3:-}"
  local RET; local RETVAL
  [[ -z "${BLOCK_HASH}" ]] && echo Must provide the BLOCK && return 1
  [[ -z "${WORK_VALUE}" ]] && echo Must provide the work value to verify && return 1
  [[ -n "${DIFFICULTY_HEX}" && $(is_version_equal_or_greater 19 0) == "true" ]] && DIFFICULTY_PARAM=", \"difficulty\": \"${DIFFICULTY_HEX}\""

  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
{ "action": "work_validate", "work": "${WORK_VALUE}", "hash": "${BLOCK_HASH}" ${DIFFICULTY_PARAM} }
JSON
)
  RETVAL=$?
  if [[ 0 -eq $RETVAL ]]; then
    echo $RET | show_errors
    return $?
  fi
  echo $RET
  return $RETVAL
}

# Desc: Returns the network's current active PoW difficulty
# Desc: and the node's configured threshold difficulty
# Desc: Note: Undocumented RPC feature beginning at V19.0RC1
# Desc:   This RPC call name may change so is not guaranteed to work.
# RPC: active_difficulty
# Returns: JSON from the node RPC.
active_difficulty_rpc() {
  if [[ $(is_version_equal_or_greater 19 0) != "true" ]]; then
    error "This RPC call is only available for node V19+" && return 1
  fi
  $CURL -sS -g -d '{ "action": "key_expand", "key": "'${KEY}'" }' "${NODEHOST}"
}

# Desc: Returns the node's configured threshold difficulty
# RPC: active_difficulty
# Returns: Hex value for lowest difficulty threshold configured for the node.
active_difficulty_threshold() {
  local RETVAL=0; local RET=
  active_difficulty_rpc | show_errors | $GREP "threshold" | $CUT -d'"' -f4
}

# Desc: Returns the network's current active PoW difficulty 
# RPC: active_difficulty
# Returns: Hex value for network's current detected difficulty.
active_difficulty_active() {
  local RETVAL=0; local RET=
  active_difficulty_rpc | show_errors | $GREP "active" | $CUT -d'"' -f4
}

# Desc: Broadcast the given JSON block to the network
# RPC: process:block
# P1: <$json_block>
# P1Desc: The JSON block to broadcast.
# P2o: <$subtype> (node V18+ only)
# P2Desc: Specify the block sub-type to prevent accidental
# P2Desc: sends instead of a receive when using state blocks.
# Returns: JSON from the node RPC.
process_rpc() {
  local BLOCK="${1:-}"
  local SUBTYPE="${2:-}"; local SUBTYPE_PARAM=
  [[ -n "${SUBTYPE}" && $(is_version_equal_or_greater 18 0) == "true" ]] && SUBTYPE_PARAM=", \"subtype\": \"${SUBTYPE}\"" && debug "Subtype Param: ${SUBTYPE_PARAM}"
  local RET; local RETVAL
  [[ -z "${BLOCK}" ]] && echo Must provide the BLOCK && return 1
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
{ "action": "process" ${SUBTYPE_PARAM} , "block": "${BLOCK}" }
JSON
)
  RETVAL=$?
  DEBUG_BROADCAST=$RET
  if [[ 0 -eq $RETVAL ]]; then
    echo $RET | show_errors
    return $?
  fi
  echo $RET
  return $RETVAL
}

# Desc: Broadcast the given JSON block to the network
# RPC: process:block
# P1: <$json_block>
# P1Desc: The JSON block to broadcast.
# P2o: <$subtype>
# P2Desc: Specify the block sub-type to prevent accidental
# P2Desc: sends instead of a receive when using state blocks.
# Returns: Text (block hash) or empty on failure
broadcast_block() {
  local BLOCK="${1:-}"
  local SUBTYPE="${2:-}"
  local RET; local RETVAL
  RET=$(process_rpc "${BLOCK}" "${SUBTYPE}")
  RETVAL=$?
  DEBUG_BROADCAST=$RET
  if [[ 0 -eq $RETVAL ]]; then
    local HASH=$(echo "${RET}" | $GREP hash | $CUT -d'"' -f4)
    [[ -z "${HASH}" ]] && error "No hash value returned in broadcast_block. Block was probably invalid and failed to publish! Node RPC says: ${RET}" && return 1
    echo $HASH
  else
    error "Non-zero return code ($RETVAL) when using RPC to broadcast block \"${BLOCK}\"."
  fi
  return $RETVAL
}

# Desc: List all associated work peers. These
# Desc: are peers that help perform PoW operations
# Desc: (if configured)
# RPC: work_peers
# Returns: JSON from the node RPC
work_peers_rpc() {
  $CURL -sS -g -d '{ "action": "work_peers" }' "${NODEHOST}"
}

# Desc: List all associated work peers. These
# Desc: are peers that help perform PoW operations
# Desc: (if configured)
# RPC: work_peers
# Returns: JSON from the node RPC
# DEPRECATED: Just wraps work_peers_rpc. May be removed in future version
work_peer_list() {
  work_peers_rpc $@ | show_errors
}

# Desc: Add a work peer to farm out the PoW
# Desc: operations on the node.
# RPC: work_peer_add:address:port
# P1: <$work_peer_address>
# P1Desc: The work peer IP/host address
# P2: <$work_peer_port>
# P2Desc: The work peer port number
# Returns: JSON from the node RPC.
work_peer_add_rpc() {
  local ADDRESS="${1:-}"
  local PORT=${2:-}
  local RET; local RETVAL

  [[ $# -ne 2 ]] && error "Invalid parameters
    expected: ADDRESS PORT" && return 9
  [[ "false" == $(is_integer "${PORT}") ]] && error "Port must be an integer." && return 2

  $CURL -sS -g -d '{ "action": "work_peer_add", "address": "'${ADDRESS}'", "port": "'${PORT}'" }' "${NODEHOST}"
}

# Desc: Add a work peer to farm out the PoW
# Desc: operations on the node.
# RPC: work_peer_add:address:port
# P1: <$work_peer_address>
# P1Desc: The work peer IP/host address
# P2: <$work_peer_port>
# P2Desc: The work peer port number
# Returns: Text (success) or empty on failure.
work_peer_add() {
  local RETVAL; local RET=
  RET=$(work_peer_add_rpc $@ | show_errors)
  RETVAL=$?
  [[ $(echo "${RET}" | $GREP -o success) != "success" ]] && error "RPC failed to add work peer. Response was ${RET}, exit code ($RETVAL)." && return 1
  echo success
  return 0
}


# Desc: Clear the list of all work peers 
# Desc: configured on the node.
# RPC: work_peers_clear
# Returns: Text (success) or empty on failure.
work_peer_clear_all() {
  local RET; local RETVAL
  RET=$(work_peers_clear_rpc $@ | show_errors)
  RETVAL=$?
  [[ $(echo "${RET}" | $GREP -o success) != "success" ]] && error "RPC failed to clear all work peers. Response was ${RET}, exit code ($RETVAL)." && return 1

  echo success
  return 0
}

# Desc: Clear the list of all work peers 
# Desc: configured on the node.
# RPC: work_peers_clear
# Returns: JSON from the node RPC.
work_peers_clear_rpc() {
  local RET; local RETVAL
  $CURL -sS -g -d '{ "action": "work_peers_clear" }' "${NODEHOST}"
}
#######################################
# Convenience functions
#######################################

# Desc: Grep's stdin and if 'error' is found, will
# Desc: output the string to stderr, and give off a non-zero (1)
# Desc: return code.
# Desc: This is used by many internal wrapper functions so we
# Desc: do not swallow the node RPC error messages.
# Desc: WARNING: THIS WILL BLOCK ON WAITING FOR STDIN.
# Returns: The input, but outputs any string containing 'error' to stderr
show_errors() {
  local INPUT=$(cat -)
  local ERROR=$(echo "${INPUT}"| $GREP -i "error")
  [[ -n "$ERROR" ]] && echo "$ERROR" >&2 && echo "${INPUT}" && return 1
  echo "${INPUT}"
  return 0
}

# Desc: Escapes any special characters in given input
# Desc: Thanks to: http://stackoverflow.com/a/2705678/120999
# P1: <$string_input>
# P1Desc: The string to parse and escape.
# Returns: The input string with special characters escaped
unregex() {
  # This is a function because dealing with quotes is a pain.
  # http://stackoverflow.com/a/2705678/120999
  $SED -e 's/[]\/()$*.^|[]/\\&/g' <<< "${1:-}"
}

# Desc: Simple trim (POSIX compliant)
# Desc: to remove leading and trailing whitespace.
# Desc: Thanks to stackoverflow comment: 
# Desc: https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
# Returns: The input trimmed
trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Desc: Parses resulting blocks and strips out leading
# Desc: colon-space-quote and trailing quote from string
# P1: <$JSON_block_result_from_node_RPC>
# P1Desc: Block result from node RPC for stripping.
# Returns: Block with stripped characters ready for 
# Returns: broadcasting or other use.
strip_block() {
  local TEMPV="${1:-}"
  #Strip ': "' from front and '"' from back.
  TEMPV="${TEMPV#\: \"}"
  TEMPV="${TEMPV%\"}"
  #Strip \n
  TEMPV="${TEMPV//\\\n/}"
  echo "$TEMPV"
}

# Desc: Converts from nano raw amounts into
# Desc: MNano (standard measurement unit in 2018)
# P1: <$raw_nano_amount_number>
# P1Desc: The raw nano amount to convert into MNano
# Returns: Number (MNano to six decimal places only)
raw_to_mnano() {
  local RAW_AMOUNT=${1:-}

  local RET=$(echo "scale=6; ${RAW_AMOUNT} / ${ONE_MNANO}" | $BC)
  echo $RET
}

# Desc: Converts from NANO (MNano) amounts into raw
# P1: <$mnano_amount_number>
# P1Desc: The MNano amount to convert into raw
# Returns: Number (raw amount)
mnano_to_raw() {
  local MNANO_AMOUNT=${1:-}

  local RET=$(echo "scale=0; (${MNANO_AMOUNT} * ${ONE_MNANO})/1" | $BC)
  echo $RET
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer) 
#      0 means success (is an integer)
# Also add textual booleans for convenience

# Desc: Check if input satisfies criteria 
# Desc: to be an integer.
# P1: <$input>
# P1Desc: The input string to check.
# Returns: Boolean as string (true) if integer
# Returns: or false if not.
# Returns: Also function return codes are C-style
# Returns: RETVAL is 1 if error (NaN)
# Returns: or 0 if success (is integer)
is_integer() {
  local INPUT="${1:-}"
  [[ -n ${INPUT//[0-9]/} ]] && echo "false" && return 1
  echo "true" && return 0
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer)
#      0 means success (is an integer)
# Also add textual booleans for convenience

# Desc: Check if input satisfies criteria
# Desc: to be a decimal (also works with integer).
# Desc: Thanks to user 'pixelbeat' in StackOverflow thread:
# Desc: https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
# P1: <$input>
# P1Desc: The input string to check.
# Returns: Boolean as string (true) if decimal
# Returns: or false if not.
# Returns: Also function return codes are C-style
# Returns: RETVAL is 1 if error (NaN)
# Returns: or 0 if success (is decimal)
is_decimal() {
  local INPUT="${1:-}"
  local RESULT; local RETVAL
  # filter octal/hex/ord()
  RESULT=$(printf '%s' "${INPUT}" | $SED "s/^0*\([1-9]\)/\1/; s/'/^/")
  test "$num" && printf '%f' "$num" >/dev/null 2>&1
  RETVAL=$?
  [[ 0 -ne $RETVAL ]] && echo "false" && return 1
  echo "true" && return 0
}

# Desc: Update nano-shell to the latest version
# Desc: This will only succeed if no (or minimal)
# Desc: changes have been made to the script itself.
# Desc: nano-shell checks this by calculating an MD5SUM
# Desc: of the file (with certain variables excluded)
# Desc: and comparing it to the internal MD5SUM variable
# Desc: If they don't match, it will download the new
# Desc: version of nano-shell, but leave it alongside
# Desc: the old script with the same filename and
# Desc: the extension '.new' added to it.
# P1o: <master,testing,bleeding>
# P1Desc: You can specify which branch to pull the
# P1Desc: release from. It defaults to 'master'
# P1Desc: but you can pull the 'testing' version
# P1Desc: or even 'bleeding' but this is not recommended
# Returns: Status message indicating whether this was
# Returns: a success or the failure reason.
update_nano_functions() {
  local TESTING=${1:-}
  local BRANCH="master"
  [[ "${TESTING}" == "testing" ]] && BRANCH="develop"
  [[ "${TESTING}" == "bleeding" ]] && BRANCH="develop-next" && echo "WARNING: DO NOT USE THIS BRANCH ON THE LIVE NANO NETWORK. TESTING ONLY"
  local SOURCE_URL="https://raw.githubusercontent.com/VenKamikaze/nano-shell/${BRANCH}/nano-functions.bash"
  if [[ -n "${NANO_FUNCTIONS_LOCATION}" && -w "${NANO_FUNCTIONS_LOCATION}" ]]; then
    $CURL -sS -o "${NANO_FUNCTIONS_LOCATION}.new" "${SOURCE_URL}"
    if [[ $? -eq 0 && -n $($GREP NANO_FUNCTIONS_HASH "${NANO_FUNCTIONS_LOCATION}.new") ]]; then
      local OLD_SCRIPT_HASH="$(get_nano_functions_md5sum)"
      if [[ "${OLD_SCRIPT_HASH}" == "${NANO_FUNCTIONS_HASH}" ]]; then
        echo "Hash check for ${NANO_FUNCTIONS_LOCATION} succeeded and matched internal hash."
        echo "$(basename ${NANO_FUNCTIONS_LOCATION}) downloaded OK... renaming old script and replacing with new."
        PRE_SED_HASH=$(get_nano_functions_md5sum "${NANO_FUNCTIONS_LOCATION}.new")
        echo "Setting NODEHOST variable in new script."
        $SED -i 's/^NODEHOST=\".*\"$/NODEHOST="'${NODEHOST}'"/g' "${NANO_FUNCTIONS_LOCATION}.new"
        if [[ "$PRE_SED_HASH" != $(get_nano_functions_md5sum "${NANO_FUNCTIONS_LOCATION}.new") ]]; then
          error "Setting new NODEHOST variable failed."
          error "nano-shell could not be updated."
          error "Your original nano-shell script should be intact."
          error "Please update manually."
          return 2
        fi
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

# Desc: Get the calculated md5sum of nano-shell
# Desc: excluding variables:
# Desc: NANO_FUNCTIONS_HASH, NODEHOST DEBUG
# Returns: md5sum of nano-shell
get_nano_functions_md5sum() {
  local FILE_TO_HASH=${1:-$NANO_FUNCTIONS_LOCATION}
  local THE_HASH=$($GREP -vE '^NANO_FUNCTIONS_HASH=.*$' ${FILE_TO_HASH} | $GREP -vE '^NODEHOST=.*$' | $GREP -vE '^DEBUG=.*$' | md5sum)
  echo "${THE_HASH:0:32}"
}

# Desc: Get the major version of the node
# Desc: e.g. if you run node v16.3
# Desc: it will return 16
# Desc: (Note: swallows errors from the node RPC)
# Returns: Number (major version of node)
get_nano_version_major() {
  [[ -z "${NANO_NODE_VERSION:-}" ]] && NANO_NODE_VERSION=$(nano_version_number)
  echo "${NANO_NODE_VERSION}" | $CUT -d'.' -f1
}

# Desc: Get the minor version of the node
# Desc: e.g. if you run node v16.3
# Desc: it will return 3
# Desc: (Note: swallows errors from the node RPC)
# Returns: Number (minor version of node)
get_nano_version_minor() {
  [[ -z "${NANO_NODE_VERSION:-}" ]] && NANO_NODE_VERSION=$(nano_version_number)
  local RET=$(echo "${NANO_NODE_VERSION}" | $CUT -d'.' -f2)
  [[ -z "${RET}" ]] && echo 0
  echo "${RET}"
}

# C style return values suck and always confuse me when making shell scripts
# However, we will make this function return C style exit codes
# E.g. 1 means error (not an integer) 
#      0 means success (is an integer)
# Also add textual booleans for convenience

# Desc: Checks if the node version of greater or equal
# Desc: to the given major and minor version parameters
# Desc: (Note: swallows errors from the node RPC)
# P1: <$major_number>
# P1Desc: The major version to compare
# P2: <$minor_number>
# P2Desc: The minor version to compare
# Returns: Boolean as string (true or false)
# Returns: Also uses C-style function return
# Returns: code, e.g. 0 if true, 1 if false.
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

#Wrapper that calls the appropriate internal __create_open_block_.* methods based on parameters passed in
# Note: help for parameter group 2 is disabled as it has not been tested.

# Desc: Create and broadcast an open block
# Desc: (state) on the nano network
# g1P1: <$private_key>
# g1P1Desc: The private key of the broadcasting account
# g1P2: <$source_block_hash>
# g1P2Desc: The source block hash to pocket
# g1P3: <$destaccount>
# g1P3Desc: The destination account to receive 
# g1P3Desc: the funds into (and open the account)
# g1P4: <$representative_account>
# g1P4Desc: The representative to set for the 
# g1P4Desc: $destaccount
# g1P5o: <$work_signature> (node V19+ only)
# g1P5Desc: The pre-computed work value to use for signing
# g1P5Desc: this block. This will avoid calculating new work
# g1P5Desc: and will use the value provided in this parameter.
# g1P5Desc: See 'generate_work' function for getting this value
# g2P1: <$wallet_uuid>
# g2P1Desc: The wallet id for <$destaccount> that will receive the funds
# g2P1Desc: and we will create an open block for.
# g2P2: <$source_block_hash>
# g2P2Desc: The source block hash to pocket
# g2P3: <$destaccount>
# g2P3Desc: The destination account to receive 
# g2P3Desc: the funds into (and open the account)
# g2P4: <$representative_account>
# g2P4Desc: The representative to set for the 
# g2P4Desc: $destaccount
# g2P5o: <$work_signature> (node V19+ only)
# g2P5Desc: The pre-computed work value to use for signing
# g2P5Desc: this block. This will avoid calculating new work
# g2P5Desc: and will use the value provided in this parameter.
# g2P5Desc: See 'generate_work' function for getting this value
# RPC: account_info:account
# RPC: block:hash
# RPC: block_create:type:key:representative:source:destination:previous:balance
# RPC: or block_create:type:wallet:account:representative:source:destination:previous:balance
# Returns: Text (block hash) of the broadcast open block
# Returns: if successful.
open_block() {
  local NEWBLOCK; local RET=255
  local IS_FIRST_PARAM_WALLET_UUID=$(wallet_contains "${1}" "${2}" 2>/dev/null)
  debug "Group 2 parameters ? ${IS_FIRST_PARAM_WALLET_UUID}"

  if [[ ( $# -eq 4 || $# -eq 5 ) && ${IS_FIRST_PARAM_WALLET_UUID} -eq 0 ]]; then
    NEWBLOCK=$(__create_open_block_privkey $@)
    RET=$?
  elif [[ $# -eq 4 || $# -eq 5 ]]; then
    NEWBLOCK=$(__create_open_block_wallet $@)
    RET=$?
  else
    error "Invalid parameters
    expected: PRIVKEY SOURCE_BLOCK_HASH DESTACCOUNT REPRESENTATIVE [WORK_DIFFICULTY]
          or: WALLETUUID SOURCE_BLOCK_HASH DESTACCOUNT REPRESENTATIVE [WORK_DIFFICULTY]"
    return 9
  fi

  if [[ ( 0 -eq $RET && -n "${NEWBLOCK}" ) ]]; then
    broadcast_block "${NEWBLOCK}" "open"
  fi
}

#Wrapper that calls the appropriate internal __create_send_block_.* methods based on parameters passed in

# Desc: Create and broadcast a send block
# Desc: (state) on the nano network
# Desc: Requires environment variable 'NANO_UNSAFE_COMMANDS' to be set to 1
# Desc: Note: to determine whether the first argument is either <$private_key>
# Desc: Note: or <$wallet_uuid> the first two parameters are ALWAYS sent to 
# Desc: Note: the wallet_contains node RPC.
# g1P1: <$private_key>
# g1P1Desc: The private key of the broadcasting account
# g1P2: <$account>
# g1P2Desc: The broadcasting account (sender)
# g1P3: <$destaccount>
# g1P3Desc: The destination account to send 
# g1P3Desc: the funds to 
# g1P4: <$balance_MNano>
# g1P4Desc: The NANO (MNano) amount to send
# g1P4Desc: to the $destaccount
# g1P5o: <$work_signature> (node V19+ only)
# g1P5Desc: The pre-computed work value to use for signing
# g1P5Desc: this block. This will avoid calculating new work
# g1P5Desc: and will use the value provided in this parameter.
# g1P5Desc: See 'generate_work' function for getting this value
# g2P1: <$wallet_uuid>
# g2P1Desc: The wallet UUID of the sending account
# g2P2: <$account>
# g2P2Desc: The broadcasting account (sender)
# g2P3: <$destaccount>
# g2P3Desc: The destination account to send 
# g2P3Desc: the funds to 
# g2P4: <$balance_MNano>
# g2P4Desc: The NANO (MNano) amount to send
# g2P4Desc: to the $destaccount
# g2P5o: <$work_signature> (node V19+ only)
# g2P5Desc: The pre-computed work value to use for signing
# g2P5Desc: this block. This will avoid calculating new work
# g2P5Desc: and will use the value provided in this parameter.
# g2P5Desc: See 'generate_work' function for getting this value
# RPC: wallet_contains:walletuuid:account
# RPC: account_info:account
# RPC: block:hash
# RPC: account_representative:account
# RPC: block_create:type:key:account:destination:previous:balance:representative
# RPC: or block_create:type:wallet_uuid:account:destination:previous:balance:representative
# Returns: Text (block hash) of the broadcast send block
# Returns: if successful.
send_block() {
  [[ 1 -ne $(allow_unsafe_commands) ]] && return 1
  local NEWBLOCK; local RET=255
  local IS_FIRST_PARAM_WALLET_UUID=$(wallet_contains "${1}" "${2}" 2>/dev/null)
  debug "Group 2 parameters ? ${IS_FIRST_PARAM_WALLET_UUID}"

  if [[ ( $# -eq 4 || $# -eq 5 ) && ${IS_FIRST_PARAM_WALLET_UUID} -eq 0 ]]; then
    local RAW_AMOUNT=$(mnano_to_raw $4)
    NEWBLOCK=$(__create_send_block_privkey $1 $2 $3 ${RAW_AMOUNT} ${5:-})
    RET=$?
  elif [[ ( $# -eq 4 || $# -eq 5 ) && ${IS_FIRST_PARAM_WALLET_UUID} -eq 1 ]]; then
    local RAW_AMOUNT=$(mnano_to_raw $4)
    NEWBLOCK=$(__create_send_block_wallet $1 $2 $3 ${RAW_AMOUNT} ${5:-})
    RET=$?
  elif [[ $# -lt 4 || $# -gt 5 ]]; then
    error "Invalid parameters
    expected: PRIVKEY ACCOUNT DESTACCOUNT BALANCE_IN_MNANO [WORK_DIFFICULTY]
          or: WALLETUUID ACCOUNT DESTACCOUNT BALANCE_IN_MNANO [WORK_DIFFICULTY]"
    return 9
  fi

  if [[ ( 0 -eq $RET && -n "${NEWBLOCK}" ) ]]; then
    broadcast_block "${NEWBLOCK}" "send"
  fi
}

#Wrapper that calls the appropriate internal __create_receive_block.* methods based on parameters passed in
# Desc: Create and broadcast a receive block
# Desc: (state) on the nano network
# Desc: Note: to determine whether the first argument is either <$private_key>
# Desc: Note: or <$wallet_uuid> the first two parameters are ALWAYS sent to 
# Desc: Note: the wallet_contains node RPC.
# g1P1: <$private_key>
# g1P1Desc: The private key of the broadcasting account
# g1P2: <$source_block_hash>
# g1P2Desc: The block hash to pocket
# g1P3: <$destaccount>
# g1P3Desc: The account to receive the funds
# g1P4o: <$work_signature> (node V19+ only)
# g1P4Desc: The pre-computed work value to use for signing
# g1P4Desc: this block. This will avoid calculating new work
# g1P4Desc: and will use the value provided in this parameter.
# g1P4Desc: See 'generate_work' function for getting this value
# g2P1: <$wallet_uuid>
# g2P1Desc: The wallet UUID of the sending account
# g2P2: <$source_block_hash>
# g2P2Desc: The block hash to pocket
# g2P3: <$destaccount>
# g2P3Desc: The account to receive the funds
# g2P4o: <$work_signature> (node V19+ only)
# g2P4Desc: The pre-computed work value to use for signing
# g2P4Desc: this block. This will avoid calculating new work
# g2P4Desc: and will use the value provided in this parameter.
# g2P4Desc: See 'generate_work' function for getting this value
# Returns: Text (block hash) of the broadcast receive block
# Returns: if successful.
receive_block() {
  local NEWBLOCK; local RET=255
  local IS_FIRST_PARAM_WALLET_UUID=$(wallet_contains "${1}" "${3}" 2>/dev/null)
  debug "Group 2 parameters ? ${IS_FIRST_PARAM_WALLET_UUID}"
  if [[ ( $# -eq 3 || $# -eq 4 ) && ${IS_FIRST_PARAM_WALLET_UUID} -eq 0 ]]; then
    NEWBLOCK=$(__create_receive_block_privkey "${1}" "${2}" "${3}" "" "${4:-}")
    RET=$?
  elif [[ $# -eq 3 || $# -eq 4 ]]; then
    NEWBLOCK=$(__create_receive_block_wallet "${1}" "${2}" "${3}" "" "${4:-}")
	RET=$?
  else
    error "Invalid parameters
    expected: PRIVKEY SOURCE_BLOCK_HASH DESTACCOUNT [WORK_DIFFICULTY]
          or: WALLETUUID SOURCE_BLOCK_HASH DESTACCOUNT [WORK_DIFFICULTY]"
    return 9
  fi

  if [[ ( 0 -eq $RET && -n "${NEWBLOCK}" ) ]]; then
    broadcast_block "${NEWBLOCK}" "receive"
  fi
}

#Wrapper that calls the appropriate internal __create_changerep_block.* methods based on parameters passed in

# Desc: Create and broadcast a change
# Desc: representative block
# Desc: (state) on the nano network
# g1P1: <$private_key>
# g1P1Desc: The private key of the broadcasting account
# g1P2: <$account>
# g1P2Desc: The nano account to change the representative of.
# g1P3: <$representative_account>
# g1P3Desc: The representative account to set for
# g1P3Desc: $account
# g1P4o: <$work_signature> (node V19+ only)
# g1P4Desc: The pre-computed work value to use for signing
# g1P4Desc: this block. This will avoid calculating new work
# g1P4Desc: and will use the value provided in this parameter.
# g1P4Desc: See 'generate_work' function for getting this value
# g2P1: <$wallet_uuid>
# g2P1Desc: The wallet UUID of the sending account
# g2P2: <$account>
# g2P2Desc: The nano account within $wallet_uuid to change the representative of.
# g2P3: <$representative_account>
# g2P3Desc: The representative account to set for
# g2P3Desc: $account
# g2P4o: <$work_signature> (node V19+ only)
# g2P4Desc: The pre-computed work value to use for signing
# g2P4Desc: this block. This will avoid calculating new work
# g2P4Desc: and will use the value provided in this parameter.
# g2P4Desc: See 'generate_work' function for getting this value
# Returns: Text (block hash) of the broadcast change block
changerep_block() {
  local NEWBLOCK; local RET=255
  local IS_FIRST_PARAM_WALLET_UUID=$(wallet_contains "${1}" "${2}" 2>/dev/null)
  debug "Group 2 parameters ? ${IS_FIRST_PARAM_WALLET_UUID}"
  if [[ ( $# -eq 3 || $# -eq 4 ) && ${IS_FIRST_PARAM_WALLET_UUID} -eq 0 ]]; then
    NEWBLOCK=$(__create_changerep_block_privkey $@)
    RET=$?
  elif [[ $# -eq 3 || $# -eq 4 ]]; then
    NEWBLOCK=$(__create_changerep_block_wallet $@)
    RET=$?
  else
    error "Invalid parameters
    expected: PRIVKEY ACCOUNT REPRESENTATIVE [WORK_DIFFICULTY]
          or: WALLETUUID ACCOUNT REPRESENTATIVE [WORK_DIFFICULTY]"
    return 9
  fi
  if [[ ( 0 -eq $RET && -n "${NEWBLOCK}" ) ]]; then
    broadcast_block "${NEWBLOCK}" "change"
  fi
}

#######################################
# Stress-test functions
#######################################

# Desc: This function will loop until interrupted
# Desc: or until a failure occurs.
# Desc: It loops running the 'generate_spam_and_broadcast' function.
# P1: <$private_key>
# P1Desc: The private key of the broadcasting account
# P2: <$account_address>
# P2Desc: The sending account address
# P3: <$dest_account_address>
# P3Desc: The destination account address
# P3Desc: to receive the spam sends.
# P4o: <$blocks_to_create_in_batch>
# P4Desc: The number of blocks to generate per batch
# P4Desc: e.g. if set to 5, it will pre-generate 5 blocks
# P4Desc: then will send all 5, and will then repeat.
# P4Desc: If not specified, will attempt to use
# P4Desc: the value set in the environment variable
# P4Desc: named BLOCKS_TO_CREATE, otherwise defaults to 1
# P5o: <$work_difficulty>
# P5Desc: The work difficulty to use (dynPoW) for the spam
# P5Desc: Can be either a 16 character hexadecimal string
# P5Desc: Or use inbuilt values from nano-shell:
# P5Desc:   weak, normal, strong, very_strong
generate_spam_and_broadcast_until_stopped() {
  local PREGENERATE_BLOCKS_NUMBER=${4:-1}
  local WORK_DIFFICULTY=${5:-$DIFFICULTY_NORMAL}
  [[ -n "${BLOCKS_TO_CREATE}" && $# -lt 4 ]] && PREGENERATE_BLOCKS_NUMBER=${BLOCKS_TO_CREATE}

  while true; do
    generate_spam_and_broadcast $1 $2 $3 ${PREGENERATE_BLOCKS_NUMBER} ${WORK_DIFFICULTY}
    [[ $? -ne 0 ]] && error "Call to generate_spam_and_broadcast failed. Aborting infinite loop and exiting..." && return 1
  done
}

# Desc: This function generates a given number
# Desc: of blocks, and then immediately sends them.
# P1: <$private_key>
# P1Desc: The private key of the broadcasting account
# P2: <$account_address>
# P2Desc: The sending account address
# P3: <$dest_account_address>
# P3Desc: The destination account address
# P3Desc: to receive the spam sends.
# P4: <$blocks_to_create_in_batch>
# P4Desc: The number of blocks to generate per batch
# P4Desc: e.g. if set to 5, it will pre-generate 5 blocks
# P4Desc: then send all 5.
# P4Desc: Note: can be specified in environment variable
# P4Desc: named BLOCKS_TO_CREATE for backwards compatibility.
# P5o: <$work_difficulty>
# P5Desc: The work difficulty to use (dynPoW) for the spam
# P5Desc: Can be either a 16 character hexadecimal string
# P5Desc: Or use inbuilt values from nano-shell:
# P5Desc:   weak, normal, strong, very_strong
generate_spam_and_broadcast() {
  [[ $# -lt 3 || $# -gt 5 ]] && error "Invalid parameters
                    expected: PRIVKEY SRCACCOUNT DESTACCOUNT [BLOCKS_TO_CREATE_IN_BATCH] [WORK_DIFFICULTY]" && return 9

  local BLOCKS_TO_CREATE=${BLOCKS_TO_CREATE:-}
  [[ $# -ge 4 ]] && BLOCKS_TO_CREATE=${4}
  local WORK_DIFFICULTY=${5:-$DIFFICULTY_NORMAL}

  [[ -z "${BLOCKS_TO_CREATE}" || "false" == $(is_integer "${BLOCKS_TO_CREATE}") ]] && error "Please set the environment variable BLOCKS_TO_CREATE (integer) before calling this method." && return 3
  [[ -z "${BLOCK_STORE}" ]] && BLOCK_STORE=$($MKTEMP --tmpdir block_store_temp.XXXXX)

  generate_spam_sends_to_file $1 $2 $3 ${WORK_DIFFICULTY} ${BLOCKS_TO_CREATE}
  [[ $? -ne 0 ]] && error "Error in function. Aborting and removing ${BLOCK_STORE}." && $RM -f "${BLOCK_STORE}" && return 1

  send_pre-generated_blocks
  local RET=$?
  [[ -f "${BLOCK_STORE}.$(date +%F.%H.%M.%S)" ]] && $RM -f "${BLOCK_STORE}.$(date +%F.%H.%M.%S)"
  [[ -f "${BLOCK_STORE}" ]] && $RM -f "${BLOCK_STORE}"
  return $RET
}

# Desc: This function generates a given number 
# Desc: of blocks and writes them to a file
# P1: <$private_key>
# P1Desc: The private key of the broadcasting account
# P2: <$account_address>
# P2Desc: The sending account address
# P3: <$dest_account_address>
# P3Desc: The destination account address
# P4o: <$work_difficulty>
# P4Desc: The work difficulty to use (dynPoW) for the spam
# P4Desc: Can be either a 16 character hexadecimal string
# P4Desc: Or use inbuilt values from nano-shell:
# P4Desc:   weak, normal, strong, very_strong
# P5o: <$blocks_to_create_in_batch>
# P5Desc: The number of blocks to generate per batch
# P5Desc: e.g. if set to 5, it will generate 5 blocks
# P5Desc: This parameter can also be specified in environment variable
# P5Desc: named BLOCKS_TO_CREATE for backwards compatibility.
# P5Desc: If not specified, will default to 1
# P6o: <$block_store_file>
# P6Desc: The file that will contain the blocks generated
# P6Desc: If this file already exists and the associated
# P6Desc: $block_store_file.hash file also exists
# P6Desc: then nano-shell will resume generating blocks
# P6Desc: from the last block+hash generated in the file.
# P6Desc: This parameter can also be specified in environment variable
# P6Desc: named BLOCK_STORE for backwards compatibility.
# P6Desc: If not specified, will default to your $TMPDIR
# P6Desc: in a file named 'block_store_temp.XXXXX'
generate_spam_sends_to_file() {
  [[ $# -lt 3 || $# -gt 6 ]] && error "Invalid parameters
                    expected: PRIVKEY SOURCE DESTACCOUNT [WORK_DIFFICULTY] [BLOCKS_TO_CREATE_IN_BATCH] [BLOCK_STORE_FILE]" && return 9

  debug "generate_spam_sends_to_file 1=$1 2=$2 3=$3 4=$4 5=$5 6=$6"
  local BLOCK_STORE="${BLOCK_STORE:-}"
  local WORK_DIFFICULTY=${4:-$DIFFICULTY_NORMAL}
  [[ $# -eq 6 ]] && BLOCK_STORE="${6:-}"
  [[ -z "${BLOCK_STORE}" ]] && BLOCK_STORE=$($MKTEMP --tmpdir block_store_temp.XXXXX)

  local BLOCKS_TO_CREATE=${BLOCKS_TO_CREATE:-}
  [[ $# -gt 4 ]] && BLOCKS_TO_CREATE=${5:-1}

  [[ ! -e "${BLOCK_STORE:-}" ]] && [[ ! -w $(dirname "${BLOCK_STORE:-}") ]] && error "\$block_store_file does not exist and could not be created. Is the location writable?" && return 3
  [[ -z "${BLOCKS_TO_CREATE}" || "false" == $(is_integer "${BLOCKS_TO_CREATE}") ]] && error "\$blocks_to_create_in_batch should be specified as an integer. Got value ${BLOCKS_TO_CREATE} " && return 3

  local CURRENT_BALANCE
  local PREVIOUS_BLOCK_HASH
  if [[ -f "${BLOCK_STORE}" ]]; then
    local STORE_SIZE=$($WC -c <"${BLOCK_STORE}")
    if [[ 0 -lt ${STORE_SIZE:-0} ]]; then
      if [[ -f "${BLOCK_STORE}.hash" ]]; then
        echo "File ${BLOCK_STORE} exists, and associated hash file exists. Getting last block hash, will continue generating from that point."
        PREVIOUS_BLOCK_HASH=$($TAIL -n1 "${BLOCK_STORE}.hash")
        CURRENT_BALANCE=$($TAIL -n1 "${BLOCK_STORE}" | $GREP -oP '\\"balance\\"\:\s{0,}\\"[0-9]+' | $CUT -d'"' -f4)
        [[ ${#PREVIOUS_BLOCK_HASH} -ne 64 ]] && error "Previous block hash from file ${BLOCK_STORE}.hash was not a valid hash" && return 4
        [[ -z ${CURRENT_BALANCE} ]] && error "Balance in last generated block in ${BLOCK_STORE} was not found." && return 5
      else
        error "File ${BLOCK_STORE} exists, but not associated hash file exists. You should remove ${BLOCK_STORE} before using this function." && return 6
      fi
    fi
  fi

  local MESSAGE="Generating blocks: "
  echo "${MESSAGE}"

  for ((idx=0; idx < ${BLOCKS_TO_CREATE}; idx++)); do

    local PREVIOUS="${PREVIOUS_BLOCK_HASH}"
    local IGNORE_BLOCK_COUNT_CHECK=1
    __generate_spam_send_to_file $1 $2 $3 ${WORK_DIFFICULTY}
    [[ $? -ne 0 ]] && error "Bombing out due to error in generate_spam_send_to_file" && return 1

    $PRINTF "\rCreated %${#BLOCKS_TO_CREATE}d blocks" "$((idx+1))"

    [[ "${PREVIOUS_BLOCK_HASH}" == "${BLOCK_HASH}" ]] && error "VALIDATION FAILED: Previously generated hash matches hash just generated." && return 2
    PREVIOUS_BLOCK_HASH="${BLOCK_HASH}"
  done
  echo '...done!'
}

# Desc: (Internal function)
# Desc: This function generates a given number 
# Desc: of blocks and writes them to a file
# Desc: This function expects particular environment variables
# P1: <$private_key>
# P1Desc: The private key of the broadcasting account
# P2: <$account_address>
# P2Desc: The sending account address
# P3: <$dest_account_address>
# P3Desc: The destination account address
# P4o: <$work_difficulty>
# P4Desc: The work difficulty (dynPoW)
__generate_spam_send_to_file() {
  [[ -z "${BLOCK_STORE:-}" ]] && error "Please set the environment variable BLOCK_STORE before calling this method." && return 3

  if [[ $# -gt 2 && $# -lt 5 ]]; then
    
    local WORK_RESULT=
    if [[ "${WORK_DIFFICULTY}" != "${DIFFICULTY_NORMAL}" && "${WORK_DIFFICULTY}" != "normal" ]]; then
      local PREVIOUS=${PREVIOUS:-$(get_frontier_hash_from_account ${2})}
      [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account sending funds had no previous block, or previous block hash is invalid." && return 5
      WORK_RESULT=$(generate_work ${PREVIOUS} 1 ${WORK_DIFFICULTY}) 
      debug "Work result=${WORK_RESULT}"
    fi

    # Send one RAW
    __create_send_block_privkey $1 $2 $3 1 $WORK_RESULT >/dev/null
    if [[ ${#BLOCK_HASH} -eq 64 ]]; then
      debug "Block generated, got hash ${BLOCK_HASH}. Storing block in ${BLOCK_STORE}."
      echo "${BLOCK}" >> "${BLOCK_STORE}"
      debug "Storing hash in ${BLOCK_STORE}.hash."
      echo "${BLOCK_HASH}" >> "${BLOCK_STORE}.hash"
      CURRENT_BALANCE=$(echo "${BLOCK}" | $GREP -oP '\\"balance\\"\:\s{0,}\\"[0-9]+' | $CUT -d'"' -f4)
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

# Desc: This function broadcasts all blocks contained within 
# Desc: filename defined by environment variable $BLOCK_STORE
# Desc: This function expects particular environment variables
# Desc: If a failure happens on broadcast, this function will
# Desc: attempt to truncate the broadcast blocks from $BLOCK_STORE
# Desc: and keep any unbroadcast blocks in $BLOCK_STORE
# Desc: Successfully broadcast blocks can be found afterwards
# Desc: under ${BLOCK_STORE}.(current_date).sent
# Desc: Note: Modifies file defined in $BLOCK_STORE
# Returns: Counter of blocks broadcast
send_pre-generated_blocks() {
  [[ -z "${BLOCK_STORE:-}" ]] && error "Please set the environment variable BLOCK_STORE before calling this method." && return 1
  [[ ! -f "${BLOCK_STORE}" ]] && error "File ${BLOCK_STORE} did not exist. Did you run 'generate_spam_sends_to_file'?" && return 1

  local RET; local HASH; let LINE_NO=0
  echo "Beginning broadcast of all pre-generated blocks in ${BLOCK_STORE}: "

  while read -r line; do
    #Not specifying 'subtype' of block here to avoid any slowdowns/checks on the node side.
    HASH=$(broadcast_block "${line}")
    RET=$?
    [[ $RET -ne 0 || -z "${HASH}" ]] && error "Failed to broadcast block at line number ${LINE_NO}. Aborting run." && RET=2 && break

    $PRINTF "\rSent %10d blocks" "$((LINE_NO+1))"
    LINE_NO=$((LINE_NO+1))
  done < "${BLOCK_STORE}"
  [[ $RET -eq 0 ]] && echo '...done!' || echo '...failed!'

  if [[ $RET -eq 0 ]]; then
    echo "Broadcast ${LINE_NO} blocks in ${BLOCK_STORE}. Renaming file to ${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
    debug "Broadcast ${LINE_NO} blocks in ${BLOCK_STORE}. Renaming file to ${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
    mv "${BLOCK_STORE}" "${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
    [[ -f "${BLOCK_STORE}.hash" ]] && mv "${BLOCK_STORE}.hash" "${BLOCK_STORE}.hash.$(date +%F.%H.%M.%S).sent"
  elif [[ $LINE_NO -gt 0 ]]; then
    error "PARTIAL BROADCAST of ${LINE_NO} blocks in ${BLOCK_STORE}. Successfully broadcast blocks will be moved to ${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
    $HEAD -n${LINE_NO} "${BLOCK_STORE}" >> "${BLOCK_STORE}.$(date +%F.%H.%M.%S).sent"
    [[ -f "${BLOCK_STORE}.hash" ]] && $HEAD -n${LINE_NO} "${BLOCK_STORE}.hash" >> "${BLOCK_STORE}.hash.$(date +%F.%H.%M.%S).sent"
    $SED -e "1,${LINE_NO}d" -i "${BLOCK_STORE}"
    $SED -e "1,${LINE_NO}d" -i "${BLOCK_STORE}.hash"
  else
    error "FAILED to broadcast any blocks from ${BLOCK_STORE}. No files modified."
  fi
  return $RET
}

#######################################
# Block generation functions
#######################################

# Desc: (Internal function)
# Desc: Creates an open block (state)
# Desc: to pocket funds from an existing SOURCE block
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# P1: <$private_key>
# P1Desc: The private key of the broadcasting account
# P2: <$source_block_hash>
# P2Desc: The source block hash to pocket
# P3: <$dest_account_address>
# P3Desc: The destination account to receive 
# P3Desc: the funds into (and open the account)
# P4: <$representative_account>
# P4Desc: The representative to set for the 
# P4Desc: newly opened $dest_account_address
# P5o: <$work_value>
# P5Desc: Avoid doing a Proof of Work calculation and
# P5Desc:   instead use the supplied pre-generated work value
# P5Desc:   for this block.
# RPC: account_info:account
# RPC: block:hash
# RPC: block_create:type:key:representative:source:destination:previous:balance
# Returns: JSON from node RPC (open block)
__create_open_block_privkey() {
  local PRIVKEY=${1:-}
  local SOURCE_BLOCK_HASH=${2:-}
  local DESTACCOUNT=${3:-}
  local DESTACCOUNT_NOPREFIX="${DESTACCOUNT/xrb_/}"
  DESTACCOUNT_NOPREFIX="${DESTACCOUNT_NOPREFIX/nano_/}"
  local REPRESENTATIVE=${4:-}
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"
  local WORK_VALUE=${5:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""

  local PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ -z "$PREVIOUS" ]] && PREVIOUS=${ZEROES}
  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  if [[ -z "$CURRENT_BALANCE" ]]; then
    [[ "${PREVIOUS}" != "${ZEROES}" ]] && echo "VALIDATION FAILED: Balance for ${DESTACCOUNT} returned null, yet previous hash was non-zero." && return 4
    CURRENT_BALANCE=0
  fi

  local AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE_BLOCK_HASH}")

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | $BC)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE_BLOCK_HASH}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to open account $DESTACCOUNT with state block by receiving block $SOURCE_BLOCK_HASH"
  
  local RETVAL; local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "key": "${PRIVKEY}", "representative": "${REPRESENTATIVE}", "source": "${SOURCE_BLOCK_HASH}", "destination": "${DESTACCOUNT}", "previous": "${PREVIOUS}", "balance": "${NEW_BALANCE}" ${WORK} }
JSON
)
  echo "$RET" | show_errors >/dev/null
  RETVAL=$?
  
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"xrb_${DESTACCOUNT_NOPREFIX}\\\""* && "${RET}" != *"\"account\\\": \\\"nano_${DESTACCOUNT_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts new balance after pocketing open block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    debug "repnoprefix: ${REPRESENTATIVE_NOPREFIX}"
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}

# TODO: Untested - check this function works
# Desc: (Internal function)
# Desc: Creates an open block (state)
# Desc: to pocket funds from an existing SOURCE block
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# P1: <$wallet_uuid>
# P1Desc: The wallet UUID containing the nano address to open
# P2: <$source_block_hash>
# P2Desc: The source block hash to pocket
# P3: <$dest_account_address>
# P3Desc: The destination account to receive 
# P3Desc: the funds into (and open the account)
# P4: <$representative_account>
# P4Desc: The representative to set for the 
# P4Desc: newly opened $dest_account_address
# P5o: <$work_value>
# P5Desc: Avoid doing a Proof of Work calculation and
# P5Desc:   instead use the supplied pre-generated work value
# P5Desc:   for this block.
# RPC: account_info:account
# RPC: block:hash
# RPC: block_create:type:wallet:account:representative:source:destination:previous:balance
# Returns: JSON from node RPC (open block)
__create_open_block_wallet() {
  local WALLET=${1:-}
  local SOURCE_BLOCK_HASH=${2:-}
  local DESTACCOUNT=${3:-}
  local DESTACCOUNT_NOPREFIX="${DESTACCOUNT/xrb_/}"
  DESTACCOUNT_NOPREFIX="${DESTACCOUNT_NOPREFIX/nano_/}"
  local REPRESENTATIVE=${4:-}
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"
  local WORK_VALUE=${5:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""

  local PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ -z "$PREVIOUS" ]] && PREVIOUS=0
  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  if [[ -z "$CURRENT_BALANCE" ]]; then
    [[ "${PREVIOUS}" != "${ZEROES}" ]] && echo "VALIDATION FAILED: Balance for ${DESTACCOUNT} returned null, yet previous hash was non-zero." && return 4
    CURRENT_BALANCE=0
  fi

  local AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE_BLOCK_HASH}")

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | $BC)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "wallet": "'${WALLET}'", "account": "'${DESTACCOUNT}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE_BLOCK_HASH}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to open account $ACCOUNT with state block by receiving block $SOURCE_BLOCK_HASH"
  
  local RETVAL; local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "wallet": "${WALLET}", "account": "${DESTACCOUNT}", "representative": "${REPRESENTATIVE}", "source": "${SOURCE_BLOCK_HASH}", "destination": "${DESTACCOUNT}", "previous": "${PREVIOUS}", "balance": "${NEW_BALANCE}" ${WORK} }
JSON
)
  echo "$RET" | show_errors >/dev/null
  RETVAL=$?
  
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"xrb_${DESTACCOUNT_NOPREFIX}\\\""* && "${RET}" != *"\"account\\\": \\\"nano_${DESTACCOUNT_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts new balance after pocketing open block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}

# Desc: (Internal function)
# Desc: Creates a send block (state)
# Desc: to transfer <$amount_raw> from 
# Desc: <$source_account_address> to a <$dest_account_address>
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# P1: <$private_key>
# P1Desc: The private key of the sender
# P2: <$source_account_address>
# P2Desc: The account that is sending the funds
# P3: <$dest_account_address>
# P3Desc: The destination account to receive the funds
# P4: <$amount_raw>
# P4Desc: The amount of nano (RAW) to send
# P5o: <$work_value>
# P5Desc: Avoid doing a Proof of Work calculation and
# P5Desc:   instead use the supplied pre-generated work value
# P5Desc:   for this block.
# RPC: account_info:account
# RPC: block:hash
# RPC: account_representative:account
# RPC: block_create:type:key:account:destination:previous:balance:representative
# Returns: JSON from node RPC (send block)
__create_send_block_privkey() {
  local PRIVKEY=${1:-}
  local SRCACCOUNT=${2:-}
  local DESTACCOUNT=${3:-}
  local DESTACCOUNT_NOPREFIX="${DESTACCOUNT/xrb_/}"
  DESTACCOUNT_NOPREFIX="${DESTACCOUNT_NOPREFIX/nano_/}"
  local AMOUNT_RAW=${4:-}
  local WORK_VALUE=${5:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""

  local PREVIOUS=${PREVIOUS:-$(get_frontier_hash_from_account ${SRCACCOUNT})}
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account sending funds had no previous block, or previous block hash is invalid." && return 5

  local CURRENT_BALANCE=${CURRENT_BALANCE:-$(get_balance_from_account ${SRCACCOUNT})}
  if [[ $(echo "${AMOUNT_RAW} != 0" | $BC) -eq 1 && ( -z "$CURRENT_BALANCE" || $(echo "${CURRENT_BALANCE} == 0" | $BC) -eq 1 ) ]]; then
    error "VALIDATION FAILED: Balance for ${SRCACCOUNT} returned null or zero, no funds are available to send." && return 4
  fi  

  if [[ $(echo "${AMOUNT_RAW} > ${CURRENT_BALANCE}" | $BC) -eq 1 ]]; then
    error "VALIDATION FAILED: You are attempting to send an amount greater than the balance of $SRCACCOUNT." && return 7
  fi  

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} - ${AMOUNT_RAW}" | $BC)
  if [[ $(echo "${NEW_BALANCE} > ${CURRENT_BALANCE}" | $BC) -eq 1 ]]; then
    error "VALIDATION FAILED: Post send balance is greater than existing balance. Are you trying to send a negative amount?." && return 8
  fi  

  local REPRESENTATIVE=$(get_account_representative "${SRCACCOUNT}")
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"
  if [[ ! ( ${REPRESENTATIVE} == xrb* && ${#REPRESENTATIVE} -eq 64 || ${REPRESENTATIVE} == nano* && ${#REPRESENTATIVE} -eq 65 ) ]]; then
    error "VALIDATION FAILED: Representative account for ${SRCACCOUNT} is unrecognised format (does not start with xrb or nano and does not match expected length). Got ${REPRESENTATIVE}" && return 11
  fi

  debug "Amount to send: ${AMOUNT_RAW} | Existing balance (${SRCACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "account": "'${SRCACCOUNT}'", "link": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'", "representative": "'${REPRESENTATIVE}'" '${WORK}' }'

  local RETVAL; local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "key": "${PRIVKEY}", "account": "${SRCACCOUNT}", "link": "${DESTACCOUNT}", "previous": "${PREVIOUS}", "balance": "${NEW_BALANCE}", "representative": "${REPRESENTATIVE}" ${WORK} }
JSON
)
  echo "$RET" | show_errors >/dev/null
  RETVAL=$?
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug " Return code: $RETVAL"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"link_as_account\\\": \\\"xrb_${DESTACCOUNT_NOPREFIX}\\\""* && "${RET}" != *"\"link_as_account\\\": \\\"nano_${DESTACCOUNT_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain destination account in link_as_account field: ${DESTACCOUNT}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain correct new balance after sending funds: ${NEW_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain destination account representative: ${REPRESENTATIVE}"
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}

# Desc: (Internal function)
# Desc: Creates a send block (state)
# Desc: to transfer <$amount_raw> from
# Desc: <$source_account_address> to a <$dest_account_address>
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# Desc: Note: wallet must be unlocked before attempting this.
# DesC: Note: See 'password_enter_rpc' for unlocking wallet
# P1: <$wallet_uuid>
# P1Desc: The sender's wallet UUID associated with $source_account_address
# P2: <$source_account_address>
# P2Desc: The account that is sending the funds
# P3: <$dest_account_address>
# P3Desc: The destination account to receive the funds
# P4: <$amount_raw>
# P4Desc: The amount of nano (RAW) to send
# P5o: <$work_value>
# P5Desc: Avoid doing a Proof of Work calculation and
# P5Desc:   instead use the supplied pre-generated work value
# P5Desc:   for this block.
# RPC: account_info:account
# RPC: block:hash
# RPC: account_representative:account
# RPC: block_create:type:key:account:destination:previous:balance:representative
# Returns: JSON from node RPC (send block)
__create_send_block_wallet() {
  local WALLET_UUID=${1:-}
  local SRCACCOUNT=${2:-}
  local DESTACCOUNT=${3:-}
  local DESTACCOUNT_NOPREFIX="${DESTACCOUNT/xrb_/}"
  DESTACCOUNT_NOPREFIX="${DESTACCOUNT_NOPREFIX/nano_/}"
  local AMOUNT_RAW=${4:-}
  local WORK_VALUE=${5:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""

  local PREVIOUS=${PREVIOUS:-$(get_frontier_hash_from_account ${SRCACCOUNT})}
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account sending funds had no previous block, or previous block hash is invalid." && return 5

  local CURRENT_BALANCE=${CURRENT_BALANCE:-$(get_balance_from_account ${SRCACCOUNT})}
  if [[ $(echo "${AMOUNT_RAW} != 0" | $BC) -eq 1 && ( -z "$CURRENT_BALANCE" || $(echo "${CURRENT_BALANCE} == 0" | $BC) -eq 1 ) ]]; then
    error "VALIDATION FAILED: Balance for ${SRCACCOUNT} returned null or zero, no funds are available to send." && return 4
  fi

  if [[ $(echo "${AMOUNT_RAW} > ${CURRENT_BALANCE}" | $BC) -eq 1 ]]; then
    error "VALIDATION FAILED: You are attempting to send an amount greater than the balance of $SRCACCOUNT." && return 7
  fi

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} - ${AMOUNT_RAW}" | $BC)
  if [[ $(echo "${NEW_BALANCE} > ${CURRENT_BALANCE}" | $BC) -eq 1 ]]; then
    error "VALIDATION FAILED: Post send balance is greater than existing balance. Are you trying to send a negative amount?." && return 8
  fi

  local REPRESENTATIVE=$(get_account_representative "${SRCACCOUNT}")
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"
  if [[ ! ( ${REPRESENTATIVE} == xrb* && ${#REPRESENTATIVE} -eq 64 || ${REPRESENTATIVE} == nano* && ${#REPRESENTATIVE} -eq 65 ) ]]; then
    error "VALIDATION FAILED: Representative account for ${SRCACCOUNT} is unrecognised format (does not start with xrb or nano and does not match expected length). Got ${REPRESENTATIVE}" && return 11
  fi

  debug "Amount to send: ${AMOUNT_RAW} | Existing balance (${SRCACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "wallet": "'${WALLET_UUID}'", "account": "'${SRCACCOUNT}'", "link": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'", "representative": "'${REPRESENTATIVE}'" '${WORK}' }'

  local RETVAL; local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "wallet": "${WALLET_UUID}", "account": "${SRCACCOUNT}", "link": "${DESTACCOUNT}", "previous": "${PREVIOUS}", "balance": "${NEW_BALANCE}", "representative": "${REPRESENTATIVE}" ${WORK} }
JSON
)
  echo $RET | show_errors >/dev/null
  RETVAL=$?
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug " Return code: $RETVAL"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"link_as_account\\\": \\\"xrb_${DESTACCOUNT_NOPREFIX}\\\""* && "${RET}" != *"\"link_as_account\\\": \\\"nano_${DESTACCOUNT_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain destination account in link_as_account field: ${DESTACCOUNT}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain correct new balance after sending funds: ${NEW_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain destination account representative: ${REPRESENTATIVE}"
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}


# Desc: (Internal function)
# Desc: Creates a receive block (state)
# Desc: to pocket funds found in <$source_block_hash>
# Desc: to <$dest_account_address>
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# P1: <$private_key>
# P1Desc: The private key of the sender
# P2: <$source_block_hash>
# P2Desc: The existing block hash on the network that
# P2Desc: contains the funds to pocket
# P3: <$dest_account_address>
# P3Desc: The destination account to receive the funds
# P4o: <$representative>
# P4Desc: The representative for <$dest_account_address>
# P5o: <$work_value>
# P5Desc: Avoid doing a Proof of Work calculation and
# P5Desc:   instead use the supplied pre-generated work value
# P5Desc:   for this block.
# RPC: account_info:account
# RPC: account_representative:account
# RPC: block:hash
# RPC: block_create:type:key:representative:source:destination:previous:balance
# Returns: JSON from node RPC (receive block)
__create_receive_block_privkey() {
  local PRIVKEY=${1:-}
  local SOURCE=${2:-}
  local DESTACCOUNT=${3:-}
  local DESTACCOUNT_NOPREFIX="${DESTACCOUNT/xrb_/}"
  DESTACCOUNT_NOPREFIX="${DESTACCOUNT_NOPREFIX/nano_/}"
  local REPRESENTATIVE=${4:-}
  local WORK_VALUE=${5:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""
  local PREVIOUS=${PREVIOUS:-}

  [[ -z "$PREVIOUS" ]] && PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account receiving funds had no previous block, or previous block hash is invalid." && return 5

  [[ -z "${REPRESENTATIVE}" ]] && REPRESENTATIVE=$(get_account_representative "${DESTACCOUNT}")
  if [[ ! ( ${REPRESENTATIVE} == xrb* && ${#REPRESENTATIVE} -eq 64 || ${REPRESENTATIVE} == nano* && ${#REPRESENTATIVE} -eq 65 ) ]]; then
    error "VALIDATION FAILED: Representative account for ${DESTACCOUNT} is unrecognised format (does not start with xrb or nano and does not match expected length). Got ${REPRESENTATIVE}" && return 11
  fi
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"

  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  if [[ -z "$CURRENT_BALANCE" ]]; then
    [[ "${PREVIOUS}" != "${ZEROES}" ]] && echo "VALIDATION FAILED: Balance for ${DESTACCOUNT} returned null, yet previous hash was non-zero." && return 4
    CURRENT_BALANCE=0
  fi

  local AMOUNT_IN_BLOCK; local RETVAL
  AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE}")
  RETVAL=$?
  [[ $RETVAL -ne 0 ]] && echo "$AMOUNT_IN_BLOCK" && return $RETVAL

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | $BC)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to generate state receive block for $DESTACCOUNT by receiving block $SOURCE"
  
  local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "key": "${PRIVKEY}", "representative": "${REPRESENTATIVE}", "source": "${SOURCE}", "destination": "${DESTACCOUNT}", "previous": "${PREVIOUS}", "balance": "${NEW_BALANCE}" ${WORK} }
JSON
)
  echo $RET | show_errors >/dev/null
  RETVAL=$?
  
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"xrb_${DESTACCOUNT_NOPREFIX}\\\""* && "${RET}" != *"\"account\\\": \\\"nano_${DESTACCOUNT_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account new balance after pocketing receive block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}

# Desc: (Internal function)
# Desc: Creates a receive block (state)
# Desc: to pocket funds found in <$source_block_hash>
# Desc: to <$account>
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# Desc: Note: wallet must be unlocked before attempting this.
# DesC: Note: See 'password_enter_rpc' for unlocking wallet
# P1: <$wallet_uuid>
# P1Desc: The sender's wallet UUID associated with $source_account_address
# P2: <$source_block_hash>
# P2Desc: The existing block hash on the network that
# P2Desc: contains the funds to pocket
# P3: <$account>
# P3Desc: The destination account to receive the funds
# P4o: <$representative>
# P4Desc: The representative for <$account>
# P5o: <$work_value>
# P5Desc: Avoid doing a Proof of Work calculation and
# P5Desc:   instead use the supplied pre-generated work value
# P5Desc:   for this block.
# RPC: account_info:account
# RPC: account_representative:account
# RPC: block:hash
# RPC: block_create:type:key:representative:source:destination:previous:balance
# Returns: JSON from node RPC (receive block)
__create_receive_block_wallet() {
  local WALLET_UUID=${1:-}
  local SOURCE_BLOCK_HASH=${2:-}
  local DESTACCOUNT=${3:-}
  local DESTACCOUNT_NOPREFIX="${DESTACCOUNT/xrb_/}"
  DESTACCOUNT_NOPREFIX="${DESTACCOUNT_NOPREFIX/nano_/}"
  local REPRESENTATIVE=${4:-}
  local WORK_VALUE=${5:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""
  local PREVIOUS=${PREVIOUS:-}

  [[ -z "$PREVIOUS" ]] && PREVIOUS=$(get_frontier_hash_from_account ${DESTACCOUNT})
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account receiving funds had no previous block, or previous block hash is invalid." && return 5

  [[ -z "${REPRESENTATIVE}" ]] && REPRESENTATIVE=$(get_account_representative "${DESTACCOUNT}")
  if [[ ! ( ${REPRESENTATIVE} == xrb* && ${#REPRESENTATIVE} -eq 64 || ${REPRESENTATIVE} == nano* && ${#REPRESENTATIVE} -eq 65 ) ]]; then
    error "VALIDATION FAILED: Representative account for ${DESTACCOUNT} is unrecognised format (does not start with xrb or nano and does not match expected length). Got ${REPRESENTATIVE}" && return 11
  fi
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"

  local CURRENT_BALANCE=$(get_balance_from_account ${DESTACCOUNT})
  if [[ -z "$CURRENT_BALANCE" ]]; then
    [[ "${PREVIOUS}" != "${ZEROES}" ]] && echo "VALIDATION FAILED: Balance for ${DESTACCOUNT} returned null, yet previous hash was non-zero." && return 4
    CURRENT_BALANCE=0
  fi

  local AMOUNT_IN_BLOCK; local RETVAL
  AMOUNT_IN_BLOCK=$(block_info_amount "${SOURCE_BLOCK_HASH}")
  RETVAL=$?
  [[ $RETVAL -ne 0 ]] && echo "$AMOUNT_IN_BLOCK" && return $RETVAL

  local NEW_BALANCE=$(echo "${CURRENT_BALANCE} + ${AMOUNT_IN_BLOCK}" | $BC)

  debug "Amount in block: ${AMOUNT_IN_BLOCK} | Existing balance (${DESTACCOUNT}): ${CURRENT_BALANCE} | New balance will be: ${NEW_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "wallet": "'${WALLET_UUID}'", "representative": "'${REPRESENTATIVE}'", "source": "'${SOURCE_BLOCK_HASH}'", "destination": "'${DESTACCOUNT}'", "previous": "'${PREVIOUS}'", "balance": "'${NEW_BALANCE}'" }'

  debug "About to generate state receive block for $DESTACCOUNT by receiving block $SOURCE_BLOCK_HASH"
  
  local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "wallet": "${WALLET_UUID}", "account": "${DESTACCOUNT}", "representative": "${REPRESENTATIVE}", "source": "${SOURCE_BLOCK_HASH}", "destination": "${DESTACCOUNT}", "previous": "${PREVIOUS}", "balance": "${NEW_BALANCE}" ${WORK} }
JSON
)
  echo $RET | show_errors >/dev/null
  RETVAL=$?
  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"account\\\": \\\"xrb_${DESTACCOUNT_NOPREFIX}\\\""* && "${RET}" != *"\"account\\\": \\\"nano_${DESTACCOUNT_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account to pocket open block funds: ${DESTACCOUNT}" >&2
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${NEW_BALANCE}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination account new balance after pocketing receive block funds: ${NEW_BALANCE}" >&2
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    echo "VALIDATION FAILED: Response did not contain destination accounts representative: ${REPRESENTATIVE}" >&2
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}



# Desc: (Internal function)
# Desc: Creates a change representative block (state)
# Desc: for <$dest_account_address>
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# P1: <$private_key>
# P1Desc: The private key for the <$dest_account_address>
# P2: <$dest_account_address>
# P2Desc: The nano account address to change
# P2Desc: the <$representative> for.
# P3: <$representative>
# P3Desc: The representative to set
# P3Desc: for <$dest_account_address>
# P4o: <$work_value>
# P4Desc: Avoid doing a Proof of Work calculation and
# P4Desc:   instead use the supplied pre-generated work value
# P4Desc:   for this block.
# RPC: account_info:account
# RPC: account_representative:account
# RPC: block_create:type:key:account:link:previous:balance:representative
# Returns: JSON from node RPC (change representative block)
__create_changerep_block_privkey() {
  local PRIVKEY=${1:-}
  local SRCACCOUNT=${2:-}
  local REPRESENTATIVE=${3:-}
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"
  local WORK_VALUE=${4:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""

  local PREVIOUS=${PREVIOUS:-$(get_frontier_hash_from_account ${SRCACCOUNT})}
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account changing representative had no previous block, or previous block hash is invalid." && return 5

  local CURRENT_BALANCE=${CURRENT_BALANCE:-$(get_balance_from_account ${SRCACCOUNT})}
  if [[ -z "$CURRENT_BALANCE" ]]; then
    error "VALIDATION FAILED: Balance for ${SRCACCOUNT} returned null." && return 4
  fi  

  if [[ ! ( ${REPRESENTATIVE} == xrb* && ${#REPRESENTATIVE} -eq 64 || ${REPRESENTATIVE} == nano* && ${#REPRESENTATIVE} -eq 65 ) ]]; then
    error "VALIDATION FAILED: Representative account for ${SRCACCOUNT} is unrecognised format (does not start with xrb or nano and does not match expected length). Got ${REPRESENTATIVE}" && return 11
  fi

  local OLD_REPRESENTATIVE=$(get_account_representative "${SRCACCOUNT}")
  local OLD_REPRESENTATIVE_NOPREFIX="${OLD_REPRESENTATIVE/xrb_/}"
  OLD_REPRESENTATIVE_NOPREFIX="${OLD_REPRESENTATIVE_NOPREFIX/nano_/}"
  [[ "${REPRESENTATIVE_NOPREFIX}" == "${OLD_REPRESENTATIVE_NOPREFIX}" ]] && error "VALIDATION FAILED: New and old representative are identical. Ignoring creation of block." && return 12

  debug "Changing representative for ${SRCACCOUNT} to ${REPRESENTATIVE} | Existing balance: ${CURRENT_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "account": "'${SRCACCOUNT}'", "link": "'${ZEROES}'", "previous": "'${PREVIOUS}'", "balance": "'${CURRENT_BALANCE}'", "representative": "'${REPRESENTATIVE}'" }'

  local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "key": "${PRIVKEY}", "account": "${SRCACCOUNT}", "link": "${ZEROES}", "previous": "${PREVIOUS}", "balance": "${CURRENT_BALANCE}", "representative": "${REPRESENTATIVE}" ${WORK} }
JSON
)
  echo $RET | show_errors >/dev/null
  RETVAL=$?

  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"link_as_account\\\": \\\"xrb_${BURN_ADDRESS_NOPREFIX}\\\""* && "${RET}" != *"\"link_as_account\\\": \\\"nano_${BURN_ADDRESS_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain burn address in link_as_account field: ${BURN_ADDRESS}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${CURRENT_BALANCE}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain correct balance after creating block. Should have shown balance: ${CURRENT_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain new representative: ${REPRESENTATIVE}"
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}

# Desc: (Internal function)
# Desc: Creates a change representative block (state)
# Desc: for <$account>
# Desc: but does not broadcast it to the network
# Desc: Stores resulting block hash in variable $BLOCK_HASH
# Desc: Note: wallet must be unlocked before attempting this.
# DesC: Note: See 'password_enter_rpc' for unlocking wallet
# P1: <$wallet_uuid>
# P1Desc: The sender's wallet UUID associated with $source_account_address
# P2: <$account>
# P2Desc: The nano account address in <$wallet_uuid> to change
# P2Desc: the representative to <$representative>.
# P3: <$representative>
# P3Desc: The representative to set
# P3Desc: for <$account>
# P4o: <$work_value>
# P4Desc: Avoid doing a Proof of Work calculation and
# P4Desc:   instead use the supplied pre-generated work value
# P4Desc:   for this block.
# RPC: account_info:account
# RPC: account_representative:account
# RPC: block_create:type:key:account:link:previous:balance:representative
# Returns: JSON from node RPC (change representative block)
__create_changerep_block_wallet() {
  local WALLET_UUID=${1:-}
  local SRCACCOUNT=${2:-}
  local REPRESENTATIVE=${3:-}
  local REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE/xrb_/}"
  REPRESENTATIVE_NOPREFIX="${REPRESENTATIVE_NOPREFIX/nano_/}"
  local WORK_VALUE=${4:-}
  local WORK=
  [[ -n "${WORK_VALUE}" ]] && WORK=", \"work\": \"${WORK_VALUE}\""

  local PREVIOUS=${PREVIOUS:-$(get_frontier_hash_from_account ${SRCACCOUNT})}
  [[ "${#PREVIOUS}" -ne 64 ]] && error "VALIDATION FAILED: Account changing representative had no previous block, or previous block hash is invalid." && return 5

  local CURRENT_BALANCE=${CURRENT_BALANCE:-$(get_balance_from_account ${SRCACCOUNT})}
  if [[ -z "$CURRENT_BALANCE" ]]; then
    error "VALIDATION FAILED: Balance for ${SRCACCOUNT} returned null." && return 4
  fi  

  if [[ ! ( ${REPRESENTATIVE} == xrb* && ${#REPRESENTATIVE} -eq 64 || ${REPRESENTATIVE} == nano* && ${#REPRESENTATIVE} -eq 65 ) ]]; then
    error "VALIDATION FAILED: Representative account for ${SRCACCOUNT} is unrecognised format (does not start with xrb or nano and does not match expected length). Got ${REPRESENTATIVE}" && return 11
  fi

  local OLD_REPRESENTATIVE=$(get_account_representative "${SRCACCOUNT}")
  local OLD_REPRESENTATIVE_NOPREFIX="${OLD_REPRESENTATIVE/xrb_/}"
  OLD_REPRESENTATIVE_NOPREFIX="${OLD_REPRESENTATIVE_NOPREFIX/nano_/}"
  [[ "${REPRESENTATIVE_NOPREFIX}" == "${OLD_REPRESENTATIVE_NOPREFIX}" ]] && error "VALIDATION FAILED: New and old representative are identical. Ignoring creation of block." && return 12

  debug "Changing representative for ${SRCACCOUNT} to ${REPRESENTATIVE} | Existing balance: ${CURRENT_BALANCE}"
  debug 'JSON data: { "action": "block_create", "type": "state", "key": "'${PRIVKEY}'", "account": "'${SRCACCOUNT}'", "link": "'${ZEROES}'", "previous": "'${PREVIOUS}'", "balance": "'${CURRENT_BALANCE}'", "representative": "'${REPRESENTATIVE}'" }'

  local RET=
  RET=$($CURL -sS -H "Content-Type: application/json" -g -d@- "${NODEHOST}" 2>/dev/null <<JSON
  { "action": "block_create", "type": "state", "wallet": "${WALLET_UUID}", "account": "${SRCACCOUNT}", "link": "${ZEROES}", "previous": "${PREVIOUS}", "balance": "${CURRENT_BALANCE}", "representative": "${REPRESENTATIVE}" ${WORK} }
JSON
)
  echo $RET | show_errors >/dev/null
  RETVAL=$?

  debug "UNPUBLISHED BLOCK FULL RESPONSE:"
  debug "------------------"
  debug "$RET"
  debug "------------------"
  DEBUG_FULL_RESPONSE="$RET"

  if [[ "${RET}" != *"\"link_as_account\\\": \\\"xrb_${BURN_ADDRESS_NOPREFIX}\\\""* && "${RET}" != *"\"link_as_account\\\": \\\"nano_${BURN_ADDRESS_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain burn address in link_as_account field: ${BURN_ADDRESS}"
    return 1
  fi
  if [[ "${RET}" != *"\"balance\\\": \\\"${CURRENT_BALANCE}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain correct balance after creating block. Should have shown balance: ${CURRENT_BALANCE}"
    return 2
  fi
  if [[ "${RET}" != *"\"representative\\\": \\\"xrb_${REPRESENTATIVE_NOPREFIX}\\\""* && "${RET}" != *"\"representative\\\": \\\"nano_${REPRESENTATIVE_NOPREFIX}\\\""* ]]; then
    error "VALIDATION FAILED: Response did not contain new representative: ${REPRESENTATIVE}"
    return 3
  fi

  BLOCK_HASH=$(echo "${RET}" | $GREP hash | $GREP -oP ':(.*)' | $CUT -d'"' -f2)
  debug "UNPUBLISHED BLOCK HASH:"
  debug "------------------"
  debug "${BLOCK_HASH}"
  debug "------------------"

  local TEMPV=$(echo "${RET}" | $GREP block | $GREP -oP ':(.*)')
  BLOCK=$(strip_block "${TEMPV}")
  echo "$BLOCK"
}



check_dependencies
[[ $? -ne 0 ]] && echo "${BASH_SOURCE[0]} had dependency errors - this script may not function." || echo "${BASH_SOURCE[0]} sourced."

[[ 1 -eq ${DEBUG} && -w "$(dirname ${DEBUGLOG})" ]] && echo "---- ${NANO_FUNCTIONS_LOCATION} v${NANO_FUNCTIONS_VERSION} sourced: $(date '+%F %H:%M:%S.%3N')" >> "${DEBUGLOG}"

[[ -z "${NANO_NETWORK_TYPE:-}" ]] && NANO_NETWORK_TYPE=$(determine_network)
print_warning
if [[ "${NANO_NETWORK_TYPE}" == "OTHER" ]]; then
  error "WARNING: Could not determine what nano network your node is operating on. remote_block_count not available."
else
  [[ -z "${NANO_NODE_VERSION:-}" ]] && NANO_NODE_VERSION=$(nano_version_number)
  [[ "${NANO_NODE_VERSION}" == "${NANO_NODE_VERSION_UNKNOWN}" ]] && error "WARNING: Unable to determine node version. Assuming latest version and all functions are supported. This may impact the functionality of some RPC commands."
fi

NANO_FUNCTIONS_HASH=bfadfa56e2e25e920f9ff71cd461bd6f
