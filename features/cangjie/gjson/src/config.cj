package gjson

// 全局配置管理
// 集中管理所有可配置选项，提高代码的可维护性和一致性

// DisableEscapeHTML 控制是否禁用HTML转义
// 当设置为true时，不会将 >、<、& 字符转义为 \uXXXX 形式
public var DisableEscapeHTML: Bool = false

// DisableModifiers 控制是否禁用修饰符功能
// 当设置为true时，@修饰符将不会被解析和执行
public var DisableModifiers: Bool = false