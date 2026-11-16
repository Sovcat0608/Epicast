# Epicast beta.17 — adjacent tabs and Restoration recovery

Local follow-up to the user's beta.16 review: group the tab rows side by side, expose Open effects while placing a crest in developer mode, and recover recorded Restoration effects. The user accepted the installed result and explicitly requested beta.17 publication on2026-11-16. Schema6 and all artwork are unchanged.

The native [PanelTabButtonMixin](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua) resizes labels on OnShow and display changes. Beta.16 sized the tabs initially but positioned each at a fixed X, leaving gaps once native sizing ran. Each second tab now follows the previous tab's actual right edge. A12-unit frame gap accommodates the native textures extending beyond their frame edges. Tests simulate show/display resize with changing font widths and check adjacency, layout bounds and combat state.

Open effects is a developer-only button in the crest header, available on both Placement and Behavior; normal mode hides it. It preserves pending placement text in its draft owner and does not commit preferences. The library window itself is unchanged.

Exactly nine Restoration rows were recovered from the already archived pre-reset configuration and baked into the crest, with all model fitting, position, opacity and bindings intact. See [recovery provenance](restoration-recovery.md). No live SavedVariables were read or written, and the archived backup was only read. Arcane's approved twelve-layer preset and all49 artwork files are unchanged.

Full regression tests passed, including repeated Restoration spell triggers and native tab resizing. Offline layout previews are generated from the actual widget mock; the user subsequently confirmed the installed result looks good and requested publication.

## Verified build and installation

Built `dist/Epicast-0.1.0-beta.17.zip`:83 files,25,933,980 bytes,SHA256 `A35F31C6CD9ED8FD444210171F054E5F8DB544A2F4B42E4F1A31D1DFB98DAB0B`. Source/archive hashes verified. Compared with beta.16:78 identical payloads,5 changed (Options, CrestBakes, TOC version, README, CHANGELOG),0 additions/removals. All49 textures, Arcane preset and native trigger/CDM code remain byte-identical.

Installed to `D:/World of Warcraft/_forever_/Interface/AddOns/Epicast`. All83 installed payloads and5 original backups independently hash-verified. Backup/receipt: `artifacts/install-20261116-200109/`. Rollback preflight passed without applying; schema6 is unchanged. No live SavedVariables access. The previously archived backup was read only for the explicitly requested Restoration recovery. There are no new TOC modules or textures; reload the UI to load the update.

Full tests/audit passed. Evidence: `artifacts/beta17-test.log`, `beta17-audit.log`, `beta17-package-comparison.json`, `beta17-install-independent.json`; offline previews under `artifacts/beta17-ui/` inspected for adjacent tab rows and header button layout. The user accepted the installed review. The exact tested ZIP is being published without rebuilding or changing runtime payloads. Publication verification is recorded below.
