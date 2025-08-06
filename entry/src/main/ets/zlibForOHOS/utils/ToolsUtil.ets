export function dateGetTime(timestamp: number|string, time: boolean = true, date: boolean = true): string {
  try {
    let nowDate = new Date(timestamp);``
    let year = nowDate.getFullYear();
    let month = String(nowDate.getMonth() + 1).padStart(2, '0');
    let day = String(nowDate.getDate()).padStart(2, '0');
    let hours = String(nowDate.getHours()).padStart(2, '0');
    let minutes = String(nowDate.getMinutes()).padStart(2, '0');
    let seconds = String(nowDate.getSeconds()).padStart(2, '0');


    if (time && date) {
      return `${year}.${month}.${day} ${hours}:${minutes}:${seconds}`
    } else if (!time && date) {
      return `${year}.${month}.${day}`
    } else if (time && !date) {
      return `${hours}:${minutes}:${seconds}`
    } else {
      return ''
    }

  } catch {
    return 'Unknown'
  }

}