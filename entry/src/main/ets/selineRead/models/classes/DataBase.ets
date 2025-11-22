import { relationalStore } from "@kit.ArkData";
import { BusinessError } from "@kit.BasicServicesKit";
import { XContext } from "commonpackage";
import { common } from "@kit.AbilityKit";
import { I_ZlibUserInfo } from "../../../zlibrary/interface/I_ZlibUserInfo";
import { ZlibUser, __ZlibUser__ } from "../../commons/shareDatas";
import { ZlibUserInfo } from "../../../zlibrary/classes/UserInfo";

export class RelationStoreManager{

  static async CreateDataBase(context:common.Context): Promise<relationalStore.RdbStore | undefined>{
    //数据库配置
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: 'SelineRead.db',
      securityLevel: relationalStore.SecurityLevel.S3,
      customDir: 'DataBase',
    };

    //建表
    return await relationalStore.getRdbStore(context, STORE_CONFIG).then(async (store)=>{
      console.info('成功获取数据库');
      let storeVersion = store.version;
      if (storeVersion === 0) {
        try {
          const ZlibraryAccountTable =
            'CREATE TABLE IF NOT EXISTS ZlibraryAccount (ID INTEGER PRIMARY KEY AUTOINCREMENT, Account TEXT KEY, Password TEXT, Cookie TEXT)';
          //创建表单
          await store.execute(ZlibraryAccountTable)
          storeVersion = 1
        } catch (e) {
          const err = e as BusinessError;
          console.error(`Failed to execute sql. Code:${err.code}, message:${err.message}`);
        }
      }
      store.version = storeVersion;
      return store
    }).catch((err:BusinessError)=>{
      console.error(`获取数据库失败. Code:${err.code}, message:${err.message}`);
      return undefined
    })

  }

  static async addValue(store:relationalStore.RdbStore|undefined,table:string,value:relationalStore.ValuesBucket){
    if (store) {
      try {
        const rowId = await store.insert(table, value);
        console.info(`成功插入数据rowId:${rowId}`);
      } catch (error) {
        const err = error as BusinessError;
        console.error(`插入数据失败 Code:${err.code}, message:${err.message}`);
      }
    }
  }

  static async getZlibAccount(store:relationalStore.RdbStore|undefined, needClear:boolean = true){
    if (store ) {
      await ((store as relationalStore.RdbStore).query(new relationalStore.RdbPredicates('ZlibraryAccount'), ['ID','Account', 'Password', 'Cookie']).then((resultSet)=>{
         {
           console.info(`ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
           if (needClear)
           {
             __ZlibUser__.zlibAccountArray.clearData()
           }
           while (resultSet.goToNextRow()) {
             const Id = resultSet.getLong(resultSet.getColumnIndex('ID'));
             const Account = resultSet.getString(resultSet.getColumnIndex('Account'));
             const Password = resultSet.getString(resultSet.getColumnIndex('Password'));
             const Cookie = resultSet.getString(resultSet.getColumnIndex('Cookie'));
             let userInfo:ZlibUserInfo = new ZlibUserInfo()
             userInfo.id = Id
             userInfo.account = Account
             userInfo.password = Password
             userInfo.cookie = Cookie
             __ZlibUser__.zlibAccountArray.pushData(userInfo)
           }
           resultSet.close();
         }
       }).catch((res:BusinessError)=>{
         console.log(`查询失败${JSON.stringify(res)}}`)
      })
      )
    }
  }

}