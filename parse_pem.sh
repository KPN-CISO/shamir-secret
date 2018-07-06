#!/bin/bash

HEADER="-----BEGIN SHAMIR SECRET SHARE-----"
FOOTER="-----END SHAMIR SECRET SHARE-----"

LABEL_SHARE="Share label: "
LABEL_CLUSTER="Cluster: "
LABEL_CLUSTER_NAME="Cluster name: "
LABEL_SHARES_NEEDED="Shares needed: "

get_num_containers() {
  if [[ $# -ne 1 ]] && [[ ! -f $1 ]]; then
    return
  fi

  N=0
  CONTAINER_FOUND=0
  while read line; do
    if [ "$line" = "$HEADER" ]; then
      CONTAINER_FOUND=1
    fi
    if [[ "$line" = "$FOOTER" ]] && [[ "$CONTAINER_FOUND" -eq 1 ]]; then
      CONTAINER_FOUND=0
      N=$(expr $N + 1)
    fi
  done <$1
  echo $N
  return
}

get_body() {
  if [[ $# -ne 1 ]] && [[ ! -f $1 ]]; then
    return
  fi
  grep -Ev "($LABEL_SHARE|$LABEL_CLUSTER|$LABEL_CLUSTER_NAME|$LABEL_SHARES_NEEDED|$HEADER|$FOOTER)" $1
}



if [ $# -ne 2 ]; then
  echo "usage: $0 <get_num_containers | get_body> <input file>"
  exit 1
fi

case $1 in
"get_num_containers")
  shift
  get_num_containers $1
  ;;
"get_body")
  shift
  get_body $1
  ;;
*)
  echo "usage: $0 <get_num_containers | get_body> <input file>"
  exit 1
  ;;
esac

