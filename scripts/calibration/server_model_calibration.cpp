#include <arm_sme.h>
#include <arm_sve.h>
#include <linux/perf_event.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <unistd.h>

#include <algorithm>
#include <cerrno>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <numeric>
#include <random>
#include <utility>
#include <vector>

namespace {

class CycleCounter {
public:
  CycleCounter() {
    perf_event_attr Attr{};
    Attr.type = PERF_TYPE_HARDWARE;
    Attr.size = sizeof(Attr);
    Attr.config = PERF_COUNT_HW_CPU_CYCLES;
    Attr.disabled = 1;
    Attr.exclude_kernel = 1;
    Attr.exclude_hv = 1;
    Fd = static_cast<int>(
        syscall(__NR_perf_event_open, &Attr, 0, -1, -1, 0));
    if (Fd < 0) {
      std::fprintf(stderr,
                   "perf_event_open(cycles) failed: %s; grant PMU access\n",
                   std::strerror(errno));
      std::exit(2);
    }
  }

  ~CycleCounter() { close(Fd); }

  void start() {
    ioctl(Fd, PERF_EVENT_IOC_RESET, 0);
    ioctl(Fd, PERF_EVENT_IOC_ENABLE, 0);
  }

  uint64_t stop() {
    ioctl(Fd, PERF_EVENT_IOC_DISABLE, 0);
    uint64_t Cycles = 0;
    if (read(Fd, &Cycles, sizeof(Cycles)) != sizeof(Cycles)) {
      std::fprintf(stderr, "failed to read CPU cycle counter\n");
      std::exit(2);
    }
    return Cycles;
  }

private:
  int Fd = -1;
};

double median(std::vector<double> Values) {
  std::sort(Values.begin(), Values.end());
  const size_t Middle = Values.size() / 2;
  if (Values.size() % 2 != 0)
    return Values[Middle];
  return (Values[Middle - 1] + Values[Middle]) / 2.0;
}

double measureDependentLoads(size_t Bytes, uint64_t Accesses,
                             unsigned Samples) {
  const size_t Count = std::max<size_t>(Bytes / sizeof(size_t), 1024);
  std::vector<size_t> Next(Count);
  std::vector<size_t> Order(Count);
  std::iota(Order.begin(), Order.end(), 0);
  std::mt19937_64 Random(0x534d4531ULL + Count);
  std::shuffle(Order.begin(), Order.end(), Random);
  for (size_t I = 0; I < Count; ++I)
    Next[Order[I]] = Order[(I + 1) % Count];

  size_t Index = 0;
  for (size_t I = 0; I < Count * 2; ++I)
    Index = Next[Index];

  std::vector<double> Results;
  Results.reserve(Samples);
  CycleCounter Counter;
  for (unsigned Sample = 0; Sample < Samples; ++Sample) {
    Counter.start();
    for (uint64_t I = 0; I < Accesses; ++I)
      Index = Next[Index];
    const uint64_t Cycles = Counter.stop();
    asm volatile("" : "+r"(Index) : : "memory");
    Results.push_back(static_cast<double>(Cycles) / Accesses);
  }
  return median(std::move(Results));
}

std::pair<unsigned, std::vector<double>>
measureStreamingPrefetchBudget(size_t Bytes, size_t CacheLineBytes,
                               uint64_t Accesses, unsigned Samples,
                               unsigned MaximumStreams) {
  const size_t ElementsPerLine =
      std::max<size_t>(1, CacheLineBytes / sizeof(uint64_t));
  const size_t TotalLines =
      std::max<size_t>(Bytes / CacheLineBytes, MaximumStreams * 64);
  std::vector<uint64_t> Data(TotalLines * ElementsPerLine, 1);

  constexpr size_t PrefetchDistance = 8;
  std::vector<double> CyclesPerLine(MaximumStreams + 1, 0.0);
  uint64_t Checksum = 0;
  for (unsigned Streams = 1; Streams <= MaximumStreams; ++Streams) {
    const size_t LinesPerStream = TotalLines / Streams;
    std::vector<size_t> Order(LinesPerStream);
    std::iota(Order.begin(), Order.end(), 0);
    std::mt19937_64 Random(0x5052464dULL + TotalLines + Streams);
    std::shuffle(Order.begin(), Order.end(), Random);
    const uint64_t Iterations =
        std::max<uint64_t>(1, Accesses / Streams);
    std::vector<double> Results;
    Results.reserve(Samples);
    CycleCounter Counter;
    for (unsigned Sample = 0; Sample < Samples; ++Sample) {
      Counter.start();
      for (uint64_t I = 0; I < Iterations; ++I) {
        const size_t Current = Order[I % LinesPerStream];
        const size_t Future =
            Order[(I + PrefetchDistance) % LinesPerStream];
        for (unsigned Stream = 0; Stream < Streams; ++Stream) {
          const size_t StreamBase = Stream * LinesPerStream * ElementsPerLine;
          __builtin_prefetch(Data.data() + StreamBase +
                                 Future * ElementsPerLine,
                             0, 0);
          Checksum += Data[StreamBase + Current * ElementsPerLine];
        }
      }
      const uint64_t Cycles = Counter.stop();
      Results.push_back(static_cast<double>(Cycles) /
                        (Iterations * Streams));
    }
    CyclesPerLine[Streams] = median(std::move(Results));
  }
  asm volatile("" : "+r"(Checksum) : : "memory");

  const double Best = *std::min_element(CyclesPerLine.begin() + 1,
                                        CyclesPerLine.end());
  constexpr double NearPeakTolerance = 1.05;
  unsigned SustainableStreams = MaximumStreams;
  for (unsigned Streams = 1; Streams <= MaximumStreams; ++Streams) {
    if (CyclesPerLine[Streams] <= Best * NearPeakTolerance) {
      SustainableStreams = Streams;
      break;
    }
  }
  return {SustainableStreams, std::move(CyclesPerLine)};
}

__arm_locally_streaming __attribute__((noinline)) uint64_t
run2D(double *Input, double *Output, size_t Height, size_t Width,
      unsigned Repeats) {
  const size_t Step = svcntd();
  uint64_t Iterations = 0;
  for (unsigned Repeat = 0; Repeat < Repeats; ++Repeat) {
    for (size_t Y = 1; Y + 1 < Height; ++Y) {
      const size_t Row = Y * Width;
      for (size_t X = 1; X + 1 < Width; X += Step) {
        const svbool_t Pg = svwhilelt_b64_u64(X, Width - 1);
        svfloat64_t Value = svld1_f64(Pg, Input + Row + X);
        Value = svadd_f64_x(Pg, Value, svld1_f64(Pg, Input + Row + X - 1));
        Value = svadd_f64_x(Pg, Value, svld1_f64(Pg, Input + Row + X + 1));
        Value = svadd_f64_x(Pg, Value,
                            svld1_f64(Pg, Input + Row - Width + X));
        Value = svadd_f64_x(Pg, Value,
                            svld1_f64(Pg, Input + Row + Width + X));
        svst1_f64(Pg, Output + Row + X, Value);
        ++Iterations;
      }
    }
    double *Temporary = Input;
    Input = Output;
    Output = Temporary;
  }
  return Iterations;
}

__arm_locally_streaming __attribute__((noinline)) uint64_t
run3D(double *Input, double *Output, size_t Depth, size_t Height,
      size_t Width, unsigned Repeats) {
  const size_t Step = svcntd();
  const size_t Plane = Height * Width;
  uint64_t Iterations = 0;
  for (unsigned Repeat = 0; Repeat < Repeats; ++Repeat) {
    for (size_t Z = 1; Z + 1 < Depth; ++Z) {
      for (size_t Y = 1; Y + 1 < Height; ++Y) {
        const size_t Row = Z * Plane + Y * Width;
        for (size_t X = 1; X + 1 < Width; X += Step) {
          const svbool_t Pg = svwhilelt_b64_u64(X, Width - 1);
          svfloat64_t Value = svld1_f64(Pg, Input + Row + X);
          Value = svadd_f64_x(Pg, Value,
                              svld1_f64(Pg, Input + Row + X - 1));
          Value = svadd_f64_x(Pg, Value,
                              svld1_f64(Pg, Input + Row + X + 1));
          Value = svadd_f64_x(Pg, Value,
                              svld1_f64(Pg, Input + Row - Width + X));
          Value = svadd_f64_x(Pg, Value,
                              svld1_f64(Pg, Input + Row + Width + X));
          Value = svadd_f64_x(Pg, Value,
                              svld1_f64(Pg, Input + Row - Plane + X));
          Value = svadd_f64_x(Pg, Value,
                              svld1_f64(Pg, Input + Row + Plane + X));
          svst1_f64(Pg, Output + Row + X, Value);
          ++Iterations;
        }
      }
    }
    double *Temporary = Input;
    Input = Output;
    Output = Temporary;
  }
  return Iterations;
}

template <typename Function>
double measureStencil(Function &&Run, unsigned Samples) {
  std::vector<double> Results;
  Results.reserve(Samples);
  CycleCounter Counter;
  for (unsigned Sample = 0; Sample < Samples; ++Sample) {
    const uint64_t WarmupIterations = Run(10);
    if (WarmupIterations == 0) {
      std::fprintf(stderr, "stencil calibration produced zero iterations\n");
      std::exit(2);
    }
    Counter.start();
    const uint64_t Iterations = Run(10000);
    const uint64_t Cycles = Counter.stop();
    Results.push_back(static_cast<double>(Cycles) / Iterations);
  }
  return median(std::move(Results));
}

uint64_t parseUnsigned(const char *Raw, const char *Name) {
  char *End = nullptr;
  errno = 0;
  const unsigned long long Value = std::strtoull(Raw, &End, 10);
  if (errno != 0 || !End || *End != '\0' || Value == 0) {
    std::fprintf(stderr, "invalid %s: %s\n", Name, Raw);
    std::exit(1);
  }
  return Value;
}

} // namespace

