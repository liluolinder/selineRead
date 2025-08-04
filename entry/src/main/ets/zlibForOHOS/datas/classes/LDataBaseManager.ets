import { relationalStore } from "@kit.ArkData";
import { I_RelationalStoreDataBaseConfig,
  I_RelationalStoreDataBaseKV,
  I_RelationalStoreDataBaseTableForm } from "../interfaces/I_LDataBaseManager";
import { BusinessError } from "@kit.BasicServicesKit";
import { Context } from "@ohos.abilityAccessCtrl";
import { RelationalStoreDataBaseTableType } from "../enums/RelationalStoreDataBaseTableType";
import { JSON } from "@kit.ArkTS";

export class LDataBaseManager {

   private  generateTableForm(tableForms: I_RelationalStoreDataBaseTableForm[]): string {
    let res: string = ''
    let tempRes: string = ''
    let typeRes: string = ''
    tableForms.forEach((item: I_RelationalStoreDataBaseTableForm, index: number) => {
      switch (item.type) {
        case RelationalStoreDataBaseTableType.TEXT:
          typeRes = 'TEXT'
          break;
        case RelationalStoreDataBaseTableType.INTEGER:
          typeRes = 'INTEGER'
          break;
        case RelationalStoreDataBaseTableType.REAL:
          typeRes = 'REAL'
          break;
        case RelationalStoreDataBaseTableType.BLOB:
          typeRes = 'BLOB'
          break;
        case RelationalStoreDataBaseTableType.NULL:
          typeRes = 'NULL'
          break;
        default:
          typeRes = ''
          break;
      }

      tempRes = `${item.key + ' '}${typeRes + ' '}${item.canNull ? '' : 'NOT NULL '}${item.isKey ? 'PRIMARY KEY ' :
        ''}${item.needAutoIncrement ? 'AUTOINCREMENT ' : ''}`

      res += `${tempRes}${index == tableForms.length - 1 ? "" : ", "}`

    })
    return res.replaceAll(" ,", ",").trim()
  }

  async createRelationalStoreDataBase(context: Context,
    Config: I_RelationalStoreDataBaseConfig): Promise<relationalStore.RdbStore | undefined> {
    let resStore: relationalStore.RdbStore | undefined

    const STORE_CONFIG: relationalStore.StoreConfig = {
      // 数据库文件名
      name: Config.dataBaseName,
      // 数据库安全级别,默认为S3
      securityLevel: Config.securityLevel ?? relationalStore.SecurityLevel.S3,
      // 可选参数，指定数据库是否加密，默认不加密
      encrypt: Config.encrypt ?? false,
      // 可选参数，数据库自定义路径。默认在本应用沙箱目录下创建RdbStore实例。
      customDir: Config.customDir,
      // 可选参数，指定数据库是否以只读方式打开。默认为false，表示数据库可读可写。为true时，只允许从数据库读取数据，不允许对数据库进行写操作，否则会返回错误码801。
      isReadOnly: false,
      // 可选参数，指定用户在全文搜索场景(FTS)下使用哪种分词器。默认在FTS下仅支持英文分词，不支持其他语言分词。
      tokenizer: Config.tokenizer
    };

     await relationalStore.getRdbStore(context, STORE_CONFIG).then((store)=>{
       console.info('FUCK:Succeeded in getting RdbStore.');
       resStore = store
     }).catch((err:BusinessError)=>{
       console.error(`FUCK:Failed to get RdbStore. Code:${err.code}, message:${err.message}`);
       return;
     })
    return resStore;
  }

  async createTableForRelationDataBase(store: relationalStore.RdbStore | undefined, TableName: string,
    tableForms: I_RelationalStoreDataBaseTableForm[]) {
    if (store) {
      const SQL_CREATE_TABLE =
        `CREATE TABLE IF NOT EXISTS ${TableName} (${this.generateTableForm(tableForms)})`;
      console.log(`FUCK${SQL_CREATE_TABLE}`)
      let storeVersion = store.version;
      // 当数据库创建时，数据库默认版本为0
      if (storeVersion === 0) {
        try {
          await store.execute(SQL_CREATE_TABLE); // 创建数据表，以便后续调用insert接口插入数据
          storeVersion = 1;
          console.log(`FUCK:succeed create table`)
          // 设置数据库的版本，入参为大于0的整数
        } catch (e) {
          const err = e as BusinessError;
          console.error(`FUCK:Failed to execute sql. Code:${err.code}, message:${err.message}`);
        }
      }
      store.version = storeVersion;
    } else {
      console.error("FUCK:数据库不存在")
    }
  }

