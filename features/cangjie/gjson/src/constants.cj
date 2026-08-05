package gjson

// 字符常量
let SPACE: Byte = b' '
let TAB: Byte = b'\t'
let NEWLINE: Byte = b'\n'
let CARRIAGE_RETURN: Byte = b'\r'

// JSON结构字符
let OPEN_BRACE: Byte = b'{'
let CLOSE_BRACE: Byte = b'}'
let OPEN_BRACKET: Byte = b'['
let CLOSE_BRACKET: Byte = b']'
let DOUBLE_QUOTE: Byte = b'"'
let COLON: Byte = b':'
let COMMA: Byte = b','
let BACKSLASH: Byte = b'\\'

// 十六进制字符数组
let HEX_CHARS: Array<Byte> = [
    b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9',
    b'a', b'b', b'c', b'd', b'e', b'f'
]