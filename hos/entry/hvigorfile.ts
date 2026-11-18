import { hapTasks } from '@ohos/hvigor-ohos-plugin';
import * as path from 'path';
import { restoreCangjieEntryPlugin } from '../restore-cangjie-entry';

export default {
    system: hapTasks,  /* Built-in plugin of Hvigor. It cannot be modified. */
    plugins: [restoreCangjieEntryPlugin(path.resolve(__dirname, '../../lib/common'))]
}
