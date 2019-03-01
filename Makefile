# set CC if it has not been set yet
CC ?= gcc
# prepend default options to allow conflicting flags (like -O levels) to be overwritten by passed CFLAGS variable
CFLAGS := -Wall -Wextra -pedantic -O3 -fstack-protector -Wl,-z,relro,-z,now -pie $(CFLAGS)
SRC = src/shamir.c
CREATE_SRC = src/create_shares.c
CREATE_BIN = bin/create_shares
RECOVER_SRC = src/recover_shares.c
RECOVER_BIN = bin/recover_shares

TEST_CFLAGS = -Wall -Wextra -pedantic -Og -Wfloat-equal -Wundef -Wshadow -Wpointer-arith -Wcast-align -Wstrict-prototypes -Wstrict-overflow=5 -Wwrite-strings -Waggregate-return -Wcast-qual -Wswitch-default -Wswitch-enum -Wconversion -Wunreachable-code -Wformat=2

.PHONY: all static static_blocking secure blocking insecure clean test

# default, build non-blocking using OpenSSL
all: secure

# non-blocking, OpenSSL libcrypto statically linked, still requires libdl & pthread dynamically
static: LFLAGS += -Wl,-Bstatic -lsodium -Wl,-Bdynamic -l:libdl.so -lpthread
static: create_secure recover_secure

# blocking, OpenSSL libcrypto statically linked, still requires libdl & pthread dynamically
static_blocking: LFLAGS += -Wl,-Bstatic -lcrypto -Wl,-Bdynamic -l:libdl.so -lpthread
static_blocking: create_blocking recover_blocking

# non-blocking, libcrypto dynamically linked
secure: LFLAGS += -lsodium
secure: create_secure recover_secure

# blocking, libcrypto dynamically linked
blocking: LFLAGS += -lcrypto
blocking: create_blocking recover_blocking

# non-blocking, not using libcrypto
insecure: create recover

test: create_test recover_test

create:
	$(CC) $(CREATE_SRC) $(SRC) $(CFLAGS) -o $(CREATE_BIN)

recover:
	$(CC) $(RECOVER_SRC) $(SRC) $(CFLAGS) -o $(RECOVER_BIN)

create_secure:
	$(CC) $(CREATE_SRC) $(SRC) $(CFLAGS) -DUSE_SODIUM -o $(CREATE_BIN) $(LFLAGS)

recover_secure:
	$(CC) $(RECOVER_SRC) $(SRC) $(CFLAGS) -DUSE_SODIUM -o $(RECOVER_BIN) $(LFLAGS)

create_blocking:
	$(CC) $(CREATE_SRC) $(SRC) $(CFLAGS) -DUSE_OPENSSL -DUSE_BLOCKING -o $(CREATE_BIN) $(LFLAGS)

recover_blocking:
	$(CC) $(RECOVER_SRC) $(SRC) $(CFLAGS) -DUSE_OPENSSL -DUSE_BLOCKING -o $(RECOVER_BIN) $(LFLAGS)

create_test:
	$(CC) $(CREATE_SRC) $(SRC) $(TEST_CFLAGS) -o $(CREATE_BIN)

recover_test:
	$(CC) $(RECOVER_SRC) $(SRC) $(TEST_CFLAGS) -o $(RECOVER_BIN)

clean:
	rm -f $(CREATE_BIN) $(RECOVER_BIN)
