local Signal = require(script.Parent.Signal)

return {
    PrimaryDatabaseError = Signal.new(),
    SecondaryDatabaseError = Signal.new(),
}