PNC = PNC or {}
PNC.Identity = PNC.Identity or {}

local Identity = PNC.Identity

Identity.SEED_MAX = 2147483646

function Identity.RollSeed()
    return ZombRand(Identity.SEED_MAX) + 1
end

function Identity.NormalizeSeed(seed, fallback)
    local numeric = math.floor(tonumber(seed) or 0)
    if numeric > 0 then
        numeric = numeric % Identity.SEED_MAX
        if numeric <= 0 then
            numeric = 1
        end
        return numeric
    end
    return Identity.HashText(tostring(fallback or "pnc_seed"))
end

function Identity.HashText(text, seed)
    local value = Identity.NormalizeSeed(seed or 5381, 5381)
    local source = tostring(text or "")
    local i
    for i = 1, #source do
        value = ((value * 33) + string.byte(source, i)) % Identity.SEED_MAX
    end
    if value <= 0 then
        value = 1
    end
    return value
end

function Identity.MixSeed(seed, salt)
    return Identity.HashText(tostring(salt or "seed"), Identity.NormalizeSeed(seed, salt))
end

function Identity.Index(seed, salt, count)
    local size = math.max(0, math.floor(tonumber(count) or 0))
    if size <= 0 then
        return 1
    end
    return (Identity.MixSeed(seed, salt) % size) + 1
end

function Identity.Range(seed, salt, minValue, maxValue)
    local low = math.floor(tonumber(minValue) or 0)
    local high = math.floor(tonumber(maxValue) or low)
    if high < low then
        high = low
    end
    return low + (Identity.MixSeed(seed, salt) % ((high - low) + 1))
end

function Identity.Float(seed, salt)
    return Identity.MixSeed(seed, salt) / Identity.SEED_MAX
end
