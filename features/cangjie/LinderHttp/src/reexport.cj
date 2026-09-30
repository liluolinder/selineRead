package linderHttp

/*
 * 顶层包只做一件事：把 `linderHttp.http` 的全部公开类型再导出。
 *
 * 这样使用方有且只有一种导入写法：
 *   import linderHttp.*
 * 既拿到 HttpClient / Response 等核心类型，也拿到 LinderHttp 一行式入口。
 */

public import linderHttp.http.*
