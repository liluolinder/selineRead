package sdl

public enum TextureBlendMode {
    | None
    | Blend
    | Add
    | Mod
    | Mul
}

public enum TextureFlip {
    | None
    | Horizontal
    | Vertical
    | Both
}

public struct TextureRenderOptions {
    public let source: ?Rect
    public let center: ?Point
    public let flip: TextureFlip

    public init(source!: ?Rect = None, center!: ?Point = None, flip!: TextureFlip = TextureFlip.None) {
        this.source = source
        this.center = center
        this.flip = flip
    }
}

public class Texture <: Resource {
    internal let ptr: CPointer<Unit>
    private let streaming: Bool
    private var closed = false

    public let width: Float32
    public let height: Float32

    internal init(ptr: CPointer<Unit>, streaming!: Bool = false) {
        this.ptr = ptr
        this.streaming = streaming
        var w: Float32 = 0.0
        var h: Float32 = 0.0
        ensureSdl(unsafe { SDL_GetTextureSize(ptr, inout w, inout h) }, "SDL_GetTextureSize")
        this.width = w
        this.height = h
    }

    public func size(): Size {
        Size(width, height)
    }

    public func setColorMod(color: Color): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_SetTextureColorMod(ptr, color.r, color.g, color.b) }, "SDL_SetTextureColorMod")
    }

    public func setAlpha(alpha: Int64): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_SetTextureAlphaMod(ptr, toChannel(alpha)) }, "SDL_SetTextureAlphaMod")
    }

    public func setBlendMode(mode: TextureBlendMode): Unit {
        ensureOpen()
        ensureSdl(unsafe { SDL_SetTextureBlendMode(ptr, blendModeCode(mode)) }, "SDL_SetTextureBlendMode")
    }

    /** Convenience boundary that does not leak enum constructors into importing packages. */
    public func setAlphaBlending(enabled: Bool): Unit {
        setBlendMode(if (enabled) { TextureBlendMode.Blend } else { TextureBlendMode.None })
    }

    /** Replaces the pixels of an RGBA32 streaming texture during the renderer-owner frame. */
    public func updateRgba(pixels: CPointer<UInt8>, pitch: Int32): Unit {
        ensureOpen()
        if (!streaming) {
            throw CuiException("Only a streaming texture can accept pixel updates.")
        }
        validateStreamingPixels(pixels, Int32(width), pitch)
        ensureSdl(unsafe { SDL_UpdateTexture(ptr, CPointer<SdlRect>(), pixels, pitch) }, "SDL_UpdateTexture")
    }

    /**
     * Copies one owned RGBA32 frame into this streaming texture. The temporary native
     * buffer exists only for the SDL call and is released on success or failure; callers
     * never lend an Array backing address across the FFI boundary.
     */
    public func updateRgba(pixels: Array<UInt8>, pitch: Int32): Unit {
        let required = validateStreamingArrayPixels(
            pixels, Int32(width), Int32(height), pitch)
        let native = unsafe { LibC.malloc<UInt8>(count: required) }
        if (native.isNull()) {
            throw CuiException("Streaming texture pixel allocation failed.")
        }
        try {
            for (i in 0..required) {
                unsafe { native.write(i, pixels[i]) }
            }
            updateRgba(native, pitch)
        } finally {
            unsafe { LibC.free(native) }
        }
    }

    public func isClosed(): Bool {
        closed
    }

    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        unsafe {
            if (ptr.isNotNull()) {
                SDL_DestroyTexture(ptr)
            }
        }
    }

    /**
     * Throws `CuiException` when a closed texture is reused.
     */
    private func ensureOpen(): Unit {
        if (closed) {
            throw CuiException("Texture is already closed.")
        }
    }
}

