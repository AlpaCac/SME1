#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

void stencil_2d5p_sme_f32(size_t height, size_t width,
                          const float *restrict input,
                          float *restrict output, float center_weight,
                          float axis_weight);
void stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                          const float *restrict input,
                          float *restrict output, float center_weight,
                          float axis_weight);

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

static int test_2d(size_t height, size_t width) {
  size_t count = height * width;
  float *input = malloc(count * sizeof(*input));
  float *actual = malloc(count * sizeof(*actual));
  float *expected = malloc(count * sizeof(*expected));
  if (!input || !actual || !expected)
    return 0;

  initialize(input, actual, expected, count);
  reference_2d(height, width, input, expected, 0.5f, 0.125f);
  stencil_2d5p_sme_f32(height, width, input, actual, 0.5f, 0.125f);
  int passed = compare(actual, expected, count);

  free(input);
  free(actual);
  free(expected);
  return passed;
}

static int test_3d(size_t depth, size_t height, size_t width) {
  size_t count = depth * height * width;
  float *input = malloc(count * sizeof(*input));
  float *actual = malloc(count * sizeof(*actual));
  float *expected = malloc(count * sizeof(*expected));
  if (!input || !actual || !expected)
    return 0;

  initialize(input, actual, expected, count);
  reference_3d(depth, height, width, input, expected, 0.5f, 0.125f);
  stencil_3d7p_sme_f32(depth, height, width, input, actual, 0.5f, 0.125f);
  int passed = compare(actual, expected, count);

  free(input);
  free(actual);
  free(expected);
  return passed;
}

int main(void) {
  const size_t cases_2d[][2] = {
      {2, 2}, {3, 3}, {5, 7}, {17, 19}, {33, 65}};
  const size_t cases_3d[][3] = {
      {2, 3, 3}, {3, 3, 3}, {4, 5, 7}, {7, 9, 17}, {9, 17, 33}};

  for (size_t i = 0; i < sizeof(cases_2d) / sizeof(cases_2d[0]); ++i) {
    if (!test_2d(cases_2d[i][0], cases_2d[i][1]))
      return 1;
  }
  for (size_t i = 0; i < sizeof(cases_3d) / sizeof(cases_3d[0]); ++i) {
    if (!test_3d(cases_3d[i][0], cases_3d[i][1], cases_3d[i][2]))
      return 1;
  }

  puts("stencil correctness: PASS");
  return 0;
}
