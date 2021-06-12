local IS_STUDIO = game:GetService("RunService"):IsStudio()

return {
    -- Collection
    DOCUMENT_COOLDOWN = 7,

    -- Document
    ALLOW_CLEAN_SAVING = false,
    AUTOSAVE_INTERVAL = IS_STUDIO and 30 or 5 * 60,
    SUPPORTED_TYPES = {
        "nil",
        "string",
        "boolean",
        "number",
        "table",

        "Vector2",
        "Vector3",
        "CFrame",
        "Color3",
        "BrickColor",
        "ColorSequence",
        "ColorSequenceKeypoint",
        "NumberRange",
        "NumberSequence",
        "NumberSequenceKeypoint",
        "UDim",
        "UDim2",
        "EnumItem",
    },

    -- LockSession
    LOCK_EXPIRE = IS_STUDIO and 5 or 60 * 5,
    WRITE_MAX_INTERVAL = 7,

    -- DataLayer
    COMPRESSION_ENABLED = true,
    MINIMUM_LENGTH_TO_COMPRES = {
        Standard = 1000,
    },

    -- RetryLayer
    MAX_RETRIES = 5,

    -- DataStoreLayer
    SCOPE = "_package/eryn.io/quicksave",
}