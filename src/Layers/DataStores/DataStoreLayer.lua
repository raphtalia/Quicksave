local Constants = require(script.Parent.Parent.Parent.QuicksaveConstants)

local DataStoreService = require(script.Parent.Parent.Parent.MockDataStoreService)

local DataStoreLayer = {
    _dataStores = {};
}

function DataStoreLayer._getDataStore(collectionName)
    if DataStoreLayer._dataStores[collectionName] == nil then
        DataStoreLayer._dataStores[collectionName] = DataStoreService:GetDataStore(collectionName, Constants.DATASTORE_SCOPE)
    end

    return DataStoreLayer._dataStores[collectionName]
end

function DataStoreLayer.perform(methodName, collectionName, ...)
    local dataStore = DataStoreLayer._getDataStore(collectionName)

    return dataStore[methodName](dataStore, ...)
end

return DataStoreLayer