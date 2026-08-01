import { ZlibBookInfoArk , ZlibBookInfoBriefArk} from "libohos_app_cangjie_entry.zlib4cj.so"

export interface I_BookInfoParam{
  type:number
  data:ZlibBookInfoBriefArk | ZlibBookInfoArk
}