local event = require("__flib__.event")
local migration = require("__flib__.migration")

local constants = require("constants")

local belt_trace = require("scripts.belt-trace")
local global_data = require("scripts.global-data")
local migrations = require("scripts.migrations")
local player_data = require("scripts.player-data")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()
  global_data.init()

  for i in pairs(game.players) do
    player_data.init(i)
    player_data.refresh(game.get_player(i), global.players[i])
  end
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed(e, migrations) then
    for i, player_table in pairs(global.players) do
      player_data.refresh(game.get_player(i), player_table)
    end
  end
end)

-- ENTITY

event.on_selected_entity_changed(function(e)
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]

  -- TODO: smarts to avoid re-drawing the same path
  if player_table.active_trace then
    -- FIXME: TEMPORARY FOR DEBUG
    return
    -- belt_trace.cancel(player_table)
  end

  local selected = player.selected
  if selected and selected.valid and constants.selection_types[selected.type] then
    belt_trace.start(player, player_table, selected)
  end
end)

-- FIXME: TEMPORARY FOR DEBUG
event.on_gui_opened(function(e)
  local player_table = global.players[e.player_index]
  if player_table.active_trace then
    belt_trace.cancel(player_table)
  end
end)

-- PLAYER

event.on_player_created(function(e)
  player_data.init(e.player_index)
  player_data.refresh(game.get_player(e.player_index), global.players[e.player_index])
end)

event.on_player_removed(function(e)
  global.players[e.player_index] = nil
end)

event.on_player_left_game(function(e)
  local player_table = global.players[e.player_index]
  if player_table.active_trace then
    belt_trace.cancel(player_table)
  end
end)

-- TICK

-- TODO: register conditionally
event.on_tick(function()
  belt_trace.iterate()
end)