import { relationalStore } from "@kit.ArkData"
import { RelationalStoreDataBaseTableType } from "../enums/RelationalStoreDataBaseTableType"


export interface I_RelationalStoreDataBaseConfig{
  // 数据库文件名
  dataBaseName:string
  // 数据库安全级别，默认为S3
  securityLevel?:relationalStore.SecurityLevel
  // 可选参数，指定数据库是否加密，默认不加密
  encrypt?:boolean
  // 可选参数，数据库自定义路径。默认在本应用沙箱目录下创建RdbStore实例。
  customDir?:string
  // 可选参数，指定数据库是否以只读方式打开。默认为false，表示数据库可读可写。为true时，只允许从数据库读取数据，不允许对数据库进行写操作，否则会返回错误码801。
  isReadOnly?:boolean
  //分词选项
  tokenizer?:relationalStore.Tokenizer
}

export interface I_RelationalStoreDataBaseTableForm{
  key:string
  needAutoIncrement:boolean
  isKey:boolean
  canNull:boolean
  type:RelationalStoreDataBaseTableType
}

export interface I_RelationalStoreDataBaseKV{
  key:string
  value:relationalStore.ValueType
}



