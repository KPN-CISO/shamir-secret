#!/bin/bash

HEADER="-----BEGIN SHAMIR SECRET SHARE-----"
FOOTER="-----END SHAMIR SECRET SHARE-----"

SHAMIR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
TMP_INPUT_FILE=".tmp_input"

usage() {
  echo "usage: $0 <input_file> [options]"
  echo ""
  echo "Interactive mode"
  echo "  $ $0 <input_file>"
  echo "Automated mode"
  echo "  $ $0 <input_file> <share_label> <n_clusters> <n_custodians:k_to_reconstruct:cluster_label_1> .. <n_custodians:k_to_reconstruct:cluster_label_n>"
  echo "example"
  echo "  $ $0 /path/to/private.pem \"Important private key\" 2 \"3:2:Dept 1\" \"5:3:Dept 2\""
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

# only 1 argument means we are running in interactive mode
if [ $# -eq 1 ]; then
  INTERACTIVE="1"
else
  INTERACTIVE=""
fi

# build the ssss binaries if necessary
if [ ! -x "$SHAMIR_DIR/create_shares" ]; then
  cd "$SHAMIR_DIR"
  make
  cd -
fi

# sanity check
SECRET_FILE=$1; shift
if [ ! -f $SECRET_FILE ]; then
  usage
  exit 1
fi

cd $SHAMIR_DIR

# share name and number of clusters
if [ $INTERACTIVE ]; then
  read -p "Share label: " SHARE_LABEL
  read -p "Number of clusters: " N_CLUSTERS
else
  SHARE_LABEL="$1"; shift
  N_CLUSTERS="$1"; shift
  if [ "$N_CLUSTERS" -ne "$#" ]; then
    echo "[!] wrong number of arguments for the number of clusters"
    echo ""
    usage
    exit 1
  fi
fi

if [[ $N_CLUSTERS -lt 1 ]] || [[ $N_CLUSTERS -gt 255 ]]; then
  echo "[!] Number of clusters must be at least 1 and at most 255"
  exit 1
fi

# build the master shares for each cluster
echo "[*] creating master shares for each cluster. please move your mouse or use your keyboard to generate entropy"
base64 -w 64 $SECRET_FILE > $SHAMIR_DIR/$TMP_INPUT_FILE
$SHAMIR_DIR/create_shares $N_CLUSTERS $N_CLUSTERS $SHAMIR_DIR/$TMP_INPUT_FILE
rm $SHAMIR_DIR/$TMP_INPUT_FILE
echo "[*] finished creating master shares"

for ((i=1;i<=$N_CLUSTERS;i++)); do
  mv $(printf key%02x $i) $(printf master%02x $i)
done

# build the .share files for each custodian of each cluster
for ((i=1;i<=$N_CLUSTERS;i++))
{
  # set parameters for this cluster
  MASTER_FILE=$(printf master%02x $i)
  if [ $INTERACTIVE ]; then
    read -p "Cluster $i label: " CLUSTER_NAME
    read -p "Cluster $i ($CLUSTER_NAME) number of custodians: " CLUSTER_N
    read -p "Cluster $i ($CLUSTER_NAME) custodians required to reconstruct: " CLUSTER_K
  else
    CLUSTER_N=$(echo "$1" | cut -d ":" -f1)
    CLUSTER_K=$(echo "$1" | cut -d ":" -f2)
    CLUSTER_NAME=$(echo "$1" | cut -d ":" -f3-)
    shift
  fi

  # sanity check
  if [[ $CLUSTER_N -lt 1 ]] || [[ $CLUSTER_N -gt 255 ]] || [[ $CLUSTER_K -lt 1 ]] || [[ $CLUSTER_K -gt 255 ]] || [[ $CLUSTER_N -lt $CLUSTER_K ]]; then
    echo "[!] The number of custodians must be at least 1 and at most 255, and the number required to reconstruct must be lower or equal to the total number of custodians"
    exit 1
  fi

  # create the raw shares
  echo "[*] creating custodian shares for cluster $i ($CLUSTER_NAME). please move your mouse or use your keyboard to generate entropy"
  base64 -w 64 $MASTER_FILE > $SHAMIR_DIR/$TMP_INPUT_FILE
  $SHAMIR_DIR/create_shares $CLUSTER_N $CLUSTER_K $SHAMIR_DIR/$TMP_INPUT_FILE
  rm $SHAMIR_DIR/$TMP_INPUT_FILE
  echo "[*] finished creating shares for cluster $i ($CLUSTER_NAME)"

  # wrap the raw shares in a readable PEM format
  for ((j=1;j<=$CLUSTER_N;j++))
  {
    KEY_FILE=$(printf key%02x $j)
    SHARE_FILE=$(echo $i.$CLUSTER_NAME.$KEY_FILE.share | tr -d " ")
    echo $HEADER > "$SHARE_FILE"
    echo "Share label: $SHARE_LABEL" >> "$SHARE_FILE"
    echo "Cluster: $i" >> "$SHARE_FILE"
    echo "Cluster name: $CLUSTER_NAME" >> "$SHARE_FILE"
    echo "Shares needed: $CLUSTER_K" >> "$SHARE_FILE"
    echo "" >> "$SHARE_FILE"
    base64 -w 64 $KEY_FILE >> "$SHARE_FILE"
    echo $FOOTER >> "$SHARE_FILE"
    rm $KEY_FILE
  }
  rm $MASTER_FILE
}
