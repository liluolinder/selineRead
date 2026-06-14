import { relationalStore } from "@kit.ArkData";
import { BusinessError } from "@kit.BasicServicesKit";
import { common } from "@kit.AbilityKit";
import { __Download__, __ZlibUser__ } from "../../commons/shareDatas";
import { ZlibUserInfo } from "../../../zlibrary/classes/UserInfo";
import { DownloadInfo, DownloadStatus } from "./DownloadInfo";
import { ZlibServiceAddress, ZlibServiceStatus } from "./ZlibServiceAddress";
import { XContext } from "commonpackage";
import { add } from "color";


export class RelationStoreManager {
  static async CreateDataBase(context: common.Context): Promise<relationalStore.RdbStore | undefined> {
    //数据库配置
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: 'SelineRead.db',
      securityLevel: relationalStore.SecurityLevel.S3,
      customDir: 'DataBase',
    };

    //建表
    return await relationalStore.getRdbStore(context, STORE_CONFIG).then(async (store) => {
      console.info('成功获取数据库');
      let storeVersion = store.version;
      if (storeVersion === 0) {
        try {
          const ZlibraryAccountTable =
            'CREATE TABLE IF NOT EXISTS ZlibraryAccount (ID INTEGER PRIMARY KEY AUTOINCREMENT, Account KEY TEXT , Password TEXT, Cookie TEXT)';
          //创建表单
          await store.execute(ZlibraryAccountTable).then((res) => {
            console.log('创建ZlibraryAccountTable结果为' + JSON.stringify(res))
          })
          storeVersion = 1
        } catch (e) {
          const err = e as BusinessError;
          console.error(`Failed to execute sql. Code:${err.code}, message:${err.message}`);
        }
      }
      if (storeVersion == 1 || storeVersion == 2) {
        try {
          const DownloadTable =
            'CREATE TABLE IF NOT EXISTS ZlibDownloadTable (ID INTEGER PRIMARY KEY AUTOINCREMENT, BookID INTEGER, ' +
              'BookHref TEXT, BookName TEXT, BookAuthor TEXT, BookPublisher TEXT, BookImage TEXT, BookDownLoadTime TEXT, HaveDownload INTEGER)'
          //创建表单
          await store.execute(DownloadTable).then((res) => {
            console.log("创建ZlibDownloadTable结果为" + JSON.stringify(res))
          })

          storeVersion = 3
        } catch (e) {
          const err = e as BusinessError;
          console.error(`Failed to execute sql. Code:${err.code}, message:${err.message}`);
        }
      }
      if (storeVersion == 3) {
        try {
          const ZlibServiceUrlTable =
            'CREATE TABLE IF NOT EXISTS ZlibServiceUrl (ID INTEGER PRIMARY KEY AUTOINCREMENT, Url TEXT)'
          //创建表单
          await store.execute(ZlibServiceUrlTable).then(async (res) => {
            console.log("创建ZlibServiceUrlTable结果为" + JSON.stringify(res))
            RelationStoreManager.addValue(store, 'ZlibServiceUrl', {
              Url:'https://zh.zlibraryd.ru/'
            })
          })
          storeVersion = 4
        } catch (e) {
          const err = e as BusinessError;
          console.error(`Failed to execute sql. Code:${err.code}, message:${err.message}`);
        }
      }
      store.version = storeVersion
      return store
    }).catch((err: BusinessError) => {
      console.error(`获取数据库失败. Code:${err.code}, message:${err.message}`);
      return undefined
    })

  }

  static async addValue(store: relationalStore.RdbStore | undefined, table: string,
    value: relationalStore.ValuesBucket) {
    if (store) {
      try {
        const rowId = await store.insert(table, value);
        console.info(`成功插入数据rowId:${rowId}`);
      } catch (error) {
        const err = error as BusinessError;
        console.error(`插入数据失败 Code:${err.code}, message:${err.message}`);
      }
    }else{
      console.error(`插入数据失败 数据库对象不存在`);
    }
  }

  static async updateValue(store: relationalStore.RdbStore | undefined, predicates: relationalStore.RdbPredicates,
    value: relationalStore.ValuesBucket) {
    if (store !== undefined) {
      (store as relationalStore.RdbStore).update(value, predicates, (err: BusinessError, rows: number) => {
        if (err) {
          console.error(`更新数据失败 Code:${err.code}, message:${err.message}`);
          return;
        }
        console.info(`成功更新数据. row count: ${rows}`);
      })
    }
  }

  static async deleteValue(store: relationalStore.RdbStore | undefined, predicates: relationalStore.RdbPredicates) {
    if (store !== undefined) {
      (store as relationalStore.RdbStore).delete(predicates, (err: BusinessError, rows: number) => {
        if (err) {
          console.error(`删除失败Code:${err.code}, message:${err.message}`);
          return;
        }
        console.info(`删除成功 rows: ${rows}`);
      })
    }
  }

  static async getZlibAccount(store: relationalStore.RdbStore | undefined, needClear: boolean = true) {
    if (store) {
      await ((store as relationalStore.RdbStore).query(new relationalStore.RdbPredicates('ZlibraryAccount'),
        ['ID', 'Account', 'Password', 'Cookie']).then((resultSet) => {
        {
          console.info(`ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
          if (needClear) {
            __ZlibUser__.zlibAccountArray.clearData()
          }
          while (resultSet.goToNextRow()) {
            const Id = resultSet.getLong(resultSet.getColumnIndex('ID'));
            const Account = resultSet.getString(resultSet.getColumnIndex('Account'));
            const Password = resultSet.getString(resultSet.getColumnIndex('Password'));
            const Cookie = resultSet.getString(resultSet.getColumnIndex('Cookie'));
            let userInfo: ZlibUserInfo = new ZlibUserInfo()
            userInfo.id = Id
            userInfo.account = Account
            userInfo.password = Password
            userInfo.cookie = Cookie

            if (userInfo.account == __ZlibUser__.account && userInfo.password == __ZlibUser__.password) {
              __ZlibUser__.zlibClient.login(userInfo.account, userInfo.password, (res) => {
                __ZlibUser__.localChooseAccount = res
                userInfo.userName = res.name
                userInfo.userDownloadLimitNumber =
                  `${res.todayDownloadNum}/${res.downloadLimit}`
                userInfo.userAvatar = ''
                __ZlibUser__.userName = res.name
                __ZlibUser__.avatar = ''
              },(error)=>{
                XContext.toast(error)
              })
            }

            __ZlibUser__.zlibAccountArray.pushData(userInfo)
          }
          resultSet.close();
        }
      }).catch((res: BusinessError) => {
        console.log(`查询失败${JSON.stringify(res)}`)
      })
      )
    }
  }

  static async getZlibDownload(store: relationalStore.RdbStore | undefined) {
    if (store) {
      await ((store as relationalStore.RdbStore).query(new relationalStore.RdbPredicates('ZlibDownloadTable'),
        ['ID', 'BookID', 'BookHref', 'BookName', 'BookAuthor', 'BookPublisher', 'BookImage', 'BookDownLoadTime',
          'HaveDownload']).then((resultSet) => {
        {
          console.info(`ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
          while (resultSet.goToNextRow()) {
            const bookId = resultSet.getLong(resultSet.getColumnIndex('BookID'));
            const bookHref = resultSet.getString(resultSet.getColumnIndex('BookHref'));
            const bookName = resultSet.getString(resultSet.getColumnIndex('BookName'));
            const bookAuthor = resultSet.getString(resultSet.getColumnIndex('BookAuthor'));
            const bookPublisher = resultSet.getString(resultSet.getColumnIndex('BookPublisher'));
            const bookImage = resultSet.getString(resultSet.getColumnIndex('BookImage'));
            const bookDownloadTime = resultSet.getString(resultSet.getColumnIndex('BookDownLoadTime'));
            const haveDownload = resultSet.getLong(resultSet.getColumnIndex('HaveDownload'));
            let item: DownloadInfo = new DownloadInfo()
            item.fileName = bookName
            item.fileImage = bookImage
            item.bookAuthor = bookAuthor
            item.bookHref = bookHref
            item.bookId = bookId
            item.downloadTime = bookDownloadTime
            item.status = (haveDownload == 1 ? DownloadStatus.Complete : DownloadStatus.Failed)
            __Download__.downloadArray.pushUnshiftData(item)
          }
          resultSet.close();
        }
      }).catch((res: BusinessError) => {
        console.log(`查询失败${JSON.stringify(res)}`)
      })
      )
    } else {
      console.log(`数据库错误`)
    }
  }

  static async getZlibServerAddress(store: relationalStore.RdbStore | undefined) {
    if (store) {
      await ((store as relationalStore.RdbStore).query(new relationalStore.RdbPredicates('ZlibServiceUrl'),
        ['ID', 'Url']).then((resultSet) => {
        {
          console.info(`ResultSet column names: ${resultSet.columnNames}, column count: ${resultSet.columnCount}`);
          while (resultSet.goToNextRow()) {
            const id = resultSet.getLong(resultSet.getColumnIndex('ID'));
            const url = resultSet.getString(resultSet.getColumnIndex('Url'));
            let address:ZlibServiceAddress = new ZlibServiceAddress(url, ZlibServiceStatus.Unknown)
            address.id = id
            __ZlibUser__.zlibServiceAddressArray.push(address)

          }
          console.log(JSON.stringify(__ZlibUser__.zlibServiceAddressArray))
          resultSet.close();
        }

      }).catch((res: BusinessError) => {
        console.log(`查询失败${JSON.stringify(res)}`)
      })
      )
    } else {
      console.log(`数据库错误`)
    }

  }
}

