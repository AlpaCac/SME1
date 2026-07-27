#include <errno.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

void stencil_2d5p_sme_f32(size_t height, size_t width,
                          const float *restrict input,
                          float *restrict output, float center_weight,
                          float axis_weight);
void stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                          const float *restrict input,
                          float *restrict output, float center_weight,
                          float axis_weight);

static double now_seconds(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC_RAW, &ts) != 0) {
    perror("clock_gettime");
    exit(2);
  }
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

static int compare_double(const void *lhs, const void *rhs) {
  double a = *(const double *)lhs;
  double b = *(const double *)rhs;
  return (a > b) - (a < b);
}

static size_t parse_size(const char *text, const char *name) {
  char *end = NULL;
  errno = 0;
  uintmax_t value = strtoumax(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0' || value > SIZE_MAX) {
    fprintf(stderr, "invalid %s: %s\n", name, text);
    exit(2);
  }
  return (size_t)value;
}

static void initialize(float *input, float *output, size_t count) {
  for (size_t i = 0; i < count; ++i) {
    input[i] = (float)((int)(i % 31) - 15) * 0.03125f;
    output[i] = 0.0f;
  }
}

static double checksum(const float *output, size_t count) {
  double sum = 0.0;
  size_t stride = count / 1024 + 1;
  for (size_t i = 0; i < count; i += stride)
    sum += output[i];
  return sum;
}

static int benchmark_2d(size_t height, size_t width, size_t repetitions,
                        size_t samples) {
  if (height < 3 || width < 3)
    return 2;
  size_t count = height * width;
  float *input = malloc(count * sizeof(*input));
  float *output = malloc(count * sizeof(*output));
  double *times = malloc(samples * sizeof(*times));
  if (!input || !output || !times)
    return 2;
  initialize(input, output, count);

  stencil_2d5p_sme_f32(height, width, input, output, 0.5f, 0.125f);
  for (size_t sample = 0; sample < samples; ++sample) {
    double start = now_seconds();
    for (size_t i = 0; i < repetitions; ++i)
      stencil_2d5p_sme_f32(height, width, input, output, 0.5f, 0.125f);
    times[sample] = now_seconds() - start;
  }

  qsort(times, samples, sizeof(*times), compare_double);
  double median = times[samples / 2];
  double updates =
      (double)(height - 2) * (double)(width - 2) * (double)repetitions;
  printf("kernel=2d elements=%zu repetitions=%zu samples=%zu "
         "median_seconds=%.9f gupdates_per_second=%.6f checksum=%.9f\n",
         count, repetitions, samples, median, updates / median / 1.0e9,
         checksum(output, count));

  free(input);
  free(output);
  free(times);
  return 0;
}

static int benchmark_3d(size_t depth, size_t height, size_t width,
                        size_t repetitions, size_t samples) {
  if (depth < 3 || height < 3 || width < 3)
    return 2;
  size_t count = depth * height * width;
  float *input = malloc(count * sizeof(*input));
  float *output = malloc(count * sizeof(*output));
  double *times = malloc(samples * sizeof(*times));
  if (!input || !output || !times)
    return 2;
  initialize(input, output, count);

  stencil_3d7p_sme_f32(depth, height, width, input, output, 0.5f, 0.125f);
  for (size_t sample = 0; sample < samples; ++sample) {
    double start = now_seconds();
    for (size_t i = 0; i < repetitions; ++i)
      stencil_3d7p_sme_f32(depth, height, width, input, output, 0.5f, 0.125f);
    times[sample] = now_seconds() - start;
  }

  qsort(times, samples, sizeof(*times), compare_double);
  double median = times[samples / 2];
  double updates = (double)(depth - 2) * (double)(height - 2) *
                   (double)(width - 2) * (double)repetitions;
  printf("kernel=3d elements=%zu repetitions=%zu samples=%zu "
         "median_seconds=%.9f gupdates_per_second=%.6f checksum=%.9f\n",
         count, repetitions, samples, median, updates / median / 1.0e9,
         checksum(output, count));

  free(input);
  free(output);
  free(times);
  return 0;
}

int main(int argc, char **argv) {
  if (argc == 6 && strcmp(argv[1], "2d") == 0)
    return benchmark_2d(parse_size(argv[2], "height"),
                        parse_size(argv[3], "width"),
                        parse_size(argv[4], "repetitions"),
                        parse_size(argv[5], "samples"));
  if (argc == 7 && strcmp(argv[1], "3d") == 0)
    return benchmark_3d(parse_size(argv[2], "depth"),
                        parse_size(argv[3], "height"),
                        parse_size(argv[4], "width"),
                        parse_size(argv[5], "repetitions"),
                        parse_size(argv[6], "samples"));

  fprintf(stderr,
          "usage: %s 2d HEIGHT WIDTH REPETITIONS SAMPLES\n"
          "       %s 3d DEPTH HEIGHT WIDTH REPETITIONS SAMPLES\n",
          argv[0], argv[0]);
  return 2;
}
