# Quicksave

DataStore abstraction library that offers:

- Collection/Document structure
- Session locking
- Schemas
- Migrations
- Data compression
- Automatic retry
- Automatic throttling
- Backups
- Promise-based API
- Developer sanity

Not ready for production yet. Needs a lot more tests.

## Concepts

### Collections

Collections are analogous to Roblox Datastores. Collections contain documents. For each collection, you, as the developer, specify:

- A schema that each document in the collection must follow
- The default data that new documents should have (this must adhere to the schema)
- A set of migrations that run in order to translate documents that follow older versions of the schema into the current version.

### Documents

Documents are potentially large data structures that are related to each other. Typically, you will have one document per player of your game. Documents are read and written to as one operation to the DataStore, because a document is always stored in a single DataStore key.

Acquiring a document also means that you have an exclusive lock on the data inside of it. Another game server can never write to this document as long as it's active on the current server.

Documents have keys which you can read or write to individually. You can only read or write keys that are present in the collection's schema.

Data within a document is automatically compressed which allows you to have larger documents.

Reading from or writing to a document does not yield. By the time you have a reference to a document, all of its data has loaded. Documents are automatically saved on a periodic interval and saved when the game server closes. You can also manually save a document at any time.

Due to DataStore throttling, saving is not instant. Documents will only ever save their latest data. If the save is throttled and you call save multiple times, the document will only save once with the latest data.

Documents can be closed, which unlocks the document, allowing other game servers to acquire a lock on it. Documents always save their current data upon closing. You are unable to write to a document that has begun closing. Closing a document can take up to a few seconds due to DataStore throttling.

Once a document has fully closed and become inactive, attempting to open the document again immediately will be delayed for up to seven seconds due to DataStore throttling.

### Migrations

If you ever need to change the structure data in your schema, you can write a migration which can convert existing documents to the current schema. All migrations that ocurred between the current document and the present schema will be run in order.

### Databases

The primary database by default is DataStores. The secondary database is used for backups and must be configured. You can configure the primary and secondary databases to be switched
in roles allowing an external database to be used as the primary and DataStores as the secondary.

Backups are only used if the primary database is reachable and returns outdated or no data to avoid potentially overwriting data on the primary database.

