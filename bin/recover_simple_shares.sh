#!/bin/bash

HEADER="-----BEGIN SHAMIR SECRET SHARE-----"
FOOTER="-----END SHAMIR SECRET SHARE-----"

SHAMIR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

if [ "$#" -lt "1" ]; then
  echo "usage: $0 [secret_share 1] .. [secret_share k]"
  exit 1
fi

BIN_SHARES=""
for share in "$@"; do
  $SHAMIR_DIR/parse_pem.sh get_body $share | base64 -d > $share.bin
  BIN_SHARES="$BIN_SHARES $share.bin"
done

if [ ! -x "$SHAMIR_DIR/recover_shares" ]; then
  cd "$SHAMIR_DIR"
  make recover_secure
  cd -
fi


$SHAMIR_DIR/recover_shares ${BIN_SHARES} | base64 -d

rm ${BIN_SHARES}
