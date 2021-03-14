local queue = require("lib.queue")

local belt_trace = {}

function belt_trace.start(player, player_table, entity)
  local data = queue.new()
  data.objects = {[entity.unit_number] = {}}
  queue.push_right(data, {entity = entity, direction = "inputs"})
  queue.push_right(data, {entity = entity, direction = "outputs"})

  player_table.active_trace = data
end

function belt_trace.cancel(player_table)
  for _, obj in pairs(player_table.active_trace.objects) do
    if obj.id then
      rendering.destroy(obj.id)
    end
  end
  player_table.active_trace = nil
end

local function draw_sprite(player_index, entity)
  return rendering.draw_circle{
    color = {r = 1, g = 1},
    filled = true,
    radius = 0.3,
    surface = entity.surface,
    target = entity.position,
    players = {player_index}
  }
end

function belt_trace.iterate()
  for _, player in pairs(game.connected_players) do
    local player_index = player.index
    -- TODO: perhaps add a lookup table to top-level `global`?
    local player_table = global.players[player_index]
    local data = player_table.active_trace
    if data then
      -- iterate the queue
      -- TODO: make the amount configurable
      for _ = 1, 10 do
        if queue.length(data) == 0 then break end

        local entity_data = queue.pop_left(data)
        local entity = entity_data.entity
        if entity.valid then
          -- get standard belt neighbours
          local neighbours = entity.belt_neighbours[entity_data.direction]

          -- add special-case neighbours
          if entity.type == "linked-belt" then
            neighbours[#neighbours + 1] = entity.linked_belt_neighbour
          elseif entity.type == "underground-belt" then
            neighbours[#neighbours + 1] = entity.neighbours
          end

          -- iterate all neighbours
          for _, neighbour in pairs(neighbours) do
            if data.objects[neighbour.unit_number] then
              -- TODO: update that object to include the new direction
            else
              -- iterate the neighbour's neighbours later in the cycle
              queue.push_right(data, {entity = neighbour, direction = entity_data.direction, source = entity})
              -- add neighbour to lookup table right away
              data.objects[neighbour.unit_number] = {}
            end
          end

          -- add source entity for sprite purposes, if there is one
          -- currently unused
          neighbours[#neighbours + 1] = entity_data.source

          -- draw sprite
          local obj = data.objects[entity.unit_number]
          if not obj.id then
            obj.id = draw_sprite(player_index, entity)
          end
        end
      end
    end
  end
end

return belt_trace