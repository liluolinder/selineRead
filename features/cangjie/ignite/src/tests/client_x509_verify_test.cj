package ignite.tests

import std.collection.ArrayList
import ignite.client.*
import ignite.security

@Test
public class ClientX509VerifyTestSuite {
    @TestCase
    public func testClientX509VerifyRejectsHttpBeforeNetwork(): Unit {
        let marks = ArrayList<String>()
        let client = RestClient(
            readTimeout: Duration.second * 5,
            writeTimeout: Duration.second * 5,
            poolSize: 2
        )
            .useX509Verify(security.X509VerifyOption(enabled: true, requireHttps: true))
            .onError({ _ =>
                marks.add("error")
            })

        try {
            let _ = client.request()
                .method("GET")
                .url("http://127.0.0.1:1/blocked")
                .send()
            @Fail("x509 verify should block non-https request")
        } catch (e: security.SecurityException) {
            @Assert(e.code, security.SecurityErrorCode.VerifyFailed)
        }

        @Assert(marks.size, 1)
        @Assert(marks[0], "error")
    }
}
