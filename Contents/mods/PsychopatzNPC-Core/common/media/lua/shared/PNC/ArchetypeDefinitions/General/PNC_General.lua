--[[
    PNC General Archetype Definition
    Declares the baseline survivor archetype bundle in a preload-safe format so
    Project Zomboid load order cannot drop the registration on the floor.
]]

PNC = PNC or {}
PNC.PendingArchetypeBundles = PNC.PendingArchetypeBundles or {}

local bundle = {
    definition = {
        label = "General Survivor",
        type = "survivor",
        tags = { "civilian", "companion" },
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
            { "Base.Hat_BaseballCap", "Base.Tshirt_DefaultTEXTURE_TINT", "Base.Trousers_Denim", "Base.Shoes_Random" },
            { "Base.Hat_Beany", "Base.HoodieUP_WhiteTINT", "Base.Trousers_JeanBaggy", "Base.Shoes_TrainerTINT" },
            { "Base.Glasses_Aviators", "Base.Shirt_Lumberjack", "Base.Trousers_Black", "Base.Shoes_BlackBoots" },
            { "Base.Hat_VisorBlack", "Base.Vest_DefaultTEXTURE_TINT", "Base.Shorts_LongDenim", "Base.Shoes_Sandals" },
            { "Base.Hat_Cowboy", "Base.Tshirt_Rock", "Base.Trousers_Padded", "Base.Shoes_WorkBoots" },
        },
        female = {
            { "Base.Hat_BaseballCap", "Base.Tshirt_DefaultTEXTURE_TINT", "Base.Trousers_Denim", "Base.Shoes_Random" },
            { "Base.Hat_Beany", "Base.HoodieDOWN_WhiteTINT", "Base.Skirt_Knees", "Base.Shoes_TrainerTINT" },
            { "Base.Glasses_Aviators", "Base.Shirt_Lumberjack", "Base.Trousers_Black", "Base.Shoes_BlackBoots" },
            { "Base.Dress_Normal", "Base.Hat_SummerHat", "Base.Shoes_Sandals" },
            { "Base.Shirt_CropTopTINT", "Base.Shorts_ShortDenim", "Base.Shoes_Random" },
        },
    },
    skills = {
        Strength = { min = 1, max = 4 },
        Fitness = { min = 1, max = 4 },
        Nimble = { min = 1, max = 3 },
        Sneaking = { min = 1, max = 3 },
    },
    loadout = {
        bagChoices = { "Base.Bag_Schoolbag", "Base.Bag_DuffelBag" },
        primaryChoices = { "Base.Hammer", "Base.KitchenKnife", "Base.BaseballBat" },
        supplies = {
            { type = "Base.Bandage", stack = 2, preferredContainer = "bag" },
            { type = "Base.WaterBottleFull", stack = 1, preferredContainer = "bag" },
            { type = "Base.Crisps", stack = 1, preferredContainer = "bag" },
        },
    },
}

PNC.PendingArchetypeBundles.General = bundle

if PNC.RegisterArchetypeBundle then
    PNC.RegisterArchetypeBundle("General", bundle)
end
