package gjson

// 字面值解析工具模块
// 基于Go版本优化模式，将字面值解析相关的工具函数从utils.cj分离至此文件
// 职责：处理JSON字面值的解析和字符串处理操作

// tolit parses a literal (true/false/null)
func tolit(json: String): String {
    var i = 1
    while (i < json.size) {
        if (json[i] < b'a' || json[i] > b'z') {
            return json[..i]
        }
        i++
    }
    return json
}