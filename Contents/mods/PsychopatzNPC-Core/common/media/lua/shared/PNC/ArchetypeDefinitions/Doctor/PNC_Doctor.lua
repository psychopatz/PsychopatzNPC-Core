--[[
    PNC Doctor Archetype Definition
    Declares a preload-safe archetype bundle for doctor-flavored survivors.
]]

PNC = PNC or {}
PNC.PendingArchetypeBundles = PNC.PendingArchetypeBundles or {}

local bundle = {
    definition = {
        label = "Doctor",
        type = "survivor",
        tags = { "civilian", "medical" },
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
            { "Base.Hat_SurgicalMask", "Base.JacketLong_Doctor", "Base.Shirt_FormalWhite", "Base.Trousers_Suit", "Base.Shoes_Black" },
            { "Base.Hat_SurgicalCap", "Base.Shirt_Scrubs", "Base.Trousers_Scrubs", "Base.Shoes_BlueTrainers" },
            { "Base.Hat_HeadMirrorUP", "Base.JacketLong_Doctor", "Base.Shirt_FormalBlue", "Base.Trousers_Black", "Base.Shoes_Black" },
            { "Base.Glasses_Reading", "Base.Tshirt_Scrubs", "Base.Trousers_Scrubs", "Base.Shoes_BlueTrainers" },
        },
        female = {
            { "Base.Hat_SurgicalMask", "Base.JacketLong_Doctor", "Base.Shirt_FormalWhite", "Base.Skirt_Knees", "Base.Shoes_Black" },
            { "Base.Hat_SurgicalCap", "Base.Shirt_Scrubs", "Base.Trousers_Scrubs", "Base.Shoes_BlueTrainers" },
            { "Base.Hat_HeadMirrorUP", "Base.JacketLong_Doctor", "Base.Shirt_FormalBlue", "Base.Trousers_Black", "Base.Shoes_Black" },
            { "Base.Glasses_Reading", "Base.Tshirt_Scrubs", "Base.Trousers_Scrubs", "Base.Shoes_BlueTrainers" },
        },
    },
    skills = {
        Nimble = { min = 2, max = 4 },
        Sneaking = { min = 1, max = 3 },
        Fitness = { min = 1, max = 3 },
    },
    loadout = {
        bagChoices = { "Base.Bag_DoctorBag", "Base.Bag_Satchel" },
        primaryChoices = { "Base.Scalpel", "Base.KitchenKnife", "Base.Hammer" },
        supplies = {
            { type = "Base.Bandage", stack = 4, preferredContainer = "bag" },
            { type = "Base.Disinfectant", stack = 1, preferredContainer = "bag" },
            { type = "Base.Pills", stack = 1, preferredContainer = "bag" },
        },
    },
}

PNC.PendingArchetypeBundles.Doctor = bundle

if PNC.RegisterArchetypeBundle then
    PNC.RegisterArchetypeBundle("Doctor", bundle)
end
