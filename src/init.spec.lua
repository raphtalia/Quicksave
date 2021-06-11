--# selene: allow(shadowing)

local SUPER_SPEED = true

local HttpService = game:GetService("HttpService")

local t = require(script.Parent.t)

local MockDataStoreConstants = require(script.Parent.MockDataStoreService.MockDataStoreService.MockDataStoreConstants)

if SUPER_SPEED then
	MockDataStoreConstants.WRITE_COOLDOWN = 0
	MockDataStoreConstants.BUDGETING_ENABLED = false
end

local progressTime do
	if SUPER_SPEED then
		local getTimeModule = require(script.Parent.getTime)

		local currentTime = 0
		getTimeModule.getTime = function()
			return currentTime
		end

		getTimeModule.testProgressTime = function(amount)
			currentTime = currentTime + amount
		end

		progressTime = getTimeModule.testProgressTime
	else
		progressTime = function() end
	end
end

local MockDataStoreService = require(script.Parent.MockDataStoreService)

MockDataStoreService:ImportFromJSON([[
	{
		"DataStore":{
			"migrationTests":{
				"_package/eryn.io/quicksave":{
					"migrationTest":{
					"data":"{\"generation\":0,\"data\":{\"lockedAt\":1603680426,\"updatedAt\":1603680426,\"lockId\":\"{614A5286-A137-4598-A3EF-54825220DEDC}\",\"data\":{\"oldKey\":\"foobar\"},\"createdAt\":1603680426}}",
					"scheme":"raw/1"
					}
				}
			},
			"playerData":{
				"_package/eryn.io/quicksave":{
					"evaera":{
					"data":"{\"generation\":1,\"data\":{\"lockedAt\":1603680426,\"updatedAt\":1603680426,\"lockId\":\"{614A5286-A137-4598-A3EF-54825220DEDC}\",\"data\":{\"foo\":\"bar\"},\"createdAt\":1603680426}}",
					"scheme":"raw/1"
					},
					"locked":{
					"data":"{\"generation\":1,\"data\":{\"lockedAt\":9999999999,\"updatedAt\":1603680426,\"lockId\":\"{614A5286-A137-4598-A3EF-54825220DEDC}\",\"data\":{\"foo\":\"bar\"},\"createdAt\":1603680426}}",
					"scheme":"raw/1"
					}
				}
			},
			"jsonTests":{
				"_package/eryn.io/quicksave":{
					"jsonTest":{
					"data":"{\"generation\":0,\"data\":{\"updatedAt\":1623375760,\"data\":{\"v9\":[\"_T\",9,[[\"_T\",10,0,20,0],[\"_T\",10,1,20,0] ] ],\"v13\":[\"_T\",13,\"KeyCode\",\"W\"],\"v12\":[\"_T\",12,1,0,1,0],\"v10\":[\"_T\",10,0,1,0.5],\"v4\":[\"_T\",4,16777215],\"v5\":[\"_T\",5,21],\"v3\":[\"_T\",3,1,2,3,1,0,0,0,1,0,0,0,1],\"v8\":[\"_T\",8,10,10],\"v6\":[\"_T\",6,[[\"_T\",7,0,0],[\"_T\",7,1,0] ] ],\"v2\":[\"_T\",2,1,2,3],\"v7\":[\"_T\",7,0,16711680],\"v1\":[\"_T\",1,1,2],\"v11\":[\"_T\",11,1,1]},\"createdAt\":1623375760}}",
					"scheme":"raw/1"
					}
				}
			}
		}
	}
]])

