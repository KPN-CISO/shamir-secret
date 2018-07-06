#ifndef _SHAMIR_H
#define _SHAMIR_H

#include <inttypes.h>

struct point {
  int64_t x;
  int64_t y;
};

extern const int64_t SSSS_PRIME;

void init_random();
int64_t get_random(int64_t min, int64_t max);
struct point *create_shares(int64_t secret, int64_t k, int64_t n, int64_t prime, int64_t *coefs_buf);
int64_t reconstruct_secret(struct point *points, int points_n, int64_t prime);

#endif