  async insertValueToRelationalDataBase(store: relationalStore.RdbStore | undefined, TableName: string,
    valueBucket: relationalStore.ValuesBucket) {
    /*{
  NAME: value1,
  AGE: value2,
  SALARY: value3,
  CODES: value4,
  IDENTITY: value5,
   };*/
    if (store !== undefined) {
      try {
        const rowId = await store.insert(`${TableName}`, valueBucket);
        console.info(`FUCK:Succeeded in inserting data. rowId:${rowId}`);
      } catch (error) {
        const err = error as BusinessError;
        console.error(`FUCK:Failed to insert data. Code:${err.code}, message:${err.message}`);
      }
    }
  }

  async updateValueToRelationalDataBase(store: relationalStore.RdbStore | undefined, TableName: string,
    equalRules: I_RelationalStoreDataBaseKV[],
    valueBucket: relationalStore.ValuesBucket) {
    let predicates = new relationalStore.RdbPredicates(TableName);
    equalRules.forEach((item) => {
      predicates.equalTo(item.key, item.value)
    })

    if (store !== undefined) {
      (store as relationalStore.RdbStore).update(valueBucket, predicates, (err: BusinessError, rows: number) => {
        if (err) {
          console.error(`FUCK:Failed to update data. Code:${err.code}, message:${err.message}`);
          return;
        }
        console.info(`FUCK:Succeeded in updating data. row count: ${rows}`);
      })
    }
  }

  async deleteValueToRelationalDataBase(store: relationalStore.RdbStore | undefined, TableName: string,
    equalRules: I_RelationalStoreDataBaseKV[],) {
    let predicates = new relationalStore.RdbPredicates(TableName);
    equalRules.forEach((item) => {
      predicates.equalTo(item.key, item.value)
    });
    if (store !== undefined) {
      (store as relationalStore.RdbStore).delete(predicates, (err: BusinessError, rows: number) => {
        if (err) {
          console.error(`FUCK:Failed to delete data. Code:${err.code}, message:${err.message}`);
          return;
        }
        console.info(`FUCK:Delete rows: ${rows}`);
      })
    }
  }

  async queryValueToRelationalDataBase(store: relationalStore.RdbStore | undefined, TableName: string,
    equalRules: I_RelationalStoreDataBaseKV[], needReturnValue: I_RelationalStoreDataBaseTableForm[]) : Promise<string>
  {

    let jsonArray:object[]=[]
    let needReturnValueStringArray:string[]=[]
    let getValue:relationalStore.ValueType
    needReturnValue.forEach((item)=>{
      needReturnValueStringArray.push(item.key)
    })

    let predicates = new relationalStore.RdbPredicates(TableName);
    equalRules.forEach((item) => {
      predicates.equalTo(item.key, item.value)
    });
    if (store !== undefined) {
       await (store as relationalStore.RdbStore).query(predicates, needReturnValueStringArray)
         .then((resultSet)=>{
           console.info(`FUCK:ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
           // resultSet是一个数据集合的游标，默认指向第-1个记录，有效的数据从0开始。
           while (resultSet.goToNextRow()) {
             let obj:object = new Object
             needReturnValue.forEach((item)=>{
               switch (item.type) {
                 case RelationalStoreDataBaseTableType.TEXT:
                   getValue = resultSet.getString(resultSet.getColumnIndex(item.key));
                   break;
                 case RelationalStoreDataBaseTableType.INTEGER:
                   getValue = resultSet.getLong(resultSet.getColumnIndex(item.key));
                   break;
                 case RelationalStoreDataBaseTableType.REAL:
                   getValue =  resultSet.getDouble(resultSet.getColumnIndex(item.key));
                   break;
                 case RelationalStoreDataBaseTableType.BLOB:
                   getValue = resultSet.getValue(resultSet.getColumnIndex(item.key));
                   break;
                 case RelationalStoreDataBaseTableType.NULL:
                   getValue = resultSet.getValue(resultSet.getColumnIndex(item.key));
                   break;
                 default:
                   break;
               }
               obj[item.key]=getValue
             })
             jsonArray.push(obj)
           }
           // 释放数据集的内存
           resultSet.close();
         }).catch((err:BusinessError)=>{
         if (err) {
           console.error(`FUCK:Failed to query data. Code:${err.code}, message:${err.message}`);
           return;
         }
       })
    }
    console.log(`FUCK${JSON.stringify(jsonArray)}`)
    return JSON.stringify(jsonArray);
  }
}

export let linderDataBaseManger:LDataBaseManager = new LDataBaseManager()