#include <stdio.h>
#include <stdlib.h>

#include "shamir.h"

#define FNAME_MAX 256
ssize_t SSIZE_MAX = ( ((ssize_t) 0 - 1 ) & ~((ssize_t)1 << ((sizeof(ssize_t) * 8) - 1)));

void usage(const char *prog)
{
  fprintf(stderr, "usage: %s <n-shares> <k-treshold> <input file>\n", prog);
}

char *read_file(const char *fname, size_t *size_out)
{
  size_t fsize, fsize_left, r;
  FILE *fp;
  char *fbuf, *fcur;

  if ((fp = fopen(fname, "r")) == NULL)
  {
    fprintf(stderr, "unable to open file %s\n", fname);
    exit(EXIT_FAILURE);
  }
  
  if (fseek(fp, 0L, SEEK_END) != 0)
  {
    fprintf(stderr, "error calling fseek on file %s\n", fname);
    exit(EXIT_FAILURE);
  }

  if ((fsize = ftell(fp)) == (size_t)-1)
  {
    fprintf(stderr, "error retrieving file size of %s\n", fname);
    exit(EXIT_FAILURE);
  }

  if (fseek(fp, 0L, SEEK_SET) != 0)
  {
    fprintf(stderr, "error calling fseek on file %s\n", fname);
    exit(EXIT_FAILURE);
  }

  if ((fbuf = malloc(fsize * sizeof(char))) == NULL)
  {
    fprintf(stderr, "malloc error\n");
    exit(EXIT_FAILURE);
  }

  fcur = fbuf;
  fsize_left = fsize;
  while (!feof(fp) && fsize_left != 0)
  {
    r = fread(fcur, sizeof(char), fsize_left, fp);
    fcur = &fcur[r];
    if (r > fsize_left)
    {
      fprintf(stderr, "I/O error reading %s\n", fname);
      exit(EXIT_FAILURE);
    }
    fsize_left -= r;
    if (ferror(fp))
    {
      fprintf(stderr, "I/O error reading %s\n", fname);
      exit(EXIT_FAILURE);
    }
  }

  if (fclose(fp) != 0)
  {
    fprintf(stderr, "warning: unable to close file %s\n", fname);
  }

  // Allow calling of read_file without setting size_out
  if (size_out != NULL)
  {
    *size_out = fsize;
  }
  return fbuf;
}

/* creates share files and writes the file headers */
FILE **create_share_files(int n, int k)
{
  FILE **fps;
  int i;
  char filename[FNAME_MAX];

  if ((fps = malloc(sizeof(FILE*) * n)) == NULL)
  {
    fprintf(stderr, "malloc error\n");
    exit(EXIT_FAILURE);
  }

  for (i = 0; i < n; i++)
  {
    if (snprintf(filename, FNAME_MAX, "key%02x", i+1) >= FNAME_MAX)
    {
      fprintf(stderr, "file name for output files too large\n");
      exit(EXIT_FAILURE);
    }

    if ((fps[i] = fopen(filename, "w")) == NULL)
    {
      fprintf(stderr, "unable to write to file %s\n", filename);
      exit(EXIT_FAILURE);
    }
    // bytes [0..3] contain, in ascii, [0..1]: k (the recovery treshold) for this share-file and [2..3]: the x used for each byte in this share-file
    if (fprintf(fps[i], "%02x%02x", (uint8_t)k, (uint8_t)i+1) < 0)
    {
      fprintf(stderr, "error writing to output files\n");
      exit(EXIT_FAILURE);
    }
  }
  return fps;
}

int main(int argc, char **argv)
{
  size_t buf_size;
  char *buf;
  ssize_t i;
  int n, k, j;
  struct point *shares;
  FILE **fp_out;
  int64_t *coefs_buf;

  /* cli arg parsing */
  if (argc != 4)
  {
    usage(argv[0]);
    exit(EXIT_FAILURE);
  }
  
  if (sscanf(argv[1], "%i", &n) != 1)
  {
    usage(argv[0]);
    exit(EXIT_FAILURE);
  }

  if (sscanf(argv[2], "%i", &k) != 1)
  {
    usage(argv[0]);
    exit(EXIT_FAILURE);
  }

  if (n > 255 || k > n)
  {
    fprintf(stderr, "k <= n < 256\n");
    exit(EXIT_FAILURE);
  }

  /* read input file, create output files */
  buf = read_file(argv[3], &buf_size);

  fp_out = create_share_files(n, k);

  /* ssss */
  init_random();

  // buf_size is unsigned, so check if it fits in a signed int
  if (buf_size > (size_t)SSIZE_MAX)
  {
    fprintf(stderr, "File size too large, aborting\n");
    exit(EXIT_FAILURE);
  }

  // create a buffer for create_shares so that it does not have tos malloc/free every call
  if ((coefs_buf = malloc(k * sizeof(int64_t))) == NULL)
  {
    fprintf(stderr, "malloc error\n");
    exit(EXIT_FAILURE);
  }

  for (i = 0; i < (int)buf_size; i++)
  {
    shares = create_shares(buf[i], k, n, SSSS_PRIME, coefs_buf);
    for (j = 0; j < n; j++)
    {
      // in our case, sizeof(SSSS_PRIME) <= sizeof(uint16_t), which is the modulus
      uint16_t data = (uint16_t)shares[j].y;
      if (fwrite(&data, sizeof(uint16_t), 1, fp_out[j]) != 1)
			{
        fprintf(stderr, "error writing to secret share, aborting\n");
        exit(EXIT_FAILURE);
      }
    }
    free(shares);
  }
  free(buf);
  free(coefs_buf);

  for (j = 0; j < n; j++)
  {
    if (fclose(fp_out[j]) != 0)
    {
      fprintf(stderr, "warning: unable to close file\n");
    }
  }

  return 0;
}

