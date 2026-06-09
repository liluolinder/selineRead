package selineDownload

import std.collection.HashMap
import std.sync.Mutex

/**
 * 下载管理器
 * 管理多个下载任务
 */
public class DownloadManager {
    private let tasks: HashMap<String, DownloadTask> = HashMap<String, DownloadTask>()
    private let mutex: Mutex = Mutex()

    public init() {}

    /**
     * 创建下载任务
     * @param taskId 任务ID
     * @param config 下载配置
     * @return 下载任务对象
     */
    public func createTask(taskId: String, config: DownloadConfig): DownloadTask {
        synchronized(mutex) {
            let task = DownloadTask(config)
            tasks[taskId] = task
            task
        }
    }

    /**
     * 获取下载任务
     * @param taskId 任务ID
     * @return 下载任务对象,不存在返回None
     */
    public func getTask(taskId: String): ?DownloadTask {
        synchronized(mutex) {
            tasks.get(taskId)
        }
    }

    /**
     * 删除下载任务
     * @param taskId 任务ID
     * @return 是否删除成功
     */
    public func removeTask(taskId: String): Bool {
        synchronized(mutex) {
            if (tasks.contains(taskId)) {
                tasks.remove(taskId)
                true
            } else {
                false
            }
        }
    }

    /**
     * 获取所有任务ID
     * @return 任务ID数组
     */
    public func getAllTaskIds(): Array<String> {
        synchronized(mutex) {
            tasks.keys().toArray()
        }
    }

    /**
     * 取消所有任务
     */
    public func cancelAll(): Unit {
        synchronized(mutex) {
            for ((_, task) in tasks) {
                task.cancel()
            }
            tasks.clear()
        }
    }

    /**
     * 暂停所有任务
     */
    public func pauseAll(): Unit {
        synchronized(mutex) {
            for ((_, task) in tasks) {
                task.pause()
            }
        }
    }

    /**
     * 恢复所有任务
     */
    public func resumeAll(): Unit {
        synchronized(mutex) {
            for ((_, task) in tasks) {
                task.resume()
            }
        }
    }
}
