local direction_util = require("__flib__.direction")
local table = require("__flib__.table")

local constants = require("constants")

local queue = require("lib.queue")

local belt_trace = {}

-- TODO: rename propagation direction to something else

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

local function draw_sprite(player_index, entity, sprite)
  return rendering.draw_sprite{
    sprite = 'ptrc_trace_belt_'..constants.marker_entry[sprite],
    orientation = entity.direction / 8,
    tint = {r = 1, g = 1},
    target = entity,
    surface = entity.surface,
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
          local prop_direction = entity_data.direction

          -- get standard belt neighbours
          local neighbours = table.map(
            entity.belt_neighbours[entity_data.direction],
            function(neighbour)
              return {entity = neighbour, direction = prop_direction}
            end
          )

          -- add special-case neighbours
          if entity.type == "linked-belt" then
            neighbours[#neighbours + 1] = {entity = entity.linked_belt_neighbour, direction = prop_direction}
          elseif entity.type == "underground-belt" then
            neighbours[#neighbours + 1] = {entity = entity.neighbours, direction = prop_direction}
          end

          -- iterate all neighbours
          for _, neighbour_data in pairs(neighbours) do
            local neighbour = neighbour_data.entity
            local object = data.objects[neighbour.unit_number]
            if object then
              -- TODO: update that object to include the new direction
            else
              -- add neighbour to lookup table right away so it's only iterated once
              data.objects[neighbour.unit_number] = {}
              -- iterate the neighbour's neighbours later in the cycle
              queue.push_right(data, {entity = neighbour, direction = prop_direction, source = entity})
            end
          end

          -- add source entity for sprite purposes, if there is one
          local source = entity_data.source
          if source then
            neighbours[#neighbours + 1] = {
              entity = source,
              direction = constants.opposite_prop_direction[prop_direction]
            }
          end

          -- draw sprite
          local obj = data.objects[entity.unit_number]
          if not obj.id then
            if entity.type == "transport-belt" then
              local entity_direction = entity.direction
              local bor = bit32.bor
              local lshift = bit32.lshift
              local sprite = 0
              for _, neighbour_data in pairs(neighbours) do
                local neighbour = neighbour_data.entity
                local direction = 0
                if neighbour_data.direction == "inputs" then
                  direction = direction_util.opposite((neighbour.direction - entity_direction) % 8)
                end
                sprite = bor(sprite, lshift(1, direction))
              end
              obj.id = draw_sprite(player_index, entity, sprite)
              obj.sprite = sprite
            end
          end
        end
      end
    end
  end
end

return belt_trace