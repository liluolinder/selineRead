@NonProduct
features {}
package ohos_app_cangjie_entry.view

internal import ohos.component.*
internal import ohos.base.*
internal import ohos.base.LengthProp
internal import ohos.state_manage.*
import ohos.state_macro_manage.*
import ohos.resource_manager.AppResource
import ohos.resource_manager.__GenerateResource__
import ohos_app_cangjie_entry.viewmodel.*
import ohos_app_cangjie_entry.model.*
import zlibraryAPI4CJ.*

@Component
public class HomeView {
    @Link
    var vm: SelineViewModel

    func build() {
        Stack(Alignment.Top) {
            Column() {
                if (this.vm.home.searchMode && this.vm.home.error.size > 0) {
                    Text(this.vm.home.error)
                        .fontSize(12)
                        .fontColor(cDanger())
                        .width(100.percent)
                        .padding(10)
                        .backgroundColor(Color(0x22D93F3F))
                }
                if (!this.vm.home.searchMode && this.vm.home.recError.size > 0) {
                    Text(this.vm.home.recError)
                        .fontSize(12)
                        .fontColor(cDanger())
                        .width(100.percent)
                        .padding(10)
                        .backgroundColor(Color(0x22D93F3F))
                }
                if (this.vm.home.searchMode) {
                    List(space: 12) {
                        ForEach(this.vm.home.skeletonItems(), itemGeneratorFunc: {
                            _: Int64, _: Int64 => ListItem() {
                                Column(8) {
                                    Column()
                                        .width(100.percent)
                                        .aspectRatio(0.6667)
                                        .borderRadius(12)
                                        .backgroundColor(Color(0xFFE5E7EB))
                                    Column()
                                        .width(72.percent)
                                        .height(15)
                                        .borderRadius(7)
                                        .backgroundColor(Color(0xFFE5E7EB))
                                    Column()
                                        .width(42.percent)
                                        .height(12)
                                        .borderRadius(6)
                                        .backgroundColor(Color(0xFFEDEFF2))
                                }
                                    .width(100.percent)
                                    .padding(12)
                                    .borderRadius(16)
                                    .backgroundColor(cCard())
                                    .alignItems(HorizontalAlign.Start)
                            }
                        })

                        ForEach(this.vm.home.books, itemGeneratorFunc: {
                            book: BookInfo, _: Int64 => ListItem() {
                                if (this.vm.home.waterfall) {
                                    Column(8) {
                                        if (this.vm.home.coverUrl(book.cover).size > 0) {
                                            Image(this.vm.home.coverUrl(book.cover))
                                                .alt(@r(app.media.default_cover))
                                                .width(100.percent)
                                                .aspectRatio(0.6667)
                                                .objectFit(ImageFit.Cover)
                                                .borderRadius(12)
                                                .clip(true)
                                        } else {
                                            Column() {Text("书").fontSize(24).fontColor(cAccent())}
                                                .width(100.percent)
                                                .aspectRatio(0.6667)
                                                .justifyContent(FlexAlign.Center)
                                                .borderRadius(12)
                                                .backgroundColor(cAccentSoft())
                                        }
                                        Text(book.title)
                                            .fontSize(15)
                                            .fontWeight(FontWeight.Medium)
                                            .fontColor(cText())
                                            .width(100.percent)
                                            .maxLines(2)
                                        Text(book.authorText())
                                            .fontSize(12)
                                            .fontColor(cWeak())
                                            .width(100.percent)
                                            .maxLines(1)
                                    }
                                        .width(100.percent)
                                        .padding(12)
                                        .borderRadius(16)
                                        .backgroundColor(cCard())
                                        .alignItems(HorizontalAlign.Start)
                                        .onClick {_ => this.vm.detail.openDetail(book.id, book.hash)}
                                } else {
                                    Row(12) {
                                        if (this.vm.home.coverUrl(book.cover).size > 0) {
                                            Image(this.vm.home.coverUrl(book.cover))
                                                .alt(@r(app.media.default_cover))
                                                .width(56)
                                                .aspectRatio(0.6667)
                                                .objectFit(ImageFit.Cover)
                                                .borderRadius(8)
                                                .clip(true)
                                        } else {
                                            Column() {Text("书").fontSize(20).fontColor(cAccent())}
                                                .width(56)
                                                .aspectRatio(0.6667)
                                                .justifyContent(FlexAlign.Center)
                                                .borderRadius(8)
                                                .backgroundColor(cAccentSoft())
                                        }
                                        Column(5) {
                                            Text(book.title)
                                                .fontSize(15)
                                                .fontWeight(FontWeight.Medium)
                                                .fontColor(cText())
                                                .maxLines(2)
                                                .width(100.percent)
                                            Text(book.authorText())
                                                .fontSize(12)
                                                .fontColor(cWeak())
                                                .maxLines(1)
                                                .width(100.percent)
                                        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                                    }
                                        .width(100.percent)
                                        .padding(12)
                                        .borderRadius(14)
                                        .backgroundColor(cCard())
                                        .onClick {_ => this.vm.detail.openDetail(book.id, book.hash)}
                                }
                            }
                        })
                    }
                        .lanes(this.vm.home.lanes(), gutter: 12)
                        .layoutWeight(1)
                        .width(100.percent)
                        .padding(left: 16, right: 16)
                        .contentStartOffset(this.vm.window.topRectHeight + 72.0)
                        .contentEndOffset(84.0 + this.vm.window.bottomRectHeight)
                        .onReachEnd {=> this.vm.home.loadMore()}
                } else {
                    List(space: 12) {
                        ForEach(this.vm.home.skeletonItems(), itemGeneratorFunc: {
                            _: Int64, _: Int64 => ListItem() {
                                Column(8) {
                                    Column()
                                        .width(100.percent)
                                        .aspectRatio(0.6667)
                                        .borderRadius(12)
                                        .backgroundColor(Color(0xFFE5E7EB))
                                    Column()
                                        .width(72.percent)
                                        .height(15)
                                        .borderRadius(7)
                                        .backgroundColor(Color(0xFFE5E7EB))
                                    Column()
                                        .width(42.percent)
                                        .height(12)
                                        .borderRadius(6)
                                        .backgroundColor(Color(0xFFEDEFF2))
                                }
                                    .width(100.percent)
                                    .padding(12)
                                    .borderRadius(16)
                                    .backgroundColor(cCard())
                                    .alignItems(HorizontalAlign.Start)
                            }
                        })
                        ForEach(this.vm.home.recBooks, itemGeneratorFunc: {
                            brief: BookInfoBrief, _: Int64 => ListItem() {
                                if (this.vm.home.waterfall) {
                                    Column(8) {
                                        if (this.vm.home.coverUrl(brief.cover).size > 0) {
                                            Image(this.vm.home.coverUrl(brief.cover))
                                                .alt(@r(app.media.default_cover))
                                                .width(100.percent)
                                                .aspectRatio(0.6667)
                                                .objectFit(ImageFit.Cover)
                                                .borderRadius(12)
                                                .clip(true)
                                        } else {
                                            Column() {Text("书").fontSize(24).fontColor(cAccent())}
                                                .width(100.percent)
                                                .aspectRatio(0.6667)
                                                .justifyContent(FlexAlign.Center)
                                                .borderRadius(12)
                                                .backgroundColor(cAccentSoft())
                                        }
                                        Text(brief.title)
                                            .fontSize(15)
                                            .fontWeight(FontWeight.Medium)
                                            .fontColor(cText())
                                            .width(100.percent)
                                            .maxLines(2)                                         
                                        Text(brief.author).fontSize(12).fontColor(cWeak()).width(100.percent).maxLines(1)
                                    }
                                        .width(100.percent)
                                        .padding(12)
                                        .borderRadius(16)
                                        .backgroundColor(cCard())
                                        .alignItems(HorizontalAlign.Start)
                                        .onClick {_ =>
                                            this.vm.pathStack.pushPath("BookDetail","测试")
                                        }
                                } else {
                                    Row(12) {
                                        if (this.vm.home.coverUrl(brief.cover).size > 0) {
                                            Image(this.vm.home.coverUrl(brief.cover))
                                                .alt(@r(app.media.default_cover))
                                                .width(56)
                                                .aspectRatio(0.6667)
                                                .objectFit(ImageFit.Cover)
                                                .borderRadius(8)
                                                .clip(true)
                                        } else {
                                            Column() {Text("书").fontSize(20).fontColor(cAccent())}
                                                .width(56)
                                                .aspectRatio(0.6667)
                                                .justifyContent(FlexAlign.Center)
                                                .borderRadius(8)
                                                .backgroundColor(cAccentSoft())
                                        }
                                        Column(5) {
                                            Text(brief.title)
                                                .fontSize(15)
                                                .fontWeight(FontWeight.Medium)
                                                .fontColor(cText())
                                                .maxLines(2)
                                                .width(100.percent)
                                            Text(brief.author)
                                                .fontSize(12)
                                                .fontColor(cWeak())
                                                .width(100.percent)
                                                .maxLines(1)
                                        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                                    }
                                        .width(100.percent)
                                        .padding(12)
                                        .borderRadius(14)
                                        .backgroundColor(cCard())
                                        .onClick {_ => 
                                        
                                        this.vm.detail.openDetail(brief.id, brief.hash)}
                                }
                            }
                        })
                    }
                        .lanes(this.vm.home.lanes(), gutter: 12)
                        .layoutWeight(1)
                        .width(100.percent)
                        .padding(left: 16, right: 16)
                        .contentStartOffset(this.vm.window.topRectHeight + 72.0)
                        .contentEndOffset(84.0 + this.vm.window.bottomRectHeight)
                }
            }
                .width(100.percent)
                .height(100.percent)
                .onAreaChange {_: Area, area: Area => this.vm.home.updateContentWidth(area.width)}


            Row(10) {
                Column() {
                    if (this.vm.home.waterfall) {
                        Image(@r(app.symbol.grid))
                            .width(22)
                            .height(22)
                            .objectFit(ImageFit.Contain)
                    } else {
                        Image("resources/base/media/icon_list.svg")
                            .width(22)
                            .height(22)
                            .objectFit(ImageFit.Contain)
                    }
                }
                    .width(44)
                    .height(44)
                    .borderRadius(22)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(cCard())
                    .shadow(radius: 10, color: 0x22000000, offsetX: 0, offsetY: 4)
                    .onClick {_ => this.vm.home.waterfall = !this.vm.home.waterfall}
                Search(value: this.vm.home.query, placeholder: "搜索书名 / 作者 / ISBN")
                    .id("searchInput")
                    .searchButton("搜索")
                    .layoutWeight(1)
                    .height(48)
                    .backgroundColor(cCard())
                    .borderRadius(24)
                    .shadow(radius: 14, color: 0x22000000, offsetX: 0, offsetY: 4)
                    .onChange {
                        value: String =>
                            this.vm.home.query = value
                            if (value.size == 0 && this.vm.home.searchMode) {
                                this.vm.home.clearSearch()
                            }
                    }
                    .onSubmit {
                        value: String =>
                            this.vm.home.query = value
                            this.vm.home.startSearch()
                    }
            }.width(100.percent).padding(left: 16, right: 16).margin(top: this.vm.window.topRectHeight + 6.0)
        }.width(100.percent).height(100.percent)
    }
}






