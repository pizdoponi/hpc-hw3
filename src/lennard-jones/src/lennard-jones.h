#ifndef LJ_H
#define LJ_H

#ifdef __cplusplus
extern "C" {
#endif

#define DT 0.002
#define SIGMA 1.0
#define EPSILON 1.0
#define R_CUT 2.5
#define JITTER 0.05

#ifndef GENERATE_GIF
#define GENERATE_GIF 0
#endif

#ifndef FRAME_WIDTH
#define FRAME_WIDTH 800
#endif

#ifndef FRAME_HEIGHT
#define FRAME_HEIGHT 800
#endif

#ifndef FRAME_EVERY
#define FRAME_EVERY 5
#endif

#ifndef FRAME_PARTICLE_RADIUS
#define FRAME_PARTICLE_RADIUS 2
#endif

#ifndef FRAME_DELAY
#define FRAME_DELAY 3
#endif

#ifndef GIF_FILE
#define GIF_FILE "simulation.gif"
#endif

#ifndef DEFAULT_GPU_BLOCK_SIZE
#define DEFAULT_GPU_BLOCK_SIZE 256
#endif

#ifndef MAX_GPU_BLOCK_SIZE
#define MAX_GPU_BLOCK_SIZE 1024
#endif

// Device type enum
typedef enum {
    CPU = 0,
    GPU = 1
} Device;

typedef struct {
    double x;
    double y;
    double vx;
    double vy;
    double fx;
    double fy;
} Particle;

typedef struct {
    unsigned int n;
    const Particle *particles;
    double start_kinetic;
    double start_potential;
    double start_total;
    double final_kinetic;
    double final_potential;
    double final_total;
} SimulationResult;

int initialize_particles(
    Particle *particles,
    unsigned int n,
    double box_size,
    double placement_fraction,
    unsigned int seed,
    double temperature
);
void wrap_positions(Particle *particles, unsigned int n, double box_size);

double compute_v_shift(void);
double compute_forces(
    Particle *particles,
    unsigned int n,
    double box_size
);
double compute_forces_gpu(
    Particle *particles,
    unsigned int n,
    double box_size
);
double leapfrog_step(
    Particle *particles,
    unsigned int n,
    double box_size
);
double leapfrog_step_gpu(
    Particle *particles,
    unsigned int n,
    double box_size
);
SimulationResult run_simulation(Particle *particles, unsigned int n, unsigned int nsteps, double box_size, int log_steps);
SimulationResult run_simulation_device(Particle *particles, unsigned int n, unsigned int nsteps, double box_size, int log_steps, Device device);
void set_gpu_block_size(unsigned int block_size);
unsigned int get_gpu_block_size(void);

#ifdef __cplusplus
}
#endif

#endif
