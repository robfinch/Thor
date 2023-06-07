// cordic.cpp : This file contains the 'main' function. Program execution begins and ends there.
//

#include <iostream>
#include <corecrt_math_defines.h>
#include <math.h>
#include "Float128.h"

double	cordic_gain(int nstages, int phase_bits) {
  double	gain = 1.0;

  for (int k = 0; k < nstages; k++) {
    double		dgain;

    dgain = 1.0 + pow(2.0, -2. * (k));
    dgain = sqrt(dgain);
    gain = gain * dgain;
  }

  return gain;
}

char* long_double_to_buf(double x)
{
  static char buf[20];

  memset(buf, 0, sizeof(buf));
  memcpy(buf, &x, 8);
  return (buf);
}


int main()
{
  __int64 k;
  __int64 nstages = 56;
  unsigned __int64 phase_bits = 64;
  unsigned __int64 phase_value;
  double x, deg, inv_gain, ovpi;
  Float128 x128, deg128;
  char* buf;
  __int64* p1;
  __int64 *p2;

  std::cout << "Hello World!\n";
  for (k = 0; k < nstages+2; k = k + 1) {
    x = atan2(1., pow(2, k));
    deg = x * 180.0 / M_PI;
    x *= (4.0 * (1uLL << (phase_bits - 2))) / (M_PI * 2.0);
    phase_value = (unsigned __int64)x;
    fprintf(stdout, "\tassign cordic_angle[%I64d] = %2I64d\'h%0*I64x; // %11.24f deg\n",
      k, phase_bits, (int)((phase_bits + 3) / 4), phase_value, deg);
  }
  fprintf(stdout, "gain: %11.24f\n", cordic_gain(nstages, phase_bits));
  inv_gain = pow(2.l, nstages) / cordic_gain(nstages, phase_bits);
  fprintf(stdout, "2^%I64d/gain: %11.24lf\n", nstages, inv_gain);// , cordic_gain(nstages, phase_bits));
  buf = long_double_to_buf(inv_gain);
  p1 = (__int64*)buf;
  p2 = (__int64*)&buf[8];
  fprintf(stdout, "%016I64x%016I64x\n", p2[0], p1[0]);
  fprintf(stdout, "%lA\n", inv_gain);
  ovpi = (pow(2.l, 61) / (2.l * M_PI));
  buf = long_double_to_buf(ovpi);
  fprintf(stdout, "%016I64x%016I64x\n", p2[0], p1[0]);
  fprintf(stdout, "Reciprocal Square Root Constants\n");
  fprintf(stdout, "fconst[8]=%016I64x\n", 0x5fe33d209e450c1bLL);
  fprintf(stdout, "fconst[9]=%016I64x\n", 0.824218612684476826);
  fprintf(stdout, "fconst[10]=%016I64x\n", 2.14994745900706619);
  fprintf(stdout, "fconst[12]=%016I64x // r2\n", 0x5fdb3d20982e5432LL);
  fprintf(stdout, "fconst[13]=%016I64x // k21\n", 2.331242396766632);
  fprintf(stdout, "fconst[14]=%016I64x\n", 1.074973693828754);
  fprintf(stdout, "Reciprocal Square Root Constants\n");
  fprintf(stdout, "fconst[16]=%016I64x; // r2\n", 0x5fe33d165ce48760LL);
  fprintf(stdout, "fconst[17]=%016I64x; // k21\n", 0.82421918338542632);
  fprintf(stdout, "fconst[18]=%016I64x; // k22\n", 2.1499482562039667);
  fprintf(stdout, "fconst[20]=%016I64x; // r1\n", 0x5fdb3d20dba7bd3cLL);
  fprintf(stdout, "fconst[21]=%016I64x; // k11\n", 2.3312471012384104);
  fprintf(stdout, "fconst[22]=%016I64x; // k12\n", 1.074974060752685);

  for (k = 0x20; k < 0x3f; k++) {
    fprintf(stdout, "csqrt[%I64d]=64'h%016I64x;\n", k-0x20, (long)sqrt(k));
  }
  for (k = 0; k < 257; k++) {
    x = 1.0 + 1.0 * ((double)k / 257.0);
    buf = long_double_to_buf(1.0 / x);
    p1 = (__int64*)buf;
    fprintf(stdout, "cres[%I64d]=20'h%0I64x;\n", k, (*p1 >> 32LL) & 0xfffffLL);
  }
}

// Run program: Ctrl + F5 or Debug > Start Without Debugging menu
// Debug program: F5 or Debug > Start Debugging menu

// Tips for Getting Started: 
//   1. Use the Solution Explorer window to add/manage files
//   2. Use the Team Explorer window to connect to source control
//   3. Use the Output window to see build output and other messages
//   4. Use the Error List window to view errors
//   5. Go to Project > Add New Item to create new code files, or Project > Add Existing Item to add existing code files to the project
//   6. In the future, to open this project again, go to File > Open > Project and select the .sln file
