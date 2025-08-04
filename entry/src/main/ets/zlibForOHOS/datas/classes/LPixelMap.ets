import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export class LPixelMap{

  public async createPixelMAp(url:string) : Promise<image.PixelMap>
  {
    let Pic = fs.openSync(url!,fs.OpenMode.READ_ONLY)
    const imageSource : image.ImageSource = image.createImageSource(Pic.fd)
    fs.close(Pic)
    return await imageSource.createPixelMap()
  }

  ISHaveAvatar(context:Context): ResourceStr
  {
    let avatarPath:string=context.filesDir+'/avatar.jpg'

    return fs.accessSync(avatarPath)?fileUri.getUriFromPath(context.filesDir+'/avatar.jpg'):$r('sys.media.person_badge_waveform')

  }

/*  public async addWaterMark(context: Context,originalPixelMap:PixelMap): Promise<image.PixelMap>
  {
    const originalInfo = originalPixelMap.getImageInfoSync();

    // 白条高度（例如60像素）
    const barHeight = 50;
    // 创建离屏Canvas（宽度与原图一致，高度为原图+白条）
    const offScreenCanvas  = new OffscreenCanvas(px2vp(originalInfo.size.width), px2vp(originalInfo.size.height)+barHeight);
    const offScreenContext = offScreenCanvas.getContext('2d');

    offScreenContext.fillStyle = context.resourceManager.getColorSync($r('sys.color.comp_background_gray').id)
    offScreenContext.fillRect(0, 0, px2vp(originalInfo.size.width),  px2vp(originalInfo.size.height)+barHeight);

    // 将原图绘制到离屏Canvas顶部
    offScreenContext.drawImage(originalPixelMap, 0, 0);


    // 绘制白色背景条
    offScreenContext.fillStyle = context.resourceManager.getColorSync($r('sys.color.comp_background_gray').id)
    offScreenContext.fillRect(0, px2vp(originalInfo.size.height), px2vp(originalInfo.size.width), barHeight);

    // 绘制左侧图片（假设已获取小图标 iconPixelMap）
    let fileData = context.resourceManager.getMediaContentSync($r('app.media.cczuHelper').id)

    let iconPixelMap =  image.createImageSource(new Uint8Array(fileData).buffer as object as ArrayBuffer).createPixelMapSync()

    const iconSize = 40; // 图标尺寸
    const iconMargin = 16; // 边距
    offScreenContext.drawImage(
      iconPixelMap,
      iconMargin,
      px2vp(originalInfo.size.height)+ (barHeight - iconSize) / 2, // 垂直居中
      iconSize,
      iconSize
    );

    // 绘制右侧文字
    offScreenContext.fillStyle = context.resourceManager.getColorSync($r('sys.color.font').id );
    offScreenContext.font = '14vp sans-serif';
    const text = 'By 常大助手(鸿蒙版)';
    const textX = iconSize + iconMargin*2
    offScreenContext.fillText(text, textX, px2vp(originalInfo.size.height) + barHeight/1.6);

    return offScreenContext.getPixelMap(0, 0, offScreenCanvas.width, offScreenCanvas.height)
  }*/

  public async  savePixelMapToSandBox(pixelMap:PixelMap,saveDir:string)
  {
    let file = fs.openSync(saveDir, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

    let packer = image.createImagePacker()

    packer.packToFile(pixelMap, file.fd, { format: "image/jpeg", quality: 98  }).then(() => {
      fs.closeSync(file)
    })

  }

  public async sharePixelMap(filePath:string[],title:string[]=[''])
  {
    let file = fs.openSync(filePath[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

    let data: systemShare.SharedData = new systemShare.SharedData({
      title:title[0],
      description:title[0],
      utd: uniformTypeDescriptor.UniformDataType.IMAGE,
      uri: fileUri.getUriFromPath(file.path),
    })
    fs.closeSync(file)

    for (let index = 1; index < filePath.length; index++) {
      file = fs.openSync(filePath[index], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      data.addRecord({
        title:title[index],
        description:title[index],
        utd: uniformTypeDescriptor.UniformDataType.IMAGE,
        uri: fileUri.getUriFromPath(file.path)
      })
      fs.closeSync(file)
    }


    let controller: systemShare.ShareController = new systemShare.ShareController(data)


    controller.show(getContext() as common.UIAbilityContext, {
      previewMode: systemShare.SharePreviewMode.DETAIL,
      selectionMode: systemShare.SelectionMode.SINGLE
    })


  }

}

export let linderPixelMap:LPixelMap=new LPixelMap()