PNC = PNC or {}
PNC.Archetypes = PNC.Archetypes or {}

local Archetypes = PNC.Archetypes
local Core = PNC.Core

local Catalog = {
    General = {
        id = "General",
        label = "General Survivor",
        visualProfile = "companion",
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        looks = {
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
        hair = {
            male = { "Messy", "Short", "ShortHair", "Baldspot", "Recede", "Crewcut", "FlatTop", "Afro" },
            female = { "Long", "Ponytail", "Bob", "Messy", "Short", "Bun", "Afro", "Rachel" },
        },
        beard = { "FullBeard", "Goatee", "Moustache", "ShortBoxedBeard", false, false, false },
        skin = {
            male = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04" },
            female = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04" },
        },
        skillBias = {
            Strength = { min = 1, max = 4 },
            Fitness = { min = 1, max = 4 },
            Nimble = { min = 1, max = 3 },
            Sneaking = { min = 1, max = 3 },
        },
    },
    Farmer = {
        id = "Farmer",
        label = "Farmer",
        visualProfile = "companion",
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        looks = {
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
        hair = {
            male = { "Messy", "Short", "Baldspot", "Crewcut", "FlatTop" },
            female = { "Ponytail", "Long", "Messy", "Bob", "Bun" },
        },
        beard = { "FullBeard", "Goatee", "Moustache", false, false },
        skin = {
            male = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04" },
            female = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04" },
        },
        skillBias = {
            Agriculture = { min = 4, max = 7 },
            AnimalCare = { min = 2, max = 5 },
            Butchering = { min = 1, max = 4 },
            Strength = { min = 2, max = 5 },
        },
    },
    Mechanic = {
        id = "Mechanic",
        label = "Mechanic",
        visualProfile = "companion",
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        looks = {
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
        },
        hair = {
            male = { "Messy", "Short", "Crewcut", "Baldspot", "Recede" },
            female = { "Ponytail", "Messy", "Long", "Short", "Bob" },
        },
        beard = { "Goatee", "Stubble", "Moustache", false, false },
        skin = {
            male = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04" },
            female = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04" },
        },
        skillBias = {
            Mechanics = { min = 5, max = 8 },
            Electrical = { min = 2, max = 5 },
            Maintenance = { min = 3, max = 6 },
            ShortBlunt = { min = 2, max = 4 },
        },
    },
    Doctor = {
        id = "Doctor",
        label = "Doctor",
        visualProfile = "companion",
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        looks = {
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
        hair = {
            male = { "Short", "Messy", "Recede", "Crewcut" },
            female = { "Bun", "Ponytail", "Bob", "Long" },
        },
        beard = { "ShortBoxedBeard", "Goatee", false, false },
        skin = {
            male = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04" },
            female = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04" },
        },
        skillBias = {
            Cooking = { min = 1, max = 3 },
            Electrical = { min = 1, max = 3 },
            Nimble = { min = 2, max = 4 },
            Sneaking = { min = 1, max = 3 },
        },
    },
    Foreman = {
        id = "Foreman",
        label = "Foreman",
        visualProfile = "companion",
        spawnOutfit = {
            male = "PNCCompanionMale",
            female = "PNCCompanionFemale",
        },
        looks = {
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
        },
        hair = {
            male = { "Short", "Messy", "Crewcut", "Recede" },
            female = { "Ponytail", "Bob", "Bun", "Long" },
        },
        beard = { "FullBeard", "Goatee", "Moustache", false },
        skin = {
            male = { "MaleBody01", "MaleBody02", "MaleBody03", "MaleBody04" },
            female = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04" },
        },
        skillBias = {
            Carpentry = { min = 4, max = 7 },
            Masonry = { min = 2, max = 5 },
            Strength = { min = 3, max = 6 },
            Maintenance = { min = 2, max = 5 },
        },
    },
    Scavenger = {
        id = "Scavenger",
        label = "Scavenger",
        visualProfile = "hostile",
        spawnOutfit = {
            male = "PNCHostileMale",
            female = "PNCHostileFemale",
        },
        looks = {
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
        },
        hair = {
            male = { "Messy", "Baldspot", "Short", "Recede" },
            female = { "Messy", "Long", "Ponytail", "Short" },
        },
        beard = { "FullBeard", "Stubble", "Goatee", false, false },
        skin = {
            male = { "MaleBody02", "MaleBody03", "MaleBody04" },
            female = { "FemaleBody02", "FemaleBody03", "FemaleBody04" },
        },
        skillBias = {
            Sneaking = { min = 3, max = 6 },
            Nimble = { min = 3, max = 6 },
            ShortBlade = { min = 2, max = 5 },
            Maintenance = { min = 1, max = 4 },
        },
    },
}

local CompanionDefaults = { "General", "Farmer", "Mechanic", "Doctor", "Foreman" }
local HostileDefaults = { "Scavenger", "Mechanic", "Foreman", "General" }

function Archetypes.Get(id)
    local key = tostring(id or "General")
    return Catalog[key] or Catalog.General
end

function Archetypes.GetCompanionDefaults()
    return CompanionDefaults
end

function Archetypes.GetHostileDefaults()
    return HostileDefaults
end

function Archetypes.List()
    return Core.DeepCopy(Catalog)
end
