# Character UI

## Purpose
- `PNC_Nameplates` owns overhead name, HP, stamina, and debug text visibility lanes.
- `PNC_CharacterWindow` owns the NPC profile shell and tabs.
- `PNC_ContextHub` and `PNC_NPCSelection` own reusable cursor selection and NPC context entry, so command, talk, debug, and future interaction flows share one hub.
- tab helper files own their own content areas so medical, bandage, and body-part systems can be added without replacing the window.
- full character and inventory payloads are requested on demand instead of being replicated every tick.

## Current Tabs
- `Info`
- `Skills`
- `Health`
- `Protection`
- `Temperature`

## Ownership Rules
- only `PNC_Nameplates` draws overhead bars and text
- only `PNC_CharacterWindow` opens and renders the profile window
- only the context hub stack decides which NPCs are selectable from a right-click
- snapshot payloads come from `PNC_Network`, not UI code
- inventory and character details come from `PNC_Network.BuildCharacterPayload`, not from ad-hoc UI caches
