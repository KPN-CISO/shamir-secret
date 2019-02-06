# Shamir Secret Sharing Scheme
A set of commandline tools for creating and recovering Shamir Secret Shares.

## dependencies
* bash 2.04+ (helper scripts)
* GNU coreutils (helper scripts)
* Make (build process)
* OpenSSL library 0.9.5+ (libcrypto) (CPRNG) or libsodium 
* C99-compatible C compiler
* (optional) /dev/random and /dev/urandom to seed OpenSSL's PRNG

## split\_simple\_shares.sh
Create a number of keyXX.share files from an input file that can be distributed among custodians.

### example usage
```sh
usage: ./split_simple_shares.sh <n keyholders> <k to recover> <secret file>
$ ./split_simple_shares.sh 3 2 private.pem
[*] creating secret shares. please move your mouse or use your keyboard to generate entropy
[*] finished creating shares
$ ls *.share
key01.share  key02.share  key03.share
```

## recover\_simple\_shares.sh
Recover a shared secret using previously generated share files.

### example usage
```sh
$ ./recover_simple_shares.sh key01.share key03.share
---
```

## split\_clustered\_shares.sh
Create a number of share "clusters" that can have different secret-reconstruction thresholds.

### example usage
```sh
$ ./split_clustered_shares.sh private.pem
Share label: shared private.pem
Number of clusters: 3
[*] creating master shares for each cluster. please move your mouse or use your keyboard to generate entropy
[*] finished creating master shares
Cluster 1 label: Dep. 1
Cluster 1 (Dep. 1) number of custodians: 2
Cluster 1 (Dep. 1) custodians required to reconstruct: 1
[*] creating custodian shares for cluster 1 (Dep. 1). please move your mouse or use your keyboard to generate entropy
[*] finished creating shares for cluster 1 (Dep. 1)
Cluster 2 label: Dep. 2
Cluster 2 (Dep. 2) number of custodians: 5
Cluster 2 (Dep. 2) custodians required to reconstruct: 3
[*] creating custodian shares for cluster 2 (Dep. 2). please move your mouse or use your keyboard to generate entropy
[*] finished creating shares for cluster 2 (Dep. 2)
Cluster 3 label: Dep. 3
Cluster 3 (Dep. 3) number of custodians: 3
Cluster 3 (Dep. 3) custodians required to reconstruct: 2
[*] creating custodian shares for cluster 3 (Dep. 3). please move your mouse or use your keyboard to generate entropy
[*] finished creating shares for cluster 3 (Dep. 3)
$ ls *.share
1.Dep.1.key01.share  1.Dep.1.key02.share  2.Dep.2.key01.share  2.Dep.2.key02.share  2.Dep.2.key03.share  2.Dep.2.key04.share  2.Dep.2.key05.share  3.Dep.3.key01.share  3.Dep.3.key02.share  3.Dep.3.key03.share
```

## recover\_clustered\_shares.sh
Recover a shared secret composed of different clusters, each of which can have different secret-reconstruction thresholds.

### example usage
```sh
$ ./recover_clustered_shares.sh 1.Dep.1.key01.share 2.Dep.2.key02.share 2.Dep.2.key04.share 2.Dep.2.key05.share 3.Dep.3.key01.share 3.Dep.3.key02.share
-----BEGIN PRIVATE KEY-----
...
```

## shamir.c / shamir.h
Shamir Secret Sharing Scheme (SSSS) implementation on prime field 65521.

SSSS can be implemented on any finite field, but prime fields allow for elegant arithmetic.
The prime (p) chosen for SSSS is fairly arbitrary, but we want it to have the following properties:

* p > N, where N is the largest value in your input (secret) domain. Since we want to create secret shares from bytes, N=0xff
* p is not too big, since p is used as upper limit to the output field, it determines the size of the secret shares.

Since p > 255, we use at least 2 output bytes per input byte.
As larger values of p do not add to the cryptographic strength of SSSS, we have chosen 0xff < p <= 2^16. 65521 is the prime closest under 2^16, but any prime satisfying the previous constraint would do.

Shamir secret sharing can be implemented to work on fields of arbitrary size, but this implementation only works on prime fields and introduces a size inflation of 2x.
An implementation on GF\_256 would allow the entire 1-byte input-domain without increasing output size, but the implementation would lose some of its simplicity.

### build options
```sh
# default, non-blocking, OpenSSL libcrypto dynamically linked
$ make
$ make secure

# blocking, OpenSSL libcrypto dynamically linked
$ make blocking

# non-blocking, OpenSSL libcrypto statically linked
$ make static

# blocking, OpenSSL libcrypto statically linked
$ make static_blocking

# non-blocking, not using OpenSSL libcrypto
$ make insecure

# set different compiler
$ CC=clang make

# add CFLAGS, conflicting flags (like -O levels) are used instead of the default ones
$ CFLAGS=-Ofast make
```
