#!/bin/bash

HEADER="-----BEGIN SHAMIR SECRET SHARE-----"
FOOTER="-----END SHAMIR SECRET SHARE-----"

SHAMIR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
TMP_INPUT_FILE=".tmp_input"

if [ "$#" -ne "3" ]; then
  echo "usage: $0 <n keyholders> <k to recover> <secret file>"
  exit 1
fi

N=$1
K=$2
SECRET_FILE=$3

if [ ! -x "$SHAMIR_DIR/create_shares" ]; then
  cd "$SHAMIR_DIR"
  make create_secure
  cd -
fi

echo "[*] creating secret shares. please move your mouse or use your keyboard to generate entropy"

base64 -w 64 $SECRET_FILE > $SHAMIR_DIR/$TMP_INPUT_FILE
$SHAMIR_DIR/create_shares $N $K $SHAMIR_DIR/$TMP_INPUT_FILE
rm $SHAMIR_DIR/$TMP_INPUT_FILE

echo "[*] finished creating shares"

for (( i=1; i<=$N; i++ ))
{
  FNAME="key$(printf %02x $i)"
  echo $HEADER > $FNAME.share
  base64 -w 64 $FNAME >> $FNAME.share
  echo $FOOTER >> $FNAME.share
  rm $FNAME
}


