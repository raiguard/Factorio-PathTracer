local table = require("__flib__.table")

local constants = {}

constants.marker_entry = {
  [0] = 0,
  [1] = 1,
  [4] = 2,
  [5] = 3,
  [16] = 4,
  [17] = 5,
  [20] = 6,
  [21] = 7,
  [64] = 8,
  [65] = 9,
  [68] = 10,
  [69] = 11,
  [80] = 12,
  [81] = 13,
  [84] = 14,
  [85] = 15,
}

constants.selection_types = table.invert{
  "transport-belt",
  "underground-belt",
  "splitter",
  "loader",
  "loader-1x1",
  "linked-belt",
}

return constants