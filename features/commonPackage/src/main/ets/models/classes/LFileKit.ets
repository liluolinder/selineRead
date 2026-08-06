import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WriteMode } from '../enums/WriteMode';
import { XContext } from './XContext';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { buffer } from '@kit.ArkTS';

export  class LFileKit {
    static async access(dir: string): Promise<boolean> {
        return await fs.access(dir).then((res: boolean) => {
            if (res) {
                console.info(`Meow:${dir} 存在`);
                return true;
            } else {
                console.info(`Meow:${dir} 不存在`);
                return false;
            }
        }).catch((err: BusinessError) => {
            console.error("Meow:检测目录" + dir + "失败,失败原因:" + err.message + ",失败码: " + err.code);
            return false;
        });
    }

    static async copy(srcUri: string, desUri: string): Promise<boolean> {
        return await fs.copy(srcUri, desUri)
            .then(() => {
                console.error(`Meow:复制成功`);
                return true
            })
            .catch((err: BusinessError) => {
                console.error(`Meow:复制失败，错误${JSON.stringify(err)}`);
                return false
            })
    }

    static async mkdir(dir: string): Promise<boolean> {
        return await fs.mkdir(dir).then(() => {
            console.info(`Meow:mkdir ${dir} succeed`);
            return true;
        }).catch((err: BusinessError) => {
            console.error("Meow:创建目录" + dir + "失败 ,失败原因:" + err.message + ",失败码: " + err.code);
            return false;
        });
    }

    static async deleteDir(dir: string): Promise<boolean> {
        return await fs.rmdir(dir).then(() => {
            console.info(`Meow:删除目录${dir}成功`);
            return true
        }).catch((err: BusinessError) => {
            console.error(`Meow:删除目录${dir}失败,错误码${err.code},错误信息${err.message}`);
            return false
        });
    }

    static async deleteSingleFile(dir: string): Promise<boolean> {
        return await fs.unlink(dir).then(() => {
            console.info(`Meow:删除目录${dir}成功`);
            return true
        }).catch((err: BusinessError) => {
            console.error(`Meow:删除目录${dir}失败,错误码${err.code},错误信息${err.message}`);
            return false
        });
    }

    static async write(dir: string, content: string|ArrayBuffer, mode: WriteMode = WriteMode.Override): Promise<boolean> {
        let openMode: number;
        switch (mode) {
            case WriteMode.Override:
                openMode = fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE;
                break;
            case WriteMode.Append:
                openMode = fs.OpenMode.WRITE_ONLY | fs.OpenMode.APPEND;
                break;
            default:
                openMode = fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE;
        }
        try {
            let willWriteFile = fs.openSync(dir, openMode)
            try {
                const writeLen = fs.writeSync(willWriteFile.fd, content)
                console.info(`Meow:写入成功，字节数：${writeLen}`);
                fs.closeSync(willWriteFile);
                return true
            } catch (error) {
                console.error("Meow写入失败:", error);
                fs.closeSync(willWriteFile);
                return false
            }
        } catch (error) {
            console.error(`Meow:打开文件${dir}失败,错误原因${error.message},错误码${error.code}`)
            return false
        }
    }

    static  async read(dir: string): Promise<string> {
        let file = fs.openSync(dir, fs.OpenMode.READ_WRITE);
        let arrayBuffer = new ArrayBuffer(8192);
        return await fs.read(file.fd, arrayBuffer).then((readLen: number) => {
            console.info(`Meow:读取${dir}成功`);
            let buf = buffer.from(arrayBuffer, 0, readLen);
           // console.info(`Meow: ${buf.toString()}`);
            return buf.toString()
        }).catch((err: BusinessError) => {
            console.error("Meow:读取文件" + dir + "失败,失败原因:" + err.message + ",失败码: " + err.code);
            return ''
        }).finally(() => {
            fs.closeSync(file);
        });
    }

    static async listDir(dir: string, option: ListFileOptions | undefined = undefined): Promise<string[]> {
        return fs.listFile(dir, option).then((filenames: Array<string>) => {
            for (let i = 0; i < filenames.length; i++) {
                console.info("Meow:fileName: %s", filenames[i]);
            }
            return filenames
        }).catch((err: BusinessError) => {
            console.error(`Meow:列出目录${dir}存在的文件(夹)失败.错误信息${err.message},错误码${err.code} `);
            return []
        });

    }

    static  async pickFile(maxSelectNumber: number = 1, fileSuffixFilters: string[] = []): Promise<string[]> {
        const documentSelectOptions = new picker.DocumentSelectOptions();
        // 选择文档的最大数目（可选）。
        documentSelectOptions.maxSelectNumber = maxSelectNumber;
        // 选择文件的后缀类型['后缀类型描述|后缀类型']，若选择项存在多个后缀名，则每一个后缀名之间用英文逗号进行分隔（可选），后缀类型名不能超过100。支持通配符方式['所有文件(*.*)|.*']，表示为显示所有文件。'图片(.png, .jpg)|.png,.jpg', '文档|.txt', '视频|.mp4', '.pdf']
        documentSelectOptions.fileSuffixFilters = fileSuffixFilters;
        //开启聚合视图模式，支持拉起文件管理应用的聚合视图。默认为DEFAULT，表示该参数不生效，非聚合视图。当该参数置为非DEFAULT时，其他参数不生效。该参数在Phone设备中可正常使用，在其他设备中无效果。
        documentSelectOptions.mergeMode = picker.MergeTypeMode.DEFAULT;


        const documentViewPicker = new picker.DocumentViewPicker(XContext.getAbilityContext());

        return await documentViewPicker.select(documentSelectOptions).then((documentSelectResult: Array<string>) => {

            console.info(`Meow:获取成功`);
            return documentSelectResult;
        }).catch((err: BusinessError) => {
            console.error(`Meow:获取失败，错误原因${err.message},错误码${err.code}`);
            return [];
        })

    }

    static async pickMedia(): Promise<string | undefined> {
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
}

