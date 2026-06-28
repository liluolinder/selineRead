/**
    Author: ystyle
    Description: A Cangjie package used to read project metadata from cjpm.toml at compile time.
    Link: local cjpmInfo metadata reader
*/
macro package ignite.api2.GetData.cjpmInfo

import std.ast.*
import std.fs.{File, OpenMode, Path}
import std.env.getVariable
import std.io.readToEnd
import std.process.executeWithOutput

class Module {
    Module(
        let cjc_version:String,
        let organization:String,
        let name:String,
        let description:String,
        let version:String,
        let output_type:String
    ) {

    }
}

var d:?Module= None
var loaded = false

// 简单解析 TOML 文件的 [package] 部分
func parseTomlValue(content: String, key: String): String {
    let lines = content.split("\n")
    var inPackage = false
    for (line in lines) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("[package]")) {
            inPackage = true
        } else if (trimmed.startsWith("[")) {
            inPackage = false
        } else if (inPackage && trimmed.startsWith("${key}")) {
            // 解析 key = "value" 格式
            let parts = trimmed.split("=")
            if (parts.size >= 2) {
                var value = parts[1].trimAscii()
                // 去掉引号
                if (value.size >= 2 && value.startsWith("\"") && value.endsWith("\"")) {
                    return value[1..value.size - 1]
                }
            }
        }
    }
    return ""
}

func getModule():?Module {
    if (loaded) {
        return d
    }

    // 从环境变量获取项目目录
    let pwd = match (getVariable("PWD")) {
        case Some(v) => v
        case _ => "."
    }
    let fs = File(Path(pwd).join("cjpm.toml"), OpenMode.Read)
    let bs = readToEnd(fs)
    let content = String.fromUtf8(bs)

    let cjc_version = parseTomlValue(content, "cjc-version")
    let organization = ""  // TOML 中没有这个字段
    let name = parseTomlValue(content, "name")
    let description = parseTomlValue(content, "description")
    let version = parseTomlValue(content, "version")
    let output_type = parseTomlValue(content, "output-type")

    d = Module(cjc_version, organization, name, description, version, output_type)
    loaded = true
    return d
}

public macro ModuleVer(inputs:Tokens):Tokens {
    let m = getModule()
    let vsersion = m?.version ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, vsersion)
}

public macro ModuleOrg(inputs:Tokens):Tokens {
    let m = getModule()
    let vsersion = m?.organization ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, vsersion)
}

public macro ModuleCjv(inputs:Tokens):Tokens {
    let m = getModule()
    let vsersion = m?.cjc_version ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, vsersion)
}

public macro ModuleName(inputs:Tokens):Tokens {
    let m = getModule()
    let vsersion = m?.name ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, vsersion)
}

public macro ModuleDesc(inputs:Tokens):Tokens {
    let m = getModule()
    let vsersion = m?.description ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, vsersion)
}

func getCommandVersion(cmd: String): ?String {
    try {
        let (exitCode, stdout, _) = executeWithOutput(cmd, ["-v"])
        if (exitCode == 0) {
            let output = String.fromUtf8(stdout)
            let lines = output.split("\n")
            if (lines.size > 0) {
                let firstLine = lines[0]
                let colonIndex = firstLine.indexOf(":")
                if (let Some(idx) <- colonIndex) {
                    let version = firstLine[idx + 1..firstLine.size]
                    return version.trimAscii()
                }
                return firstLine.trimAscii()
            }
        }
    } catch (e: Exception) {
        // 命令执行失败，返回 None
    }
    return None
}

func executeGitCommand(args: Array<String>): ?String {
    try {
        let (exitCode, stdout, _) = executeWithOutput("git", args)
        if (exitCode == 0) {
            let output = String.fromUtf8(stdout)
            return output.trimAscii()
        }
    } catch (e: Exception) {
        // 命令执行失败，返回 None
    }
    return None
}

public macro CjcVersion(inputs: Tokens): Tokens {
    let version = getCommandVersion("cjc") ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, version)
}

public macro CjpmVersion(inputs: Tokens): Tokens {
    let version = getCommandVersion("cjpm") ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, version)
}

public macro GitTag(inputs: Tokens): Tokens {
    let tag = executeGitCommand(["describe", "--tags", "--abbrev=0"]) ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, tag)
}

public macro GitCommitId(inputs: Tokens): Tokens {
    let commitId = executeGitCommand(["rev-parse", "HEAD"]) ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, commitId)
}

public macro GitCommitIdShort(inputs: Tokens): Tokens {
    let commitId = executeGitCommand(["rev-parse", "--short", "HEAD"]) ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, commitId)
}

public macro GitBranch(inputs: Tokens): Tokens {
    let branch = executeGitCommand(["rev-parse", "--abbrev-ref", "HEAD"]) ?? inputs[0].value
    return Tokens() + Token(STRING_LITERAL, branch)
}
