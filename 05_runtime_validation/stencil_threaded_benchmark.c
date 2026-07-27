#include <errno.h>
#include <inttypes.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef void (*stencil_3d_fn)(size_t, size_t, size_t, const float *restrict,
                              float *restrict, float, float);

void baseline_stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                                   const float *restrict input,
                                   float *restrict output, float center_weight,
                                   float axis_weight);
void prefetch_stencil_3d7p_sme_f32(size_t depth, size_t height, size_t width,
                                   const float *restrict input,
                                   float *restrict output, float center_weight,
                                   float axis_weight);

typedef struct {
  pthread_mutex_t mutex;
  pthread_cond_t condition;
  size_t ready;
  size_t total;
  int start;
} StartGate;

typedef struct {
  stencil_3d_fn kernel;
  size_t depth;
  size_t height;
  size_t width;
  size_t repetitions;
  const float *input;
  float *output;
  StartGate *gate;
} Worker;

typedef struct {
  float *input;
  float *baseline;
  float *prefetch;
} Domain;

static void fail_pthread(int error, const char *operation) {
  if (error == 0)
    return;
  errno = error;
  perror(operation);
  exit(2);
}

static double now_seconds(void) {
  struct timespec ts;
  if (clock_gettime(CLOCK_MONOTONIC_RAW, &ts) != 0) {
    perror("clock_gettime");
    exit(2);
  }
  return (double)ts.tv_sec + (double)ts.tv_nsec * 1.0e-9;
}

static int compare_double(const void *lhs, const void *rhs) {
  double a = *(const double *)lhs;
  double b = *(const double *)rhs;
  return (a > b) - (a < b);
}

static size_t parse_size(const char *text, const char *name) {
  char *end = NULL;
  errno = 0;
  uintmax_t value = strtoumax(text, &end, 10);
  if (errno != 0 || end == text || *end != '\0' || value > SIZE_MAX) {
    fprintf(stderr, "invalid %s: %s\n", name, text);
    exit(2);
  }
  return (size_t)value;
}

static void gate_init(StartGate *gate, size_t total) {
  fail_pthread(pthread_mutex_init(&gate->mutex, NULL), "pthread_mutex_init");
  fail_pthread(pthread_cond_init(&gate->condition, NULL), "pthread_cond_init");
  gate->ready = 0;
  gate->total = total;
  gate->start = 0;
}

static void gate_destroy(StartGate *gate) {
  fail_pthread(pthread_cond_destroy(&gate->condition), "pthread_cond_destroy");
  fail_pthread(pthread_mutex_destroy(&gate->mutex), "pthread_mutex_destroy");
}

static void gate_wait_worker(StartGate *gate) {
  fail_pthread(pthread_mutex_lock(&gate->mutex), "pthread_mutex_lock");
  gate->ready++;
  fail_pthread(pthread_cond_broadcast(&gate->condition),
               "pthread_cond_broadcast");
  while (!gate->start)
    fail_pthread(pthread_cond_wait(&gate->condition, &gate->mutex),
                 "pthread_cond_wait");
  fail_pthread(pthread_mutex_unlock(&gate->mutex), "pthread_mutex_unlock");
}

static void gate_wait_ready(StartGate *gate) {
  fail_pthread(pthread_mutex_lock(&gate->mutex), "pthread_mutex_lock");
  while (gate->ready != gate->total)
    fail_pthread(pthread_cond_wait(&gate->condition, &gate->mutex),
                 "pthread_cond_wait");
}

static void gate_release(StartGate *gate) {
  gate->start = 1;
  fail_pthread(pthread_cond_broadcast(&gate->condition),
               "pthread_cond_broadcast");
  fail_pthread(pthread_mutex_unlock(&gate->mutex), "pthread_mutex_unlock");
}

static void *worker_main(void *opaque) {
  Worker *worker = opaque;
  gate_wait_worker(worker->gate);
  for (size_t i = 0; i < worker->repetitions; ++i) {
    worker->kernel(worker->depth, worker->height, worker->width, worker->input,
                   worker->output, 0.5f, 0.125f);
  }
  return NULL;
}

static double run_workers(stencil_3d_fn kernel, Domain *domains,
                          size_t thread_count, size_t depth, size_t height,
                          size_t width, size_t repetitions, int use_prefetch) {
  pthread_t *threads = calloc(thread_count, sizeof(*threads));
  Worker *workers = calloc(thread_count, sizeof(*workers));
  if (!threads || !workers) {
    fprintf(stderr, "worker allocation failed\n");
    exit(2);
  }

  StartGate gate;
  gate_init(&gate, thread_count);
  for (size_t i = 0; i < thread_count; ++i) {
    workers[i] = (Worker){
        .kernel = kernel,
        .depth = depth,
        .height = height,
        .width = width,
        .repetitions = repetitions,
        .input = domains[i].input,
        .output = use_prefetch ? domains[i].prefetch : domains[i].baseline,
        .gate = &gate,
    };
    fail_pthread(pthread_create(&threads[i], NULL, worker_main, &workers[i]),
                 "pthread_create");
  }

  gate_wait_ready(&gate);
  double start = now_seconds();
  gate_release(&gate);
  for (size_t i = 0; i < thread_count; ++i)
    fail_pthread(pthread_join(threads[i], NULL), "pthread_join");
  double elapsed = now_seconds() - start;

  gate_destroy(&gate);
  free(workers);
  free(threads);
  return elapsed;
}

