// Copyright ©2019 The Gonum Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build !noasm,!appengine,!safe

#include "textflag.h"

#define X_ SI
#define LEN DX
#define IDX AX
#define TAIL BX

#define ALPHA X0
#define CONJ_ALPHA X1
#define ALPHA1 X10
#define CONJ_ALPHA1 X11

#define REAL_0 X3
#define IMAG_0 X2
#define REAL_1 X5
#define IMAG_1 X4
#define REAL_2 X7
#define IMAG_2 X6
#define REAL_3 X9
#define IMAG_3 X8

// func ScalUnitary(alpha complex64, x []complex64)
TEXT ·ScalUnitary(SB), NOSPLIT, $0
	MOVQ x_base+8(FP), X_  // X_ = &x
	MOVQ x_len+16(FP), LEN // LEN = len(x)
	CMPQ LEN, $0
	JE   scal_end          // if LEN == 0 { return }

	CVTPS2PD alpha+0(FP), ALPHA           // ALPHA  = { imag(a), real(a) }
	MOVAPS   ALPHA, CONJ_ALPHA
	SHUFPD   $0x1, CONJ_ALPHA, CONJ_ALPHA // CONJ_ALPHA = { real(a), imag(a) }
	XORQ     IDX, IDX                     // IDX = 0
	MOVQ     LEN, TAIL                    // TAIL = LEN
	SHRQ     $2, LEN                      // LEN = floor( LEN / 4 )
	JZ       scal_tail2                   // if LEN == 0 { goto scal_tail2 }

	MOVAPS ALPHA, ALPHA1           // Copy ALPHA and CONJ_ALPHA for pipelineing
	MOVAPS CONJ_ALPHA, CONJ_ALPHA1

scal_loop: // x[i] *= a unrolled 4x
	// Convert complex64 to complex128 to increase calculation precision
	CVTPS2PD (X_)(IDX*8), IMAG_0   // IMAG = { imag(x[i]), real(x[i]) }
	CVTPS2PD 8(X_)(IDX*8), IMAG_1
	CVTPS2PD 16(X_)(IDX*8), IMAG_2
	CVTPS2PD 24(X_)(IDX*8), IMAG_3

	MOVDDUP IMAG_0, REAL_0 // REAL = { real(x[i]), real(x[i]) }
	MOVDDUP IMAG_1, REAL_1
	MOVDDUP IMAG_2, REAL_2
	MOVDDUP IMAG_3, REAL_3

	SHUFPD $0x3, IMAG_0, IMAG_0 // IMAG = { imag(x[i]), imag(x[i]) }
	SHUFPD $0x3, IMAG_1, IMAG_1
	SHUFPD $0x3, IMAG_2, IMAG_2
	SHUFPD $0x3, IMAG_3, IMAG_3

	MULPD ALPHA, REAL_0       // REAL = {  imag(a) * real(x[i]),   real(a) * real(x[i]) }
	MULPD ALPHA1, REAL_1
	MULPD ALPHA, REAL_2
	MULPD ALPHA1, REAL_3
	MULPD CONJ_ALPHA, IMAG_0  // IMAG = {  real(a) * imag(x[i]),   imag(a) * imag(x[i]) }
	MULPD CONJ_ALPHA1, IMAG_1
	MULPD CONJ_ALPHA, IMAG_2
	MULPD CONJ_ALPHA1, IMAG_3

	// REAL = {
	//  imag(result[i]):   imag(a)*real(x[i]) + real(a)*imag(x[i]),
	//  real(result[i]):   real(a)*real(x[i]) - imag(a)*imag(x[i]),
	//  }
	ADDSUBPD IMAG_0, REAL_0
	ADDSUBPD IMAG_1, REAL_1
	ADDSUBPD IMAG_2, REAL_2
	ADDSUBPD IMAG_3, REAL_3

	CVTPD2PS REAL_0, REAL_0        // Convert complex128 back to complex64 (with rounding)
	CVTPD2PS REAL_1, REAL_1
	CVTPD2PS REAL_2, REAL_2
	CVTPD2PS REAL_3, REAL_3
	MOVSD    REAL_0, (X_)(IDX*8)   // x[i] = REAL
	MOVSD    REAL_1, 8(X_)(IDX*8)
	MOVSD    REAL_2, 16(X_)(IDX*8)
	MOVSD    REAL_3, 24(X_)(IDX*8)

	ADDQ $4, IDX   // IDX += 4
	DECQ LEN       // LEN--
	JNZ  scal_loop // if LEN > 0 { continue scal_loop }

scal_tail2:
	TESTQ $2, TAIL
	JZ    scal_tail1

	// Convert complex64 to complex128 to increase calculation precision
	CVTPS2PD (X_)(IDX*8), IMAG_0  // IMAG = { imag(x[i]), real(x[i]) }
	CVTPS2PD 8(X_)(IDX*8), IMAG_1

	MOVDDUP IMAG_0, REAL_0 // REAL = { real(x[i]), real(x[i]) }
	MOVDDUP IMAG_1, REAL_1

	SHUFPD $0x3, IMAG_0, IMAG_0 // IMAG = { imag(x[i]), imag(x[i]) }
	SHUFPD $0x3, IMAG_1, IMAG_1

	MULPD ALPHA, REAL_0      // REAL = {  imag(a) * real(x[i]),   real(a) * real(x[i]) }
	MULPD ALPHA, REAL_1
	MULPD CONJ_ALPHA, IMAG_0 // IMAG = {  real(a) * imag(x[i]),   imag(a) * imag(x[i]) }
	MULPD CONJ_ALPHA, IMAG_1

	// REAL = {
	//  imag(result[i]):   imag(a)*real(x[i]) + real(a)*imag(x[i]),
	//  real(result[i]):   real(a)*real(x[i]) - imag(a)*imag(x[i]),
	//  }
	ADDSUBPD IMAG_0, REAL_0
	ADDSUBPD IMAG_1, REAL_1

	CVTPD2PS REAL_0, REAL_0       // Convert complex128 to complex64 (with rounding)
	CVTPD2PS REAL_1, REAL_1
	MOVSD    REAL_0, (X_)(IDX*8)  // x[i] = REAL
	MOVSD    REAL_1, 8(X_)(IDX*8)
	ADDQ     $2, IDX              // IDX += 2

scal_tail1:
	TESTQ $1, TAIL
	JZ    scal_end

	CVTPS2PD (X_)(IDX*8), IMAG_0  // IMAG_0 = { imag(x[i]), real(x[i]) }
	MOVDDUP  IMAG_0, REAL_0       // REAL_0 = { real(x[i]), real(x[i]) }
	SHUFPD   $0x3, IMAG_0, IMAG_0 // IMAG_0 = { imag(x[i]), imag(x[i]) }
	MULPD    CONJ_ALPHA, IMAG_0   // IMAG_0 = { real(a) * imag(x[i]), imag(a) * imag(x[i]) }
	MULPD    ALPHA, REAL_0        // REAL_0 = { imag(a) * real(x[i]), real(a) * real(x[i]) }

	// REAL_0 = { imag(a)*real(x[i]) + real(a)*imag(x[i]),
	//            real(a)*real(x[i]) - imag(a)*imag(x[i])  }
	ADDSUBPD IMAG_0, REAL_0
	CVTPD2PS REAL_0, REAL_0
	MOVSD    REAL_0, (X_)(IDX*8) // x[i]  = REAL_0

scal_end:
	RET
