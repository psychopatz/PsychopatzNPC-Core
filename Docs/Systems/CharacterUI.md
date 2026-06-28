# Character UI

## Purpose
- `PNC_Nameplates` owns overhead name, HP, stamina, and debug text visibility lanes.
- `PNC_CharacterWindow` owns the NPC profile shell and tabs.
- tab helper files own their own content areas so medical, bandage, and body-part systems can be added without replacing the window.

## Current Tabs
- `Info`
- `Skills`
- `Health`
- `Protection`
- `Temperature`

## Ownership Rules
- only `PNC_Nameplates` draws overhead bars and text
- only `PNC_CharacterWindow` opens and renders the profile window
- snapshot payloads come from `PNC_Network`, not UI code

