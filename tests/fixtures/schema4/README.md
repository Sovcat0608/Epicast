# Historical software fixtures

These code snapshots support the old schema-4 trigger, migration and UI regression tests. `load-order.json` records their original load order. Shared effect, buff-reader and model-lifecycle modules still load from the current runtime.

The retired Mage renderer code is retained here solely so existing trigger regressions can execute against their original callers. No artwork files are stored here, and these fixtures are never packaged. They are **not artwork references or instructions for the Mage restart**. Current runtime tests use the real TOC with no fixture overrides.

Beta.18 also freezes the prior `BindingControls.lua` here so the archived combined studio continues to exercise its original UI contract while current tests use the new spell sidebar.
