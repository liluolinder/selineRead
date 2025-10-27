import { Cover } from "./Cover"
import { XAnimation, XContext } from "commonpackage"
import { photoAccessHelper } from "@kit.MediaLibraryKit"
import { fileIo, fileUri } from "@kit.CoreFileKit"
import { common } from "@kit.AbilityKit"
import { request } from "@kit.BasicServicesKit"

@ComponentV2
export struct BigImage {
    @Param image: ResourceStr = ''
    @Local areaWidth: number = 0
    @Local areaHeight: number = 0
    @Local zoom: number = 1
    @Local angle: number = 0
    @Local offsetX: number = 0
    @Local offsetY: number = 0
    startOffsetX: number = 0
    startOffsetY: number = 0
    startZoom: number = 0
    finger1startX: number = 0
    finger1startY: number = 0
    centerStartX: number = 0
    centerStartY: number = 0
    centerX: number = 0
    centerY: number = 0
    startDistant: number = 0
    type: number = 0
    lastZoom: number = 0
    speed: number = 0
    clicked: boolean = false

    build() {
        Stack({ alignContent: Alignment.BottomEnd }) {
            Cover({ data: this.image, haveShadow: false , aspectRatioValue:undefined, imageFit: ImageFit.Contain })
                .size({ width: '100%', height: '100%' })
                .geometryTransition('image', { follow: true })
                .rotate({ z: 1, angle: this.angle })
                .offset({ x: this.offsetX, y: this.offsetY })
                .scale({ x: this.zoom, y: this.zoom })

        }
        .gesture(PanGesture().onActionStart((event) => {
            try {
                this.startOffsetX = this.offsetX
                this.startOffsetY = this.offsetY
                if (event.fingerList.length == 1 && this.type == 0) {
                    this.type = 1
                    this.finger1startX = event.fingerList[0].localX
                    this.finger1startY = event.fingerList[0].localY
                } else if (event.fingerList.length == 2 && this.type == 0) {
                    this.centerStartX =
                        (event.fingerList[0].localX + event.fingerList[1].localX) / 2 - this.areaWidth / 2
                    this.centerStartY =
                        (event.fingerList[0].localY + event.fingerList[1].localY) / 2 - this.areaHeight / 2
                    this.type = 2
                    this.startDistant = Math.sqrt(Math.pow(event.fingerList[0].localX - event.fingerList[1].localX, 2) +
                    Math.pow(event.fingerList[0].localY - event.fingerList[1].localY, 2))
                    this.startZoom = this.zoom
                    this.lastZoom = this.zoom
                }
            } catch {
            }
        })
            .onActionUpdate((event) => {
                try {
                    if (event.fingerList.length == 1 && this.type == 1) {
                        this.offsetX =
                            this.startOffsetX + (event.fingerList[0].localX - this.finger1startX) * Math.sqrt(this.zoom)
                        this.offsetY =
                            this.startOffsetY + (event.fingerList[0].localY - this.finger1startY) * Math.sqrt(this.zoom)
                    } else if (event.fingerList.length == 2 && this.type == 2) {
                        this.centerX =
                            (event.fingerList[0].localX + event.fingerList[1].localX) / 2 - this.areaWidth / 2
                        this.centerY =
                            (event.fingerList[0].localY + event.fingerList[1].localY) / 2 - this.areaHeight / 2
                        this.zoom = Math.min(Math.max(this.startZoom +
                            (Math.sqrt(Math.pow(event.fingerList[0].localX - event.fingerList[1].localX, 2) +
                            Math.pow(event.fingerList[0].localY - event.fingerList[1].localY, 2)) - this.startDistant) *
                                (0.002 + Math.sqrt(this.zoom) * 0.004), 0.6), 3.5)
                        this.startOffsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) / this.zoom
                        this.startOffsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) / this.zoom
                        this.offsetX = this.startOffsetX + (this.centerX - this.centerStartX) * Math.sqrt(this.zoom)
                        this.offsetY = this.startOffsetY + (this.centerY - this.centerStartY) * Math.sqrt(this.zoom)
                        this.lastZoom = this.zoom
                    }
                } catch {
                }
            })
            .onActionEnd(() => {
                if (this.type == 2) {
                    if (this.zoom < 0.7) {
                        XAnimation.runWithAnimation(() => {
                            this.zoom = 0.7
                            this.startOffsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) / this.zoom
                            this.startOffsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) / this.zoom
                            this.offsetX = this.startOffsetX + (this.centerX - this.centerStartX) * Math.sqrt(this.zoom)
                            this.offsetY = this.startOffsetY + (this.centerY - this.centerStartY) * Math.sqrt(this.zoom)
                        })
                    }
                    if (this.zoom > 3) {
                        XAnimation.runWithAnimation(() => {
                            this.zoom = 3
                            this.startOffsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) / this.zoom
                            this.startOffsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) / this.zoom
                            this.offsetX = this.startOffsetX + (this.centerX - this.centerStartX) * Math.sqrt(this.zoom)
                            this.offsetY = this.startOffsetY + (this.centerY - this.centerStartY) * Math.sqrt(this.zoom)
                        })
                    }
                }
                this.type = 0
            })
        )
        .onAxisEvent((event) => {
            if (event.action == AxisAction.BEGIN) {
                this.startZoom = this.zoom
                this.type = 3
            }
            if (event.action == AxisAction.UPDATE) {
                animateToImmediately({ duration: 100, curve: Curve.Ease }, () => this.zoom =
                    Math.min(Math.max(this.startZoom -
                        (event.axisVertical ?? 0) * (0.003 + Math.sqrt(this.zoom) * 0.003), 0.6),
                        3.5))
            }
            if (event.action == AxisAction.END || event.action == AxisAction.CANCEL) {
                if (this.zoom < 0.7) {
                    XAnimation.runWithAnimation(() => this.zoom = 0.7)
                }
                if (this.zoom > 3) {
                    XAnimation.runWithAnimation(() => this.zoom = 3)
                }
                this.type = 0
            }
        })
        .onClick((event) => {
            if (this.clicked) {
                if (this.zoom == 1) {
                    this.centerX = event.x - this.areaWidth / 2
                    this.centerY = event.y - this.areaHeight / 2
                    this.lastZoom = this.zoom
                    XAnimation.runWithAnimation(() => {
                        this.zoom = 1.75
                        this.offsetX += (this.lastZoom - this.zoom) * (this.centerX - this.offsetX) * this.zoom
                        this.offsetY += (this.lastZoom - this.zoom) * (this.centerY - this.offsetY) * this.zoom
                    })
                } else {
                    XAnimation.runWithAnimation(() => {
                        this.zoom = 1
                        this.offsetX = 0
                        this.offsetY = 0
                    })
                }
            } else {
                this.clicked = true
                setTimeout(() => this.clicked = false, 200)
            }
        })
        .size({ width: '100%', height: '100%' })
        .onAreaChange((_, newValue) => {
            this.areaWidth = new Number(newValue.width).valueOf()
            this.areaHeight = new Number(newValue.height).valueOf()
        })
    }
}