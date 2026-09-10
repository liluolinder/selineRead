package linderHttp

/**
 * 文件冲突处理策略
 * 
 * 定义当目标文件已存在时的处理方式。
 */
public enum ConflictMethod {
    | OverWrite  // 覆盖现有文件
    | Harmony    // 自动重命名（如 file.txt → file(1).txt）
}
