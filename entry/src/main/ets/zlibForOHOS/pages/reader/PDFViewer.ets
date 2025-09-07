import { PdfView, pdfViewManager } from '@hms.officeservice.PdfView';
import pdfService from '@hms.officeservice.pdfservice';

@Builder
export function pdfViewerBuilder(){
  PDFViewer()
}

@ComponentV2
struct PDFViewer{

  @Local lineHeight: number = 30

  @Local totalCount: number = 0

  @Local nowCount: number = 0

  pdfController = new pdfViewManager.PdfController();

  path: string = ''

  scroller: ListScroller = new ListScroller()



  build() {
    NavDestination() {
      Column(){
        PdfView({controller: this.pdfController, showScroll: false, pageFit: pdfService.PageFit.FIT_PAGE})
          .size({width: '100%', height: '100%'})
          .onAppear(()=>{
            this.pdfController.loadDocument(this.path)
            this.totalCount = this.pdfController.getPageIndex()
          })
      }.size({width: '100%', height: '100%'})
    }.backgroundColor($r('app.color.start_window_background'))
    .expandSafeArea([SafeAreaType.SYSTEM])
    .title('PDF查看器')
    .onReady((context)=>{
      this.path = context.pathInfo.param as string
    })
  }
}
