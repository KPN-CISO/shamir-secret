#!/bin/bash

SHAMIR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

# extract value of Cluster: from pem-encoded share
function share_get_cluster
{
  if [[ $# -ne 1 ]] && [[ ! -f $1 ]]; then
    return
  fi

  N=$(cat $1 | grep -E "^Cluster: [0-9]+$" | cut -d " " -f2)
  expr $N + 0 > /dev/null 2>&1
  if [ "$?" -eq 0 ]; then
    echo $N
  else
    echo "-1"
  fi
}

# obtain all key files for cluster $1 and output its recovered secret in "$1.master" as one of the master keys
function share_recover_cluster
{
  CLUSTER_N=$1
  shift

  CLUSTER_SET=""
  KEYFILE_SET=""
  for file in "$@"; do
    i=$(share_get_cluster "$file")
    if [ $i -eq $CLUSTER_N ]; then
      CLUSTER_SET="$CLUSTER_SET $file"
    fi
  done

  for file in $CLUSTER_SET; do
    keyfile=$file.key
    KEYFILE_SET="$KEYFILE_SET $keyfile"
    $SHAMIR_DIR/parse_pem.sh get_body $file | base64 -d > $keyfile
    #head -n-1 $file | tail -n+7 | base64 -d > $keyfile
  done

  ./recover_shares $KEYFILE_SET | base64 -d > $CLUSTER_N.master
  echo " $CLUSTER_N.master"

  rm $KEYFILE_SET
}

function is_in_list
{
  ELEMENT=$1
  shift
  if [ "$#" -eq 0 ]; then
    echo 0; return
  fi
  for i in "$@"; do
    if [[ ! -z "$i" ]] && [[ ! -z "$ELEMENT" ]] && [[ "$i" -eq "$ELEMENT" ]]; then
      echo "1"; return
    fi
  done
  echo "0"; return
}

if [ "$#" -lt 1 ]; then
  echo "usage: $0 [secret_share 1] .. [secret_share k]"
  exit 1
fi

DONE=""
MASTER_KEYS=""
for i in "$@"; do
  # 1) get the cluster number of the current file
  n=$(share_get_cluster $i)
  # 2) have we already recovered this cluster number?
  if [ "$(is_in_list $n $DONE)" -eq "1" ]; then
    continue
  # 3) recover this cluster number's master key
  else
    MASTER_KEYS="$MASTER_KEYS "$(share_recover_cluster $n "$@")
    DONE="$DONE $n"
  fi
done

# recover the original secret by combining the master keys
./recover_shares $MASTER_KEYS | base64 -d

rm $MASTER_KEYS
