# ForeverExport

Standalone, manual character report exporter for **World of Warcraft: Forever**. No dependency on ForeverQuest or any other custom addon.

Use `/fexport` or `/foreverexport` in-game to open a selected, copyable report. Press **Ctrl+C** to copy; the addon never uploads anything automatically.

The report includes your character, XP, money, location, gear, talents (tree allocations and spent ranks), professions, active quests and objectives, bag contents, and up to 20 recent quest turn-ins observed since installation. It can optionally import older ForeverQuest turn-in records on first launch when both addons' saved variables are available.

At your personal bank, click **Deposit Reagents** in the lower-right footer to invoke Forever's built-in crafting-reagent deposit action. This uses the game's own reagent classification and moves items from your carried bags when room is available. It does not scan or withdraw bank items, and the character report is unchanged.\n\nInstall via WoWUp from this GitHub repository once the first release is published, or extract the release ZIP so you have `Interface/AddOns/ForeverExport/ForeverExport.toc`.

**Testing:** Lua 5.1 syntax and mocked game API smoke tests run on release. Real WoW: Forever client behavior remains to be verified.
