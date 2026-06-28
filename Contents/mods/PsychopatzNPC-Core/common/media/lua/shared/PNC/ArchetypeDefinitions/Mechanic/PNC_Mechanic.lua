if PNC and PNC.RegisterArchetype then
    PNC.RegisterArchetype("Mechanic", {
        label = "Mechanic",
        type = "survivor",
        tags = { "civilian", "mechanic" },
        visualProfile = "companion",
        defaultForFaction = "companion",
        allowedJobs = {
            FollowOwner = true,
            GuardAnchor = true,
            PatrolRoute = true,
        },
    })

    PNC.RegisterArchetypeLooks("Mechanic", {
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        male = {
            { "Base.Hat_BaseballCap_AmericanTire", "Base.Boilersuit", "Base.Shoes_WorkBoots" },
            { "Base.Hat_Bandana", "Base.Shirt_Workman", "Base.Dungarees", "Base.Shoes_WorkBoots" },
            { "Base.Hat_BaseballCap_Gas2Go", "Base.Tshirt_Gas2Go", "Base.Trousers_JeanBaggy", "Base.Shoes_BlackBoots" },
            { "Base.Hat_BaseballCap_ThunderGas", "Base.Boilersuit_BlueRed", "Base.Shoes_WorkBoots" },
        },
        female = {
            { "Base.Hat_BaseballCap_AmericanTire", "Base.Boilersuit", "Base.Shoes_WorkBoots" },
            { "Base.Hat_BandanaTied", "Base.Shirt_Workman", "Base.Dungarees", "Base.Shoes_WorkBoots" },
            { "Base.Hat_BaseballCap_Fossoil", "Base.Tshirt_Fossoil", "Base.Trousers_Denim", "Base.Shoes_WorkBoots" },
            { "Base.Hat_BaseballCap_ThunderGas", "Base.Boilersuit_BlueRed", "Base.Shoes_WorkBoots" },
        },
    })

    PNC.RegisterArchetypeSkills("Mechanic", {
        Mechanics = { min = 5, max = 8 },
        Electrical = { min = 2, max = 5 },
        Maintenance = { min = 3, max = 6 },
        ShortBlunt = { min = 2, max = 4 },
    })

    PNC.RegisterArchetypeLoadout("Mechanic", {
        bagChoices = { "Base.Toolbox_Mechanic", "Base.Bag_DuffelBag" },
        primaryChoices = { "Base.PipeWrench", "Base.Wrench", "Base.Hammer" },
        supplies = {
            { type = "Base.Bandage", stack = 1, preferredContainer = "bag" },
            { type = "Base.Screwdriver", stack = 1, preferredContainer = "bag" },
            { type = "Base.EngineParts", stack = 1, preferredContainer = "bag" },
        },
    })
end
