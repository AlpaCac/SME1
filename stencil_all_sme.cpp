#include <arm_sme.h>
#include <arm_sve.h>

#include <stdint.h>

namespace {

inline void swap_buffers(double *&left, double *&right) {
  double *temporary = left;
  left = right;
  right = temporary;
}

} // namespace

#define ACCUMULATE_3D_OFFSET(offset)                                         \
  value = svadd_f64_x(                                                       \
      predicate, value,                                                      \
      svld1_f64(predicate, source + center + x + (offset)))

/*
 * These signatures match the server kernels:
 *
 *   stencil1D_3point_sme(double *, double *, int, int)
 *   stencil2D_*point_sme(double *, double *, int, int, int)
 *   stencil3D_*point_sme(double *, double *, int, int, int, int)
 *
 * The final integer is the number of time steps. Boundaries are left
 * unchanged; callers must initialize both buffers' boundary regions.
 */

__arm_locally_streaming void
stencil1D_3point_sme(double *input, double *output, int length,
                     int time_steps) {
  if (!input || !output || length < 3 || time_steps <= 0)
    return;

  double *source = input;
  double *destination = output;
  const int64_t end = static_cast<int64_t>(length) - 1;
  const int64_t vector_length = static_cast<int64_t>(svcntd());

  for (int step = 0; step < time_steps; ++step) {
    for (int64_t x = 1; x < end; x += vector_length) {
      const svbool_t predicate =
          svwhilelt_b64_u64(static_cast<uint64_t>(x),
                            static_cast<uint64_t>(end));
      svfloat64_t value = svld1_f64(predicate, source + x);
      value = svadd_f64_x(predicate, value,
                          svld1_f64(predicate, source + x - 1));
      value = svadd_f64_x(predicate, value,
                          svld1_f64(predicate, source + x + 1));
      svst1_f64(predicate, destination + x, value);
    }
    swap_buffers(source, destination);
  }
}

__arm_locally_streaming void
stencil2D_5point_sme(double *input, double *output, int height, int width,
                     int time_steps) {
  if (!input || !output || height < 3 || width < 3 || time_steps <= 0)
    return;

  double *source = input;
  double *destination = output;
  const int64_t row_stride = width;
  const int64_t end = static_cast<int64_t>(width) - 1;
  const int64_t vector_length = static_cast<int64_t>(svcntd());

  for (int step = 0; step < time_steps; ++step) {
    for (int64_t y = 1; y + 1 < height; ++y) {
      const int64_t row = y * row_stride;
      for (int64_t x = 1; x < end; x += vector_length) {
        const svbool_t predicate =
            svwhilelt_b64_u64(static_cast<uint64_t>(x),
                              static_cast<uint64_t>(end));
        svfloat64_t value = svld1_f64(predicate, source + row + x);
        value = svadd_f64_x(predicate, value,
                            svld1_f64(predicate, source + row + x - 1));
        value = svadd_f64_x(predicate, value,
                            svld1_f64(predicate, source + row + x + 1));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row - row_stride + x));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row + row_stride + x));
        svst1_f64(predicate, destination + row + x, value);
      }
    }
    swap_buffers(source, destination);
  }
}

__arm_locally_streaming void
stencil2D_9point_sme(double *input, double *output, int height, int width,
                     int time_steps) {
  if (!input || !output || height < 3 || width < 3 || time_steps <= 0)
    return;

  double *source = input;
  double *destination = output;
  const int64_t row_stride = width;
  const int64_t end = static_cast<int64_t>(width) - 1;
  const int64_t vector_length = static_cast<int64_t>(svcntd());

  for (int step = 0; step < time_steps; ++step) {
    for (int64_t y = 1; y + 1 < height; ++y) {
      const int64_t row = y * row_stride;
      for (int64_t x = 1; x < end; x += vector_length) {
        const svbool_t predicate =
            svwhilelt_b64_u64(static_cast<uint64_t>(x),
                              static_cast<uint64_t>(end));
        svfloat64_t value = svld1_f64(predicate, source + row + x);
        value = svadd_f64_x(predicate, value,
                            svld1_f64(predicate, source + row + x - 1));
        value = svadd_f64_x(predicate, value,
                            svld1_f64(predicate, source + row + x + 1));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row - row_stride + x - 1));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row - row_stride + x));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row - row_stride + x + 1));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row + row_stride + x - 1));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row + row_stride + x));
        value = svadd_f64_x(
            predicate, value,
            svld1_f64(predicate, source + row + row_stride + x + 1));
        svst1_f64(predicate, destination + row + x, value);
      }
    }
    swap_buffers(source, destination);
  }
}