extend Renderer {
    /** Creates an exact-pixel RGBA32 texture for decoded or generated frame delivery. */
    public func createStreamingRgbaTexture(pixelWidth: Int32, pixelHeight: Int32): Texture {
        validateStreamingSize(pixelWidth, pixelHeight)
        if (ptr.isNull()) {
            throw CuiException("A headless renderer cannot create a streaming texture.")
        }
        let raw = unsafe {
            SDL_CreateTexture(ptr, SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING, pixelWidth, pixelHeight)
        }
        if (raw.isNull()) {
            throw CuiException("SDL_CreateTexture streaming failed: ${lastSdlError()}")
        }
        let _ = unsafe { SDL_SetTextureScaleMode(raw, SDL_SCALEMODE_LINEAR) }
        let _ = unsafe { SDL_SetTextureBlendMode(raw, SDL_BLENDMODE_NONE) }
        Texture(raw, streaming: true)
    }

    /** Creates an RGBA render-target texture at the renderer's current logical scale. */
    public func createTargetTexture(logicalWidth: Float32, logicalHeight: Float32): Texture {
        if (logicalWidth <= 0.0 || logicalHeight <= 0.0) {
            throw CuiException("Target texture dimensions must be greater than 0.")
        }
        if (ptr.isNull()) {
            throw CuiException("A headless renderer cannot create a target texture.")
        }
        let pixelWidth = Int32(max(1.0, logicalWidth * currentScaleX()) + 0.5)
        let pixelHeight = Int32(max(1.0, logicalHeight * currentScaleY()) + 0.5)
        let raw = unsafe {
            SDL_CreateTexture(ptr, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, pixelWidth, pixelHeight)
        }
        if (raw.isNull()) {
            throw CuiException("SDL_CreateTexture target failed: ${lastSdlError()}")
        }
        let _ = unsafe { SDL_SetTextureScaleMode(raw, SDL_SCALEMODE_LINEAR) }
        let _ = unsafe { SDL_SetTextureBlendMode(raw, SDL_BLENDMODE_BLEND) }
        try {
            Texture(raw)
        } catch (error: Exception) {
            // Texture construction queries the native size and may reject. Until construction
            // succeeds the raw allocation is still owned here.
            unsafe { SDL_DestroyTexture(raw) }
            throw error
        }
    }

    /** Draws one logical frame into `texture`, restoring the previous target and scale. */
    public func renderToTexture(
        texture: Texture,
        logicalWidth: Float32,
        logicalHeight: Float32,
        clearColor: Color,
        draw: () -> Unit
    ): Unit {
        renderToTextureTarget(
            texture, logicalWidth, logicalHeight, Some(clearColor), draw)
    }

    /**
     * Continues drawing into an existing target without clearing it. This low-level
     * primitive is used by transactional retained executors after they copied the
     * previously committed frame exactly once; ordinary applications should use the
     * clearing `renderToTexture` API.
     */
    public func renderToTexturePreserving(
        texture: Texture,
        logicalWidth: Float32,
        logicalHeight: Float32,
        draw: () -> Unit
    ): Unit {
        renderToTextureTarget(texture, logicalWidth, logicalHeight, None<Color>, draw)
    }

    private func renderToTextureTarget(
        texture: Texture,
        logicalWidth: Float32,
        logicalHeight: Float32,
        clearColor: ?Color,
        draw: () -> Unit
    ): Unit {
        if (texture.isClosed()) {
            throw CuiException("Cannot render into a closed texture.")
        }
        if (logicalWidth <= 0.0 || logicalHeight <= 0.0) {
            throw CuiException("Target texture logical dimensions must be greater than 0.")
        }
        if (ptr.isNull()) {
            return
        }
        let previousTarget = unsafe { SDL_GetRenderTarget(ptr) }
        let previousScaleX = currentScaleX()
        let previousScaleY = currentScaleY()
        let previousClips = snapshotClipStack()
        try {
            ensureSdl(unsafe { SDL_SetRenderTarget(ptr, texture.ptr) }, "SDL_SetRenderTarget")
            setScale(texture.width / logicalWidth, texture.height / logicalHeight)
            resetClipStack()
            match (clearColor) {
                case Some(value) => clear(value)
                case None => ()
            }
            draw()
        } finally {
            let _ = unsafe { SDL_SetRenderTarget(ptr, previousTarget) }
            setScale(previousScaleX, previousScaleY)
            restoreClipStack(previousClips)
        }
    }

    /**
     * Throws `CuiException` when the source surface is closed or SDL cannot create a texture.
     */
    public func textureFromSurface(surface: Surface): Texture {
        if (surface.isClosed()) {
            throw CuiException("Cannot create texture from a closed surface.")
        }
        let texture = unsafe { SDL_CreateTextureFromSurface(ptr, surface.ptr) }
        if (texture.isNull()) {
            throw CuiException("SDL_CreateTextureFromSurface failed: ${lastSdlError()}")
        }
        Texture(texture)
    }

    /**
     * Throws `CuiException` when SDL cannot load the image or create a texture from it.
     */
    public func loadTexture(path: String): Texture {
        var texture = CPointer<Unit>()
        try (surface = Surface.load(path)) {
            texture = unsafe { SDL_CreateTextureFromSurface(ptr, surface.ptr) }
        }
        if (texture.isNull()) {
            throw CuiException("SDL_CreateTextureFromSurface failed: ${lastSdlError()}")
        }
        Texture(texture)
    }

    /**
     * Throws `CuiException` when the texture is closed or SDL cannot render it.
     */
    public func texture(texture: Texture, destination: Rect, source!: ?Rect = None): Unit {
        if (texture.isClosed()) {
            throw CuiException("Cannot render a closed texture.")
        }
        var dst = destination.toSdlFRect()
        match (source) {
            case Some(rect) =>
                var src = rect.toSdlFRect()
                ensureSdl(unsafe { SDL_RenderTexture(ptr, texture.ptr, inout src, inout dst) }, "SDL_RenderTexture")
            case None => ensureSdl(unsafe { SDL_RenderTexture(ptr, texture.ptr, CPointer<SdlFRect>(), inout dst) },
                "SDL_RenderTexture")
        }
    }

    /**
     * Throws `CuiException` when the texture is closed or SDL cannot render it.
     */
    public func textureRotated(
        texture: Texture,
        destination: Rect,
        angle: Float64,
        options!: TextureRenderOptions = TextureRenderOptions()
    ): Unit {
        if (texture.isClosed()) {
            throw CuiException("Cannot render a closed texture.")
        }
        var dst = destination.toSdlFRect()
        match ((options.source, options.center)) {
            case (Some(srcRect), Some(centerPoint)) =>
                var src = srcRect.toSdlFRect()
                var pivot = centerPoint.toSdlFPoint()
                ensureSdl(unsafe {
                    SDL_RenderTextureRotated(ptr, texture.ptr, inout src, inout dst, angle, inout pivot,
                        flipCode(options.flip))
                }, "SDL_RenderTextureRotated")
            case (Some(srcRect), None) =>
                var src = srcRect.toSdlFRect()
                ensureSdl(unsafe {
                    SDL_RenderTextureRotated(ptr, texture.ptr, inout src, inout dst, angle, CPointer<SdlFPoint>(),
                        flipCode(options.flip))
                }, "SDL_RenderTextureRotated")
            case (None, Some(centerPoint)) =>
                var pivot = centerPoint.toSdlFPoint()
                ensureSdl(unsafe {
                    SDL_RenderTextureRotated(ptr, texture.ptr, CPointer<SdlFRect>(), inout dst, angle, inout pivot,
                        flipCode(options.flip))
                }, "SDL_RenderTextureRotated")
            case (None, None) => ensureSdl(unsafe {
                SDL_RenderTextureRotated(
                    ptr,
                    texture.ptr,
                    CPointer<SdlFRect>(),
                    inout dst,
                    angle,
                    CPointer<SdlFPoint>(),
                    flipCode(options.flip)
                )
            }, "SDL_RenderTextureRotated")
        }
    }
}

