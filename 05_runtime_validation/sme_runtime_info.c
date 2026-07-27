#include <arm_sme.h>
#include <arm_sve.h>
#include <stddef.h>
#include <stdio.h>

__arm_locally_streaming static size_t streaming_vl_bytes(void) {
  return svcntb();
}

int main(void) {
  printf("streaming_vl_bytes=%zu\n", streaming_vl_bytes());
  return 0;
}
