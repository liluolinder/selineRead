

@ComponentV2
export struct Cover {
    @Param @Require data: ResourceStr | undefined
    @Param defaultImg: ResourceStr = $r('app.media.default_cover')
    @Param isVideo: boolean = false
    @Param haveShadow: boolean = true
    @Param imageFit: ImageFit = ImageFit.Auto
    @Local private isFinish: boolean = false
    @Param aspectRatioValue?: number = 1

    build() {
        Stack() {
            Image(this.data ?? this.defaultImg)
                .transition(TransitionEffect.OPACITY)
                .objectFit(this.imageFit)
                .aspectRatio(this.aspectRatioValue)
                .autoResize(true)
                .onComplete((res) => {
                    if(res?.width && res?.width > 0 && res?.height && res?.height > 0) this.isFinish = true
                })
            if(!this.isFinish){
                Image(this.defaultImg)
                    .transition(TransitionEffect.OPACITY.animation({duration: 150, curve: Curve.Ease}))
                    .objectFit(this.imageFit)
                    .aspectRatio(this.aspectRatioValue)
                    .autoResize(true)
            }


            if (this.isVideo) {
                Image($r('sys.media.ohos_ic_public_play'))
                    .fillColor($r('sys.color.comp_background_list_card'))
                    .size({ width: '60' })
            }
        }
        .enabled(false)
        .reuseId(this.data?.toString())
        .shadow({
            radius: this.haveShadow ? 25 : 0,
            color: $r('app.color.shadow_color'),
            offsetX: 0,
            offsetY: 10
        })
    }
}
