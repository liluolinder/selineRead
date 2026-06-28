package jinguissl_core.crypto.perf

import std.time.MonoTime
import jinguissl_core.crypto.error.{CryptoException, CryptoErrorCode}

@When[os == "Linux"]
foreign func sched_setaffinity(
    pid: Int32,
    cpusetSize: UIntNative,
    cpuset: CPointer<UInt8>
): Int32

public class BenchConfig {
    public let name: String
    public let warmupRounds: Int64
    public let samples: Int64

    public init(name: String, warmupRounds!: Int64 = 2, samples!: Int64 = 5) {
        let normalizedName = name.trimAscii()
        if (normalizedName.size == 0) {
            throw CryptoException(InvalidArgument, "benchmark name must not be empty")
        }
        if (warmupRounds < 0) {
            throw CryptoException(InvalidArgument, "benchmark warmup rounds must be non-negative")
        }
        if (samples <= 0) {
            throw CryptoException(InvalidArgument, "benchmark samples must be positive")
        }
        this.name = normalizedName
        this.warmupRounds = warmupRounds
        this.samples = samples
    }
}

public class BenchCpuBinding {
    public let requested: Bool
    public let coreId: Int64
    public let supported: Bool
    public let applied: Bool
    public let detail: String

    public init(requested: Bool, coreId: Int64, supported: Bool, applied: Bool, detail: String) {
        this.requested = requested
        this.coreId = coreId
        this.supported = supported
        this.applied = applied
        this.detail = detail
    }
}

public class BenchSummary {
    public let name: String
    public let warmupRounds: Int64
    public let samples: Int64
    public let elapsedMedianNs: Int64
    public let throughputMinMiBS: Float64
    public let throughputMedianMiBS: Float64
    public let throughputMaxMiBS: Float64
    public let throughputMeanMiBS: Float64
    public let throughputTrimmedMeanMiBS: Float64
    public let throughputSpreadRatio: Float64

    public init(
        name: String,
        warmupRounds: Int64,
        samples: Int64,
        elapsedMedianNs: Int64,
        throughputMinMiBS: Float64,
        throughputMedianMiBS: Float64,
        throughputMaxMiBS: Float64,
        throughputMeanMiBS: Float64,
        throughputTrimmedMeanMiBS: Float64,
        throughputSpreadRatio: Float64
    ) {
        this.name = name
        this.warmupRounds = warmupRounds
        this.samples = samples
        this.elapsedMedianNs = elapsedMedianNs
        this.throughputMinMiBS = throughputMinMiBS
        this.throughputMedianMiBS = throughputMedianMiBS
        this.throughputMaxMiBS = throughputMaxMiBS
        this.throughputMeanMiBS = throughputMeanMiBS
        this.throughputTrimmedMeanMiBS = throughputTrimmedMeanMiBS
        this.throughputSpreadRatio = throughputSpreadRatio
    }
}

public class BenchStabilityConfig {
    public let maxSpreadRatio: Float64
    public let maxRetries: Int64
    public let sampleStep: Int64

    public init(
        maxSpreadRatio!: Float64 = 1.25,
        maxRetries!: Int64 = 2,
        sampleStep!: Int64 = 2
    ) {
        if (maxSpreadRatio <= 0.0) {
            throw CryptoException(InvalidArgument, "benchmark max spread ratio must be positive")
        }
        if (maxRetries < 0) {
            throw CryptoException(InvalidArgument, "benchmark max retries must be non-negative")
        }
        if (sampleStep <= 0) {
            throw CryptoException(InvalidArgument, "benchmark sample step must be positive")
        }
        this.maxSpreadRatio = maxSpreadRatio
        this.maxRetries = maxRetries
        this.sampleStep = sampleStep
    }
}

public class BenchStableSummary {
    public let summary: BenchSummary
    public let attempts: Int64
    public let stable: Bool
    public let maxSpreadRatio: Float64

