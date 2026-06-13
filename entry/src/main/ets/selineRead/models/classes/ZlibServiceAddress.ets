
@ObservedV2
export class ZlibServiceAddress{
  @Trace url:string = ''
  @Trace status:ZlibServiceStatus = ZlibServiceStatus.Unknown

  constructor(_url:string, _status:ZlibServiceStatus){
    this.url = _url
    this.status = _status
  }
}

export enum ZlibServiceStatus{
  Unknown, Accessible, UnAccessible
}