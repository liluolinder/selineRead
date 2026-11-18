@NonProduct
features {}
package ohos_app_cangjie_entry.viewmodel

internal import ohos.state_manage.ObservedObject
internal import ohos.state_manage.ObservedProperty
internal import ohos.state_manage.ObservedComplexAbstract
import ohos.state_macro_manage.Observed
import ohos.state_macro_manage.Publish
import ohos.concurrency.launch
import zlibraryAPI4CJ.*
import ohos_app_cangjie_entry.model.*

// ---------------------------------------------------------------------------
// 设置：登录/退出、服务器地址、恢复默认。
// ---------------------------------------------------------------------------

@Observed
public class SettingsViewModel {
    public var owner: ?SelineViewModel = None

    @Publish
    public var email: String = ""
    @Publish
    public var password: String = ""
    @Publish
    public var loggingIn: Bool = false
    @Publish
    public var settingsMessage: String = ""
    @Publish
    public var baseUrlInput: String = ""
    @Publish
    public var seedUrlInput: String = ""

    private func shell(): SelineViewModel {
        match (this.owner) {
            case Some(value) => value
            case None => throw Exception("SettingsViewModel is not attached to SelineViewModel")
        }
    }

    public func doLogin(): Unit {
        if (this.loggingIn) {
            return
        }
        if (this.email.size == 0 || this.password.size == 0) {
            this.settingsMessage = "请输入邮箱和密码"
            return
        }
        this.loggingIn = true
        this.settingsMessage = "正在登录…"
        spawn {
            => try {
                let name = ZlibService.login(this.email, this.password)
                let current = ZlibService.currentSite()
                launch(
                    {
                        =>
                            this.loggingIn = false
                            this.settingsMessage = "登录成功"
                            let root = this.shell()
                            root.loggedIn = true
                            root.accountName = name
                            root.site = current
                            root.saved.invalidate()
                            toast("欢迎回来，${name}")
                    }
                )
            } catch (err: ZlibError) {
                let text = formatZlibError(err)
                launch(
                    {
                        =>
                            this.loggingIn = false
                            this.settingsMessage = text
                    }
                )
            } catch (err: Exception) {
                let text = err.message
                launch(
                    {
                        =>
                            this.loggingIn = false
                            this.settingsMessage = text
                    }
                )
            }
        }
    }

    public func doLogout(): Unit {
        ZlibService.logout()
        let root = this.shell()
        root.loggedIn = false
        root.accountName = ""
        root.saved.invalidate()
        this.settingsMessage = "已退出登录"
        toast("已退出登录")
    }

    public func saveServer(): Unit {
        if (this.baseUrlInput.size == 0) {
            this.settingsMessage = "站点地址不能为空"
            return
        }
        SelineSettings.setBaseUrl(this.baseUrlInput)
        SelineSettings.setSeedUrl(this.seedUrlInput)
        ZlibService.resetClients()
        ZlibService.bootstrap()
        let root = this.shell()
        root.site = ZlibService.currentSite()
        root.loggedIn = ZlibService.isLoggedIn()
        root.accountName = ZlibService.accountName()
        this.settingsMessage = "已保存，后续请求使用新站点"
        toast("服务器设置已更新")
    }

    public func restoreDefaults(): Unit {
        SelineSettings.setBaseUrl(DEFAULT_BASE_URL)
        SelineSettings.setSeedUrl(DEFAULT_SEED_URL)
        this.baseUrlInput = DEFAULT_BASE_URL
        this.seedUrlInput = DEFAULT_SEED_URL
        ZlibService.resetClients()
        ZlibService.bootstrap()
        this.shell().site = ZlibService.currentSite()
        this.settingsMessage = "已恢复默认站点"
    }
}
