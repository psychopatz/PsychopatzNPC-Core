if PNC and PNC.RegisterArchetype then
    PNC.RegisterArchetype("Scavenger", {
        label = "Scavenger",
        type = "raider",
        tags = { "hostile", "scavenger" },
        visualProfile = "hostile",
        defaultForFaction = "hostile",
        allowedJobs = {
            RoamArea = true,
            HuntNearestPlayer = true,
            EngageTarget = true,
        },
    })

    PNC.RegisterArchetypeLooks("Scavenger", {
        spawnOutfit = {
            male = "PNCHostileMale",
            female = "PNCHostileFemale",
        },
        male = {
            { "Base.Hat_Beany", "Base.PonchoGarbageBag", "Base.Trousers_JeanBaggy", "Base.Shoes_Slippers" },
            { "Base.Hat_GasMask", "Base.HoodieDOWN_WhiteTINT", "Base.Trousers_Crafted_Burlap", "Base.Shoes_Random" },
            { "Base.Hat_BalaclavaFace", "Base.Jacket_PaddedDOWN", "Base.Trousers_Padded", "Base.Shoes_BlackBoots" },
            { "Base.Hat_HeadSack_Burlap", "Base.Shirt_Crafted_DenimRandom", "Base.Trousers_Crafted_DenimRandom", "Base.Shoes_TrainerTINT" },
        },
        female = {
            { "Base.Hat_Beany", "Base.PonchoGarbageBag", "Base.Trousers_JeanBaggy", "Base.Shoes_Slippers" },
            { "Base.Hat_GasMask", "Base.HoodieDOWN_WhiteTINT", "Base.Skirt_Long_Crafted_Burlap", "Base.Shoes_Random" },
            { "Base.Hat_BalaclavaFace", "Base.Jacket_PaddedDOWN", "Base.Trousers_Padded", "Base.Shoes_BlackBoots" },
            { "Base.Hat_HeadSack_Burlap", "Base.Dress_Knees_Crafted_DenimRandom", "Base.Shoes_TrainerTINT" },
        },
    })

    PNC.RegisterArchetypeSkills("Scavenger", {
        Sneaking = { min = 3, max = 6 },
        Nimble = { min = 3, max = 6 },
        ShortBlade = { min = 2, max = 5 },
        Maintenance = { min = 1, max = 4 },
    })

    PNC.RegisterArchetypeLoadout("Scavenger", {
        bagChoices = { "Base.Bag_Schoolbag", "Base.Bag_DuffelBag" },
        primaryChoices = { "Base.KitchenKnife", "Base.Pipe", "Base.HandAxe" },
        supplies = {
            { type = "Base.Bandage", stack = 1, preferredContainer = "bag" },
            { type = "Base.WaterBottleEmpty", stack = 1, preferredContainer = "bag" },
            { type = "Base.Crisps", stack = 1, preferredContainer = "bag" },
        },
    })
end