    public init(summary: BenchSummary, attempts: Int64, stable: Bool, maxSpreadRatio: Float64) {
        this.summary = summary
        this.attempts = attempts
        this.stable = stable
        this.maxSpreadRatio = maxSpreadRatio
    }
}

public func benchTryPinCurrentThread(coreId: Int64): BenchCpuBinding {
    if (coreId < 0) {
        return BenchCpuBinding(false, coreId, false, false, "cpu pinning is not requested")
    }
    if (coreId >= 64) {
        return BenchCpuBinding(
            true,
            coreId,
            false,
            false,
            "cpu pinning currently supports core ids in [0, 63]"
        )
    }
    benchTryPinCurrentThreadImpl(coreId)
}

@When[os == "Linux"]
private func benchTryPinCurrentThreadImpl(coreId: Int64): BenchCpuBinding {
    unsafe {
        let mask = LibC.malloc<UInt8>(count: 8)
        if (mask.isNull()) {
            return BenchCpuBinding(true, coreId, true, false, "cpu affinity setup failed due to allocation error")
        }
        try {
            var i = 0
            while (i < 8) {
                mask.write(i, UInt8(0))
                i += 1
            }
            let byteIndex = coreId / 8
            let bitIndex = coreId % 8
            let bit = UInt8(UInt8(1) << UInt8(bitIndex))
            mask.write(byteIndex, bit)
            let rc = sched_setaffinity(Int32(0), UIntNative(8), mask)
            if (rc == 0) {
                return BenchCpuBinding(true, coreId, true, true, "cpu affinity pinned successfully")
            }
            BenchCpuBinding(true, coreId, true, false, "cpu affinity pin call failed with errno-style return ${rc}")
        } finally {
            LibC.free(mask)
        }
    }
}

@When[os != "Linux"]
private func benchTryPinCurrentThreadImpl(coreId: Int64): BenchCpuBinding {
    BenchCpuBinding(
        true,
        coreId,
        false,
        false,
        "cpu affinity pinning is not supported on this platform in current benchmark helper"
    )
}

public func benchRun(config: BenchConfig, task: () -> Int64): BenchSummary {
    var warmup = 0
    while (warmup < config.warmupRounds) {
        _ = task()
        warmup += 1
    }

    let elapsedNs = Array<Int64>(config.samples, repeat: 0)
    let throughputMiBS = Array<Float64>(config.samples, repeat: 0.0)

    var sample = 0
    while (sample < config.samples) {
        let start = MonoTime.now()
        let processedBytes = task()
        let elapsed = (MonoTime.now() - start).toNanoseconds()
        elapsedNs[sample] = elapsed
        throughputMiBS[sample] = computeMiBS(processedBytes, elapsed)
        sample += 1
    }

    let elapsedSorted = sortInt64(elapsedNs)
    let throughputSorted = sortFloat64(throughputMiBS)
    BenchSummary(
        config.name,
        config.warmupRounds,
        config.samples,
        medianInt64(elapsedSorted),
        throughputSorted[0],
        medianFloat64(throughputSorted),
        throughputSorted[throughputSorted.size - 1],
        averageFloat64(throughputMiBS),
        trimmedMeanFloat64(throughputSorted),
        throughputSpreadRatio(throughputSorted[0], throughputSorted[throughputSorted.size - 1])
    )
}

public func benchFormatSummary(summary: BenchSummary): String {
    "name=${summary.name} warmup=${summary.warmupRounds} samples=${summary.samples} " +
    "elapsed_ns_median=${summary.elapsedMedianNs} " +
    "throughput_mib_s_min=${summary.throughputMinMiBS} " +
    "throughput_mib_s_median=${summary.throughputMedianMiBS} " +
    "throughput_mib_s_max=${summary.throughputMaxMiBS} " +
    "throughput_mib_s_mean=${summary.throughputMeanMiBS} " +
    "throughput_mib_s_trimmed_mean=${summary.throughputTrimmedMeanMiBS} " +
    "throughput_spread_ratio=${summary.throughputSpreadRatio}"
}

