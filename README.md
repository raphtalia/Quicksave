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
