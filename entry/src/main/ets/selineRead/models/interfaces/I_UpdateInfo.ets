export interface I_UpdateInfo{
  version: string
  date: string
  description?:string
  addNewFunArray?: string[] | undefined
  fixBugsArray?: string[] | undefined
  optimizeArray?: string[] | undefined

}