__arm_locally_streaming void
stencil3D_13point_sme(double *input, double *output, int depth, int height,
                      int width, int time_steps) {
  if (!input || !output || depth < 5 || height < 5 || width < 5 ||
      time_steps <= 0)
    return;

  double *source = input;
  double *destination = output;
  const int64_t row_stride = width;
  const int64_t plane_stride = static_cast<int64_t>(height) * width;
  const int64_t end = static_cast<int64_t>(width) - 2;
  const int64_t vector_length = static_cast<int64_t>(svcntd());

  for (int step = 0; step < time_steps; ++step) {
    for (int64_t z = 2; z + 2 < depth; ++z) {
      for (int64_t y = 2; y + 2 < height; ++y) {
        const int64_t center = z * plane_stride + y * row_stride;
        for (int64_t x = 2; x < end; x += vector_length) {
          const svbool_t predicate =
              svwhilelt_b64_u64(static_cast<uint64_t>(x),
                                static_cast<uint64_t>(end));
          svfloat64_t value =
              svld1_f64(predicate, source + center + x);
          ACCUMULATE_3D_OFFSET(-1);
          ACCUMULATE_3D_OFFSET(1);
          ACCUMULATE_3D_OFFSET(-2);
          ACCUMULATE_3D_OFFSET(2);
          ACCUMULATE_3D_OFFSET(-row_stride);
          ACCUMULATE_3D_OFFSET(row_stride);
          ACCUMULATE_3D_OFFSET(-2 * row_stride);
          ACCUMULATE_3D_OFFSET(2 * row_stride);
          ACCUMULATE_3D_OFFSET(-plane_stride);
          ACCUMULATE_3D_OFFSET(plane_stride);
          ACCUMULATE_3D_OFFSET(-2 * plane_stride);
          ACCUMULATE_3D_OFFSET(2 * plane_stride);
          svst1_f64(predicate, destination + center + x, value);
        }
      }
    }
    swap_buffers(source, destination);
  }
}

__arm_locally_streaming void
stencil3D_25point_sme(double *input, double *output, int depth, int height,
                      int width, int time_steps) {
  if (!input || !output || depth < 9 || height < 9 || width < 9 ||
      time_steps <= 0)
    return;

  double *source = input;
  double *destination = output;
  const int64_t row_stride = width;
  const int64_t plane_stride = static_cast<int64_t>(height) * width;
  const int64_t end = static_cast<int64_t>(width) - 4;
  const int64_t vector_length = static_cast<int64_t>(svcntd());

  for (int step = 0; step < time_steps; ++step) {
    for (int64_t z = 4; z + 4 < depth; ++z) {
      for (int64_t y = 4; y + 4 < height; ++y) {
        const int64_t center = z * plane_stride + y * row_stride;
        for (int64_t x = 4; x < end; x += vector_length) {
          const svbool_t predicate =
              svwhilelt_b64_u64(static_cast<uint64_t>(x),
                                static_cast<uint64_t>(end));
          svfloat64_t value =
              svld1_f64(predicate, source + center + x);
          ACCUMULATE_3D_OFFSET(-1);
          ACCUMULATE_3D_OFFSET(1);
          ACCUMULATE_3D_OFFSET(-2);
          ACCUMULATE_3D_OFFSET(2);
          ACCUMULATE_3D_OFFSET(-3);
          ACCUMULATE_3D_OFFSET(3);
          ACCUMULATE_3D_OFFSET(-4);
          ACCUMULATE_3D_OFFSET(4);
          ACCUMULATE_3D_OFFSET(-row_stride);
          ACCUMULATE_3D_OFFSET(row_stride);
          ACCUMULATE_3D_OFFSET(-2 * row_stride);
          ACCUMULATE_3D_OFFSET(2 * row_stride);
          ACCUMULATE_3D_OFFSET(-3 * row_stride);
          ACCUMULATE_3D_OFFSET(3 * row_stride);
          ACCUMULATE_3D_OFFSET(-4 * row_stride);
          ACCUMULATE_3D_OFFSET(4 * row_stride);
          ACCUMULATE_3D_OFFSET(-plane_stride);
          ACCUMULATE_3D_OFFSET(plane_stride);
          ACCUMULATE_3D_OFFSET(-2 * plane_stride);
          ACCUMULATE_3D_OFFSET(2 * plane_stride);
          ACCUMULATE_3D_OFFSET(-3 * plane_stride);
          ACCUMULATE_3D_OFFSET(3 * plane_stride);
          ACCUMULATE_3D_OFFSET(-4 * plane_stride);
          ACCUMULATE_3D_OFFSET(4 * plane_stride);
          svst1_f64(predicate, destination + center + x, value);
        }
      }
    }
    swap_buffers(source, destination);
  }
}

