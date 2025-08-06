@ComponentV2
export struct EmptyPage{

  build() {
    NavDestination(){
      Stack(){

        Image($r('app.media.zlib')).size({width: 250, height: 250}).draggable(false).opacity(0.4)

      }.size({width:'100%', height:'100%'}).backgroundColor($r('sys.color.comp_background_gray'))
    }
  }
}

@Builder
export function emptyPageBuilder() {
  EmptyPage()
}