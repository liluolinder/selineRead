/*
Copyright (c) 2025 琉离铟落linder
SelineRead is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan
PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY
KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
NON-INFRINGEMENT, MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details.

Mulan Permissive Software License，Version 2

Mulan Permissive Software License，Version 2 (Mulan PSL v2)

January 2020 http://license.coscl.org.cn/MulanPSL2
 */


import { relationalStore } from "@kit.ArkData"

@ObservedV2
export class Notification{
  @Trace id:number=0
}
export let  __Notification__:Notification = new Notification()

@ObservedV2
export class SysShareData{
  @Trace currentBreakpoint:string=''
  @Trace bottomRectHeight:number=0
  @Trace topRectHeight:number=0
}
export let  __System__:SysShareData = new SysShareData()

@ObservedV2
export class UserShareData{

  @Trace avatar:ResourceStr=''
  @Trace isLoginZlib:boolean=true
  @Trace zlibAccount:string=''
  @Trace zlibPassword:string=''

}
export let  __User__:UserShareData = new UserShareData()


@ObservedV2
export class DataBaseShareData{

  @Trace baseStore:relationalStore.RdbStore|undefined


}
export let  __DataBase__:DataBaseShareData = new DataBaseShareData()
