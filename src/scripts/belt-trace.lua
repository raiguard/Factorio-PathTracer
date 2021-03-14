local direction_util = require("__flib__.direction")

local constants = require("constants")

local queue = require("lib.queue")

local bor = bit32.bor
local lshift = bit32.lshift

local belt_trace = {}

-- TODO: rename propagation direction to something else

function belt_trace.start(player, player_table, entity)
  local data = queue.new()
  data.objects = {[entity.unit_number] = {entity = entity}}
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

local function draw_sprite(obj, sprite, player_index)
  local entity = obj.entity

  local sprite_file = "ptrc_trace_belt_"..constants.marker_entry[sprite]

  if obj.id then
    rendering.set_sprite(obj.id, sprite_file)
  else
    obj.id = rendering.draw_sprite{
      sprite = sprite_file,
      orientation = entity.direction / 8,
      tint = {r = 1, g = 1},
      target = entity,
      surface = entity.surface,
      players = {player_index}
    }
  end

  obj.sprite = sprite
end

local function interpret_directions(sprite, prop_direction, neighbour_direction, entity_direction)
  local direction = 0
  if prop_direction == "inputs" then
    direction = direction_util.opposite((neighbour_direction - entity_direction) % 8)
  end
  return bor(sprite, lshift(1, direction))
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
          local opposite_prop_direction = prop_direction == "inputs" and "outputs" or "inputs"

          local neighbours = entity.belt_neighbours[prop_direction]

          -- add special-case neighbours
          if entity.type == "linked-belt" then
            neighbours[#neighbours + 1] = entity.linked_belt_neighbour
          elseif entity.type == "underground-belt" then
            neighbours[#neighbours + 1] = entity.neighbours
          end

          -- iterate all neighbours
          for _, neighbour in pairs(neighbours) do
            local object = data.objects[neighbour.unit_number]
            if object then
              if object.entity.type == "transport-belt" then
                draw_sprite(
                  object,
                  interpret_directions(
                    object.sprite or 0,
                    opposite_prop_direction,
                    entity.direction,
                    neighbour.direction
                  ),
                  player_index
                )
              end
            else
              -- add neighbour to lookup table right away so it's only iterated once
              data.objects[neighbour.unit_number] = {entity = neighbour}
              -- iterate the neighbour's neighbours later in the cycle
              queue.push_right(data, {entity = neighbour, direction = prop_direction, source = entity})
            end
          end

          -- draw sprite
          local obj = data.objects[entity.unit_number]
          if entity.type == "transport-belt" then
            local entity_direction = entity.direction
            local sprite = 0
            for _, neighbour in pairs(neighbours) do
              sprite = interpret_directions(sprite, prop_direction, neighbour.direction, entity_direction)
            end
            local source = entity_data.source
            if source then
              sprite = interpret_directions(sprite, opposite_prop_direction, source.direction, entity_direction)
            end
            draw_sprite(obj, sprite, player_index)
          end
        end
      end
    end
  end
end

return belt_trace