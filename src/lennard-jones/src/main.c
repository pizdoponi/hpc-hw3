#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <omp.h>

#include "lennard-jones.h"

static const char *device_to_string(Device device) {
    return device == GPU ? "gpu" : "cpu";
}

static void print_help(const char *exe) {
    printf("Usage: %s [N] [nsteps] [device]\n", exe);
    printf("       %s [options]\n", exe);
    printf("\nOptions:\n");
    printf("  -n, --particles <N>         Number of particles (default: 100)\n");
    printf("  -s, --steps <N>             Number of simulation steps (default: 100)\n");
    printf("  -d, --device <cpu|gpu>      Execution device (default: cpu)\n");
    printf("  -b, --block-size <N>        GPU thread block size (default: %u)\n", DEFAULT_GPU_BLOCK_SIZE);
    printf("      --density <rho>         Reduced density (default: 0.95)\n");
    printf("      --temperature <T>       Reduced temperature (default: 0.5)\n");
    printf("      --seed <N>              Random seed (default: 42)\n");
    printf("  -l, --log-energies          Print energy values at every step\n");
    printf("      --save-final-state <f>  Save final particle state to CSV\n");
    printf("  -h, --help                  Show this help\n");
    printf("\nPositional arguments are kept for backward compatibility:\n");
    printf("  %s 1000 5000 gpu\n", exe);
}

static int parse_unsigned_arg(const char *text, const char *name, unsigned int *value) {
    char *end = NULL;
    unsigned long parsed = 0;

    errno = 0;
    parsed = strtoul(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0' || parsed > UINT_MAX) {
        fprintf(stderr, "Invalid %s: %s\n", name, text);
        return 0;
    }

    *value = (unsigned int)parsed;
    return 1;
}

static int parse_double_arg(const char *text, const char *name, double *value) {
    char *end = NULL;
    double parsed = 0.0;

    errno = 0;
    parsed = strtod(text, &end);
    if (errno != 0 || end == text || *end != '\0') {
        fprintf(stderr, "Invalid %s: %s\n", name, text);
        return 0;
    }

    *value = parsed;
    return 1;
}

static int parse_device_arg(const char *text, Device *device) {
    if (strcmp(text, "gpu") == 0) {
        *device = GPU;
        return 1;
    }
    if (strcmp(text, "cpu") == 0) {
        *device = CPU;
        return 1;
    }

    fprintf(stderr, "Invalid device: %s (expected 'cpu' or 'gpu')\n", text);
    return 0;
}

static int save_particles_csv(
    const char *path,
    const Particle *particles,
    unsigned int n,
    unsigned int nsteps,
    double box_size,
    double density,
    double temperature,
    unsigned int seed,
    unsigned int block_size,
    Device device
) {
    FILE *fp = fopen(path, "w");
    if (!fp) {
        fprintf(stderr, "Failed to open final-state output file: %s\n", path);
        return 0;
    }

    fprintf(fp, "# particles=%u\n", n);
    fprintf(fp, "# steps=%u\n", nsteps);
    fprintf(fp, "# device=%s\n", device_to_string(device));
    fprintf(fp, "# density=%.12f\n", density);
    fprintf(fp, "# temperature=%.12f\n", temperature);
    fprintf(fp, "# seed=%u\n", seed);
    fprintf(fp, "# gpu_block_size=%u\n", block_size);
    fprintf(fp, "# box_size=%.12f\n", box_size);
    fprintf(fp, "index,x,y,vx,vy,fx,fy\n");

    for (unsigned int i = 0; i < n; ++i) {
        fprintf(
            fp,
            "%u,%.15f,%.15f,%.15f,%.15f,%.15f,%.15f\n",
            i,
            particles[i].x,
            particles[i].y,
            particles[i].vx,
            particles[i].vy,
            particles[i].fx,
            particles[i].fy
        );
    }

    fclose(fp);
    return 1;
}

