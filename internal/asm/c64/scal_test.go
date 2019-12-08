// Copyright ©2016 The Gonum Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package c64

import (
	"fmt"
	"math/rand"
	"testing"
)

var scalTests = []struct {
	alpha complex64
	x     []complex64
	want  []complex64
}{
	{
		alpha: 0,
		x:     []complex64{},
		want:  []complex64{},
	},
	{
		alpha: 1 + 1i,
		x:     []complex64{1},
		want:  []complex64{1 + 1i},
	},
	{
		alpha: -1i,
		x:     []complex64{1},
		want:  []complex64{-1i},
	},
	{
		alpha: 2,
		x:     []complex64{1, -2},
		want:  []complex64{2, -4},
	},
	{
		alpha: 2,
		x:     []complex64{1, -2, 3},
		want:  []complex64{2, -4, 6},
	},
	{
		alpha: 2,
		x:     []complex64{1, -2, 3, 4},
		want:  []complex64{2, -4, 6, 8},
	},
	{
		alpha: 2,
		x:     []complex64{1, -2, 3, 4, -5},
		want:  []complex64{2, -4, 6, 8, -10},
	},
	{
		alpha: 2,
		x:     []complex64{0, 1, -2, 3, 4, -5, 6, -7},
		want:  []complex64{0, 2, -4, 6, 8, -10, 12, -14},
	},
	{
		alpha: 2,
		x:     []complex64{0, 1, -2, 3, 4, -5, 6, -7, 8},
		want:  []complex64{0, 2, -4, 6, 8, -10, 12, -14, 16},
	},
	{
		alpha: 2,
		x:     []complex64{0, 1, -2, 3, 4, -5, 6, -7, 8, 9},
		want:  []complex64{0, 2, -4, 6, 8, -10, 12, -14, 16, 18},
	},
	{
		alpha: 3 - 4i,
		x:     []complex64{0, 1, -2, 3, 4, -5, 6, -7, 8, 9, 12},
		want:  []complex64{0 + 0i, 3 - 4i, -6 + 8i, 9 - 12i, 12 - 16i, -15 + 20i, 18 - 24i, -21 + 28i, 24 - 32i, 27 - 36i, 36 - 48i},
	},
	{
		alpha: 3 - 4i,
		x:     []complex64{0, 1, -2, 3, 4, -5, 6, -7, 8, 9},
		want:  []complex64{0 + 0i, 3 - 4i, -6 + 8i, 9 - 12i, 12 - 16i, -15 + 20i, 18 - 24i, -21 + 28i, 24 - 32i, 27 - 36i},
	},
}

func TestScalUnitary(t *testing.T) {
	const xGdVal = -0.5
	for i, test := range scalTests {
		for _, align := range align1 {
			prefix := fmt.Sprintf("Test %v (x:%v)", i, align)
			xgLn := 4 + align
			xg := guardVector(test.x, xGdVal, xgLn)
			x := xg[xgLn : len(xg)-xgLn]

			ScalUnitary(test.alpha, x)

			for i := range test.want {
				if !same(x[i], test.want[i]) {
					t.Errorf(msgVal, prefix, i, x[i], test.want[i])
				}
			}
			if !isValidGuard(xg, xGdVal, xgLn) {
				t.Errorf(msgGuard, prefix, "x", xg[:xgLn], xg[len(xg)-xgLn:])
			}
			if t.Failed() {
				t.Error(x)
			}
		}
	}
}

func TestRandScalUnitary(t *testing.T) {
	naive := func(alpha complex64, x []complex64) {
		for i := range x {
			x[i] *= alpha
		}
	}
	for i := 0; i < 300; i++ {
		ln := rand.Intn(5000) + 1
		t.Run(fmt.Sprintf("%d-%d", i, ln), func(t *testing.T) {
			diff := 0
			x := randSlice(ln)
			y := make([]complex64, ln)
			copy(y, x)
			a := complex(rand.Float32(), rand.Float32())
			ScalUnitary(a, x)
			naive(a, y)
			for i := range x {
				if !same(x[i], y[i]) {
					diff++
				}
			}
			if diff != 0 {
				t.Errorf("diff %v", float64(diff)/float64(ln))
			}
		})
	}
}

func BenchmarkScalUnitary(t *testing.B) {
	a := complex(rand.Float32(), rand.Float32())
	naive := func(alpha complex64, x []complex64) {
		for i := range x {
			x[i] *= alpha
		}
	}
	for _, v := range []int{1, 3, 10, 30, 100, 300, 1e4, 3e4, 1e5, 3e5} {
		t.Run(fmt.Sprintf("%d", v), func(t *testing.B) {
			for i := 0; i < t.N; i++ {
				ScalUnitary(a, x[:v])
			}
		})
		t.Run(fmt.Sprintf("n%d", v), func(t *testing.B) {
			for i := 0; i < t.N; i++ {
				naive(a, x[:v])
			}
		})
	}
}
