if PNC and PNC.RegisterArchetype then
    PNC.RegisterArchetype("Foreman", {
        label = "Foreman",
        type = "survivor",
        tags = { "civilian", "builder" },
        visualProfile = "companion",
        defaultForFaction = "companion",
        allowedJobs = {
            FollowOwner = true,
            GuardAnchor = true,
            PatrolRoute = true,
        },
    })

    PNC.RegisterArchetypeLooks("Foreman", {
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        male = {
            { "Base.Hat_HardHat", "Base.Vest_Foreman", "Base.Shirt_Workman", "Base.Trousers_JeanBaggy", "Base.Shoes_WorkBoots" },
            { "Base.Hat_HardHat", "Base.Vest_HighViz", "Base.Tshirt_White", "Base.Trousers_Denim", "Base.Shoes_WorkBoots" },
            { "Base.Hat_HardHat_Miner", "Base.Boilersuit", "Base.Shoes_WorkBoots" },
            { "Base.Hat_EarMuff_Protectors", "Base.Shirt_Denim", "Base.Trousers_Padded", "Base.Shoes_WorkBoots" },
        },
        female = {
            { "Base.Hat_HardHat", "Base.Vest_Foreman", "Base.Shirt_Workman", "Base.Trousers_JeanBaggy", "Base.Shoes_WorkBoots" },
            { "Base.Hat_HardHat", "Base.Vest_HighViz", "Base.Tshirt_White", "Base.Trousers_Denim", "Base.Shoes_WorkBoots" },
            { "Base.Hat_HardHat_Miner", "Base.Boilersuit", "Base.Shoes_WorkBoots" },
            { "Base.Hat_EarMuff_Protectors", "Base.Shirt_Denim", "Base.Trousers_Padded", "Base.Shoes_WorkBoots" },
        },
    })

    PNC.RegisterArchetypeSkills("Foreman", {
        Carpentry = { min = 4, max = 7 },
        Masonry = { min = 2, max = 5 },
        Strength = { min = 3, max = 6 },
        Maintenance = { min = 2, max = 5 },
    })

    PNC.RegisterArchetypeLoadout("Foreman", {
        bagChoices = { "Base.Bag_DuffelBag", "Base.Bag_Satchel" },
        primaryChoices = { "Base.Hammer", "Base.Crowbar", "Base.HandAxe" },
        supplies = {
            { type = "Base.Bandage", stack = 1, preferredContainer = "bag" },
            { type = "Base.NailsBox", stack = 1, preferredContainer = "bag" },
            { type = "Base.Plank", stack = 1, preferredContainer = "root" },
        },
    })
end
