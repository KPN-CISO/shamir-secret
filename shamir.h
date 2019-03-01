#ifndef _SHAMIR_H
#define _SHAMIR_H

#include <inttypes.h>

struct point {
  int64_t x;
  int64_t y;
};

extern const int64_t SSSS_PRIME;

extern void init_random(void);
extern int64_t get_random(int64_t min, int64_t max);
extern struct point *create_shares(int64_t secret, int64_t k, int64_t n, int64_t prime, int64_t *coefs_buf);
extern int64_t reconstruct_secret(struct point *points, int points_n, int64_t prime);

#endif
