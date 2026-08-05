package gjson
import std.unittest.*
import std.unittest.testmacro.*

var complicatedJSON = #"
{
        "tagged": "OK",
        "Tagged": "KO",
        "NotTagged": true,
        "unsettable": 101,
        "Nested": {
                "Yellow": "Green",
                "yellow": "yellow"
        },
        "nestedTagged": {
                "Green": "Green",
                "Map": {
                        "this": "that",
                        "and": "the other thing"
                },
                "Ints": {
                        "Uint": 99,
                        "Uint16": 16,
                        "Uint32": 32,
                        "Uint64": 65
                },
                "Uints": {
                        "int": -99,
                        "Int": -98,
                        "Int16": -16,
                        "Int32": -32,
                        "int64": -64,
                        "Int64": -65
                },
                "Uints": {
                        "Float32": 32.32,
                        "Float64": 64.64
                },
                "Byte": 254,
                "Bool": true
        },
        "LeftOut": "you shouldn't be here",
        "SelfPtr": {"tagged":"OK","nestedTagged":{"Ints":{"Uint32":32}}},
        "SelfSlice": [{"tagged":"OK","nestedTagged":{"Ints":{"Uint32":32}}}],
        "SelfSlicePtr": [{"tagged":"OK","nestedTagged":{"Ints":{"Uint32":32}}}],
        "SelfPtrSlice": [{"tagged":"OK","nestedTagged":{"Ints":{"Uint32":32}}}],
        "interface": "Tile38 Rocks!",
        "Interface": "Please Download",
        "Array": [0,2,3,4,5],
        "time": "2017-05-07T13:24:43-07:00",
        "Binary": "R0lGODlhPQBEAPeo",
        "NonBinary": [9,3,100,115]
}
"#

var complicatedJSONBytes = complicatedJSON.toArray()

var cangjieLspInitJson = #"{"params":{"processId":1613264,"clientInfo":{"version":"0.11.6+v0.11.6","name":"Neovim"},"rootPath":"/home/ystyle/Projects/Cangjie/xisp","trace":"off","initializationOptions":{"stdLibPathOption":"/tmp/cjvs_multishells/1576151_1770796338331","modulesHomeOption":"/tmp/cjvs_multishells/1576151_1770796338331","multiModuleOption":{"file:///home/ystyle/Projects/Cangjie/xisp":{"requires":[],"name":"xisp"}},"telemetryOption":true,"extensionPath":"/tmp/cjvs_multishells/1576151_1770796338331","conditionCompilePaths":[],"singleConditionCompileOption":[],"conditionCompileOption":[],"targetLib":"/home/ystyle/Projects/Cangjie/xisp/target/release"},"capabilities":{"window":{"showDocument":{"support":true},"workDoneProgress":true,"showMessage":{"messageActionItem":{"additionalPropertiesSupport":true}}},"textDocument":{"diagnostic":{"dynamicRegistration":false,"tagSupport":{"valueSet":[1,2]}},"implementation":{"linkSupport":true},"typeDefinition":{"linkSupport":true},"codeAction":{"dynamicRegistration":true,"dataSupport":true,"codeActionLiteralSupport":{"codeActionKind":{"valueSet":["","quickfix","refactor","refactor.extract","refactor.inline","refactor.rewrite","source","source.organizeImports"]}},"resolveSupport":{"properties":["edit"]},"isPreferredSupport":true},"definition":{"dynamicRegistration":true,"linkSupport":true},"declaration":{"linkSupport":true},"synchronization":{"didSave":true,"willSaveWaitUntil":true,"dynamicRegistration":false,"willSave":true},"hover":{"dynamicRegistration":true,"contentFormat":["markdown","plaintext"]},"semanticTokens":{"tokenModifiers":["declaration","definition","readonly","static","deprecated","abstract","async","modification","documentation","defaultLibrary"],"dynamicRegistration":true,"serverCancelSupport":false,"multilineTokenSupport":false,"overlappingTokenSupport":true,"tokenTypes":["namespace","type","class","enum","interface","struct","typeParameter","parameter","variable","property","enumMember","event","function","method","macro","keyword","modifier","comment","string","number","regexp","operator","decorator"],"legend":{"tokenTypes":["comment","keyword","string","number","regexp","operator","namespace","type","struct","class","interface","enum","typeParameter","function","member","property","macro","variable","parameter","label"],"tokenModifiers":["declaration","documentation","static","abstract","deprecated","async","readonly"]},"requests":{"full":{"delta":true},"range":true},"formats":["relative"],"augmentsSyntaxTokens":true},"inlayHint":{"dynamicRegistration":true,"resolveSupport":{"properties":["textEdits","tooltip","location","command"]}},"callHierarchy":{"dynamicRegistration":false},"publishDiagnostics":{"tagSupport":{"valueSet":[1,2]},"relatedInformation":true,"dataSupport":true},"references":{"dynamicRegistration":true},"documentSymbol":{"symbolKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]},"hierarchicalDocumentSymbolSupport":true,"dynamicRegistration":true},"rename":{"dynamicRegistration":true,"prepareSupport":true},"completion":{"contextSupport":true,"dynamicRegistration":true,"completionItemKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25]},"completionItem":{"documentationFormat":["markdown","plaintext"],"tagSupport":{"valueSet":[1]},"snippetSupport":true,"resolveSupport":{"properties":["documentation","detail","additionalTextEdits"]},"deprecatedSupport":true,"preselectSupport":false,"commitCharactersSupport":false},"completionList":{"itemDefaults":["editRange","insertTextFormat","insertTextMode","data"]}},"documentHighlight":{"dynamicRegistration":true},"signatureHelp":{"dynamicRegistration":true,"signatureInformation":{"documentationFormat":["markdown","plaintext"],"parameterInformation":{"labelOffsetSupport":true},"activeParameterSupport":true}},"foldingRange":{"foldingRange":{"collapsedText":true},"lineFoldingOnly":true,"foldingRangeKind":{"valueSet":["comment","imports","region"]},"dynamicRegistration":false},"codeLens":{"dynamicRegistration":false,"resolveSupport":{"properties":["command"]}},"rangeFormatting":{"dynamicRegistration":true,"rangesSupport":true},"formatting":{"dynamicRegistration":true}},"general":{"positionEncodings":["utf-8","utf-16","utf-32"]},"workspace":{"didChangeWatchedFiles":{"dynamicRegistration":true,"relativePatternSupport":true},"workspaceEdit":{"resourceOperations":["rename","create","delete"]},"didChangeConfiguration":{"dynamicRegistration":false},"configuration":true,"semanticTokens":{"refreshSupport":true},"inlayHint":{"refreshSupport":true},"applyEdit":true,"workspaceFolders":true,"symbol":{"dynamicRegistration":false,"symbolKind":{"valueSet":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26]}}}},"workDoneToken":"1","workspaceFolders":[{"uri":"file:///home/ystyle/Projects/Cangjie/xisp","name":"/home/ystyle/Projects/Cangjie/xisp"}],"rootUri":"file:///home/ystyle/Projects/Cangjie/xisp"},"jsonrpc":"2.0","method":"initialize","id":1}"#
var cangjieLspInitJsonBytes = cangjieLspInitJson.toArray()

