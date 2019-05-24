#!/bin/bash
#
# Counts confirmations from the node via confirmation_history_rpc
# Dependencies:
#   + NanoNode v19+
#   + nano-functions.bash v0.991+

INCLUDE_BLOCK_COUNT=1

SYSTEM_INFO_BANNER=""

MKTEMP=/bin/mktemp
GREP=/bin/grep
BC=/bin/bc
SORT=/bin/sort
WC=/bin/wc
RM=/bin/rm
PRINTF=/bin/printf

# Each element in CONFIRMATION_SAMPLES contains a count of unique new confirmations
[[ ! -z ${CONFIRMATION_SAMPLES_ARRAY_1} ]] && unset CONFIRMATION_SAMPLES_ARRAY_1
declare -a CONFIRMATION_SAMPLES_ARRAY_1

[[ ! -z ${CONFIRMATION_SAMPLES_ARRAY_2} ]] && unset CONFIRMATION_SAMPLES_ARRAY_2
declare -a CONFIRMATION_SAMPLES_ARRAY_2

declare HIGHEST_CPS_1MIN=0
declare HIGHEST_CPS_2MIN=0
declare HIGHEST_CPS_5MIN=0
declare HIGHEST_CPS_10MIN=0
declare HIGHEST_CPS_30MIN=0
declare HIGHEST_CPS_60MIN=0

poll_confirmation_history() {
  # Rate in seconds, defaults to 1
  declare DELAY_IN_SEC=${1:-1}
  declare ARRAY_60MIN_MARKER=$(echo "scale=0; ( ( 60 / ${DELAY_IN_SEC} ) * 60 ) + 1" | $BC)
  declare ARRAY_CLEAN_MODULUS=$(echo "scale=0; ( ( 60 / ${DELAY_IN_SEC} ) * 120 ) + 1" | $BC)
  local CONF_FILE_PREFIX=$($MKTEMP --dry-run --tmpdir confirmation_history.XXXXX)
  local OUTPUT_FILE=${OUTPUT_FILE:-$($MKTEMP --tmpdir confirmation_history.XXXXX.output)}

  declare -i INDEX=0
  while /bin/true; do
    confirmation_history_rpc | grep hash > ${CONF_FILE_PREFIX}.${INDEX}
    determine_unique_per_rate ${CONF_FILE_PREFIX} ${INDEX} ${DELAY_IN_SEC} > "${OUTPUT_FILE}"
    clear && cat "${OUTPUT_FILE}"
    sleep ${DELAY_IN_SEC}
    (( INDEX += 1 ))
    if [[ $(( $INDEX % $ARRAY_CLEAN_MODULUS )) -eq 0 ]]; then
      echo "Debug: Cleaning array..."
      CONFIRMATION_SAMPLES_ARRAY_2=("${CONFIRMATION_SAMPLES_ARRAY_1[@]:ARRAY_60MIN_MARKER}")
      CONFIRMATION_SAMPLES_ARRAY_1=("${CONFIRMATION_SAMPLES_ARRAY_2[@]}")
    fi
  done
}