return function()
	warn("Running tests at", SUPER_SPEED and "super speed" or "regular speed")

	local Quicksave = require(script.Parent)

	describe("Quicksave", function()
		it("should be able to create collections", function()
			Quicksave.createCollection("collectionName", {
				schema = {
					foo = t.optional(t.string);
					key = t.optional(t.string);
					oldKey = t.none;
					newKey = t.optional(t.string);
					["1234"] = t.optional(t.exactly("foo"));
				};
				defaultData = {};
			})
		end)

		it("should not allow duplicate collections", function()
			expect(function()
				Quicksave.createCollection("collectionName", {
					schema = {};
					migrations = {};
				})
			end).to.throw()
		end)

		it("should be able to get collections", function()
			local collection = Quicksave.getCollection("collectionName")

			expect(collection).to.be.ok()
			expect(collection.name).to.equal("collectionName")
			expect(Quicksave.getCollection("collectionName")).to.equal(collection)
		end)
	end)

	describe("Collection", function()
		it("should be able to get documents", function()
			local collection = Quicksave.getCollection("collectionName")

			local document = collection:getDocument("foobar"):expect()

			expect(document.collection).to.equal(collection)
			expect(document.name).to.equal("foobar")

			expect(collection:getDocument("foobar"):expect()).to.equal(document)
		end)
	end)

	describe("Document", function()
		Quicksave.createCollection("playerData", {
			schema = {
				foo = t.optional(t.string);
				key = t.optional(t.string);
				oldKey = t.none;
				newKey = t.optional(t.string);
				["1234"] = t.optional(t.exactly("foo"));
			};
			defaultData = {};
		})

		local document, guid

		beforeEach(function()
			guid = HttpService:GenerateGUID()
			document = Quicksave.getCollection("playerData"):getDocument(guid):expect()
		end)

		it("should not be able to load a locked document", function()
			local ok, err = Quicksave.getCollection("playerData"):getDocument("locked"):await()

			expect(ok).to.equal(false)
			expect(err.kind).to.equal(Quicksave.Error.Kind.CouldNotAcquireLock)
		end)

		it("should compress large data", function()
			local doc = Quicksave.getCollection("playerData"):getDocument("large"):expect()

			doc:set("foo", string.rep("a", 2000))
			progressTime(7)
			doc:close():expect()

			if SUPER_SPEED then
				-- otherwise budgets are enabled and this could throttle
				local raw = MockDataStoreService:GetDataStore("playerData", "_package/eryn.io/quicksave"):GetAsync("large")

				expect(#raw < 2000).to.equal(true)
			end

			progressTime(7)

			local doc = Quicksave.getCollection("playerData"):getDocument("large"):expect()
			expect(doc:get("foo")).to.equal(string.rep("a", 2000))
		end)

		it("should be able to load existing data", function()
			local doc = Quicksave.getCollection("playerData"):getDocument("evaera"):expect()

			expect(doc:get("foo")).to.equal("bar")
		end)

		it("should be able to load existing data with a migration", function()
			Quicksave.createCollection("migrationTests", {
				schema = {
					oldKey = t.none;
					newKey = t.string;
				};
				defaultData = {
					newKey = "hi"
				};
				migrations = {
					function(oldData)
						return {
							newKey = oldData.oldKey
						}
					end
				};
			})

			local doc = Quicksave.getCollection("migrationTests"):getDocument("migrationTest"):expect()

			expect(doc:get("newKey")).to.equal("foobar")
			expect(doc:get("oldKey")).to.never.be.ok()
		end)

		it("should give new keys as nil", function()
			expect(document:get("key")).to.equal(nil)
		end)

		it("should be able to retrieve keys", function()
			document:set("key", "foo")

			expect(document:get("key")).to.equal("foo")
		end)

		it("should be able to save", function()
			document:set("foo", "bar")

			progressTime(7)

			document:save():expect()
		end)

		it("should error when writing to a closed document", function()
			document:set("foo", "bar")

			document:close()

			expect(function()
				document:set("foo", "not bar")
			end).to.throw()

			expect(function()
				document:save():expect()
			end).to.throw()
		end)

		it("should be able to save, unlock, relock and load the same data", function()
			document:set("foo", "bar")

			progressTime(7)

			document:close():expect()

			progressTime(7)

			local document2 = Quicksave.getCollection("playerData"):getDocument(guid):expect()

			expect(document).to.never.equal(document2)

			expect(document2:get("foo")).to.equal("bar")
		end)

		it("should convert number keys to strings", function()
			document:set(1234, "foo")

			expect(document:get("1234")).to.equal("foo")
		end)

		it("should disallow unserializable objects from being set", function()
			expect(function()
				document:set("key", workspace)
			end).to.throw()

			expect(function()
				document:set("key", {workspace})
			end).to.throw()

			expect(function()
				document:set("key", {nested = workspace})
			end).to.throw()
		end)

		it("should disallow tables with metatables from being set", function()
			expect(function()
				document:set("key", setmetatable({}, {}))
			end).to.throw()

			expect(function()
				document:set("key", { nested = setmetatable({}, {}) })
			end).to.throw()
		end)

		it("should mark as unsaved after edits", function()
			expect(document:isModified()).to.equal(false)

			document:set("foo", "bar")

			expect(document:isModified()).to.equal(true)
		end)

		it("should mark as saved after saving", function()
			document:set("foo", "bar")

			progressTime(7)

			document:save():expect()

			progressTime(7)

			expect(document:isModified()).to.equal(false)
		end)

		it("should not mark as unsaved if new value is identical to last", function()
			document:set("foo", document:get("foo"))

			expect(document:isModified()).to.equal(false)
		end)

		it("should have no data by default", function()
			local isEmpty = true

			for _ in pairs(document._data._currentData) do
				isEmpty = false
				break
			end

			expect(isEmpty).to.be.equal(true)
		end)

		describe("Document", function()
			Quicksave.createCollection("jsonTests", {
				schema = {
					v1 = t.optional(t.Vector2);
					v2 = t.optional(t.Vector3);
					v3 = t.optional(t.CFrame);
					v4 = t.optional(t.Color3);
					v5 = t.optional(t.BrickColor);
					v6 = t.optional(t.ColorSequence);
					v7 = t.optional(t.ColorSequenceKeypoint);
					v8 = t.optional(t.NumberRange);
					v9 = t.optional(t.NumberSequence);
					v10 = t.optional(t.NumberSequenceKeypoint);
					v11 = t.optional(t.UDim);
					v12 = t.optional(t.UDim2);
					v13 = t.optional(t.EnumItem);
				};
				defaultData = {};
			})

			local document

			beforeEach(function()
				document = Quicksave.getCollection("jsonTests"):getDocument("jsonTest"):expect()
			end)

			it("should deserialize data", function()
				expect(typeof(document:get("v1"))).to.be.equal("Vector2")
				expect(typeof(document:get("v2"))).to.be.equal("Vector3")
				expect(typeof(document:get("v3"))).to.be.equal("CFrame")
				expect(typeof(document:get("v4"))).to.be.equal("Color3")
				expect(typeof(document:get("v5"))).to.be.equal("BrickColor")
				expect(typeof(document:get("v6"))).to.be.equal("ColorSequence")
				expect(typeof(document:get("v7"))).to.be.equal("ColorSequenceKeypoint")
				expect(typeof(document:get("v8"))).to.be.equal("NumberRange")
				expect(typeof(document:get("v9"))).to.be.equal("NumberSequence")
				expect(typeof(document:get("v10"))).to.be.equal("NumberSequenceKeypoint")
				expect(typeof(document:get("v11"))).to.be.equal("UDim")
				expect(typeof(document:get("v12"))).to.be.equal("UDim2")
				expect(typeof(document:get("v13"))).to.be.equal("EnumItem")
			end)

			it("should be able to save, unlock, relock and load the same data", function()
				document:set("v1", Vector2.new(5, 5))

				progressTime(7)

				document:close():expect()

				progressTime(7)

				local document2 = Quicksave.getCollection("jsonTests"):getDocument("jsonTest"):expect()

				expect(document).to.never.equal(document2)

				expect(document2:get("v1")).to.equal(Vector2.new(5, 5))
			end)
		end)
	end)
end