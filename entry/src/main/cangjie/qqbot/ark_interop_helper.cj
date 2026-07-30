package ohos_app_cangjie_entry.qqbot

@C func ArkTS_Interop_Stub() {}

@C struct DL_info {
    var dli_fname: CString = CString(CPointer<UInt8>())
    var dli_fbase: CPointer<Unit> = CPointer<Unit>()
    var dli_sname: CString = CString(CPointer<UInt8>())
    var dli_saddr: CPointer<Unit> = CPointer<Unit>()
}

foreign func dladdr(addr: CPointer<Unit>, info: CPointer<DL_info>): Int

func getLibName(): String {
    var info = DL_info()
    unsafe { dladdr(CPointer<Unit>(ArkTS_Interop_Stub), inout info) }
    return info.dli_fname.toString().split('/').last.getOrThrow()
}
