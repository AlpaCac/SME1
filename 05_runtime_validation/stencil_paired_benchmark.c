#include <errno.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef void (*stencil_2d_fn)(size_t, size_t, const float *restrict,
                              float *restrict, float, float);
typedef void (*stencil_3d_fn)(size_t, size_t, size_t, const float *restrict,
                              float *restrict, float, float);

void baseline_stencil_2d5p_sme_f32(size_t height, size_t width,
                                   const float *restrict input,
                                   float *restrict output, float center_weight,
                                   float axis_weight);
void prefetch_stencil_2d5p_sme_f32(size_t height, size_t width,
                                   const float *restrict input,
                                   float *restrict output, float center_weight,
                                   float axis_weight);
void baseline_stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                                   const float *restrict input,
                                   float *restrict output, float center_weight,
                                   float axis_weight);
void prefetch_stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
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

static void initialize(float *input, float *baseline, float *prefetch,
                       size_t count) {
  for (size_t i = 0; i < count; ++i) {
    input[i] = (float)((int)(i % 31) - 15) * 0.03125f;
    baseline[i] = 0.0f;
    prefetch[i] = 0.0f;
  }
}

static double checksum(const float *output, size_t count) {
  double sum = 0.0;
  size_t stride = count / 1024 + 1;
  for (size_t i = 0; i < count; i += stride)
    sum += output[i];
  return sum;
}

static double measure_2d(stencil_2d_fn kernel, size_t height, size_t width,
                         const float *input, float *output,
                         size_t repetitions) {
  double start = now_seconds();
  for (size_t i = 0; i < repetitions; ++i)
    kernel(height, width, input, output, 0.5f, 0.125f);
  return now_seconds() - start;
}

static double measure_3d(stencil_3d_fn kernel, size_t depth, size_t height,
                         size_t width, const float *input, float *output,
                         size_t repetitions) {
  double start = now_seconds();
  for (size_t i = 0; i < repetitions; ++i)
    kernel(depth, height, width, input, output, 0.5f, 0.125f);
  return now_seconds() - start;
}

static void print_result(const char *kernel, size_t count, double updates,
                         double *baseline_times, double *prefetch_times,
                         double *speedups, size_t samples,
                         double baseline_checksum,
                         double prefetch_checksum) {
  qsort(baseline_times, samples, sizeof(*baseline_times), compare_double);
  qsort(prefetch_times, samples, sizeof(*prefetch_times), compare_double);
  qsort(speedups, samples, sizeof(*speedups), compare_double);
  double baseline_gups =
      updates / baseline_times[samples / 2] / 1.0e9;
  double prefetch_gups =
      updates / prefetch_times[samples / 2] / 1.0e9;
  printf("kernel=%s elements=%zu samples=%zu baseline_gups=%.6f "
         "prefetch_gups=%.6f paired_speedup=%.6f "
         "baseline_checksum=%.9f prefetch_checksum=%.9f\n",
         kernel, count, samples, baseline_gups, prefetch_gups,
         speedups[samples / 2], baseline_checksum, prefetch_checksum);
}

static int benchmark_2d(size_t height, size_t width, size_t repetitions,
                        size_t samples) {
  if (height < 3 || width < 3 || repetitions == 0 || samples == 0)
    return 2;
  size_t count = height * width;
  float *input = malloc(count * sizeof(*input));
  float *baseline = malloc(count * sizeof(*baseline));
  float *prefetch = malloc(count * sizeof(*prefetch));
  double *baseline_times = malloc(samples * sizeof(*baseline_times));
  double *prefetch_times = malloc(samples * sizeof(*prefetch_times));
  double *speedups = malloc(samples * sizeof(*speedups));
  if (!input || !baseline || !prefetch || !baseline_times ||
      !prefetch_times || !speedups)
    return 2;
  initialize(input, baseline, prefetch, count);

  baseline_stencil_2d5p_sme_f32(height, width, input, baseline, 0.5f,
                                0.125f);
  prefetch_stencil_2d5p_sme_f32(height, width, input, prefetch, 0.5f,
                                0.125f);
  for (size_t sample = 0; sample < samples; ++sample) {
    if ((sample & 1) == 0) {
      baseline_times[sample] = measure_2d(
          baseline_stencil_2d5p_sme_f32, height, width, input, baseline,
          repetitions);
      prefetch_times[sample] = measure_2d(
          prefetch_stencil_2d5p_sme_f32, height, width, input, prefetch,
          repetitions);
    } else {
      prefetch_times[sample] = measure_2d(
          prefetch_stencil_2d5p_sme_f32, height, width, input, prefetch,
          repetitions);
      baseline_times[sample] = measure_2d(
          baseline_stencil_2d5p_sme_f32, height, width, input, baseline,
          repetitions);
    }
    speedups[sample] = baseline_times[sample] / prefetch_times[sample];
  }

  double updates =
      (double)(height - 2) * (double)(width - 2) * (double)repetitions;
  print_result("2d", count, updates, baseline_times, prefetch_times, speedups,
               samples, checksum(baseline, count),
               checksum(prefetch, count));
  free(input);
  free(baseline);
  free(prefetch);
  free(baseline_times);
  free(prefetch_times);
  free(speedups);
  return 0;
}

static int benchmark_3d(size_t depth, size_t height, size_t width,
                        size_t repetitions, size_t samples) {
  if (depth < 3 || height < 3 || width < 3 || repetitions == 0 ||
      samples == 0)
    return 2;
  size_t count = depth * height * width;
  float *input = malloc(count * sizeof(*input));
  float *baseline = malloc(count * sizeof(*baseline));
  float *prefetch = malloc(count * sizeof(*prefetch));
  double *baseline_times = malloc(samples * sizeof(*baseline_times));
  double *prefetch_times = malloc(samples * sizeof(*prefetch_times));
  double *speedups = malloc(samples * sizeof(*speedups));
  if (!input || !baseline || !prefetch || !baseline_times ||
      !prefetch_times || !speedups)
    return 2;
  initialize(input, baseline, prefetch, count);

  baseline_stencil_3d7p_sme_f32(depth, height, width, input, baseline, 0.5f,
                                0.125f);
  prefetch_stencil_3d7p_sme_f32(depth, height, width, input, prefetch, 0.5f,
                                0.125f);
  for (size_t sample = 0; sample < samples; ++sample) {
    if ((sample & 1) == 0) {
      baseline_times[sample] = measure_3d(
          baseline_stencil_3d7p_sme_f32, depth, height, width, input,
          baseline, repetitions);
      prefetch_times[sample] = measure_3d(
          prefetch_stencil_3d7p_sme_f32, depth, height, width, input,
          prefetch, repetitions);
    } else {
      prefetch_times[sample] = measure_3d(
          prefetch_stencil_3d7p_sme_f32, depth, height, width, input,
          prefetch, repetitions);
      baseline_times[sample] = measure_3d(
          baseline_stencil_3d7p_sme_f32, depth, height, width, input,
          baseline, repetitions);
    }
    speedups[sample] = baseline_times[sample] / prefetch_times[sample];
  }

  double updates = (double)(depth - 2) * (double)(height - 2) *
                   (double)(width - 2) * (double)repetitions;
  print_result("3d", count, updates, baseline_times, prefetch_times, speedups,
               samples, checksum(baseline, count),
               checksum(prefetch, count));
  free(input);
  free(baseline);
  free(prefetch);
  free(baseline_times);
  free(prefetch_times);
  free(speedups);
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
  return 2;
}
