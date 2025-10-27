@ComponentV2
export struct CollectionVideo {
    @Param @Require videoSrc: string
    private controller: VideoController = new VideoController()

    build() {
        Column() {
            Video({
                src: this.videoSrc,
                previewUri: $r('app.media.default_cover'),
                controller: this.controller
            })
                .objectFit(ImageFit.Contain)
                .autoPlay(true)
                .loop(true)
        }.size({ width: '100%', height: '100%' })
    }
}