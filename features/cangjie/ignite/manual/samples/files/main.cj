import ignite.*
import std.collection.ArrayList
import std.fs.{exists, File, OpenMode}
import std.io.InputStream

let FILE_SAMPLE_GUIDE = "manual/samples/files/assets/guide.txt"
let FILE_SAMPLE_UPLOAD = "/tmp/ignite_sample_files_upload.txt"

main() {
    let app = App(config: Config(appName: "ignite-sample-files"))

    app.get("/", { ctx =>
        _ = ctx.json(
            "{\"routes\":[\"/view\",\"/download\",\"/range\",\"/stream-known\",\"/stream-unknown\",\"/uploaded\",\"POST /push-upload\"],\"asset\":\"guide.txt\"}"
        )
    })

    app.get("/view", { ctx =>
        _ = ctx.sendFile(FILE_SAMPLE_GUIDE)
    })

    app.get("/download", { ctx =>
        _ = ctx.download(FILE_SAMPLE_GUIDE, filename: "ignite-guide.txt")
    })

    app.get("/range", { ctx =>
        _ = ctx.sendFileRange(FILE_SAMPLE_GUIDE)
    })

    app.get("/stream-known", { ctx =>
        let body = readTextFile(FILE_SAMPLE_GUIDE)
        let stream = FileSampleBytesInput(toFileSampleByteArray(body.toArray()))
        _ = ctx.sendStream(
            stream,
            contentType: "text/plain; charset=utf-8",
            contentLength: Some(body.size)
        )
    })

    app.get("/stream-unknown", { ctx =>
        let body = readTextFile(FILE_SAMPLE_GUIDE)
        let stream = FileSampleBytesInput(toFileSampleByteArray(body.toArray()))
        _ = ctx.sendStream(stream, contentType: "text/plain; charset=utf-8")
    })

    app.post("/push-upload", { ctx =>
        let saved = ctx.saveBodyToFile(FILE_SAMPLE_UPLOAD)
        _ = ctx.status(201).json(
            "{\"saved\":\"${saved}\",\"path\":\"${FILE_SAMPLE_UPLOAD}\"}"
        )
    })

    app.get("/uploaded", { ctx =>
        if (exists(FILE_SAMPLE_UPLOAD)) {
            _ = ctx.sendFile(FILE_SAMPLE_UPLOAD)
            return
        }
        _ = ctx.status(404).json("{\"error\":\"no uploaded fixture yet\"}")
    })

    println("[sample/files] listening on http://127.0.0.1:18812")
    println("[sample/files] try: curl -i http://127.0.0.1:18812/view")
    println("[sample/files] try: curl -i http://127.0.0.1:18812/download")
    println("[sample/files] try: curl -i -H 'Range: bytes=0-63' http://127.0.0.1:18812/range")
    println("[sample/files] try: curl -i http://127.0.0.1:18812/stream-known")
    println("[sample/files] try: curl -i http://127.0.0.1:18812/stream-unknown")
    println("[sample/files] try: printf 'ignite-upload-demo' | curl -i -X POST --data-binary @- http://127.0.0.1:18812/push-upload")
    println("[sample/files] try: curl -i http://127.0.0.1:18812/uploaded")
    app.listen("127.0.0.1", 18812)
}

class FileSampleBytesInput <: InputStream {
    let bytes: Array<Byte>
    var cursor: Int64 = 0

    init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    public override func read(outBuf: Array<Byte>): Int64 {
        if (cursor >= bytes.size || outBuf.size == 0) {
            return 0
        }
        let remaining = bytes.size - cursor
        let readLen = if (remaining < outBuf.size) { remaining } else { outBuf.size }
        for (i in 0..readLen) {
            outBuf[i] = bytes[cursor + i]
        }
        cursor += readLen
        readLen
    }

    public func close(): Unit {}
}

func toFileSampleByteArray(input: Array<UInt8>): Array<Byte> {
    let out = Array<Byte>(input.size, repeat: 0)
    var i = 0
    while (i < input.size) {
        out[i] = input[i]
        i += 1
    }
    out
}

func readTextFile(path: String): String {
    let file = File(path, OpenMode.Read)
    let out = ArrayList<UInt8>()
    let tmp = Array<UInt8>(4096, repeat: 0)
    while (true) {
        let n = file.read(tmp)
        if (n <= 0) {
            break
        }
        for (i in 0..n) {
            out.add(tmp[i])
        }
    }
    file.close()
    String.fromUtf8(out.toArray())
}
