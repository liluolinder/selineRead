export class StringFormat {
    static formatTimestamp(timestamp: number): string {
        if (timestamp.toString().length === 10) {
            timestamp *= 1000;
        }
        const date = new Date(timestamp);

        // 提取时间分量
        const year = date.getFullYear().toString();
        let month = (date.getMonth() + 1).toString(); // 月份+1
        let day = date.getDate().toString();
        let hour = date.getHours().toString();
        let minute = date.getMinutes().toString();
        let second = date.getSeconds().toString();

        // 单位数补零
        month = month.padStart(2, '0');
        day = day.padStart(2, '0');
        hour = hour.padStart(2, '0');
        minute = minute.padStart(2, '0');
        second = second.padStart(2, '0');

        // 拼接为 YYYY-MM-DD HH:mm:ss
        return `${year}-${month}-${day} ${hour}:${minute}:${second}`;
    }

    static formatMilliseconds(ms: number): string {
        const totalSeconds = Math.floor(ms / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const hh = hours.toString().padStart(2, '0');
        const mm = minutes.toString().padStart(2, '0');
        const ss = seconds.toString().padStart(2, '0');
        return hours > 0
            ? `${hh}:${mm}:${ss}`
            : `${mm}:${ss}`;
    }


    static formatSeconds(totalSeconds: number): string {
        totalSeconds = Math.round(totalSeconds)
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;

        // 格式化分钟和秒为两位数
        const mm = minutes.toString().padStart(2, '0');
        const ss = seconds.toString().padStart(2, '0');

        if (hours > 0) {
            const hh = hours.toString().padStart(2, '0');
            return `${hh}:${mm}:${ss}`; // 包含小时
        } else {
            return `${mm}:${ss}`; // 省略小时
        }
    }

    static formatNumber(numVal: number): string {
        if (numVal < 10000) {
            return numVal.toString();
        } else if (numVal < 10000000) {
            // 1万~1千万：舍弃后三位
            const temp = Math.floor(numVal / 1000); // 先舍弃后三位
            const value = temp / 10; // 转换为万单位
            let result = value.toFixed(1); // 保留1位小数
            if (result.endsWith('.0')) {
                result = result.slice(0, -2); // 移除".0"后缀
            }
            return result + 'w';
        } else {
            // 1千万以上：舍弃后六位
            const temp = Math.floor(numVal / 1000000); // 先舍弃后六位
            const value = temp / 10; // 转换为千万单位
            let result = value.toFixed(1); // 保留1位小数
            if (result.endsWith('.0')) {
                result = result.slice(0, -2); // 移除".0"后缀
            }
            return result + 'kw';
        }
    }

    static convertToMilliseconds(min: string, sec: string, ms: string): number {
        const minutes = parseInt(min, 10);
        const seconds = parseInt(sec, 10);
        const milliseconds = parseInt(ms, 10);
        return (minutes * 60 + seconds) * 1000 + milliseconds;
    }
}