int main(int Argc, char **Argv) {
  if (Argc != 9) {
    std::fprintf(stderr,
                 "usage: %s L1_BYTES L2_BYTES MEMORY_BYTES ACCESSES "
                 "SAMPLES STREAMING_VL_BYTES CACHE_LINE_BYTES "
                 "STREAM_ACCESSES\n",
                 Argv[0]);
    return 1;
  }
  const size_t L1Bytes = parseUnsigned(Argv[1], "L1_BYTES");
  const size_t L2Bytes = parseUnsigned(Argv[2], "L2_BYTES");
  const size_t MemoryBytes = parseUnsigned(Argv[3], "MEMORY_BYTES");
  const uint64_t Accesses = parseUnsigned(Argv[4], "ACCESSES");
  const unsigned Samples = parseUnsigned(Argv[5], "SAMPLES");
  const size_t StreamingVLBytes =
      parseUnsigned(Argv[6], "STREAMING_VL_BYTES");
  const size_t CacheLineBytes = parseUnsigned(Argv[7], "CACHE_LINE_BYTES");
  const uint64_t StreamAccesses =
      parseUnsigned(Argv[8], "STREAM_ACCESSES");

  const size_t VectorElements = std::max<size_t>(1, StreamingVLBytes / 8);
  const size_t Height2D = 6;
  const size_t Width2D = VectorElements * 4 + 2;
  std::vector<double> Input2D(Height2D * Width2D, 1.0);
  std::vector<double> Output2D(Height2D * Width2D, 0.0);

  const size_t Depth3D = 5;
  const size_t Height3D = 5;
  const size_t Width3D = VectorElements * 2 + 2;
  std::vector<double> Input3D(Depth3D * Height3D * Width3D, 1.0);
  std::vector<double> Output3D(Depth3D * Height3D * Width3D, 0.0);

  const double L1Cycles = measureDependentLoads(L1Bytes, Accesses, Samples);
  const double L2Cycles = measureDependentLoads(L2Bytes, Accesses, Samples);
  const double MemoryCycles =
      measureDependentLoads(MemoryBytes, Accesses, Samples);
  constexpr unsigned MaximumMeasuredStreams = 17;
  auto [SustainableStreams, StreamCycles] = measureStreamingPrefetchBudget(
      MemoryBytes, CacheLineBytes, StreamAccesses, Samples,
      MaximumMeasuredStreams);
  const double Cycles2D = measureStencil(
      [&](unsigned Repeats) {
        return run2D(Input2D.data(), Output2D.data(), Height2D, Width2D,
                     Repeats);
      },
      Samples);
  const double Cycles3D = measureStencil(
      [&](unsigned Repeats) {
        return run3D(Input3D.data(), Output3D.data(), Depth3D, Height3D,
                     Width3D, Repeats);
      },
      Samples);

  std::printf("l1_dependent_load_cycles=%.6f\n", L1Cycles);
  std::printf("l2_dependent_load_cycles=%.6f\n", L2Cycles);
  std::printf("memory_dependent_load_cycles=%.6f\n", MemoryCycles);
  std::printf("useful_cycles_2d=%.6f\n", Cycles2D);
  std::printf("useful_cycles_3d=%.6f\n", Cycles3D);
  std::printf("sustainable_prefetch_streams=%u\n", SustainableStreams);
  for (unsigned Streams = 1; Streams <= MaximumMeasuredStreams; ++Streams)
    std::printf("stream_cycles_per_line_%u=%.6f\n", Streams,
                StreamCycles[Streams]);
  std::printf("checksum=%.6f\n", Output2D[Width2D + 1] +
                                     Output3D[Height3D * Width3D + Width3D + 1]);
  return 0;
}