@Test
class GjsonBenchmarks {
    @Bench
    func benchmarkValid() {
        valid(complicatedJSON)
    }
    @Bench
    func benchmarkvalidBytes() {
        validBytes(complicatedJSONBytes)
    }
    @Bench
    func benchmarkValidCangjieLspInitJsonBytes() {
        validBytes(cangjieLspInitJsonBytes)
    }
    @Bench
    func benchmarkParseBytes() {
        parseBytes(complicatedJSONBytes)
    }
    @Bench
    func benchmarkGetBytes() {
        getBytes(complicatedJSONBytes, "tagged")
    }
    @Bench
    func benchmarkParseBytesLsp() {
        parseBytes(cangjieLspInitJsonBytes)
    }
    @Bench
    func benchmarkGetBytesLsp() {
        getBytes(cangjieLspInitJsonBytes, "params.clientInfo.name")
    }
}

@Test
class ZeroCopyComparison {
    func parseBytesOld(json: Array<Byte>): Result {
        parse(String.fromUtf8(json))
    }
    func getBytesOld(json: Array<Byte>, path: String): Result {
        get(String.fromUtf8(json), path)
    }
    
    @Bench
    func benchmarkParseBytesOld() {
        parseBytesOld(complicatedJSONBytes)
    }
    @Bench
    func benchmarkParseBytesNew() {
        parseBytes(complicatedJSONBytes)
    }
    @Bench
    func benchmarkGetBytesOld() {
        getBytesOld(complicatedJSONBytes, "tagged")
    }
    @Bench
    func benchmarkGetBytesNew() {
        getBytes(complicatedJSONBytes, "tagged")
    }
    @Bench
    func benchmarkParseBytesLspOld() {
        parseBytesOld(cangjieLspInitJsonBytes)
    }
    @Bench
    func benchmarkParseBytesLspNew() {
        parseBytes(cangjieLspInitJsonBytes)
    }
    @Bench
    func benchmarkGetBytesLspOld() {
        getBytesOld(cangjieLspInitJsonBytes, "params.clientInfo.name")
    }
    @Bench
    func benchmarkGetBytesLspNew() {
        getBytes(cangjieLspInitJsonBytes, "params.clientInfo.name")
    }
}

@Test
class StringConversionBenchmarks {
    @Bench
    func benchmarkStringFromUtf8Small() {
        String.fromUtf8(complicatedJSONBytes)
    }
    @Bench
    func benchmarkStringWithRawDataSmall() {
        unsafe { String.withRawData(complicatedJSONBytes) }
    }
    @Bench
    func benchmarkStringFromUtf8Large() {
        String.fromUtf8(cangjieLspInitJsonBytes)
    }
    @Bench
    func benchmarkStringWithRawDataLarge() {
        unsafe { String.withRawData(cangjieLspInitJsonBytes) }
    }
}
