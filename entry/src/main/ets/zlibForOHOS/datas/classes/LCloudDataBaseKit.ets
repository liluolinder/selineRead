import { cloudDatabase } from "@kit.CloudFoundationKit";
import { preferences, ValueType } from "@kit.ArkData";
import { CloudDataBaseType } from "../enums/CloudDataBaseType";
import { addLog } from "../../utils/ToolsUtil";

export class pushToken extends cloudDatabase.DatabaseObject{
  public naturalbase_ClassName(): string {
    return "pushToken";
  }

  public pushToken: string | undefined;
  public needGetNewAPI: boolean | undefined;
}

export class LCloudDataBaseKit<T extends cloudDatabase.DatabaseObject>{
  databaseZone?:cloudDatabase.DatabaseZone
  type?:CloudDataBaseType

  constructor(databaseZone:string) {
    this.databaseZone = cloudDatabase.zone(databaseZone);
  }

  async query(condition:cloudDatabase.DatabaseQuery<T>) :Promise<T[]>
  {
    try {
      let resultArray:T[] = await this.databaseZone?.query(condition) as T[];
      addLog('云数据库',`成功查询，结果为: ${JSON.stringify(resultArray)}`)
      return resultArray
    } catch (err) {
      addLog('云数据库',`查询错误code: ${err.code}, message: ${err.message}`,true)
      return []
    }
  }

  async upsert(record:T | T[]) {
    try {
      let recordInfo = await this.databaseZone?.upsert(record);
      addLog('云数据库',`成功插入/更新数据: ${JSON.stringify(recordInfo)}`)
    } catch (err) {
      addLog('云数据库',`插入/更新数据失败: ${err.code}, message: ${err.message}`,true)
    }
  }
}

export let pushTokenDataBase:LCloudDataBaseKit<pushToken> = new LCloudDataBaseKit<pushToken>('pushToken')