internal func validateStreamingSize(width: Int32, height: Int32): Unit {
    if (width <= 0 || height <= 0) {
        throw CuiException("Streaming texture dimensions must be greater than 0.")
    }
}

internal func validateStreamingPixels(pixels: CPointer<UInt8>, width: Int32, pitch: Int32): Unit {
    if (pixels.isNull()) {
        throw CuiException("Streaming texture pixels must not be null.")
    }
    if (width <= 0 || pitch < width * 4) {
        throw CuiException("Streaming texture pitch must cover one RGBA32 row.")
    }
}

internal func validateStreamingArrayPixels(
    pixels: Array<UInt8>,
    width: Int32,
    height: Int32,
    pitch: Int32
): Int64 {
    if (width <= 0 || height <= 0) {
        throw CuiException("Streaming texture dimensions must be greater than 0.")
    }
    let minimumPitch = Int64(width) * 4
    if (pitch <= 0 || Int64(pitch) < minimumPitch) {
        throw CuiException("Streaming texture pitch must cover one RGBA32 row.")
    }
    let rowBytes = Int64(pitch)
    let rows = Int64(height)
    if (rowBytes > Int64.Max / rows) {
        throw CuiException("Streaming texture pixel byte count overflowed.")
    }
    let required = rowBytes * rows
    if (pixels.size < required) {
        throw CuiException("Streaming texture pixels do not cover every row.")
    }
    required
}

private func blendModeCode(mode: TextureBlendMode): UInt32 {
    match (mode) {
        case TextureBlendMode.None => UInt32(0)
        case TextureBlendMode.Blend => UInt32(1)
        case TextureBlendMode.Add => UInt32(2)
        case TextureBlendMode.Mod => UInt32(4)
        case TextureBlendMode.Mul => UInt32(8)
    }
}

private func flipCode(flip: TextureFlip): Int32 {
    match (flip) {
        case TextureFlip.None => 0
        case TextureFlip.Horizontal => 1
        case TextureFlip.Vertical => 2
        case TextureFlip.Both => 3
    }
}

private func toChannel(value: Int64): UInt8 {
    if (value < 0) {
        UInt8(0)
    } else if (value > 255) {
        UInt8(255)
    } else {
        UInt8(value)
    }
}
