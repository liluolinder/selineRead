import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { common } from '@kit.AbilityKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { globlContext } from '../../entryability/EntryAbility';
import { __Logger__, __UI__ } from '../datas/classes/ShareDatas';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { buffer, util } from '@kit.ArkTS';


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


export function setContinueState(allowContinue: boolean, currentViewingType: 'book'|'bookList'|'home', currentBookData: string, currentBookListData: string){
  __UI__.currentViewingType = currentViewingType
  __UI__.currentBookData = currentBookData
  __UI__.currentBookListData = currentBookListData
  try{
    const context = globlContext as common.UIAbilityContext
    context.setMissionContinueState(allowContinue? 0: 1)
  }catch{}
}

export async function selectImage(): Promise<string | undefined> {
  return new Promise<string | undefined>(async (resolve) => {
    let photoPicker = new photoAccessHelper.PhotoViewPicker();
    const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    photoSelectOptions.maxSelectNumber = 1;
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
    photoPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
      if (photoSelectResult.photoUris.length > 0) {
        resolve(photoSelectResult.photoUris[0])
      }
      resolve(undefined)
    })
  })
}

export async function getDownloadFolderPath() {
  const documentViewPicker = new picker.DocumentViewPicker()
  let documentSaveResult = await documentViewPicker.save({ pickerMode: picker.DocumentPickerMode.DOWNLOAD })
  return new fileUri.FileUri(documentSaveResult[0]).path + '/'
}

export function addLog(tag: string = '', text: string = '', error: boolean = false) {
  if (__Logger__.logs.length > 200) {
    __Logger__.logs = __Logger__.logs.slice(__Logger__.logs.length - 201, __Logger__.logs.length - 1)
  }
  __Logger__.logs.push({ time: new Date().getTime(), isError: error, tag: tag, text: text })
  if (error) {
    console.error(`testTAG [${tag}] ${text}`)
  } else {
    console.log(`testTAG [${tag}] ${text}`)
  }
}

export function base64Encoding(str:string):string {
  let base64Helper = new util.Base64Helper();
  let array = new Uint8Array(buffer.from(str, 'utf-8').buffer)
  let result:string = base64Helper.encodeToStringSync(array);
  return result
}

export function base64Decoding(str:string):string{
  let base64Helper = new util.Base64Helper();
  let array = base64Helper.decodeSync(str, util.Type.MIME);
  const textDecoder = util.TextDecoder.create('utf-8', {
    fatal: false,      // 忽略无效字节不报错
    ignoreBOM: true    // 忽略字节顺序标记
  });
  return textDecoder.decodeToString(array, { stream: false });
}


