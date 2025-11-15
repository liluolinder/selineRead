import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { http } from '@kit.NetworkKit';
import { generateBarcode, scanCore } from '@kit.ScanKit';

export class LPixelMap {
    public ISHaveAvatar(avatarPath: string, defaultAvatar: ResourceStr): ResourceStr {
        return fs.accessSync(avatarPath) ? fileUri.getUriFromPath(avatarPath) : defaultAvatar
    }

    async requestImage(url: string): Promise<PixelMap> {
        return new Promise((resolve, reject) => {
            let httpRequest = http.createHttp();
            httpRequest.request(url, {
                method: http.RequestMethod.GET,
                expectDataType: http.HttpDataType.ARRAY_BUFFER
            }, (error: BusinessError, data: http.HttpResponse) => {
                if (error) {
                    console.error(`请求失败: ${error.code}, ${error.message}`);
                    reject(error);
                } else {
                    let imgData: ArrayBuffer = data.result as ArrayBuffer;
                    this.buffer2pixelMap(imgData).then(resolve).catch(reject);
                }
            });
        });
    }

    async buffer2pixelMap(imgData: ArrayBuffer): Promise<PixelMap> {
        let imageSource = image.createImageSource(imgData);
        let options: image.DecodingOptions = {
            desiredSize: { width: 100, height: 100 }, // 可选：指定目标尺寸
            desiredPixelFormat: image.PixelMapFormat.RGBA_8888 // 指定像素格式
        }
        return await imageSource.createPixelMap(options);
    }

    async file2pixelMap(url: string): Promise<PixelMap> {
        let Pic = fs.openSync(url!, fs.OpenMode.READ_ONLY)
        const imageSource: image.ImageSource = image.createImageSource(Pic.fd)
        fs.close(Pic)
        return await imageSource.createPixelMap()
    }

    async savePixelMapToSandBox(pixelMap: PixelMap, saveDir: string): Promise<boolean> {
        let file = fs.openSync(saveDir, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
        let packer = image.createImagePacker()
        return await packer.packToFile(pixelMap, file.fd, { format: "image/png", quality: 98 }).then(() => {
            fs.closeSync(file)
            return true
        }).catch((err: BusinessError) => {
            console.log(`Liquid:${JSON.stringify(err)}`)
            return false
        })
    }

    async generateQRCode(content: string): Promise<PixelMap | undefined> {
        let pixelmap: PixelMap | undefined

        let options: generateBarcode.CreateOptions = {
            scanType: scanCore.ScanType.QR_CODE,
            height: 400,
            width: 400
        }

        try {
            // 码图生成接口，成功返回PixelMap格式图片
            await generateBarcode.createBarcode(content, options).then((pixelMap: image.PixelMap) => {
                pixelmap = pixelMap;
            }).catch((error: BusinessError) => {
                console.log(`Liquid:Failed to get PixelMap by promise with options. Code: ${error.code}, message: ${error.message}`);
            })
        } catch (error) {
            console.log(`Liquid:Failed to createBarcode by promise with options. Code: ${error.code}, message: ${error.message}`);
        }

        return pixelmap

    }

    async sharePixelMap(filePath: string[], title: string[] = ['']) {
        let file = fs.openSync(filePath[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)

        let data: systemShare.SharedData = new systemShare.SharedData({
            title: title[0],
            description: title[0],
            utd: uniformTypeDescriptor.UniformDataType.IMAGE,
            uri: fileUri.getUriFromPath(file.path),
        })
        fs.closeSync(file)

        for (let index = 1; index < filePath.length; index++) {
            file = fs.openSync(filePath[index], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
            data.addRecord({
                title: title[index],
                description: title[index],
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

export let linderPixelMap: LPixelMap = new LPixelMap()