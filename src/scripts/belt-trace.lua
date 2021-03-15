local direction_util = require("__flib__.direction")

local constants = require("constants")

local queue = require("lib.queue")

local bor = bit32.bor
local lshift = bit32.lshift

local belt_trace = {}

function belt_trace.start(player, player_table, entity)
  local data = queue.new()
  data.objects = {[entity.unit_number] = {entity = entity}}
  queue.push_right(data, {entity = entity, direction = "input"})
  queue.push_right(data, {entity = entity, direction = "output"})

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

local function append_belt_sprite(sprite, prop_direction, neighbour_direction, entity_direction)
  local direction = 0
  if prop_direction == "input" then
    direction = direction_util.opposite((neighbour_direction - entity_direction) % 8)
  end
  return bor(sprite, lshift(1, direction))
end

function belt_trace.iterate()
  for _, player in pairs(game.connected_players) do
    local player_index = player.index
    -- TODO: Perhaps add a lookup table to top-level `global`?
    local player_table = global.players[player_index]
    local data = player_table.active_trace
    if data then
      -- Iterate the queue
      -- TODO: Make the amount configurable
      for _ = 1, 10 do
        if queue.length(data) == 0 then break end

        local entity_data = queue.pop_left(data)
        local entity = entity_data.entity
        if entity.valid then
          local prop_direction = entity_data.direction
          local opposite_prop_direction = prop_direction == "input" and "output" or "input"

          local neighbours = entity.belt_neighbours[prop_direction.."s"]

          -- Add special-case neighbours
          if entity.type == "linked-belt" and entity.linked_belt_type ~= prop_direction then
            neighbours[#neighbours + 1] = entity.linked_belt_neighbour
          elseif entity.type == "underground-belt" and entity.belt_to_ground_type ~= prop_direction then
            neighbours[#neighbours + 1] = entity.neighbours
          end

          -- Iterate all neighbours
          for _, neighbour in pairs(neighbours) do
            local object = data.objects[neighbour.unit_number]
            if object then
              if object.entity.type == "transport-belt" then
                draw_sprite(
                  object,
                  append_belt_sprite(
                    object.sprite or 0,
                    opposite_prop_direction,
                    entity.direction,
                    neighbour.direction
                  ),
                  player_index
                )
              end
            else
              -- Add neighbour to lookup table right away so it's only iterated once
              data.objects[neighbour.unit_number] = {entity = neighbour}
              -- Iterate the neighbour's neighbours later in the cycle
              queue.push_right(data, {entity = neighbour, direction = prop_direction, source = entity})
            end
          end

          -- Draw sprite
          local obj = data.objects[entity.unit_number]
          if not obj.id then -- The source entity will be iterated twice, so only draw it once
            if entity.type == "transport-belt" then
              local entity_direction = entity.direction
              local sprite = 0
              -- Regular neighbours
              for _, neighbour in pairs(neighbours) do
                sprite = append_belt_sprite(sprite, prop_direction, neighbour.direction, entity_direction)
              end
              -- The "source neighbour" is the one entity from the opposite propagation direction that needs to be
              -- drawn as connected
              -- If the "source neighbour" does not exist, then this is the origin, so draw all connections
              local source = entity_data.source
              if source then
                sprite = append_belt_sprite(sprite, opposite_prop_direction, source.direction, entity_direction)
              else
                for _, neighbour in pairs(entity.belt_neighbours[opposite_prop_direction.."s"]) do
                  sprite = append_belt_sprite(sprite, opposite_prop_direction, neighbour.direction, entity_direction)
                end
              end

              draw_sprite(obj, sprite, player_index)
            end
          end
        end
      end
    end
  end
end

return belt_trace