package canghui_gallery_components

import chui.{ComponentCompatibility, HostPlatform, HostProfile, Symbols}

@Test
func galleryPackageIsPlatformNeutral(): Unit {
    let descriptor = GalleryComponentPackage().descriptor()
    @Expect(descriptor.id, "canghui.gallery.common")
    match (descriptor.compatibility(HostProfile(HostPlatform.Android))) {
        case ComponentCompatibility.Compatible => @Expect(true)
        case _ => @Fail("The gallery package should remain common-source.")
    }
}

@Test
func gallerySurfaceStateCanBeOwnedByAnyHost(): Unit {
    let state = GallerySurfaceState()
    state.selectedSection.value = 2
    state.notificationsEnabled.value = false
    state.rating.value = 5
    state.page.value = 4
    @Expect(state.selectedSection.value, 2)
    @Expect(state.notificationsEnabled.value, false)
    @Expect(state.rating.value, 5)
    @Expect(state.page.value, 4)
}

@Test
func gallerySymbolRegistryContainsOnlyItsDeclaredProviderSubset(): Unit {
    registerCangHuiSymbols()
    @Expect(Symbols.descriptors("material").size, 1)
    @Expect(Symbols.descriptors("ant").size, 1)
    @Expect(Symbols.descriptors("arco").size, 1)
    @Expect(Symbols.resolve(material_add).resolved.qualified(), "material.add")
    @Expect(Symbols.resolve(ant_check).resolved.qualified(), "ant.check")
    @Expect(Symbols.resolve(arco_right).resolved.qualified(), "arco.right")
}
