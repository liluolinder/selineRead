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
public class BooklistView {
    @Link var vm: SelineViewModel

    func build() {
        Column(10) {
            if (this.vm.booklists.booklistOpen) {
                Row(8) {
                    Text("‹").fontSize(26).fontColor(cAccent()).onClick { _ => this.vm.booklists.booklistOpen = false }
                    Text(this.vm.booklists.booklistTitle).fontSize(18).fontWeight(FontWeight.Bold).fontColor(cText()).layoutWeight(1)
                }
                .width(100.percent)
                List(space: 12) {
                    ForEach(this.vm.booklists.booklistBooks, itemGeneratorFunc: { book: BookInfo, _: Int64 => ListItem() {
                        Row(12) {
                            if (this.vm.home.coverUrl(book.cover).size > 0) {
                                Image(this.vm.home.coverUrl(book.cover)).alt(@r(app.media.default_cover)).width(56).aspectRatio(0.6667).objectFit(ImageFit.Cover).borderRadius(8).clip(true)
                            }
                            Column(5) {
                                Text(book.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(cText()).maxLines(2).width(100.percent)
                                Text(book.authorText()).fontSize(12).fontColor(cWeak()).width(100.percent).maxLines(1)
                            }
                            .layoutWeight(1).alignItems(HorizontalAlign.Start)
                        }
                        .width(100.percent).padding(12).borderRadius(14).backgroundColor(cCard())
                        .onClick { _ => this.vm.detail.openDetail(book.id, book.hash) }
                    } })
                }
                .layoutWeight(1).width(100.percent)
            } else {
                List(space: 12) {
                    if (this.vm.booklists.booklistError.size > 0) {
                        ListItem() { Text(this.vm.booklists.booklistError).fontSize(12).fontColor(cDanger()).padding(10) }
                    }
                    ForEach(this.vm.booklists.booklists, itemGeneratorFunc: { rl: Readlist, _: Int64 => ListItem() {
                        Column(6) {
                            Text(rl.title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(cText()).width(100.percent)
                            Text(rl.description).fontSize(12).fontColor(cWeak()).maxLines(2).width(100.percent)
                            Text("${rl.booksCount} 本 · ${this.vm.booklists.booklistOwner(rl.userId)}").fontSize(11).fontColor(cWeak())
                        }
                        .width(100.percent).padding(12).borderRadius(14).backgroundColor(cCard())
                        .onClick { _ => this.vm.booklists.openBooklist(rl) }
                    } })
                }
                .layoutWeight(1).width(100.percent)
            }
        }
        .width(100.percent).height(100.percent)
    }
}

@Component
public class SavedView {
    @Link var vm: SelineViewModel

    func build() {
        Column(10) {
            if (!this.vm.loggedIn) {
                Text("登录后可以查看收藏").fontSize(14).fontColor(cWeak()).padding(20)
            } else {
                List(space: 12) {
                    ForEach(this.vm.saved.savedBooks, itemGeneratorFunc: { book: BookInfo, _: Int64 => ListItem() {
                        Row(12) {
                            if (this.vm.home.coverUrl(book.cover).size > 0) {
                                Image(this.vm.home.coverUrl(book.cover)).alt(@r(app.media.default_cover)).width(56).aspectRatio(0.6667).objectFit(ImageFit.Cover).borderRadius(8).clip(true)
                            }
                            Column(5) {
                                Text(book.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(cText()).maxLines(2).width(100.percent)
                                Text(book.authorText()).fontSize(12).fontColor(cWeak()).width(100.percent).maxLines(1)
                            }
                            .layoutWeight(1).alignItems(HorizontalAlign.Start)
                        }
                        .width(100.percent).padding(12).borderRadius(14).backgroundColor(cCard())
                        .onClick { _ => this.vm.detail.openDetail(book.id, book.hash) }
                    } })
                }
                .layoutWeight(1).width(100.percent)
                .onReachEnd { => this.vm.saved.loadMoreSaved() }
            }
        }
        .width(100.percent).height(100.percent)
    }
}

@Component
public class DownloadsView {
    @Link var vm: SelineViewModel

    func build() {
        List(space: 12) {
            if (this.vm.downloads.downloads.size == 0) {
                ListItem() { Text("还没有下载").fontSize(14).fontColor(cWeak()).padding(20) }
            }
            ForEach(this.vm.downloads.downloads, itemGeneratorFunc: { item: LocalDownload, _: Int64 => ListItem() {
                Column(4) {
                    Text(item.title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(cText()).width(100.percent)
                    Text(item.fileName).fontSize(11).fontColor(cWeak()).width(100.percent)
                }
                .width(100.percent).padding(12).borderRadius(14).backgroundColor(cCard())
            } })
        }
        .width(100.percent).height(100.percent)
    }
}

@Component
public class SettingsView {
    @Link var vm: SelineViewModel

    func build() {
        Scroll() {
            Column(12) {
                if (this.vm.loggedIn) {
                    Text("已登录：${this.vm.accountName}").fontSize(14).fontColor(cText())
                    Text("站点：${this.vm.site}").fontSize(12).fontColor(cWeak())
                    Button("退出登录").width(100.percent).height(44).backgroundColor(cCard()).fontColor(cDanger())
                        .onClick { _ => this.vm.settings.doLogout() }
                } else {
                    Text("登录 Z-Library").fontSize(16).fontWeight(FontWeight.Bold).fontColor(cText())
                    TextInput(placeholder: "邮箱", text: this.vm.settings.email).width(100.percent).height(44).backgroundColor(cCard())
                        .onChange { value: String => this.vm.settings.email = value }
                    TextInput(placeholder: "密码", text: this.vm.settings.password).width(100.percent).height(44).backgroundColor(cCard())
                        .onChange { value: String => this.vm.settings.password = value }
                    Button(if (this.vm.settings.loggingIn) { "登录中..." } else { "登录" }).width(100.percent).height(44)
                        .backgroundColor(cAccent()).fontColor(Color(0xFFFFFFFF)).onClick { _ => this.vm.settings.doLogin() }
                }
                Text("服务器").fontSize(14).fontWeight(FontWeight.Medium).fontColor(cText())
                TextInput(placeholder: "站点地址", text: this.vm.settings.baseUrlInput).width(100.percent).height(44).backgroundColor(cCard())
                    .onChange { value: String => this.vm.settings.baseUrlInput = value }
                TextInput(placeholder: "种子站", text: this.vm.settings.seedUrlInput).width(100.percent).height(44).backgroundColor(cCard())
                    .onChange { value: String => this.vm.settings.seedUrlInput = value }
                Row(10) {
                    Button("保存").layoutWeight(1).height(42).backgroundColor(cAccent()).fontColor(Color(0xFFFFFFFF)).onClick { _ => this.vm.settings.saveServer() }
                    Button("恢复默认").layoutWeight(1).height(42).backgroundColor(cCard()).fontColor(cText()).onClick { _ => this.vm.settings.restoreDefaults() }
                }
                if (this.vm.settings.settingsMessage.size > 0) {
                    Text(this.vm.settings.settingsMessage).fontSize(12).fontColor(cWeak())
                }
            }
            .width(100.percent).padding(16).alignItems(HorizontalAlign.Start)
        }
        .width(100.percent).height(100.percent)
    }
}

@Component
public class DetailView {
    @Link var vm: SelineViewModel

    func build() {
        Column(10) {
            Row(8) {
                Text("‹").fontSize(30).fontColor(cAccent()).onClick { _ => this.vm.showDetail = false }
                Text(this.vm.detail.detailTitle).fontSize(18).fontWeight(FontWeight.Bold).fontColor(cText()).layoutWeight(1).maxLines(1)
            }
            .width(100.percent).padding(left: 16, right: 16, top: 8)
            if (this.vm.detail.detailLoading) {
                            Column(8) {
                Column().width(100.percent).aspectRatio(0.6667).borderRadius(12).backgroundColor(Color(0xFFE5E7EB))
                Column().width(72.percent).height(15).borderRadius(7).backgroundColor(Color(0xFFE5E7EB))
                Column().width(42.percent).height(12).borderRadius(6).backgroundColor(Color(0xFFEDEFF2))
            }
            .width(100.percent).padding(12).borderRadius(16).backgroundColor(cCard()).alignItems(HorizontalAlign.Start)
            } else if (this.vm.detail.detailError.size > 0) {
                Text(this.vm.detail.detailError).fontSize(12).fontColor(cDanger()).padding(10)
            } else {
                Scroll() {
                    Column(10) {
                        Row(12) {
                            if (this.vm.home.coverUrl(this.vm.detail.detailCover).size > 0) {
                                Image(this.vm.home.coverUrl(this.vm.detail.detailCover)).alt(@r(app.media.default_cover)).width(100).aspectRatio(0.6667).objectFit(ImageFit.Cover).borderRadius(8).clip(true)
                            }
                            Column(6) {
                                Text(this.vm.detail.detailAuthor).fontSize(13).fontColor(cWeak())
                                Text(this.vm.detail.detailMeta).fontSize(12).fontColor(cWeak())
                            }
                            .layoutWeight(1).alignItems(HorizontalAlign.Start)
                        }
                        .width(100.percent)
                        Text(this.vm.detail.detailDescription).fontSize(13).fontColor(cText()).width(100.percent)
                        Row(10) {
                            Button(if (this.vm.detail.detailSaved) { "取消收藏" } else { "收藏" }).layoutWeight(1).height(42)
                                .backgroundColor(cCard()).fontColor(cText()).onClick { _ => this.vm.detail.toggleSave() }
                            Button(if (this.vm.detail.detailBusy) { "处理中..." } else { "下载" }).layoutWeight(1).height(42)
                                .backgroundColor(cAccent()).fontColor(Color(0xFFFFFFFF)).onClick { _ => this.vm.detail.downloadBook() }
                        }
                    }
                    .width(100.percent).padding(16).alignItems(HorizontalAlign.Start)
                }
                .layoutWeight(1).width(100.percent)
            }
        }
        .width(100.percent).height(100.percent)
    }
}








