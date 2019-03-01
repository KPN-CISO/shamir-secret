#!/bin/bash

SHAMIR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

echo "SSSS simple test" > "$SHAMIR_DIR/test.txt"

if [ ! -x $SHAMIR_DIR/create_shares -o ! -x $SHAMIR_DIR/recover_shares ]; then
  cd $SHAMIR_DIR
  if [[ $# -eq 1 ]] && [[ $1 -eq "-s" ]]; then
    make
  else
    echo "[!] using quick prng for testing purposes"
    make insecure
  fi
  cd -
fi

echo "SSSS simple test" > "$SHAMIR_DIR/test.txt"

$SHAMIR_DIR/split_simple_shares.sh 6 4 "$SHAMIR_DIR/test.txt"

C0=$(cat "$SHAMIR_DIR/test.txt")
C1=$("$SHAMIR_DIR/recover_simple_shares.sh" "$SHAMIR_DIR/key01.share" "$SHAMIR_DIR/key02.share" "$SHAMIR_DIR/key03.share" "$SHAMIR_DIR/key04.share")
C2=$("$SHAMIR_DIR/recover_simple_shares.sh" "$SHAMIR_DIR/key02.share" "$SHAMIR_DIR/key03.share" "$SHAMIR_DIR/key04.share" "$SHAMIR_DIR/key05.share")
C3=$("$SHAMIR_DIR/recover_simple_shares.sh" "$SHAMIR_DIR/key03.share" "$SHAMIR_DIR/key04.share" "$SHAMIR_DIR/key05.share" "$SHAMIR_DIR/key06.share")
C4=$("$SHAMIR_DIR/recover_simple_shares.sh" "$SHAMIR_DIR/key01.share" "$SHAMIR_DIR/key02.share" "$SHAMIR_DIR/key04.share" "$SHAMIR_DIR/key03.share")
C5=$("$SHAMIR_DIR/recover_simple_shares.sh" "$SHAMIR_DIR/key01.share" "$SHAMIR_DIR/key02.share" "$SHAMIR_DIR/key05.share" "$SHAMIR_DIR/key06.share")
C6=$("$SHAMIR_DIR/recover_simple_shares.sh" "$SHAMIR_DIR/key02.share" "$SHAMIR_DIR/key03.share" "$SHAMIR_DIR/key05.share" "$SHAMIR_DIR/key01.share")

echo "Secret: $C0"
if [[ $C0 != $C1 ]] || [[ $C0 != $C2 ]] || [[ $C0 != $C3 ]] || [[ $C0 != $C4 ]] || [[ $C0 != $C5 ]] || [[ $C0 != $C6 ]]; then
  echo "test failed"
else
  echo "test passed"
fi

rm $SHAMIR_DIR/key0{1..6}.share
rm $SHAMIR_DIR/test.txt

