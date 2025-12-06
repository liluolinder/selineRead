export interface I_AlterDialogParam{
  title: ResourceStr
  subtitle?: ResourceStr
  message?: ResourceStr,
  autoCancel?: boolean
  alignment?:DialogAlignment
  buttonDirection?:DialogButtonDirection

  cancelCallBack:()=>void
  confirmCallBack:()=>void

}