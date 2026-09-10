package chui.host

@Test
func iosHostBootstrapAbiStaysStable(): Unit {
    @Expect(iosHostAbiVersion(), 1)
}
