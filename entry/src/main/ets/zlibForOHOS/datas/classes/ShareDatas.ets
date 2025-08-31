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


import { relationalStore } from '@kit.ArkData'
import { zlibIndexShowMod } from '../enums/zlibIndexShowMod'
import { window } from '@kit.ArkUI'
import { LogLine } from '../../pages/personal/pages/LoggerPage'

@ObservedV2
export class Notification {
  @Trace id: number = 0
}

export let __Notification__: Notification = new Notification()

@ObservedV2
export class SysShareData {
  @Trace currentBreakpoint: string = ''
  @Trace bottomRectHeight: number = 0
  @Trace leftRectHeight: number = 0
  @Trace rightRectHeight: number = 0
  @Trace topRectHeight: number = 0
  @Trace windowWidth: number = 0
  @Trace windowHeight: number = 0
  @Trace windowState: window.WindowStatusType = window.WindowStatusType.UNDEFINED
  @Trace pcMode: boolean = false
}

export let __System__: SysShareData = new SysShareData()

@ObservedV2
export class UserShareData {
  @Trace avatar: ResourceStr = ''
  @Trace isLoginZlib: boolean = true
  @Trace zlibAccount: string = ''
  @Trace zlibPassword: string = ''
}

export let __User__: UserShareData = new UserShareData()


@ObservedV2
export class DataBaseShareData {
  @Trace baseStore: relationalStore.RdbStore | undefined
}

export let __DataBase__: DataBaseShareData = new DataBaseShareData()

@ObservedV2
export class Logger {
  @Trace logs: LogLine[] = []
}

export let __Logger__: Logger = new Logger()

@ObservedV2
export class UIShareData {
  @Trace isInReader: boolean = false
  @Trace isHaveOpenBook: boolean = false
  @Trace isInSearchMode: boolean = false
  @Trace searchOrRecommend: zlibIndexShowMod = zlibIndexShowMod.Recommend
  @Trace currentColorMode: number = 1
  indexPageStack: NavPathStack = new NavPathStack()
  @Trace onlineMode: boolean = false
  @Trace showSettings: boolean = false
  @Trace showLogger: boolean = false
}

export let __UI__: UIShareData = new UIShareData()

export const minHeight = 600

export const minWidth = 700
