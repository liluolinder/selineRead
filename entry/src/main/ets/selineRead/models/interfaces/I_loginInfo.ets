export interface I_loginRes{
  success: number,
  user: I_loginRes_user
  error:string   //success 为0时,有值
}

export interface I_loginRes_user
{
  id: number,
  email: string,
  passWord:string,
  name: string,
  kindle_email: string,
  remix_userkey: string,
  donations_active: null,
  donations_expire: null,
  downloads_today: number,
  downloads_limit: number,
  confirmed: number,
  isPremium: number
}