package duplicate_probe_fixture

import chui.kmode.macros.*

@CuiProbe["fixture.duplicate"]
func firstProbe(value: String): String { value }

@CuiProbe["fixture.duplicate"]
func secondProbe(value: String): String { value }

main(): Unit {}