A backup server example can be found [here](https://github.com/raphtalia/QuicksaveSQLite3).

## Internals

Data flows through the library in this order:

1. AccessLayer (Handles locks)
2. MigrationLayer
3. DataLayer (Handles compression)
   1. Primary Database (DataStores)
      1. RetryLayer
      2. ThrottleLayer
      3. DataStoreLayer
      4. Roblox Datastores
   2. Secondary Database (Optional)
      1. RetryLayer
      2. ThrottleLayer
      3. BackupLayer (Must be configured)

## To do

- Write more tests. And more tests. And more tests.
- Easy way to tie documents to players

## API

Proper documentation site will be setup eventually.

### Properties

#### Quicksave

`t Quicksave.t`

`Promise Quicksave.Promise`

`Error Quicksave.Error`

`JSON Quicksave.JSON`

`boolean Quicksave.Constants.AUTO_CLOSE_DOCUMENTS`
Automatically closes documents when the game is closing. Documents will be
saved to the primary and secondary databases.

`number Quicksave.Constants.MAX_EXTERNAL_REQUESTS`
Maximum requests that can be made to the BackupLayer within a 60 second
interval. **This does not refer to HTTP request limit but simply how many times
`EXTERNAL_DATABASE_HANDLER` can be called.**

`number Quicksave.Constants.DOCUMENT_COOLDOWN`
Minimum amount of time between closing and re-opening the same document.

`boolean Quicksave.Constants.ALLOW_CLEAN_SAVING`
Allows saving a document when it is not dirty.

`boolean Quicksave.Constants.AUTOSAVE_ENABLED`
Enables automatic saving interval. The timer is unique for each document as it
begins when the document is opened.

`number Quicksave.Constants.AUTOSAVE_INTERVAL`
Interval between automatic saves.

`string[] Quicksave.Constants.SUPPORTED_TYPES`
List of supported data types. Tables with metatables are always excluded.

`number Quicksave.Constants.LOCK_EXPIRE`
Time since last write of a document before the lock session expires.

`number Quicksave.Constants.WRITE_MAX_INTERVAL`
Minimum time before the same document can write again.

`boolean Quicksave.Constants.COMPRESSION_ENABLED`
Enables compression of data.

`dictionary Quicksave.Constants.MINIMUM_LENGTH_TO_COMPRES`
Minimum data length for compression algorithms to be used.

`boolean Quicksave.Constants.USE_EXTERNAL_DATABASE_AS_PRIMARY`
Uses the external database as the primary database and DataStores as the
secondary.

`function Quicksave.Constants.EXTERNAL_DATABASE_HANDLER`
Handler for reading & writing data to the external database. An example can be
found [here](https://github.com/raphtalia/QuicksaveSQLite3).

`number Quicksave.Constants.DATASTORES_MAX_RETRIES`
Maximum attempts to reach DataStore API before throwing error.

`number Quicksave.Constants.EXTERNAL_MAX_RETRIES`
Maximum attempts to reach external database API before throwing error.

`string Quicksave.Constants.DATASTORE_SCOPE`
Name of scope to use in DataStores.

#### Document

`Collection Document.collection`
Collection the document belongs to.

`string Document.name`
Name of the document.

### Methods

#### Quicksave

`Collection Quicksave.createCollection(collectionName: string, options: dictionary)`
Creates a new collection with the given name. Will error if the collection
already exists. This method should be called at the beginning of every server.

`Collection Quicksave.getCollection(collectionName: string)`
Returns the collection with the given name. Will error if the collection
hasn't been created yet.

#### Collection

`Promise Collection:getDocument(documentName: string)`
Returns or creates a document with the given name. **The return is a promise
and not actually the document.** Use `:expect()` on the promise to yield until
the document loads.

`Document[] Collection:getActiveDocuments()`
Returns all active documents. **Some returned documents may be closed as they
are considered active until they finish closing.**

`number Collection:getLatestMigrationVersion()`
Returns the latest migration version.

`dictionary Collection:validateData(data: {})`
Returns if the data meets the collection's schema.

`boolean Collection:keyExists(key: string)`
Returns if a key exists in the collection's schema.

`boolean Collection:validateKey(key: string, value: any)`
Returns if a value meets a key's schema in the colelction.

#### Document

`variant Document:get(key: string)`
Returns the value of the requested key.

`void Document:set(key: string, value: any)`
Sets the value of the requested key. This method cannot be called if the
document is closed or saving.

`Promise Document:save()`
Saves the document to the primary database. By default this method cannot be
called unless the document is dirty.

`Promise Document:backup()`
Saves the document to the secondary database. **The document will still be
considered dirty afterwards.**

`Promise Document:close()`
Saves the document to the primary and secondary databases then closes the
document.

`number Document:getLastSaveElapsedTime()`
Returns the time in seconds that has elapsed since the last save to the primary
database.

`boolean Document:isLoaded()`
Returns if the document has finished loading.

`boolean Document:isClosed()`
Returns if the document is closed.

`boolean Document:isDirty()`
Returns if the document has unsaved modifications.

`boolean Document:isSaving()`
Returns if the document is in the middle of saving.

### Events

#### Quicksave

`string Quicksave.PrimaryDatabaseError`
Fires with the error if the primary database fails to handle a request.

`string Quicksave.SecondaryDatabaseError`
Fires with the error if the secondary database fails to handle a request.

#### Document

`void Document.saved`
Fires when the document is saved to the primary database.

`void Document.closed`
Fires when the document is closed.

`string, variant, variant Document.changed(key: string, newValue: any, oldValue: any)`
Fires when the document is edited.
