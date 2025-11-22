import { ListItemWithText } from "templatecomponent"

@ObservedV2
export class BookShelfData{
  @Trace bookList:string[]=[]
}

export let __BookShelf__:BookShelfData = new BookShelfData()

@ComponentV2
export struct BookShelf{

  build() {
    Column(){
      List(){
        ForEach(__BookShelf__.bookList,(item:string)=>{
          ListItemWithText({
            leftMessage:item
          })
        })
      }
    }.size({width:'100%', height:'100&'})
  }
}