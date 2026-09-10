package SelineRead

import std.fs.File
import std.fs.Path
import std.io.readToEnd

// JPEG 解码：stb_image（FFI 绑定 thirdparty/jpeg/stb_image.o，STBI_NO_STDIO）。
// 流程：读文件字节 → stbi_load_from_memory 解成 RGBA → 写成临时 BMP
// （chui 的 ImageView 原生支持）→ ImageView 按路径显示。

// stb_image C 接口
foreign func stbi_load_from_memory(
    buffer: CPointer<UInt8>,
    len: Int32,
    outX: CPointer<Int32>,
    outY: CPointer<Int32>,
    outChannels: CPointer<Int32>,
    desiredChannels: Int32
): CPointer<UInt8>

foreign func stbi_image_free(data: CPointer<UInt8>): Unit

//解码 JPEG/PNG/WebP 等文件为 (宽, 高, RGBA 字节)。失败返回 None。
func decodeImageFile(path: String): Option<(Int32, Int32, Array<UInt8>)> {
    let bytes = try {
        File.readFrom(Path(path))
    } catch (_: Exception) {
        return None
    }
    let count = bytes.size
    if (count == 0) {
        return None
    }
    var w: Int32 = 0
    var h: Int32 = 0
    var ch: Int32 = 0
    unsafe {
        let handle = acquireArrayRawData(bytes)
        try {
            // 出参用 inout 传递（对应 C 的 Int32*）
            let decoded = stbi_load_from_memory(
                handle.pointer, Int32(count), inout w, inout h, inout ch, 4)
            if (decoded.isNull()) {
                releaseArrayRawData(handle)
                return None
            }
            // 拷出像素后立即释放 stb 堆内存
            let total = Int64(w) * Int64(h) * Int64(4)
            let pixels = Array<UInt8>(total, repeat: 0)
            var i: Int64 = 0
            while (i < total) {
                pixels[i] = decoded.read(i)
                i += 1
            }
            stbi_image_free(decoded)
            releaseArrayRawData(handle)
            return Some((w, h, pixels))
        } catch (e: Exception) {
            releaseArrayRawData(handle)
            throw e
        }
    }
}
