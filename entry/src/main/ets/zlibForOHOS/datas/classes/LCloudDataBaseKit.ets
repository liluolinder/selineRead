import { cloudDatabase } from "@kit.CloudFoundationKit";
import { preferences } from "@kit.ArkData";

export class pushToken extends cloudDatabase.DatabaseObject{
  public naturalbase_ClassName(): string {
    return "pushToken";
  }

  public id: number | undefined;
  public pushToken: string | undefined;

}


export class LCloudDataBaseKit{

  databaseZone = cloudDatabase.zone('pushToken');

  async queryAllPushToken() {
    let condition:cloudDatabase.DatabaseQuery<pushToken> = new cloudDatabase.DatabaseQuery(pushToken);
    try {
      let resultArray = await this.databaseZone.query(condition);
      resultArray.forEach((item:pushToken)=>{
        console.log(`Liquid:${item.pushToken}`)
      })
    } catch (err) {
      console.log(`Liquid:${JSON.stringify(err)}`)
    }
  }

  async upsertPushToken(_pushToken:string) {
    try {
      let pushTokenItem:pushToken = new pushToken()

      pushTokenItem.pushToken = _pushToken

      let record = await this.databaseZone.upsert(pushTokenItem);
      console.log(`Liquid:Succeeded in upserting a book, result: ${JSON.stringify(record)}`);
    } catch (err) {
      console.log(`Liquid:Failed to upsert a book, code: ${err.code}, message: ${err.message}`);
    }
  }

}

export let linderCloudDataBase:LCloudDataBaseKit = new LCloudDataBaseKit()