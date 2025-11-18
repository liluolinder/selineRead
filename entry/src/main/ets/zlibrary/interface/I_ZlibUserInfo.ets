export interface I_ZlibUserInfo{
  account:string
  password:string
  cookie:string
  userName:string
  userDownloadLimitNumber:string
  userDonateNumber:string
  userAvatar:string
}

export interface I_BasicUserInfo{
  userName:string
  userDownloadLimitNumber:string
  userDonateNumber:string
  userAvatar:string
}

export interface I_UserDownloadLimitAndDonation{
  downloadLimit:string
  donation:string
}
