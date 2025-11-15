import { fileIo as fs, ListFileOptions, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { WriteMode } from '../enums/WriteMode';
import { XContext } from './XContext';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { buffer } from '@kit.ArkTS';

class LFileKit {
    async access(dir: string): Promise<boolean> {
        return await fs.access(dir).then((res: boolean) => {
            if (res) {
                console.info(`Liquid:${dir} 存在`);
                return true;
            } else {
                console.info(`Liquid:${dir} 不存在`);
                return false;
            }
        }).catch((err: BusinessError) => {
            console.error("Liquid:检测目录" + dir + "失败,失败原因:" + err.message + ",失败码: " + err.code);
            return false;
        });
    }

    async copy(srcPath: string, desPath: string): Promise<boolean> {
        try {
            const srcFile = fs.openSync(srcPath, fs.OpenMode.READ_ONLY)
            const desFile = fs.openSync(desPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
            await fs.copyFile(srcFile.fd, desFile.fd)
            fs.closeSync(srcFile)
            fs.closeSync(desFile)
            return true
        } catch (err) {
            console.error(`Liquid:复制失败，错误${JSON.stringify(err)}`);
            return false
        }

    }

    async mkdir(dir: string): Promise<boolean> {
        return await fs.mkdir(dir).then(() => {
            console.info(`Liquid:mkdir ${dir} succeed`);
            return true;
        }).catch((err: BusinessError) => {
            console.error("Liquid:创建目录" + dir + "失败 ,失败原因:" + err.message + ",失败码: " + err.code);
            return false;
        });
    }

    async deleteDir(dir: string): Promise<boolean> {
        return await fs.rmdir(dir).then(() => {
            console.info(`Liquid:删除目录${dir}成功`);
            return true
        }).catch((err: BusinessError) => {
            console.error(`Liquid:删除目录${dir}失败,错误码${err.code},错误信息${err.message}`);
            return false
        });
    }

    async deleteSingleFile(dir: string): Promise<boolean> {
        return await fs.unlink(dir).then(() => {
            console.info(`Liquid:删除目录${dir}成功`);
            return true
        }).catch((err: BusinessError) => {
            console.error(`Liquid:删除目录${dir}失败,错误码${err.code},错误信息${err.message}`);
            return false
        });
    }

    async write(dir: string, content: string, mode: WriteMode = WriteMode.Override): Promise<boolean> {
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
                console.info(`Liquid:写入成功，字节数：${writeLen}`);
                fs.closeSync(willWriteFile);
                return true
            } catch (error) {
                console.error("Liquid写入失败:", error);
                fs.closeSync(willWriteFile);
                return false
            }
        } catch (error) {
            console.error(`Liquid:打开文件${dir}失败,错误原因${error.message},错误码${error.code}`)
            return false
        }
    }

    async read(dir: string): Promise<string> {
        let file = fs.openSync(dir, fs.OpenMode.READ_WRITE);
        let arrayBuffer = new ArrayBuffer(8192);
        return await fs.read(file.fd, arrayBuffer).then((readLen: number) => {
            console.info(`Liquid:读取${dir}成功`);
            let buf = buffer.from(arrayBuffer, 0, readLen);
            console.info(`Liquid: ${buf.toString()}`);
            return buf.toString()
        }).catch((err: BusinessError) => {
            console.error("Liquid:读取文件" + dir + "失败,失败原因:" + err.message + ",失败码: " + err.code);
            return ''
        }).finally(() => {
            fs.closeSync(file);
        });
    }

    async listDir(dir: string, option: ListFileOptions | undefined = undefined): Promise<string[]> {
        return fs.listFile(dir, option).then((filenames: Array<string>) => {
            for (let i = 0; i < filenames.length; i++) {
                console.info("Liquid:fileName: %s", filenames[i]);
            }
            return filenames
        }).catch((err: BusinessError) => {
            console.error(`Liquid:列出目录${dir}存在的文件(夹)失败.错误信息${err.message},错误码${err.code} `);
            return []
        });

    }

    async pickFile(maxSelectNumber: number = 1, fileSuffixFilters: string[] = []): Promise<string[]> {
        const documentSelectOptions = new picker.DocumentSelectOptions();
        // 选择文档的最大数目（可选）。
        documentSelectOptions.maxSelectNumber = maxSelectNumber;
        // 选择文件的后缀类型['后缀类型描述|后缀类型']，若选择项存在多个后缀名，则每一个后缀名之间用英文逗号进行分隔（可选），后缀类型名不能超过100。支持通配符方式['所有文件(*.*)|.*']，表示为显示所有文件。'图片(.png, .jpg)|.png,.jpg', '文档|.txt', '视频|.mp4', '.pdf']
        documentSelectOptions.fileSuffixFilters = fileSuffixFilters;
        //开启聚合视图模式，支持拉起文件管理应用的聚合视图。默认为DEFAULT，表示该参数不生效，非聚合视图。当该参数置为非DEFAULT时，其他参数不生效。该参数在Phone设备中可正常使用，在其他设备中无效果。
        documentSelectOptions.mergeMode = picker.MergeTypeMode.DEFAULT;


        const documentViewPicker = new picker.DocumentViewPicker(XContext.getAbilityContext());

        return await documentViewPicker.select(documentSelectOptions).then((documentSelectResult: Array<string>) => {

            console.info(`Liquid:获取成功`);
            return documentSelectResult;
        }).catch((err: BusinessError) => {
            console.error(`Liquid:获取失败，错误原因${err.message},错误码${err.code}`);
            return [];
        })

    }

    async pickMedia(): Promise<string | undefined> {
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

export let File: LFileKit = new LFileKit()