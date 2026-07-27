#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#ifndef MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif

void stencil_2d5p_sme_f32(size_t height, size_t width,
                          const float *restrict input,
                          float *restrict output, float center_weight,
                          float axis_weight);
void stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                          const float *restrict input,
                          float *restrict output, float center_weight,
                          float axis_weight);

typedef struct {
  float *data;
  void *mapping;
  size_t mapping_bytes;
} GuardedBuffer;

static GuardedBuffer allocate_guarded(size_t count, int align_end) {
  GuardedBuffer buffer = {0};
  long page_value = sysconf(_SC_PAGESIZE);
  if (page_value <= 0)
    return buffer;
  size_t page = (size_t)page_value;
  size_t data_bytes = count * sizeof(float);
  size_t writable_bytes = (data_bytes + page - 1) / page * page;
  buffer.mapping_bytes = writable_bytes + 2 * page;
  buffer.mapping = mmap(NULL, buffer.mapping_bytes, PROT_NONE,
                        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (buffer.mapping == MAP_FAILED) {
    buffer.mapping = NULL;
    return buffer;
  }

  char *writable = (char *)buffer.mapping + page;
  if (mprotect(writable, writable_bytes, PROT_READ | PROT_WRITE) != 0) {
    munmap(buffer.mapping, buffer.mapping_bytes);
    buffer.mapping = NULL;
    return buffer;
  }
  buffer.data = (float *)(align_end ? writable + writable_bytes - data_bytes
                                   : writable);
  return buffer;
}

static void release_guarded(GuardedBuffer *buffer) {
  if (buffer->mapping)
    munmap(buffer->mapping, buffer->mapping_bytes);
}

static void reference_2d(size_t height, size_t width, const float *input,
                         float *output, float center_weight,
                         float axis_weight) {
  for (size_t y = 1; y + 1 < height; ++y) {
    for (size_t x = 1; x + 1 < width; ++x) {
      size_t i = y * width + x;
      float neighbors =
          input[i - 1] + input[i + 1] + input[i - width] + input[i + width];
      output[i] = center_weight * input[i] + axis_weight * neighbors;
    }
  }
}

static void reference_3d(size_t depth, size_t height, size_t width,
                         const float *input, float *output,
                         float center_weight, float axis_weight) {
  size_t plane = height * width;
  for (size_t z = 1; z + 1 < depth; ++z) {
    for (size_t y = 1; y + 1 < height; ++y) {
      for (size_t x = 1; x + 1 < width; ++x) {
        size_t i = z * plane + y * width + x;
        float neighbors = input[i - 1] + input[i + 1] + input[i - width] +
                          input[i + width] + input[i - plane] +
                          input[i + plane];
        output[i] = center_weight * input[i] + axis_weight * neighbors;
      }
    }
  }
}

static float absolute(float value) { return value < 0.0f ? -value : value; }

static int compare(const float *actual, const float *expected, size_t count) {
  for (size_t i = 0; i < count; ++i) {
    float tolerance = 1.0e-5f * (1.0f + absolute(expected[i]));
    if (absolute(actual[i] - expected[i]) > tolerance) {
      fprintf(stderr, "mismatch at %zu: actual=%g expected=%g\n", i,
              actual[i], expected[i]);
      return 0;
    }
  }
  return 1;
}

static void initialize(float *input, float *actual, float *expected,
                       size_t count) {
  for (size_t i = 0; i < count; ++i) {
    input[i] = (float)((int)(i % 29) - 14) * 0.0625f;
    actual[i] = -123.25f;
    expected[i] = -123.25f;
  }
}

static int test_2d(size_t height, size_t width, int align_end) {
  size_t count = height * width;
  GuardedBuffer input = allocate_guarded(count, align_end);
  GuardedBuffer actual = allocate_guarded(count, align_end);
  GuardedBuffer expected = allocate_guarded(count, align_end);
  if (!input.data || !actual.data || !expected.data) {
    release_guarded(&input);
    release_guarded(&actual);
    release_guarded(&expected);
    return 0;
  }

  initialize(input.data, actual.data, expected.data, count);
  reference_2d(height, width, input.data, expected.data, 0.5f, 0.125f);
  stencil_2d5p_sme_f32(height, width, input.data, actual.data, 0.5f, 0.125f);
  int passed = compare(actual.data, expected.data, count);

  release_guarded(&input);
  release_guarded(&actual);
  release_guarded(&expected);
  return passed;
}

static int test_3d(size_t depth, size_t height, size_t width, int align_end) {
  size_t count = depth * height * width;
  GuardedBuffer input = allocate_guarded(count, align_end);
  GuardedBuffer actual = allocate_guarded(count, align_end);
  GuardedBuffer expected = allocate_guarded(count, align_end);
  if (!input.data || !actual.data || !expected.data) {
    release_guarded(&input);
    release_guarded(&actual);
    release_guarded(&expected);
    return 0;
  }

  initialize(input.data, actual.data, expected.data, count);
  reference_3d(depth, height, width, input.data, expected.data, 0.5f, 0.125f);
  stencil_3d7p_sme_f32(depth, height, width, input.data, actual.data, 0.5f,
                       0.125f);
  int passed = compare(actual.data, expected.data, count);

  release_guarded(&input);
  release_guarded(&actual);
  release_guarded(&expected);
  return passed;
}

int main(void) {
  const size_t cases_2d[][2] = {
      {2, 2}, {3, 3}, {5, 7}, {17, 19}, {33, 65}};
  const size_t cases_3d[][3] = {
      {2, 3, 3}, {3, 3, 3}, {4, 5, 7}, {7, 9, 17}, {9, 17, 33}};

  for (int align_end = 0; align_end <= 1; ++align_end) {
    for (size_t i = 0; i < sizeof(cases_2d) / sizeof(cases_2d[0]); ++i) {
      if (!test_2d(cases_2d[i][0], cases_2d[i][1], align_end))
        return 1;
    }
    for (size_t i = 0; i < sizeof(cases_3d) / sizeof(cases_3d[0]); ++i) {
      if (!test_3d(cases_3d[i][0], cases_3d[i][1], cases_3d[i][2],
                   align_end))
        return 1;
    }
  }

  puts("stencil correctness: PASS");
  return 0;
}