__arm_locally_streaming void
stencil3D_27point_sme(double *input, double *output, int depth, int height,
                      int width, int time_steps) {
  if (!input || !output || depth < 3 || height < 3 || width < 3 ||
      time_steps <= 0)
    return;

  double *source = input;
  double *destination = output;
  const int64_t row_stride = width;
  const int64_t plane_stride = static_cast<int64_t>(height) * width;
  const int64_t end = static_cast<int64_t>(width) - 1;
  const int64_t vector_length = static_cast<int64_t>(svcntd());

  for (int step = 0; step < time_steps; ++step) {
    for (int64_t z = 1; z + 1 < depth; ++z) {
      for (int64_t y = 1; y + 1 < height; ++y) {
        const int64_t center = z * plane_stride + y * row_stride;
        for (int64_t x = 1; x < end; x += vector_length) {
          const svbool_t predicate =
              svwhilelt_b64_u64(static_cast<uint64_t>(x),
                                static_cast<uint64_t>(end));
          svfloat64_t value =
              svdup_f64(0.0);
          ACCUMULATE_3D_OFFSET(-plane_stride - row_stride - 1);
          ACCUMULATE_3D_OFFSET(-plane_stride - row_stride);
          ACCUMULATE_3D_OFFSET(-plane_stride - row_stride + 1);
          ACCUMULATE_3D_OFFSET(-plane_stride - 1);
          ACCUMULATE_3D_OFFSET(-plane_stride);
          ACCUMULATE_3D_OFFSET(-plane_stride + 1);
          ACCUMULATE_3D_OFFSET(-plane_stride + row_stride - 1);
          ACCUMULATE_3D_OFFSET(-plane_stride + row_stride);
          ACCUMULATE_3D_OFFSET(-plane_stride + row_stride + 1);
          ACCUMULATE_3D_OFFSET(-row_stride - 1);
          ACCUMULATE_3D_OFFSET(-row_stride);
          ACCUMULATE_3D_OFFSET(-row_stride + 1);
          ACCUMULATE_3D_OFFSET(-1);
          ACCUMULATE_3D_OFFSET(0);
          ACCUMULATE_3D_OFFSET(1);
          ACCUMULATE_3D_OFFSET(row_stride - 1);
          ACCUMULATE_3D_OFFSET(row_stride);
          ACCUMULATE_3D_OFFSET(row_stride + 1);
          ACCUMULATE_3D_OFFSET(plane_stride - row_stride - 1);
          ACCUMULATE_3D_OFFSET(plane_stride - row_stride);
          ACCUMULATE_3D_OFFSET(plane_stride - row_stride + 1);
          ACCUMULATE_3D_OFFSET(plane_stride - 1);
          ACCUMULATE_3D_OFFSET(plane_stride);
          ACCUMULATE_3D_OFFSET(plane_stride + 1);
          ACCUMULATE_3D_OFFSET(plane_stride + row_stride - 1);
          ACCUMULATE_3D_OFFSET(plane_stride + row_stride);
          ACCUMULATE_3D_OFFSET(plane_stride + row_stride + 1);
          svst1_f64(predicate, destination + center + x, value);
        }
      }
    }
    swap_buffers(source, destination);
  }
}

// Step 1 must exclude ordinary test and main functions from kernel-only IR.
int stencil_test_driver() {
  return 0;
}

int main() {
  return stencil_test_driver();
}

#undef ACCUMULATE_3D_OFFSET
