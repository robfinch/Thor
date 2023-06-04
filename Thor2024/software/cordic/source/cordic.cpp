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

int main()
{
  __int64 k;
  __int64 nstages = 54;
  unsigned __int64 phase_bits = 60;
  unsigned __int64 phase_value;
  double x, deg;
  Float128 x128, deg128;

  std::cout << "Hello World!\n";
  for (k = 0; k < nstages; k = k + 1) {
    x = atan2(1., pow(2, k));
    deg = x * 180.0 / M_PI;
    x *= (4.0 * (1uLL << (phase_bits - 2))) / (M_PI * 2.0);
    phase_value = (unsigned __int64)x;
    fprintf(stdout, "\tassign cordic_angle[%d] = %2d\'h%0*I64x; // %11.24f deg\n",
      k, phase_bits, (phase_bits + 3) / 4, phase_value, deg);
  }
  fprintf(stdout, "gain: %11.24f\n", cordic_gain(nstages, phase_bits));
  fprintf(stdout, "2^%d/gain: %11.24f\n", nstages, pow(2,nstages)/ cordic_gain(nstages, phase_bits), cordic_gain(nstages, phase_bits));
  fprintf(stdout, "%016I64x\n", (unsigned __int64)(pow(2, nstages) / cordic_gain(nstages, phase_bits)));
  fprintf(stdout, "%0I64x\n", (unsigned __int64)(pow(2., 61) / (2. * M_PI)));
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
