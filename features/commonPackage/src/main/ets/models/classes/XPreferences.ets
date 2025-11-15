/*
 * 㣻 封装
 */

import preferences from '@ohos.data.preferences'

class XPreferences {
    // 创建一个Map类型用来存储pref的name,和pref
    prefMap: Map<string, preferences.Preferences> = new Map()

    // 加载Preferences
    localPreferences(context: Context, name: string) {
        // 获取pref，返回的是一个Promise
        let pref = preferences.getPreferencesSync(context, { name: name })
        // 将Pref填入PrefMap中
        this.prefMap.set(name, pref)
    }

    // 放Preferences数据
    putPreferencesValue(name: string, key: string, value: preferences.ValueType) {
        // 从Map中获取pref
        let pref = this.prefMap.get(name)
        // 在pref中添加
        pref?.putSync(key, value)
        // 将pref输入磁盘中
        pref?.flushSync()
    }

    // 读Preferences数据
    getPreferencesValue(name: string, key: string, defaultValue: preferences.ValueType) {

        // 从map中获取pref
        let pref = this.prefMap.get(name)
        return pref?.getSync(key, defaultValue)
    }

    //删Preferences数据
    deletePreferencesValue(name: string, key: string,) {
        // 从map中获取pref
        let pref = this.prefMap.get(name)
        pref?.deleteSync(key)
    }

    // 检查Preferences中是否存在特定的键
    hasPreferencesValue(name: string, key: string, defaultValue: preferences.ValueType): boolean {
        // 从map中获取pref
        let pref = this.prefMap.get(name);
        if (pref) {
            // 尝试获取键的值，如果返回的是默认值，则键不存在
            const value = pref.getSync(key, defaultValue);
            return value !== defaultValue;
        }
        return false;
    }
}

export let XPreferencesManager: XPreferences = new XPreferences()

