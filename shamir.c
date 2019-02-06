/*
 * Shamir Secret Sharing Scheme implementation on prime field 65521.
 *
 * (c) 2019 Sebastiaan Groot <sebastiaang@kpn-cert.nl>
 *
 * The prime (p) chosen for SSSS is fairly arbitrary, but we want it to have the following properties:
 *   p > N, where N is the largest value in your input (secret) domain. Since we want to create secret shares
 *   from bytes, N=0xff
 *   p is not too big, since p is used as upper limit to the output field, it determines the size of the secret shares.
 *   Since p > 255, we use at least 2 output bytes per input byte. As larger values of p do not add to the
 *   cryptographic strength of SSSS, we have chosen 0xff < p <= 2^16. 65521 is the prime closest under 2^16,
 *   but any prime satisfying the previous constraint would do.
 *
 * Shamir secret sharing can be implemented to work on fields of arbitrary size, but this implementation only
 *   works on prime fields and introduces a size inflation of 2x. An implementation on GF_256 would allow
 *   the entire 1-byte input-domain without increasing output size, but the implementation would lose some of its
 *   simplicity.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#ifdef USE_OPENSSL
#include <openssl/rand.h>
#elif USE_SODIUM
#include <sodium.h>
#else
#include <time.h>
#endif

#include "shamir.h"

const int64_t SSSS_PRIME = 65521;

static void * (* const volatile memset_ptr)(void *, int, size_t) = memset;

static inline int64_t mod(int64_t a, int64_t b)
{
  return ((a % b) + b) % b;
}

// try to avoid optimizing memset to 0 out
static void secure_memzero(void *p, size_t len)
{
  (memset_ptr)(p, 0, len);
}

void init_random()
{
#ifdef USE_OPENSSL
  // small initial seed
  int r;
  int bytes_wanted = 32;
#ifdef USE_BLOCKING
  while ((r = RAND_load_file("/dev/random", bytes_wanted)) < bytes_wanted)
#else
  while ((r = RAND_load_file("/dev/urandom", bytes_wanted)) < bytes_wanted)
#endif
  {
    if (r > 0)
    {
      bytes_wanted -= r;
    }
  }
#elif USE_SODIUM
  if (sodium_init() < 0)
  {
    fprintf(stderr, "unable to initialize libsodium. aborting!\n");
    exit(EXIT_FAILURE);
  }
#else
  #pragma message ("Using rand() and srand(time(NULL)), to be used for testing purposes only!")
  // testing only
  srand(time(NULL));
#endif
}

int64_t get_random(int64_t min, int64_t max)
{
#ifdef USE_OPENSSL
  // ask /dev/random for the number of bits of entropy that we want to extract at most (64 bits, or 8 bytes)
  int r;
  int bytes_wanted = 8;
  int64_t rand;
  
  if (max <= min)
  {
    fprintf(stderr, "get_random: max <= min, aborting\n");
    exit(EXIT_FAILURE);
  }

  while (1)
  {
    // add 8 bytes of entropy to the pool
#ifdef USE_BLOCKING
    r = RAND_load_file("/dev/random", bytes_wanted);
#else
    r = RAND_load_file("/dev/urandom", bytes_wanted);
#endif
    if (r < bytes_wanted)
    {
      // some bytes were returned from /dev/random, so decrease bytes_wanted
      if (r > 0)
      {
        bytes_wanted -= r;
      }
      continue;
    }
    
    // because of the min/max operation at the end, conversion from uint64_t to int64_t here is harmless
    r = (int64_t)RAND_bytes((unsigned char*)&rand, sizeof(rand));
    if (r == 1)
    {
      break;
    }
    // RAND_bytes failed, so get more entropy and retry
    bytes_wanted = 8;
  }
  return (rand % (max - min)) + min;
#elif USE_SODIUM
  if (min != 0 || max > UINT32_MAX)
  {
    fprintf(stderr, "libsodium random currently only supports uniform random using 32-bit integer types\n");
    exit(EXIT_FAILURE);
  }

  return (int64_t) randombytes_uniform((uint32_t) max);
#else
  return (rand() % (max - min)) + min;
#endif
}

// fairly efficient evaluation of a polynomial modulo prime with a degree of coefs_n-1 at x
// e.g. f(x) = 2x^2 + 0x + 5 (mod 11), f(2) = 2
int64_t get_y_at(int64_t *coefs, int coefs_n, int64_t x, int64_t prime)
{
  int64_t accum = 0;
  int i;
  for (i = coefs_n-1; i >= 0; i--)
  {
    accum *= x;
    accum += coefs[i];
    accum = mod(accum, prime);
  }
  return accum;
}

// create secret shares. sizeof(coefs_buf) >= k * sizeof(int64_t) or NULL
struct point *create_shares(int64_t secret, int64_t k, int64_t n, int64_t prime, int64_t *coefs_buf)
{
  struct point *points;
  int i, manage_coefs_buf = 0;

  // init & sanity checks
  if (k > n)
    perror("not enough shares requested, secret would be irrecoverable\n");
  if (secret >= prime)
    perror("secret has to be smaller than prime\n");
  if ((points = malloc(n * sizeof(struct point))) == NULL)
    perror("malloc error\n");

  // allow coefs_buf to be managed by this function rather than the caller
  if (coefs_buf == NULL)
  {
    manage_coefs_buf = 1;
    if ((coefs_buf = malloc(k * sizeof(int64_t))) == NULL)
      perror("malloc error\n");
  }

  // secret & random coefficients
  coefs_buf[0] = secret;
  for (i = 1; i < k; i++)
  {
    coefs_buf[i] = get_random(0, prime);
  }
  
  // share generation
  for (i = 0; i < n; i++)
  {
    points[i].x = i+1;
    points[i].y = get_y_at(coefs_buf, k, i+1, prime);
  }

  if (manage_coefs_buf)
  {
    secure_memzero(coefs_buf, k * sizeof(int64_t));
    free(coefs_buf);
  }

  return points;
}

void gcde(int64_t a, int64_t b, int64_t *x_out, int64_t *y_out)
{
  int64_t q, t, x = 0, last_x = 1, y = 1, last_y = 0;

  if (x_out == NULL || y_out == NULL)
    perror("gcde: buffers not properly initialized\n");

  while (b != 0)
  {
    q = a / b;

    // in C, % is the remainder operation, which is slightly different from a proper modulo operation
    // (a mod b) => ((a % b) + b) % b
    t = b;
    b = mod(a, b);
    a = t;

    t = x;
    x = last_x - q * x;
    last_x = t;

    t = y;
    y = last_y - q * y;
    last_y = t;
  }
  *x_out = last_x;
  *y_out = last_y;
}

int64_t divmod(int64_t num, int64_t den, int64_t prime)
{
  int64_t x, y;
  gcde(den, prime, &x, &y);
  return num * x;
}

int64_t lagrange_interpolate(int64_t x, struct point *points, int points_n, int64_t prime)
{
  int64_t *nums, *dens, accum_num, accum_den, result;
  int i, j;
  
  nums = malloc(points_n * sizeof(int64_t));
  dens = malloc(points_n * sizeof(int64_t));
  if ((nums == NULL) || (dens == NULL))
    perror("malloc error\n");

  // gather nums & dens for all points
  for (i = 0; i < points_n; i++)
  {
    accum_num = 1;
    accum_den = 1;
    for (j = 0; j < points_n; j++)
    {
      if (i != j)
      {
        accum_num = mod(accum_num * (x - points[j].x),           prime);
        accum_den = mod(accum_den * (points[i].x - points[j].x), prime);
      }
    }
    nums[i] = accum_num;
    dens[i] = accum_den;
  }

  // product of all dens
  accum_den = 1;
  for (i = 0; i < points_n; i++)
  {
    accum_den = mod(accum_den * dens[i], prime);
  }

  
  // get num
  accum_num = 0;
  for (i = 0; i < points_n; i++)
  {
    int64_t val = mod(nums[i] * accum_den * points[i].y, prime);
    accum_num = accum_num + divmod(val, dens[i], prime);
  }

  // in C, % is the remainder operation, which is slightly different from a proper modulo operation
  // (a mod b) => ((a % b) + b) % b
  result = mod(divmod(accum_num, accum_den, prime), prime);

  free(nums);
  free(dens);

  return result;
}

int64_t reconstruct_secret(struct point *points, int points_n, int64_t prime)
{
  return lagrange_interpolate(0, points, points_n, prime);
}

