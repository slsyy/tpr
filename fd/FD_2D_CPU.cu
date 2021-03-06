
/*** Calculating a derivative with CD ***/
#include <cmath>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sys/time.h>

#include <cstring>
#define __FILENAME__                                                           \
  (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)
void checkErrors(char *label) {
  // we need to synchronise first to catch errors due to
  // asynchroneous operations that would otherwise
  // potentially go unnoticed
  cudaError_t err;
  err = cudaThreadSynchronize();
  if (err != cudaSuccess) {
    char *e = (char *)cudaGetErrorString(err);
    fprintf(stderr, "CUDA Error: %s (at %s)\n", e, label);
	std::exit(1);
  }
  err = cudaGetLastError();
  if (err != cudaSuccess) {
    char *e = (char *)cudaGetErrorString(err);
    fprintf(stderr, "CUDA Error: %s (at %s)\n", e, label);
	std::exit(1);
  }
}

double get_time() {
  struct timeval tim;
  cudaThreadSynchronize();
  gettimeofday(&tim, NULL);
  return (double)tim.tv_sec + (tim.tv_usec / 1000000.0);
}

void copy_array(float *u, float *u_prev, int N) {
  for (int i = 0; i < N * N; ++i)
    u_prev[i] = u[i];
}

// GPU kernel
void update(float *u, float *u_prev, int N, float h, float dt, float alpha) {

  for (int i = 0; i < N * N; ++i) {
    if ((i > N) && (i < N * N - 1 - N) && (i % N != 0) && (i % N != N - 1)) {
      u[i] = u_prev[i] + alpha * dt / (h * h) *
                             (u_prev[i + 1] + u_prev[i - 1] + u_prev[i + N] +
                              u_prev[i - N] - 4 * u_prev[i]);
    }
  }
}

int main(int argc, char **argv) {
  // Allocate in CPU
  int N = std::atoi(argv[1]);
  if (N > 1024) {
    return 1;
  }

  cudaSetDevice(0);

  float xmin = 0.0f;
  float xmax = 3.5f;
  float ymin = 0.0f;
  // float ymax 	= 2.0f;
  float h = (xmax - xmin) / (N - 1);
  float dt = 0.00001f;
  float alpha = 0.645f;
  float time = 0.4f;

  int steps = ceil(time / dt);
  int I;

  float *x = new float[N * N];
  float *y = new float[N * N];
  float *u = new float[N * N];
  float *u_prev = new float[N * N];

  // Generate mesh and intial condition
  for (int j = 0; j < N; j++) {
    for (int i = 0; i < N; i++) {
      I = N * j + i;
      x[I] = xmin + h * i;
      y[I] = ymin + h * j;
      u[I] = 0.0f;
      if ((i == 0) || (j == 0)) {
        u[I] = 200.0f;
      }
    }
  }

  // Allocate in GPU

  // Loop
  dim3 dimGrid(int((N - 0.5) / BLOCKSIZE) + 1, int((N - 0.5) / BLOCKSIZE) + 1);
  dim3 dimBlock(BLOCKSIZE, BLOCKSIZE);
  double start = get_time();
  for (int t = 0; t < steps; t++) {
    copy_array(u, u_prev, N);
    update(u, u_prev, N, h, dt, alpha);
  }
  double stop = get_time();
  checkErrors("update");

  double elapsed = stop - start;
  std::cout << elapsed << std::endl;

  std::ofstream temperature("temperature_global.txt");
  for (int j = 0; j < N; j++) {
    for (int i = 0; i < N; i++) {
      I = N * j + i;
      //	std::cout<<u[I]<<"\t";
      temperature << x[I] << "\t" << y[I] << "\t" << u[I] << std::endl;
    }
    temperature << "\n";
    // std::cout<<std::endl;
  }

  temperature.close();
}
