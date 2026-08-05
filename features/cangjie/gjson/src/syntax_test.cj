package gjson

import std.unittest.*
import std.unittest.testmacro.*

@Test
class CheckOriginalTest {
    let basicJson = "{\"name\":{\"first\":\"Tom\",\"last\":\"Anderson\"},\"age\":37,\"children\":[\"Sara\",\"Alex\",\"Jack\"],\"fav.movie\":\"Deer Hunter\",\"friends\":[{\"first\":\"Dale\",\"last\":\"Murphy\",\"age\":44,\"nets\":[\"ig\",\"fb\",\"tw\"]},{\"first\":\"Roger\",\"last\":\"Craig\",\"age\":68,\"nets\":[\"fb\",\"tw\"]},{\"first\":\"Jane\",\"last\":\"Murphy\",\"age\":47,\"nets\":[\"ig\",\"tw\"]}]}"

    @TestCase
    func testOriginalData() {
        // 检查 friends 数组
        let friends = get(basicJson, "friends.#")
        println("friends count: ${friends.num}")
        
        // 检查第一个 friend 的 nets
        let nets0 = get(basicJson, "friends.0.nets.#")
        println("nets0 count: ${nets0.num}")
        
        // 检查嵌套查询
        let result = get(basicJson, "friends.#(nets.#(==\"fb\"))#.first")
        println("nested query: exists=${result.exists()}, raw='${result.raw}'")
        
        @Assert(result.exists(), true)
    }
}
