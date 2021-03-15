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

local function draw_sprite(obj, sprite_type, sprite, player_index)
  local entity = obj.entity

  local sprite_file = "ptrc_trace_"..sprite_type.."_"..constants.marker_entry[sprite]

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

local function append_belt_sprite(sprite, prop_direction, neighbour, entity)
  local direction = 0
  if prop_direction == "input" then
    direction = direction_util.opposite((neighbour.direction - entity.direction) % 8)
  end
  return bor(sprite, lshift(1, direction))
end

local function append_splitter_sprite(sprite, prop_direction, neighbour, entity)
  local dir_add = prop_direction == "input" and 4 or 0 -- Additional shift added if it's an input
  local side_add -- Additional shift added if the neighbour is on the right side
  -- Entity direction
  local entity_direction = entity.direction
  local directions = defines.direction
  -- Entity positions
  local entity_position = entity.position
  local neighbour_position = neighbour.position

  -- Check if there are two inline splitters
  if
    neighbour.type == "splitter"
    and (entity_position.x == neighbour_position.x or entity_position.y == neighbour_position.y)
  then
    -- Add connections on both sides in the corresponding direction
    sprite = bor(sprite, lshift(1, dir_add))
    sprite = bor(sprite, lshift(1, dir_add + 2))
  else
    -- Add an individual connection to the corresponding corner
    if entity_direction == directions.north then
      side_add = (neighbour_position.x > entity_position.x) and 2 or 0
    elseif entity_direction == directions.east then
      side_add = (neighbour_position.y > entity_position.y) and 2 or 0
    elseif entity_direction == directions.south then
      side_add = (neighbour_position.x < entity_position.x) and 2 or 0
    elseif entity_direction == directions.west then
      side_add = (neighbour_position.y < entity_position.y) and 2 or 0
    end
    sprite = bor(sprite, lshift(1, side_add + dir_add))
  end

  return sprite
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
              if object.sprite then
                local obj_entity = object.entity
                local entity_type = obj_entity.type
                if entity_type == "transport-belt" or entity_type == "splitter" then
                  local append_func = entity_type == "transport-belt" and append_belt_sprite or append_splitter_sprite
                  draw_sprite(
                    object,
                    entity_type == "transport-belt" and "belt" or "splitter",
                    append_func(
                      object.sprite or 0,
                      opposite_prop_direction,
                      obj_entity,
                      neighbour
                    ),
                    player_index
                  )
                  -- TODO: Temporary
                  rendering.draw_circle{
                    color = {r = 0.5, a = 0.5},
                    filled = true,
                    radius = 0.15,
                    target = entity,
                    players = {player_index},
                    surface = entity.surface,
                    time_to_live = 2
                  }
                end
              elseif object.sources then
                object.sources[#object.sources + 1] = entity
              end
            else
              -- Add neighbour to lookup table right away so it's only iterated once
              data.objects[neighbour.unit_number] = {entity = neighbour, sources = {entity}}
              -- Iterate the neighbour's neighbours later in the cycle
              queue.push_right(data, {entity = neighbour, direction = prop_direction})
            end
          end

          -- Draw sprite
          local obj = data.objects[entity.unit_number]
          if not obj.id then -- The source entity will be iterated twice, so only draw it once
            -- TODO: deduplicate?
            local sprite = 0
            local sprite_type
            local entity_type = entity.type
            if entity_type == "transport-belt" or entity_type == "splitter" then
              sprite_type = entity_type == "splitter" and "splitter" or "belt"
              -- use a different append sprite function for belts and splitters
              local append_func = entity_type == "splitter" and append_splitter_sprite or append_belt_sprite
              -- Regular neighbours
              for _, neighbour in pairs(neighbours) do
                sprite = append_func(sprite, prop_direction, neighbour, entity)
              end
              -- The "source neighbour" is the one entity from the opposite propagation direction that needs to be
              -- drawn as connected
              -- If the "source neighbour" does not exist, then this is the origin, so draw all connections
              local sources = obj.sources
              if sources then
                for _, source in pairs(sources) do
                  sprite = append_func(sprite, opposite_prop_direction, source, entity)
                  -- TODO: Temporary
                  rendering.draw_circle{
                    color = {r = 0.5, a = 0.5},
                    filled = true,
                    radius = 0.15,
                    target = source,
                    players = {player_index},
                    surface = source.surface,
                    time_to_live = 2
                  }
                end
              else
                for _, neighbour in pairs(entity.belt_neighbours[opposite_prop_direction.."s"]) do
                  sprite = append_func(sprite, opposite_prop_direction, neighbour, entity)
                end
              end
            end
            if sprite_type then -- TEMPORARY
              draw_sprite(obj, sprite_type, sprite, player_index)
            end
          end
        end
      end
    end
  end
end

return belt_trace