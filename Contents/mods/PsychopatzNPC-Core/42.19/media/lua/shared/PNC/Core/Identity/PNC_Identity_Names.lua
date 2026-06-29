PNC = PNC or {}
PNC.IdentityNames = PNC.IdentityNames or {}

local Names = PNC.IdentityNames
local Identity = PNC.Identity

local MaleFirst = {
    "Adam", "Aaron", "Ben", "Caleb", "Derek", "Eli", "Felix", "Grant", "Harvey", "Isaac",
    "Jonah", "Liam", "Marcus", "Noah", "Owen", "Peter", "Quinn", "Rory", "Samuel", "Victor",
}

local FemaleFirst = {
    "Alice", "Beth", "Cara", "Diana", "Elise", "Faith", "Grace", "Hannah", "Ivy", "Julia",
    "Kara", "Lena", "Maya", "Nina", "Olive", "Paige", "Ruby", "Sara", "Tessa", "Wren",
}

local Surnames = {
    "Bennett", "Carter", "Dalton", "Ellis", "Foster", "Griffin", "Hayes", "Irwin", "Keller", "Lang",
    "Morris", "Nolan", "Owens", "Parker", "Quincy", "Reed", "Sawyer", "Turner", "Vance", "Walker",
}

function Names.Generate(seed, isFemale, archetypeID)
    local firstPool = isFemale and FemaleFirst or MaleFirst
    local first = firstPool[Identity.Index(seed, "name:first:" .. tostring(archetypeID or "General"), #firstPool)]
    local last = Surnames[Identity.Index(seed, "name:last", #Surnames)]
    return tostring(first or "Alex") .. " " .. tostring(last or "Walker")
end

