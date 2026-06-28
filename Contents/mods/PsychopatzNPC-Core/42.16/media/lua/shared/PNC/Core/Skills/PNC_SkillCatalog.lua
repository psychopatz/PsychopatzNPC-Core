PNC = PNC or {}
PNC.SkillCatalog = PNC.SkillCatalog or {}

local Catalog = PNC.SkillCatalog

Catalog.Groups = Catalog.Groups or {
    {
        id = "Passive",
        display = "Passive",
        skills = {
            { id = "Fitness", display = "Fitness" },
            { id = "Strength", display = "Strength" },
            { id = "Sprinting", display = "Sprinting" },
            { id = "Nimble", display = "Nimble" },
            { id = "Sneaking", display = "Sneaking" },
            { id = "Lightfooted", display = "Lightfooted" },
        },
    },
    {
        id = "CombatFirearms",
        display = "Combat - Firearms",
        skills = {
            { id = "Aiming", display = "Aiming" },
            { id = "Reloading", display = "Reloading" },
        },
    },
    {
        id = "CombatMelee",
        display = "Combat - Melee",
        skills = {
            { id = "Axe", display = "Axe" },
            { id = "LongBlade", display = "Long Blade" },
            { id = "LongBlunt", display = "Long Blunt" },
            { id = "Maintenance", display = "Maintenance" },
            { id = "ShortBlade", display = "Short Blade" },
            { id = "ShortBlunt", display = "Short Blunt" },
            { id = "Spear", display = "Spear" },
        },
    },
    {
        id = "Crafting",
        display = "Crafting",
        skills = {
            { id = "Blacksmithing", display = "Blacksmithing" },
            { id = "Carpentry", display = "Carpentry" },
            { id = "Carving", display = "Carving" },
            { id = "Cooking", display = "Cooking" },
            { id = "Electrical", display = "Electrical" },
            { id = "Glassmaking", display = "Glassmaking" },
            { id = "Knapping", display = "Knapping" },
            { id = "Masonry", display = "Masonry" },
            { id = "Mechanics", display = "Mechanics" },
            { id = "Pottery", display = "Pottery" },
            { id = "Tailoring", display = "Tailoring" },
            { id = "Welding", display = "Welding" },
        },
    },
    {
        id = "Farming",
        display = "Farming",
        skills = {
            { id = "Agriculture", display = "Agriculture" },
            { id = "AnimalCare", display = "Animal Care" },
            { id = "Butchering", display = "Butchering" },
        },
    },
}

local function ensureLookup()
    local groups
    local i
    local j
    local group
    local skill
    if Catalog.ByID then
        return
    end
    Catalog.ByID = {}
    Catalog.Order = {}
    groups = Catalog.Groups or {}
    for i = 1, #groups do
        group = groups[i]
        for j = 1, #(group.skills or {}) do
            skill = group.skills[j]
            Catalog.ByID[skill.id] = skill
            Catalog.Order[#Catalog.Order + 1] = skill.id
        end
    end
end

function Catalog.GetGroups()
    ensureLookup()
    return Catalog.Groups
end

function Catalog.GetAllSkillIDs()
    ensureLookup()
    return Catalog.Order
end

function Catalog.Find(skillID)
    ensureLookup()
    return Catalog.ByID[tostring(skillID or "")]
end
