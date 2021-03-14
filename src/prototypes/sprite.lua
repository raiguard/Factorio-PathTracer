for i = 0, 15 do
  data:extend{
    {
      type = "sprite",
      name = "ptrc_trace_belt_"..i,
      filename = "__PathTracer__/graphics/visualization/belts.png",
      x = 32 * i,
      size = 32
    }
  }
end

local size = {x = 64, y = 32}
local width = {x = 256, y = 128}
local i = 1
for y = 0, width.y - size.y, size.y do
  for x = 0, width.x - size.x, size.x do
    data:extend{
      {
        type = "sprite",
        name = "ptrc_trace_splitter_"..i,
        width = size.x,
        height = size.y,
        x = x,
        y = y,
        filename = "__PathTracer__/graphics/visualization/splitters.png"
      }
    }
    i = i + 1
  end
end
