package CJson.example.demo

main() {
    println(ExampleOne.fromJson("{\"name\":\"Chrsitmas\",\"time\":\"2022-12-25T00:00:00+01:00\"}").toJson())
    println(ClassWithOption.fromJson("{\"optionalStringWithoutValue\": null, \"optionalStringWithValue\": \"StringValue\", \"optionalIntWithoutValue\": {}, \"optionalIntWithValue\": 199}").toJson())
    println(ExampleOneStruct.fromJson("{\"name\":\"Labor Day\",\"time\":\"2023-05-01T00:00:00+10:00\"}").toJson())
    println(ExampleOneOptional.fromJson("{\"One\": null, \"Two\": null, \"Three\": 64, \"Four\": \"\"}").toJson())
    println(ExampleTwo.fromJson("{\"name\":\"New Year\",\"time\":{\"value\":\"CUST_2023-01-01T00:00:00+08:00\"}}").toJson())
}