local table = require("__flib__.table")

local constants = {}

constants.selection_types = table.invert{
  "transport-belt",
  "underground-belt",
  "splitter",
  "loader",
  "loader-1x1",
  "linked-belt"
}

return constants