#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "shamir.h"

#define FNAME_MAX 256

#define IS_BIG_ENDIAN (*(uint16_t*)"\0\xff" < 0x100)

struct share_info {
  uint16_t k;
  uint16_t x;
};

void usage(const char *prog)
{
  fprintf(stderr, "usage: %s [secret_share 1] .. [secret_share k]\n", prog);
}

size_t get_filesize(FILE *fp)
{
  long current;
  size_t fsize;

  if ((current = ftell(fp)) == -1)
  {
    fprintf(stderr, "error getting current offset in file\n");
    exit(EXIT_FAILURE);
  }

  if (fseek(fp, 0L, SEEK_END) != 0)
  {
    fprintf(stderr, "error calling fseek\n");
    exit(EXIT_FAILURE);
  }

  if ((fsize = ftell(fp)) == (size_t)-1)
  {
    fprintf(stderr, "error retrieving file size\n");
    exit(EXIT_FAILURE);
  }

  if (fseek(fp, current, SEEK_SET) != 0)
  {
    fprintf(stderr, "error calling fseek\n");
    exit(EXIT_FAILURE);
  }

  return fsize;
}

FILE **open_share_files(const char **filenames, int k)
{
  int i;
  FILE **fps;

  if ((fps = malloc(sizeof(FILE*) * k)) == NULL)
  {
    fprintf(stderr, "malloc error\n");
    exit(EXIT_FAILURE);
  }

  for (i = 0; i < k; i++)
  {
    if ((fps[i] = fopen(filenames[i], "r")) == NULL)
    {
      fprintf(stderr, "unable to read file %s\n", filenames[i]);
      exit(EXIT_FAILURE);
    }
  }

  return fps;
}

int main(int argc, char **argv)
{
  int i, j;
  FILE **fp_in;
  int share_len = -1;
  struct point *points;
  uint16_t k;

  /* we need at least 1 input file */
  if (argc < 2)
  {
    usage(argv[0]);
    exit(EXIT_FAILURE);
  }

  k = argc-1;

  /* open & check size for the input files */
  fp_in = open_share_files((const char**)&argv[1], k);

  for (i = 0; i < k; i++)
  { 
    if (share_len == -1)
    {
      share_len = (int)get_filesize(fp_in[i]);
    }
    else
    {
      if (share_len != (int)get_filesize(fp_in[i]))
      {
        fprintf(stderr, "[!] not all shares are of equal size! aborting...\n");
        exit(EXIT_FAILURE);
      }
    }
  }

  if ((points = malloc(sizeof(struct point) * k)) == NULL)
  {
    fprintf(stderr, "malloc error\n");
    exit(EXIT_FAILURE);
  }

  // gather x values associated with each share
  for (i = 0; i < k; i++)
  {
    // offset 0: 2x char k, offset 2: 2x char x
    if (fseek(fp_in[i], 2L, SEEK_SET) != 0)
    {
      fprintf(stderr, "error calling fseek\n");
      exit(EXIT_FAILURE);
    }

    if ((fscanf(fp_in[i], "%02x", (unsigned int*)&points[i].x)) != 1)
    {
      fprintf(stderr, "[!] error reading file\n");
      exit(EXIT_FAILURE);
    }
  }

  // attempt to recover shares byte by byte
  if (IS_BIG_ENDIAN)
  {
    fprintf(stderr, "Support for big-endian systems not yet present.\n");
    exit(EXIT_FAILURE);
  }
  
  for (i = 4; i < share_len; i += 2)
  {
    for (j = 0; j < k; j++)
    {
      if ((fread((uint16_t*)&points[j].y, sizeof(uint16_t), 1, fp_in[j])) != 1)
      {
        fprintf(stderr, "[!] error reading file\n");
        exit(EXIT_FAILURE);
      }
    }
    printf("%c", (unsigned int)reconstruct_secret(points, k, SSSS_PRIME));
  }

  for (i = 0; i < k; i++)
  {
    if (fclose(fp_in[i]) != 0)
    {
      fprintf(stderr, "warning: unable to close file\n");
    }
  }
  free(points);

  return 0;
}