int main(int argc, char **argv) {
    unsigned int nsteps = 100;
    unsigned int n = 100;
    double density = 0.95;
    double temperature = 0.5;
    unsigned int seed = 42;
    unsigned int block_size = DEFAULT_GPU_BLOCK_SIZE;
    int log_steps = 0;
    Device device = CPU;
    const char *final_state_path = NULL;

    Particle *particles = NULL;
    SimulationResult result;
    unsigned int positional_index = 0;

    for (int i = 1; i < argc; ++i) {
        const char *arg = argv[i];

        if (strcmp(arg, "-h") == 0 || strcmp(arg, "--help") == 0) {
            print_help(argv[0]);
            return 0;
        } else if (strcmp(arg, "-n") == 0 || strcmp(arg, "--particles") == 0) {
            if (++i >= argc || !parse_unsigned_arg(argv[i], "particle count", &n)) {
                return 1;
            }
        } else if (strcmp(arg, "-s") == 0 || strcmp(arg, "--steps") == 0) {
            if (++i >= argc || !parse_unsigned_arg(argv[i], "step count", &nsteps)) {
                return 1;
            }
        } else if (strcmp(arg, "-d") == 0 || strcmp(arg, "--device") == 0) {
            if (++i >= argc || !parse_device_arg(argv[i], &device)) {
                return 1;
            }
        } else if (strcmp(arg, "-b") == 0 || strcmp(arg, "--block-size") == 0) {
            if (++i >= argc || !parse_unsigned_arg(argv[i], "GPU block size", &block_size)) {
                return 1;
            }
        } else if (strcmp(arg, "--density") == 0) {
            if (++i >= argc || !parse_double_arg(argv[i], "density", &density)) {
                return 1;
            }
        } else if (strcmp(arg, "--temperature") == 0) {
            if (++i >= argc || !parse_double_arg(argv[i], "temperature", &temperature)) {
                return 1;
            }
        } else if (strcmp(arg, "--seed") == 0) {
            if (++i >= argc || !parse_unsigned_arg(argv[i], "seed", &seed)) {
                return 1;
            }
        } else if (strcmp(arg, "-l") == 0 || strcmp(arg, "--log-energies") == 0) {
            log_steps = 1;
        } else if (strcmp(arg, "--save-final-state") == 0) {
            if (++i >= argc) {
                fprintf(stderr, "Missing value for --save-final-state\n");
                return 1;
            }
            final_state_path = argv[i];
        } else if (arg[0] == '-') {
            fprintf(stderr, "Unknown option: %s\n", arg);
            print_help(argv[0]);
            return 1;
        } else {
            if (positional_index == 0) {
                if (!parse_unsigned_arg(arg, "particle count", &n)) {
                    return 1;
                }
            } else if (positional_index == 1) {
                if (!parse_unsigned_arg(arg, "step count", &nsteps)) {
                    return 1;
                }
            } else if (positional_index == 2) {
                if (!parse_device_arg(arg, &device)) {
                    return 1;
                }
            } else {
                fprintf(stderr, "Too many positional arguments.\n");
                print_help(argv[0]);
                return 1;
            }
            positional_index++;
        }
    }

    if (n == 0) {
        fprintf(stderr, "Particle count must be greater than zero.\n");
        return 1;
    }
    if (density <= 0.0) {
        fprintf(stderr, "Density must be greater than zero.\n");
        return 1;
    }
    if (temperature <= 0.0) {
        fprintf(stderr, "Temperature must be greater than zero.\n");
        return 1;
    }
    if (block_size == 0 || block_size > MAX_GPU_BLOCK_SIZE) {
        fprintf(
            stderr,
            "GPU block size must be in the range [1, %u].\n",
            MAX_GPU_BLOCK_SIZE
        );
        return 1;
    }

    set_gpu_block_size(block_size);

    double particle_box_size = ceil(sqrt((double)n / density));
    double box_size = (4.0 / 3.0) * particle_box_size;
    double box_fraction = particle_box_size / box_size;

    printf(
        "CONFIG particles=%u steps=%u device=%s density=%.6f temperature=%.6f seed=%u log_energies=%d gpu_block_size=%u box_size=%.6f\n",
        n,
        nsteps,
        device_to_string(device),
        density,
        temperature,
        seed,
        log_steps,
        block_size,
        box_size
    );

    if (!(particles = calloc(n, sizeof(Particle)))) {
        fprintf(stderr, "Failed to allocate simulation arrays.\n");
        return 1;
    }

    if (!initialize_particles(
            particles,
            n,
            box_size,
            box_fraction,
            seed,
            temperature
        )) {
        fprintf(stderr, "Failed to initialize particles.\n");
        free(particles);
        return 1;
    }

    double start = omp_get_wtime();
    result = run_simulation_device(particles, n, nsteps, box_size, log_steps, device);
    double stop = omp_get_wtime();
    double elapsed = stop - start;
    double delta_total = result.final_total - result.start_total;

    if (final_state_path != NULL) {
        if (!save_particles_csv(
                final_state_path,
                particles,
                n,
                nsteps,
                box_size,
                density,
                temperature,
                seed,
                block_size,
                device
            )) {
            free(particles);
            return 1;
        }
        printf("Saved final particle state to %s\n", final_state_path);
    }

    printf("\nFinished simulation.\n");
    printf("Final KE: %10.4f | delta: %+.4f\n", result.final_kinetic, result.final_kinetic - result.start_kinetic);
    printf("Final PE: %10.4f | delta: %+.4f\n", result.final_potential, result.final_potential - result.start_potential);
    printf("Final E:  %10.4f | delta: %+.4f\n", result.final_total, delta_total);
    printf("Simulation time %u steps: %.6f seconds\n", nsteps, elapsed);
    printf(
        "RESULT device=%s particles=%u steps=%u density=%.6f temperature=%.6f seed=%u log_energies=%d gpu_block_size=%u box_size=%.6f time_seconds=%.6f start_ke=%.10f start_pe=%.10f start_total=%.10f final_ke=%.10f final_pe=%.10f final_total=%.10f delta_total=%.10f final_state=%s\n",
        device_to_string(device),
        n,
        nsteps,
        density,
        temperature,
        seed,
        log_steps,
        block_size,
        box_size,
        elapsed,
        result.start_kinetic,
        result.start_potential,
        result.start_total,
        result.final_kinetic,
        result.final_potential,
        result.final_total,
        delta_total,
        final_state_path != NULL ? final_state_path : "-"
    );

    free(particles);
    return 0;
}
