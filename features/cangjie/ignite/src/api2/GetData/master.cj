package ignite.api2.GetData

import ignite.api2.GetData.cjpmInfo

// 因为 宏 检查问题，报错是正常的
public class GetDataClass{
    init(){}

    /**
    * 获取框架版本
    * @return 框架版本
    */
    public static func ModuleVer():String {
        try {
            return @cjpmInfo.ModuleVer("1.0.0")
        } catch (e: Exception) {
            return "1.0.0"
        }
    }

    /**
    * 获取项目组织名称
    * @return 项目组织名称
    */
    public static func ModuleOrg():String {
        try {
            return @cjpmInfo.ModuleOrg("1.0.0")
        } catch (e: Exception) {
            return "1.0.0"
        }
    }

    /**
    * 获取项目名称
    * @return 项目名称
    */
    public static func ModuleName():String {
        try {
            return @cjpmInfo.ModuleName("1.0.0")
        } catch (e: Exception) {
            return "1.0.0"
        }
    }

    /**
    * 获取项目描述
    * @return 项目描述
    */
    public static func ModuleDesc():String {
        try {
            return @cjpmInfo.ModuleDesc("1.0.0")
        } catch (e: Exception) {
            return "1.0.0"
        }
    }
}