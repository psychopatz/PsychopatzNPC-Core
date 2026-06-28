--[[
    PNC Farmer Archetype Definition
    Declares a preload-safe archetype bundle for farmer-flavored companion NPCs.
]]

PNC = PNC or {}
PNC.PendingArchetypeBundles = PNC.PendingArchetypeBundles or {}

local bundle = {
    definition = {
        label = "Farmer",
        type = "survivor",
        tags = { "civilian", "agriculture" },
        visualProfile = "companion",
        defaultForFaction = "companion",
        allowedJobs = {
            FollowOwner = true,
            GuardAnchor = true,
            PatrolRoute = true,
        },
    },
    looks = {
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        male = {
            { "Base.Hat_StrawHat", "Base.Dungarees", "Base.Shirt_Lumberjack", "Base.Shoes_Wellies" },
            { "Base.Hat_Cowboy", "Base.Shirt_Denim", "Base.Trousers_Denim", "Base.Shoes_WorkBoots" },
            { "Base.Hat_BaseballCap", "Base.Tshirt_WhiteTINT", "Base.Dungarees", "Base.Shoes_Wellies" },
            { "Base.Hat_StrawHat", "Base.Shirt_Lumberjack_Green", "Base.Trousers_JeanBaggy", "Base.Shoes_HikingBoots" },
        },
        female = {
            { "Base.Hat_StrawHat", "Base.Dungarees", "Base.Shirt_Lumberjack", "Base.Shoes_Wellies" },
            { "Base.Hat_Cowboy", "Base.Shirt_Denim", "Base.Trousers_Denim", "Base.Shoes_WorkBoots" },
            { "Base.Hat_BandanaTied", "Base.Tshirt_WhiteTINT", "Base.Dungarees", "Base.Shoes_Wellies" },
            { "Base.Hat_Cowboy_Brown", "Base.Shirt_CropTopTINT", "Base.Shorts_ShortDenim", "Base.Shoes_WorkBoots" },
        },
    },
    skills = {
        Agriculture = { min = 4, max = 7 },
        AnimalCare = { min = 2, max = 5 },
        Butchering = { min = 1, max = 4 },
        Strength = { min = 2, max = 5 },
    },
    loadout = {
        bagChoices = { "Base.Bag_Satchel", "Base.Bag_DuffelBag" },
        primaryChoices = { "Base.HandAxe", "Base.Shovel", "Base.GardenFork" },
        supplies = {
            { type = "Base.Bandage", stack = 2, preferredContainer = "bag" },
            { type = "Base.WaterBottleFull", stack = 1, preferredContainer = "bag" },
            { type = "Base.Cabbage", stack = 1, preferredContainer = "bag" },
            { type = "Base.SeedBag", stack = 1, preferredContainer = "bag" },
        },
    },
}

PNC.PendingArchetypeBundles.Farmer = bundle

if PNC.RegisterArchetypeBundle then
    PNC.RegisterArchetypeBundle("Farmer", bundle)
end