static void initialize_domain(Domain *domain, size_t count, size_t domain_id) {
  domain->input = malloc(count * sizeof(*domain->input));
  domain->baseline = calloc(count, sizeof(*domain->baseline));
  domain->prefetch = calloc(count, sizeof(*domain->prefetch));
  if (!domain->input || !domain->baseline || !domain->prefetch) {
    fprintf(stderr, "domain allocation failed\n");
    exit(2);
  }
  for (size_t i = 0; i < count; ++i) {
    size_t value = (i + domain_id * 7) % 31;
    domain->input[i] = (float)((int)value - 15) * 0.03125f;
  }
}

static double checksum(const Domain *domains, size_t thread_count,
                       size_t count, int use_prefetch) {
  double sum = 0.0;
  size_t stride = count / 1024 + 1;
  for (size_t domain = 0; domain < thread_count; ++domain) {
    const float *output =
        use_prefetch ? domains[domain].prefetch : domains[domain].baseline;
    for (size_t i = 0; i < count; i += stride)
      sum += output[i];
  }
  return sum;
}

int main(int argc, char **argv) {
  if (argc != 7) {
    fprintf(stderr,
            "usage: %s THREADS DEPTH HEIGHT WIDTH REPETITIONS SAMPLES\n",
            argv[0]);
    return 2;
  }

  size_t thread_count = parse_size(argv[1], "threads");
  size_t depth = parse_size(argv[2], "depth");
  size_t height = parse_size(argv[3], "height");
  size_t width = parse_size(argv[4], "width");
  size_t repetitions = parse_size(argv[5], "repetitions");
  size_t samples = parse_size(argv[6], "samples");
  if (thread_count == 0 || depth < 3 || height < 3 || width < 3 ||
      repetitions == 0 || samples == 0) {
    return 2;
  }

  size_t count = depth * height * width;
  Domain *domains = calloc(thread_count, sizeof(*domains));
  double *baseline_times = malloc(samples * sizeof(*baseline_times));
  double *prefetch_times = malloc(samples * sizeof(*prefetch_times));
  double *speedups = malloc(samples * sizeof(*speedups));
  if (!domains || !baseline_times || !prefetch_times || !speedups)
    return 2;
  for (size_t i = 0; i < thread_count; ++i)
    initialize_domain(&domains[i], count, i);

  run_workers(baseline_stencil_3d7p_sme_f32, domains, thread_count, depth,
              height, width, 1, 0);
  run_workers(prefetch_stencil_3d7p_sme_f32, domains, thread_count, depth,
              height, width, 1, 1);

  for (size_t sample = 0; sample < samples; ++sample) {
    if ((sample & 1) == 0) {
      baseline_times[sample] = run_workers(
          baseline_stencil_3d7p_sme_f32, domains, thread_count, depth, height,
          width, repetitions, 0);
      prefetch_times[sample] = run_workers(
          prefetch_stencil_3d7p_sme_f32, domains, thread_count, depth, height,
          width, repetitions, 1);
    } else {
      prefetch_times[sample] = run_workers(
          prefetch_stencil_3d7p_sme_f32, domains, thread_count, depth, height,
          width, repetitions, 1);
      baseline_times[sample] = run_workers(
          baseline_stencil_3d7p_sme_f32, domains, thread_count, depth, height,
          width, repetitions, 0);
    }
    speedups[sample] = baseline_times[sample] / prefetch_times[sample];
  }

  double baseline_checksum = checksum(domains, thread_count, count, 0);
  double prefetch_checksum = checksum(domains, thread_count, count, 1);
  qsort(baseline_times, samples, sizeof(*baseline_times), compare_double);
  qsort(prefetch_times, samples, sizeof(*prefetch_times), compare_double);
  qsort(speedups, samples, sizeof(*speedups), compare_double);
  double updates = (double)thread_count * (double)(depth - 2) *
                   (double)(height - 2) * (double)(width - 2) *
                   (double)repetitions;
  printf("kernel=3d threads=%zu depth=%zu height=%zu width=%zu samples=%zu "
         "baseline_gups=%.6f prefetch_gups=%.6f paired_speedup=%.6f "
         "baseline_checksum=%.9f prefetch_checksum=%.9f\n",
         thread_count, depth, height, width, samples,
         updates / baseline_times[samples / 2] / 1.0e9,
         updates / prefetch_times[samples / 2] / 1.0e9,
         speedups[samples / 2], baseline_checksum, prefetch_checksum);

  for (size_t i = 0; i < thread_count; ++i) {
    free(domains[i].input);
    free(domains[i].baseline);
    free(domains[i].prefetch);
  }
  free(domains);
  free(baseline_times);
  free(prefetch_times);
  free(speedups);
  return baseline_checksum == prefetch_checksum ? 0 : 1;
}
