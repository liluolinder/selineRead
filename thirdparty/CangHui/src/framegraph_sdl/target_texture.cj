package chui.framegraph_sdl

import sdl.{Renderer, Texture, TextureBlendMode}

/** Protected provider bridge; no Renderer/Texture member is added to CangHui's stable API. */
protected func createFrameGraphCopyTargetTexture(
    renderer: Renderer,
    logicalWidth: Float32,
    logicalHeight: Float32
): Texture {
    let texture = renderer.createTargetTexture(logicalWidth, logicalHeight)
    try {
        texture.setBlendMode(TextureBlendMode.None)
        texture
    } catch (error: Exception) {
        texture.close()
        throw error
    }
}
