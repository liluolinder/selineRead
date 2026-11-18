import { hvigor, HvigorPlugin } from '@ohos/hvigor';
import * as fs from 'fs';
import * as path from 'path';

const RESTORE_CANGJIE_ENTRY_TASK = 'RestoreCangjieEntry';
const GENERATE_CANGJIE_RESOURCE_TASKS = [
    'default@GenerateCangjieResource',
    'test@GenerateCangjieResource'
];
const COMPILE_CANGJIE_TASKS = [
    'default@CompileCangjie',
    'test@CompileCangjie'
];

export function restoreCangjieEntryPlugin(cangjieSourceDirectory: string): HvigorPlugin {
    const abilityEntryPath = path.join(cangjieSourceDirectory, 'ability_mainability_entry.cj');
    const completeAbilityEntry = fs.readFileSync(abilityEntryPath, 'utf8');

    return {
        pluginId: 'cjmp-restore-cangjie-entry',
        apply(node) {
            // Cangjie tasks are registered after all Hvigor nodes are evaluated.
            hvigor.nodesEvaluated(() => {
                const restoreCangjieEntry = () => {
                    fs.writeFileSync(abilityEntryPath, completeAbilityEntry, 'utf8');

                    const generatedStageEntryPath = path.join(
                        cangjieSourceDirectory,
                        `module_${node.getNodeName()}_entry.cj`
                    );
                    if (fs.existsSync(generatedStageEntryPath)) {
                        fs.unlinkSync(generatedStageEntryPath);
                    }
                };

                for (let i = 0; i < GENERATE_CANGJIE_RESOURCE_TASKS.length; i++) {
                    const generateTaskName = GENERATE_CANGJIE_RESOURCE_TASKS[i];
                    const compileTaskName = COMPILE_CANGJIE_TASKS[i];
                    const generateCangjieResourceTask = node.getTaskByName(generateTaskName);
                    const compileCangjieTask = node.getTaskByName(compileTaskName);
                    if (!generateCangjieResourceTask || !compileCangjieTask) {
                        continue;
                    }

                    node.registerTask({
                        name: RESTORE_CANGJIE_ENTRY_TASK,
                        dependencies: [generateTaskName],
                        run: restoreCangjieEntry
                    });

                    // Keep the restored source between generation and compilation. The compile
                    // hook is an idempotent guard against changes in task scheduling.
                    generateCangjieResourceTask.afterRun(restoreCangjieEntry);
                    compileCangjieTask.beforeRun(restoreCangjieEntry);
                    return;
                }
            });
        }
    };
}
