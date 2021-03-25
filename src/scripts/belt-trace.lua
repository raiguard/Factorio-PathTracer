local direction_util = require("__flib__.direction")
local table = require("__flib__.table")

local constants = require("constants")

local queue = require("lib.queue")

local bor = bit32.bor
local lshift = bit32.lshift

local belt_trace = {}

--[[
  THE PROBLEM:
  There exists an edge-case where if a loop is introduced into the traced path that includes splitters, the splitters
  will not have all of the relevant connections. We need to somehow keep track of all splitters that are "behind" each
  branch of the trace, and in the case that two branches meet, iterate all of those splitters again in the opposite
  direction.

  THE STRUCTURE:
  [top level]
    entities: A lookup table of entity data, keyed by the entity's unit number
      [unit_number]
        backtraced: if this splitter has been backtraced, will contain the direction it was backtraced in
        entity: reference to the LuaEntity itself
        key: the entity's location in the iteration queue. one it has been iterated, this is removed
        render_objects: this entity's render objects
    [queue index]
      entity_number: the unit_number of the entity to iterate
      side: the side to iterate
      splitters: splitters that are "behind" this iteration

  THE LOGIC:
  (on belt hovered)
    add to queue:
      entity_number
      splitters: {}
    add to `entities`:
      entity
      key: [queue key]

  (on tick)
    (repeat x times)
      pop `iteration` from front of queue
      pull `entity_data` from `entities`

      pull `side` from iteration
      create `opposite_side`

      assemble `connections`:
        if `side`
          each belt neighbour in `opposite_side`
          each belt neighbour that has already has an entry in `entities`
        else
          every belt neighbour

        if linked belt and linked belt type ~= `side`:
          linked belt neighbour
        elseif underground belt and underground belt type ~= `side`:
          underground belt neighbour

      create `sprite`

      iterate `connections` with `connection`:
        pull `connection_data` from `entities`
        if `connection_data`
          pull `key` from `connection_data`
          if `key` -- hasn't been iterated yet
            pull `other_iteration` from the queue by `key`
            if `other_iteration.side` ~= `side
              iterate `other_iteration.splitters` with `splitter_unit_number`
                add to queue:
                  entity_number: `splitter_unit_number`
                  side: `side`
                  splitters: {}
              iterate `iteration.splitters` with `splitter_unit_number`
                add to queue:
                  entity_number: `splitter_unit_number`
                  side: `opposite_side`
                  splitters: {}
          else
            -- TODO: update connection's sprite
        else
          if `entity_data.entity.type` is splitter`:
            append to `iteration.splitters`:
              `entity_data.entity.unit_number

          add to queue:
            entity_number: `connection_data.entity.unit_number`
            side: `side`
            splitters: `iteration.splitters`

          add to `entities`:
            entity: `connection`
            key: [end of queue index]

      add dummy sprite to `entity`
]]

function belt_trace.start(player, player_table, entity)
  local data = queue.new()
  data.entities = {[entity.unit_number] = {entity = entity}}
  queue.push_right(data, {entity_number = entity.unit_number, splitters = {}})

  player_table.active_trace = data
end

function belt_trace.cancel(player_table)
  for _, obj in pairs(player_table.active_trace.entities) do
    if obj.render_objects then
      for _, id in pairs(obj.render_objects) do
        rendering.destroy(id)
      end
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

local function append_belt_sprite(sprite, iter_direction, neighbour, entity)
  local direction = 0
  if iter_direction == "inputs" then
    direction = direction_util.opposite((neighbour.direction - entity.direction) % 8)
  end
  return bor(sprite, lshift(1, direction))
end

local function append_splitter_sprite(sprite, iter_direction, neighbour, entity)
  local dir_add = iter_direction == "inputs" and 4 or 0 -- Additional shift added if it's an input
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

-- Flatten belt_neighbours into a connections table
local function build_connections(entities, entity, iter_side)
  local connections = {}

  -- Add standard connections
  for side, neighbours in pairs(entity.belt_neighbours) do
    for _, neighbour in pairs(neighbours) do
      if not iter_side or side == iter_side or entities[neighbour.unit_number] then
        connections[#connections + 1] = {entity = neighbour, side = side}
      end
    end
  end

  -- Add special-case connections
  if entity.type == "linked-belt" then
    local neighbour = entity.linked_belt_neighbour
    if neighbour then
      connections[#connections + 1] = {entity = neighbour, side = neighbour.linked_belt_type.."s"}
    end
  elseif entity.type == "underground-belt" then
    local neighbour = entity.neighbours
    if neighbour then
      connections[#connections + 1] = {entity = neighbour, side = neighbour.belt_to_ground_type.."s"}
    end
  end

  return connections
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
      local entities = data.entities
      for _ = 1, 1 do
        if queue.length(data) == 0 then break end

        local iteration = queue.pop_left(data)

        local entity_data = entities[iteration.entity_number]
        entity_data.key = nil -- This key will no longer be valid

        local entity = entity_data.entity
        if entity.valid then
          local side = iteration.side
          local opposite_side = side and (side == "inputs" and "outputs" or "inputs") or nil

          local connections = build_connections(entities, entity, side)

          -- Add this entity to the splitters list if it is one
          local splitters = iteration.splitters
          if entity.type == "splitter" then
            splitters[entity.unit_number] = true
          end

          for _, connection_info in ipairs(connections) do
            local connection = connection_info.entity
            local connection_unit_number = connection.unit_number
            local connection_data = entities[connection_unit_number]
            if connection_data then
              -- If `key` exists, then this entity has not been iterated yet
              local key = connection_data.key
              if key then
                local connection_iteration = data[key] -- TODO: Guaranteed to exist?
                -- If this is true, then two branches of the trace are colliding head-on, resulting in a loop
                if connection_iteration.side ~= side then
                  -- Backtrace all splitters to update their connections on the opposite sides
                  for splitter_unit_number in pairs(splitters) do
                    local splitter_data = entities[splitter_unit_number]
                    if not splitter_data.backtraced then
                      splitter_data.backtraced = true
                      queue.push_right(
                        data,
                        {entity_number = splitter_unit_number, side = opposite_side, splitters = {}}
                      )
                    end
                  end
                  -- Backtrace all splitters on the other branch as well
                  for splitter_unit_number in pairs(connection_iteration.splitters) do
                    local splitter_data = entities[splitter_unit_number]
                    if not splitter_data.backtraced then
                      splitter_data.backtraced = true
                      queue.push_right(data, {entity_number = splitter_unit_number, side = side, splitters = {}})
                    end
                  end
                  -- If the connection itself is a splitter, remove its iteration side so all connections are traced
                  if connection.type == "splitter" then
                    connection_iteration.side = nil
                  end
                end
              else
                -- TODO: update sprite
              end
            else
              -- Iterate the connection in the future
              queue.push_right(
                data,
                {
                  entity_number = connection.unit_number,
                  side = connection_info.side,
                  splitters = table.shallow_copy(splitters)
                }
              )
              -- Add the connection to the entities table
              entities[connection.unit_number] = {
                entity = connection,
                key = data.last
              }
            end
          end

          if not entity_data.render_objects then
            entity_data.render_objects = {
              dummy = rendering.draw_circle{
                color = {r = 1, g = 1},
                filled = true,
                players = {player_index},
                radius = 0.15,
                surface = entity.surface,
                target = entity
              }
            }
          else
            rendering.draw_circle{
              color = {r = 1},
              filled = true,
              players = {player_index},
              radius = 0.15,
              surface = entity.surface,
              target = entity,
              time_to_live = 2
            }
          end
        end
      end
    end
  end
end

return belt_trace
