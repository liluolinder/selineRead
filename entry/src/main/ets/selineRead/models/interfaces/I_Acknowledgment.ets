export interface I_Acknowledgment{
  name:string
  avatar:ResourceStr|undefined
  info?:string
  bilibili?:string
  appInfo?:string
  appBundle?:string
  githubHome?:string
  gitcodeHome?:string
  barrier?:string
}

export interface I_Acknowledgment_List{
  name: string,
  list: I_Acknowledgment[]
}