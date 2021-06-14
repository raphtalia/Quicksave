local IS_STUDIO = game:GetService("RunService"):IsStudio()

return {
    -- Quicksave
    AUTO_CLOSE_DOCUMENTS = true,

    -- Backups
    MAX_BACKUP_REQUESTS = 300, -- Per minute

    -- Collection
    DOCUMENT_COOLDOWN = 7,

    -- Document
    ALLOW_CLEAN_SAVING = false,
    AUTOSAVE_ENABLED = true,
    AUTOSAVE_INTERVAL = IS_STUDIO and 10 or 5 * 60,
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
    BACKUP_HANDLER = nil,

    -- RetryLayer
    DATASTORES_MAX_RETRIES = 5,
    BACKUPS_MAX_RETRIES = 3,

    -- DataStoreLayer
    DATASTORE_SCOPE = "_package/eryn.io/quicksave",
}