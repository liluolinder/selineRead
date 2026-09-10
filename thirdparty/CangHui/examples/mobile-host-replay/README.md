# Mobile Host Replay

This consumer fixture exposes staged Android and provider-owned iOS input-tree
receipts through CangHui kMode without opening a window or generating a package.

```bash
cuic kmode list mobile-host-replay
cuic kmode call mobile-host-replay mobile.demo.host.replay
cuic kmode call mobile-host-replay mobile.demo.host.replay \
  'player.toggle|4|9'
cuic kmode call mobile-host-replay mobile.demo.ios.provider.replay \
  'player.toggle|4|9'
cuic kmode call mobile-host-replay mobile.demo.ios.signing.prepare \
  'ios-signing-identity,ios-provisioning-profile'
cuic kmode call mobile-host-replay mobile.demo.ios.signing.bind \
  'CangHui.app|xcode|identity-ref|profile-ref|sha256:<64-lowercase-hex>|<source-binding>'
cuic kmode call mobile-host-replay mobile.demo.ios.signing.verify \
  'CangHui.app|ios-platform-owner|codesign-verify|strict-v1|verify-demo-001|sha256:<64-lowercase-hex>|4096|<source-binding>|passed'
cuic kmode call mobile-host-replay mobile.demo.ios.installation.record \
  'CangHui.app|ios-platform-owner|physical-device|devicectl|development-install-v1|install-demo-001|sha256:<64-lowercase-hex>|4096|<source-binding>|installed'
```

The payload accepts one callback per line as
`actionId|lifecycleEpoch|surfaceGeneration`. The response follows
`canghui.mobile-host-replay.v0` and reports whether each callback is current or
stale. The JSON files under `fixtures/` are unsigned consumer package-plan
inputs represented by `canghui.mobile-application-host.v0` staged receipts.
The iOS provider endpoint binds the checked-in UIKit probe/bootstrap/runtime
input tree to the current lifecycle and surface generation. These are not
installable packages or device proof.

`mobile.demo.ios.signing.prepare` accepts a comma-separated set of non-secret
iOS signing capability labels. An empty or incomplete payload shows the blocked result.
The receipt always keeps `signedPackage=false` and `installable=false`; the
application-owned Xcode signing step is deliberately outside the endpoint.

`mobile.demo.ios.signing.bind` accepts only opaque signer labels, one
`sha256:` digest and the preparation source binding. An accepted response
correlates the metadata with the current lifecycle/surface generation; it does
not verify signature bytes or advance the package receipt.

`mobile.demo.ios.signing.verify` demonstrates the separate platform-owner
verification receipt. A passed and fully matched receipt advances the provider
to `signed-package`; the JSON still reports `installationProven=false` and
`deviceProven=false`. No signer, verifier, installation or device command is
executed by the example.

`mobile.demo.ios.installation.record` demonstrates the next external receipt.
It reconstructs the signed-package gate, then records an opaque platform
installer result. `installed` may set `installationProven=true`, but launch,
rendering and device proof remain false. The example does not run `devicectl`
or inspect an iPad identifier.
