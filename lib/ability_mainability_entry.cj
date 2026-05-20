package ohos_app_cangjie_entry

import ohos.app.ability.ui_ability.UIAbility

let ENTRYABILITY_REGISTER_RESULT = UIAbility.registerCreator("EntryAbility", {=> MainAbility()})
