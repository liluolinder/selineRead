package ignite.tests

import std.collection.ArrayList
import std.time.MonoTime
import ignite.client.*

@Test
public class ClientFaultBaselineTestSuite {
    @TestCase
    public func testFaultInjectionCoversHookAndNetworkPaths(): Unit {
        let errors = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 1,
            writeTimeout: Duration.second * 1,
            poolSize: 4
        )
            .useRetry(
                ClientRetryConfig(
                    enabled: true,
                    maxAttempts: 2,
                    idempotentOnly: true,
                    baseDelayMs: 1,
                    maxDelayMs: 2,
                    jitterMs: 0
                )
            )
            .onError({ e =>
                errors.add(e.message)
            })

        let totalRequests: Int64 = 12
        var failures: Int64 = 0
        var i: Int64 = 0
        while (i < totalRequests) {
            let builder = client.request()
                .method("GET")
                .url("http://127.0.0.1:1/fault-matrix-${i}")
                .header("x-ignite-log-case", "fault-injection")

            if ((i % 3) == 0) {
                builder.onRequest({ _ =>
                    throw Exception("injected-request-fault")
                })
            }

            try {
                let _ = builder.send()
            } catch (_: Exception) {
                failures += 1
            }
            i += 1
        }

        @Assert(failures, totalRequests)
        @Assert(errors.size, totalRequests)
    }

    @TestCase
    public func testConcurrentFailureBaselineWithSpawnWorkers(): Unit {
        let workerCount: Int64 = 6
        let requestsPerWorker: Int64 = 20
        let start = MonoTime.now()

        let futures = ArrayList<Future<Int64>>()
        for (worker in 0..workerCount) {
            futures.add(spawn {
                runFaultWorker(worker, requestsPerWorker)
            })
        }

        var totalFailures: Int64 = 0
        for (f in futures) {
            totalFailures += f.get()
        }

        let elapsedMs = (MonoTime.now() - start).toMilliseconds()
        @Assert(totalFailures, workerCount * requestsPerWorker)
        @Assert(elapsedMs < 10000, true)
    }
}

func runFaultWorker(workerId: Int64, loops: Int64): Int64 {
    let client = RestClient(
        readTimeout: Duration.second * 1,
        writeTimeout: Duration.second * 1,
        poolSize: 2
    )
        .useRetry(
            ClientRetryConfig(
                enabled: false
            )
        )

    var failures: Int64 = 0
    var i: Int64 = 0
    while (i < loops) {
        let builder = client.request()
            .method("GET")
            .url("http://127.0.0.1:1/fault-worker-${workerId}-${i}")
            .header("x-ignite-log-worker", "${workerId}")

        if ((i % 10) == 0) {
            builder.onRequest({ _ =>
                throw Exception("injected-worker-fault")
            })
        }

        try {
            let _ = builder.send()
        } catch (_: Exception) {
            failures += 1
        }

        i += 1
    }
    failures
}