determine_unique_per_rate() {
  local CONF_FILE_PREFIX=${1:-}
  declare -i CURRENT_INDEX=${2:-}
  declare POLL_RATE=${3:-}
  declare -i SAMPLES_PER_MIN=$(echo "scale=0; 60.00 / ${POLL_RATE}" | $BC)
  declare -i PREV_INDEX=${CURRENT_INDEX}-1
  [[ $CURRENT_INDEX -lt 1 ]] && echo "Gathering statistics..." && return 1

  local CURRENT_CONF_FILE=${CONF_FILE_PREFIX}.${CURRENT_INDEX}
  local PREV_CONF_FILE=${CONF_FILE_PREFIX}.${PREV_INDEX}
  declare -i COUNT_BASELINE=$(cat ${CURRENT_CONF_FILE} | wc -l)
  declare -i COUNT_UNIQUE_NEW_PLUS_BASELINE=$(cat ${CURRENT_CONF_FILE} ${PREV_CONF_FILE} | $SORT -u | $WC -l)
  declare -i COUNT_UNIQUE_PER_RATE=${COUNT_UNIQUE_NEW_PLUS_BASELINE}-${COUNT_BASELINE}
  (( CURRENT_INDEX = ${#CONFIRMATION_SAMPLES_ARRAY_1[@]} ))
  (( PREV_INDEX = ${CURRENT_INDEX} - 1 ))
  CONFIRMATION_SAMPLES_ARRAY_1+=(${COUNT_UNIQUE_PER_RATE})
  #echo "debug0: ${#CONFIRMATION_SAMPLES_ARRAY_1[@]}"
  #echo "debug1: RT=$RUNNING_TALLY,$COUNT_UNIQUE_PER_RATE"
  #(( RUNNING_TALLY += ${COUNT_UNIQUE_PER_RATE} ))
  #echo "debug2: RT=$RUNNING_TALLY"
#  CONFIRMATION_TALLY_ARRAY+=(${RUNNING_TALLY})
#  declare -i SIZE_TALLY_ARRAY=${#CONFIRMATION_TALLY_ARRAY[@]}

  declare -i RUNNING_TALLY=0
  if [[ ${CURRENT_INDEX} -gt ${SAMPLES_PER_MIN} ]]; then
    $PRINTF "Approx seconds elapsed: %8d\n" $(echo "${CURRENT_INDEX} / ( 1 / ${POLL_RATE} )" | $BC)
    for ((idx=${PREV_INDEX}; idx >= 0; idx--)); do
      (( RUNNING_TALLY += ${CONFIRMATION_SAMPLES_ARRAY_1[${idx}]} ))
      #echo "debug: RT=$RUNNING_TALLY, PI=$PREV_INDEX, idx=$idx, CSA[i]=${CONFIRMATION_SAMPLES_ARRAY_1[${idx}]}"
      if [[ $(( ${CURRENT_INDEX} - ${idx} )) -eq $SAMPLES_PER_MIN ]]; then
        local CPS=$(echo "scale=2; ${RUNNING_TALLY} / 60" | $BC)
        $PRINTF "CPM (1 min): %4d\n" "${RUNNING_TALLY}"
        $PRINTF "CPS (1 min): %4.2f\n" "${CPS}"
        [[ $(echo "$CPS > $HIGHEST_CPS_1MIN" | bc) -eq 1 ]] && HIGHEST_CPS_1MIN=$CPS
      fi
      if [[ $(( ${CURRENT_INDEX} - ${idx} )) -eq $(( ${SAMPLES_PER_MIN} * 2 )) ]]; then
        local CPS=$(echo "scale=2; ${RUNNING_TALLY} / (60*2)" | $BC)
        $PRINTF "CPM (2 min): %4.2f\n" $(echo "scale=2; ${RUNNING_TALLY} / 2" | $BC)
        $PRINTF "CPS (2 min): %4.2f\n" "${CPS}"
        [[ $(echo "$CPS > $HIGHEST_CPS_2MIN" | bc) -eq 1 ]] && HIGHEST_CPS_2MIN=$CPS
      fi
      if [[ $(( ${CURRENT_INDEX} - ${idx} )) -eq $(( ${SAMPLES_PER_MIN} * 5 )) ]]; then
        local CPS=$(echo "scale=2; ${RUNNING_TALLY} / (60*5)" | $BC)
        $PRINTF "CPM (5 min): %4.2f\n" $(echo "scale=2; ${RUNNING_TALLY} / 5" | $BC)
        $PRINTF "CPS (5 min): %4.2f\n" "${CPS}"
        [[ $(echo "$CPS > $HIGHEST_CPS_5MIN" | bc) -eq 1 ]] && HIGHEST_CPS_5MIN=$CPS
      fi
      if [[ $(( ${CURRENT_INDEX} - ${idx} )) -eq $(( ${SAMPLES_PER_MIN} * 10 )) ]]; then
        local CPS=$(echo "scale=2; ${RUNNING_TALLY} / (60*10)" | $BC)
        $PRINTF "CPM (10 min): %4.2f\n" $(echo "scale=2; ${RUNNING_TALLY} / 10" | $BC)
        $PRINTF "CPS (10 min): %4.2f\n" "${CPS}"
        [[ $(echo "$CPS > $HIGHEST_CPS_10MIN" | bc) -eq 1 ]] && HIGHEST_CPS_10MIN=$CPS
      fi
      if [[ $(( ${CURRENT_INDEX} - ${idx} )) -eq $(( ${SAMPLES_PER_MIN} * 30 )) ]]; then
        local CPS=$(echo "scale=2; ${RUNNING_TALLY} / (60*30)" | $BC)
        $PRINTF "CPM (30 min): %4.2f\n" $(echo "scale=2; ${RUNNING_TALLY} / 30" | $BC)
        $PRINTF "CPS (30 min): %4.2f\n" "${CPS}"
        [[ $(echo "$CPS > $HIGHEST_CPS_30MIN" | bc) -eq 1 ]] && HIGHEST_CPS_30MIN=$CPS
      fi
      if [[ $(( ${CURRENT_INDEX} - ${idx} )) -eq $(( ${SAMPLES_PER_MIN} * 60 )) ]]; then
        local CPS=$(echo "scale=2; ${RUNNING_TALLY} / (60*60)" | $BC)
        $PRINTF "CPM (60 min): %4.2f\n" $(echo "scale=2; ${RUNNING_TALLY} / 60" | $BC)
        $PRINTF "CPS (60 min): %4.2f\n" "${CPS}"
        [[ $(echo "$CPS > $HIGHEST_CPS_60MIN" | bc) -eq 1 ]] && HIGHEST_CPS_60MIN=$CPS
      fi
    done
    $PRINTF "-------------------------------------------\n"
    $PRINTF "Highest CPS Seen (1 min): %4.2f\n" "${HIGHEST_CPS_1MIN}"
    [[ "0" != "${HIGHEST_CPS_2MIN}" ]] && $PRINTF "Highest CPS Seen (2 min): %4.2f\n" "${HIGHEST_CPS_2MIN}"
    [[ "0" != "${HIGHEST_CPS_5MIN}" ]] && $PRINTF "Highest CPS Seen (5 min): %4.2f\n" "${HIGHEST_CPS_5MIN}"
    [[ "0" != "${HIGHEST_CPS_10MIN}" ]] && $PRINTF "Highest CPS Seen (10 min): %4.2f\n" "${HIGHEST_CPS_10MIN}"
    [[ "0" != "${HIGHEST_CPS_30MIN}" ]] && $PRINTF "Highest CPS Seen (30 min): %4.2f\n" "${HIGHEST_CPS_30MIN}"
    [[ "0" != "${HIGHEST_CPS_60MIN}" ]] && $PRINTF "Highest CPS Seen (60 min): %4.2f\n" "${HIGHEST_CPS_60MIN}"
  else
    $PRINTF "\rGathering statistics... approx seconds elapsed: %8d" $(echo "${CURRENT_INDEX} / ( 1 / ${POLL_RATE} )" | $BC)
  fi
  $RM -f ${PREV_CONF_FILE}

  [[ ${INCLUDE_BLOCK_COUNT} -eq 1 ]] && \
    $PRINTF "\n--------------------------------------------------------\n" && \
    block_count_rpc

  [[ -n ${SYSTEM_INFO_BANNER} ]] && \
    $PRINTF "--------------------------------------------------------\n" && \
    echo "${SYSTEM_INFO_BANNER}" && \
    echo "$(uptime)"

}

