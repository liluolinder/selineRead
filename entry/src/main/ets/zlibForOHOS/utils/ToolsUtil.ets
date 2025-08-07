import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { fileUri } from '@kit.CoreFileKit';
import { globlContext } from '../../entryability/EntryAbility';

export function dateGetTime(timestamp: number|string, time: boolean = true, date: boolean = true): string {
  try {
    let nowDate = new Date(timestamp);
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



export function shareBook(path: string){

   const getUtdForm = (fileName:string): utd.UniformDataType =>
  {
    let fileSuffix:string[] = fileName.split('.')

    switch (fileSuffix[fileSuffix.length-1].toLowerCase())
    {
      case 'pdf':
        return utd.UniformDataType.PDF
      case 'epub':
        return utd.UniformDataType.EPUB
      case 'azw3':
        return utd.UniformDataType.AZW3
      case 'text': case 'txt':
      return utd.UniformDataType.TEXT
      default :
        return utd.UniformDataType.EBOOK
    }

  }

  let data: systemShare.SharedData = new systemShare.SharedData({
    utd: getUtdForm(path),
    title: new fileUri.FileUri(path).name,
    uri: new fileUri.FileUri(path).toString()
  });

  let controller: systemShare.ShareController = new systemShare.ShareController(data);

  controller.show(globlContext as common.UIAbilityContext, {
    previewMode: systemShare.SharePreviewMode.DETAIL,
    selectionMode: systemShare.SelectionMode.SINGLE
  });
}