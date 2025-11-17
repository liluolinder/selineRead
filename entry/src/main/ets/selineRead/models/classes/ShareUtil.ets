/*
import { harmonyShare, systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor } from '@kit.ArkData'
import { http } from '@kit.NetworkKit'


export interface S_ShareData{
  url ?: string
  imageUrl ?: string
  title ?: string
  description ?: string
}

class GestureShare{
  data ?: S_ShareData

  private async share(event: harmonyShare.SharableTarget){
    if(!this.data?.url){
      event.reject(harmonyShare.SharableErrorCode.NO_CONTENT_ERROR)
    }
    http.createHttp()
    event.share(new systemShare.SharedData({
      utd: uniformTypeDescriptor.UniformDataType.HYPERLINK,
      content: this.data?.url,
      title: this.data?.title,
      description: this.data?.description,
      thumbnailUri: this.data?.imageUrl
    }))
  }

  on(data: S_ShareData){
    this.data = data
    harmonyShare.on('gesturesShare', (event)=>{
      this.share(event)
    })

    harmonyShare.on('knockShare', (event)=>{
      this.share(event)
    })
  }

  off(){
    harmonyShare.off('gesturesShare')
    harmonyShare.off('knockShare')
    this.data = undefined
  }
}

export const gestureShare: GestureShare = new GestureShare*/
