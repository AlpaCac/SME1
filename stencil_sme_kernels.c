#include <arm_sme.h>
#include <arm_sve.h>

#include <stddef.h>
#include <stdint.h>

/*
 * The input and output arrays must not overlap. Both kernels update interior
 * points only; callers own the boundary conditions and boundary values.
 *
 * The __arm_locally_streaming attribute makes each function enter and leave
 * SME streaming mode internally, so ordinary non-streaming callers can use
 * this API. svcntsw() obtains the streaming vector length; the remaining ACLE
 * intrinsics perform vector-length-agnostic, predicated operations.
 */

/*
 * Row-major 2D 5-point stencil:
 *
 * output[y, x] =
 *     center_weight * input[y, x]
 *   + axis_weight * (input[y, x - 1] + input[y, x + 1]
 *                  + input[y - 1, x] + input[y + 1, x])
 *
 * Arrays contain height * width float elements. Boundary elements in output
 * are left unchanged.
 */
__arm_locally_streaming void
stencil_2d5p_sme_f32(size_t height, size_t width,
                     const float *restrict input, float *restrict output,
                     float center_weight, float axis_weight) {
  if (height < 3 || width < 3) {
    return;
  }

  const size_t vector_width = (size_t)svcntsw();
  const size_t interior_end = width - 1;

  for (size_t y = 1; y + 1 < height; ++y) {
    const size_t row = y * width;

    for (size_t x = 1; x < interior_end; x += vector_width) {
      const svbool_t pg =
          svwhilelt_b32_u64((uint64_t)x, (uint64_t)interior_end);

      const svfloat32_t center = svld1_f32(pg, input + row + x);
      const svfloat32_t left = svld1_f32(pg, input + row + x - 1);
      const svfloat32_t right = svld1_f32(pg, input + row + x + 1);
      const svfloat32_t north = svld1_f32(pg, input + row - width + x);
      const svfloat32_t south = svld1_f32(pg, input + row + width + x);

      svfloat32_t neighbors = svadd_f32_x(pg, left, right);
      neighbors = svadd_f32_x(pg, neighbors, north);
      neighbors = svadd_f32_x(pg, neighbors, south);

      svfloat32_t result =
          svmul_n_f32_x(pg, neighbors, axis_weight);
      result = svmla_n_f32_x(pg, result, center, center_weight);
      svst1_f32(pg, output + row + x, result);
    }
  }
}

/*
 * Row-major 3D 7-point stencil. The x dimension is contiguous:
 *
 * output[z, y, x] =
 *     center_weight * input[z, y, x]
 *   + axis_weight * (input[z, y, x - 1] + input[z, y, x + 1]
 *                  + input[z, y - 1, x] + input[z, y + 1, x]
 *                  + input[z - 1, y, x] + input[z + 1, y, x])
 *
 * Arrays contain depth * height * width float elements. Boundary elements in
 * output are left unchanged.
 */
__arm_locally_streaming void
stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                     const float *restrict input, float *restrict output,
                     float center_weight, float axis_weight) {
  if (depth < 3 || height < 3 || width < 3) {
    return;
  }

  const size_t vector_width = (size_t)svcntsw();
  const size_t plane_stride = height * width;
  const size_t interior_end = width - 1;

  for (size_t z = 1; z + 1 < depth; ++z) {
    const size_t plane = z * plane_stride;

    for (size_t y = 1; y + 1 < height; ++y) {
      const size_t row = plane + y * width;

      for (size_t x = 1; x < interior_end; x += vector_width) {
        const svbool_t pg =
            svwhilelt_b32_u64((uint64_t)x, (uint64_t)interior_end);

        const svfloat32_t center = svld1_f32(pg, input + row + x);
        const svfloat32_t left = svld1_f32(pg, input + row + x - 1);
        const svfloat32_t right = svld1_f32(pg, input + row + x + 1);
        const svfloat32_t north =
            svld1_f32(pg, input + row - width + x);
        const svfloat32_t south =
            svld1_f32(pg, input + row + width + x);
        const svfloat32_t front =
            svld1_f32(pg, input + row - plane_stride + x);
        const svfloat32_t back =
            svld1_f32(pg, input + row + plane_stride + x);

        svfloat32_t neighbors = svadd_f32_x(pg, left, right);
        neighbors = svadd_f32_x(pg, neighbors, north);
        neighbors = svadd_f32_x(pg, neighbors, south);
        neighbors = svadd_f32_x(pg, neighbors, front);
        neighbors = svadd_f32_x(pg, neighbors, back);

        svfloat32_t result =
            svmul_n_f32_x(pg, neighbors, axis_weight);
        result = svmla_n_f32_x(pg, result, center, center_weight);
        svst1_f32(pg, output + row + x, result);
      }
    }
  }
}