public func benchRunStable(
    config: BenchConfig,
    stability: BenchStabilityConfig,
    task: () -> Int64
): BenchStableSummary {
    var best = benchRun(config, task)
    var attempts: Int64 = 1
    var retries: Int64 = 0
    var nextSamples = config.samples

    while (best.throughputSpreadRatio > stability.maxSpreadRatio && retries < stability.maxRetries) {
        retries += 1
        attempts += 1
        nextSamples += stability.sampleStep
        let retry = benchRun(
            BenchConfig(config.name, warmupRounds: config.warmupRounds, samples: nextSamples),
            task
        )
        if (retry.throughputSpreadRatio < best.throughputSpreadRatio) {
            best = retry
        } else if (
            retry.throughputSpreadRatio == best.throughputSpreadRatio &&
            retry.throughputTrimmedMeanMiBS > best.throughputTrimmedMeanMiBS
        ) {
            best = retry
        }
    }

    BenchStableSummary(
        best,
        attempts,
        best.throughputSpreadRatio <= stability.maxSpreadRatio,
        stability.maxSpreadRatio
    )
}

public func benchFormatStableSummary(stable: BenchStableSummary): String {
    benchFormatSummary(stable.summary) +
    " stable=${stable.stable} attempts=${stable.attempts} max_spread_ratio=${stable.maxSpreadRatio}"
}

private func computeMiBS(bytes: Int64, elapsedNanos: Int64): Float64 {
    if (elapsedNanos <= 0) {
        return 0.0
    }
    let mib = Float64(bytes) / 1048576.0
    let seconds = Float64(elapsedNanos) / 1000000000.0
    mib / seconds
}

private func averageFloat64(values: Array<Float64>): Float64 {
    if (values.size == 0) {
        return 0.0
    }
    var total = 0.0
    for (value in values) {
        total += value
    }
    total / Float64(values.size)
}

private func trimmedMeanFloat64(sortedValues: Array<Float64>): Float64 {
    if (sortedValues.size <= 2) {
        return averageFloat64(sortedValues)
    }
    var total = 0.0
    var i = 1
    while (i < (sortedValues.size - 1)) {
        total += sortedValues[i]
        i += 1
    }
    total / Float64(sortedValues.size - 2)
}

private func throughputSpreadRatio(minValue: Float64, maxValue: Float64): Float64 {
    if (minValue <= 0.0) {
        return 0.0
    }
    maxValue / minValue
}

private func medianInt64(values: Array<Int64>): Int64 {
    if (values.size == 0) {
        return 0
    }
    let mid = values.size / 2
    if ((values.size % 2) == 1) {
        return values[mid]
    }
    (values[mid - 1] + values[mid]) / 2
}

private func medianFloat64(values: Array<Float64>): Float64 {
    if (values.size == 0) {
        return 0.0
    }
    let mid = values.size / 2
    if ((values.size % 2) == 1) {
        return values[mid]
    }
    (values[mid - 1] + values[mid]) / 2.0
}

private func sortInt64(values: Array<Int64>): Array<Int64> {
    let out = values.clone()
    var i = 1
    while (i < out.size) {
        let value = out[i]
        var j = i - 1
        while (j >= 0 && out[j] > value) {
            out[j + 1] = out[j]
            j -= 1
        }
        out[j + 1] = value
        i += 1
    }
    out
}

private func sortFloat64(values: Array<Float64>): Array<Float64> {
    let out = values.clone()
    var i = 1
    while (i < out.size) {
        let value = out[i]
        var j = i - 1
        while (j >= 0 && out[j] > value) {
            out[j + 1] = out[j]
            j -= 1
        }
        out[j + 1] = value
        i += 1
    }
    out
}
