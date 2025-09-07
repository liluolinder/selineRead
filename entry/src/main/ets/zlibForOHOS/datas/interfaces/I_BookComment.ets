export interface I_BookComment{
  id:number
  object:string
  object_id:number
  parent_id:null|number
  user_id:number
  text:string
  date:string
  user:I_User
  dateRelative:string
}

export interface I_User{
  name:string
  avatar:string
  hash:string
  isPremium:boolean
  isCurrentUser:boolean
}

