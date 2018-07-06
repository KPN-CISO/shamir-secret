# set CC if it has not been set yet
CC ?= gcc
# prepend default options to allow conflicting flags (like -O levels) to be overwritten by passed CFLAGS variable
CFLAGS := -Wall -Wextra -pedantic -O2 $(CFLAGS)
SRC = shamir.c
CREATE_SRC = create_shares.c
CREATE_BIN = create_shares
RECOVER_SRC = recover_shares.c
RECOVER_BIN = recover_shares

.PHONY: all static static_blocking secure blocking insecure clean

# default, build non-blocking using OpenSSL
all: secure

# non-blocking, OpenSSL libcrypto statically linked, still requires libdl & pthread dynamically
static: LFLAGS += -Wl,-Bstatic -lcrypto -Wl,-Bdynamic -l:libdl.so -lpthread
static: create_secure recover_secure

# blocking, OpenSSL libcrypto statically linked, still requires libdl & pthread dynamically
static_blocking: LFLAGS += -Wl,-Bstatic -lcrypto -Wl,-Bdynamic -l:libdl.so -lpthread
static_blocking: create_blocking recover_blocking

# non-blocking, libcrypto dynamically linked
secure: LFLAGS += -lcrypto
secure: create_secure recover_secure

# blocking, libcrypto dynamically linked
blocking: LFLAGS += -lcrypto
blocking: create_blocking recover_blocking

# non-blocking, not using libcrypto
insecure: create recover

create:
	$(CC) $(CREATE_SRC) $(SRC) $(CFLAGS) -o $(CREATE_BIN)

recover:
	$(CC) $(RECOVER_SRC) $(SRC) $(CFLAGS) -o $(RECOVER_BIN)

create_secure:
	$(CC) $(CREATE_SRC) $(SRC) $(CFLAGS) -DUSE_OPENSSL -o $(CREATE_BIN) $(LFLAGS)

recover_secure:
	$(CC) $(RECOVER_SRC) $(SRC) $(CFLAGS) -DUSE_OPENSSL -o $(RECOVER_BIN) $(LFLAGS)

create_blocking:
	$(CC) $(CREATE_SRC) $(SRC) $(CFLAGS) -DUSE_OPENSSL -DUSE_BLOCKING -o $(CREATE_BIN) $(LFLAGS)

recover_blocking:
	$(CC) $(RECOVER_SRC) $(SRC) $(CFLAGS) -DUSE_OPENSSL -DUSE_BLOCKING -o $(RECOVER_BIN) $(LFLAGS)

clean:
	rm -f $(CREATE_BIN) $(RECOVER_BIN)
