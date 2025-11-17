
export interface I_LoginRes{
  errors: [],
  response:  I_LoginRes_response
}


export interface I_LoginRes_response{
  message: string
  params: string,
  user_id: number,
  user_key: string
}

