PNC = PNC or {}
PNC.SkillsWindow = PNC.SkillsWindow or {}

local SkillsWindow = PNC.SkillsWindow

function SkillsWindow.Toggle(npcId)
    if PNC.CharacterWindow and PNC.CharacterWindow.Toggle then
        return PNC.CharacterWindow.Toggle(npcId)
    end
    return nil
end
