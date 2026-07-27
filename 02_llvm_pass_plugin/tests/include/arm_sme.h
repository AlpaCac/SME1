#ifndef SME1_LLVM18_ARM_SME_COMPAT_H
#define SME1_LLVM18_ARM_SME_COMPAT_H

/*
 * LLVM 18 ships the SME ACLE header under its draft name. Keep the kernel on
 * the final <arm_sme.h> include while using the matching LLVM 18 builtins.
 */
#include <arm_sme_draft_spec_subject_to_change.h>

#endif
