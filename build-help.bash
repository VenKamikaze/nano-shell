#!/bin/bash
#
DOCO_FILE=${1:-API-Documentation.md}
source ./nano-functions.bash
HELP_LINES=$(nano_shell_help | wc -l)
let TAIL_HELP=$HELP_LINES-3
let HEAD_HELP=$HELP_LINES-4
ALL_HELP=$(nano_shell_help | tail -n${TAIL_HELP} | head -n${HEAD_HELP})
LINESEP=$(echo "")

api_doco_header() {
  echo "The available nano-shell functions are listed below."
  echo $LINESEP
}

api_list() {
  echo $LINESEP
  echo "## Functions"
  local IFS='
'
  set -f
  for func in ${ALL_HELP}; do
    echo "* [${func}](#${func})"
  done
  set +f
  unset IFS
  echo $LINESEP
}

api_detail() {
  local IFS='
'
  set -f
  for func in ${ALL_HELP}; do
    echo $LINESEP
    echo "## ${func}  "
    echo $LINESEP
    echo '```'
    nano_shell_help "${func}"
    echo '```'
    echo $LINESEP
  done
  set +f
  unset IFS
  echo $LINESEP
}

api_doco_header > ${DOCO_FILE}
api_list >> ${DOCO_FILE}
api_detail >> ${DOCO_FILE}
