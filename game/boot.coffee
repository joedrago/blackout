Game = require 'Game'

game_ = null

startup = (app, width, height) ->
  game_ = new Game(app, width, height)
  return

shutdown = ->
  return

update = ->
  game_.update()
  return

load = (data) ->
  game_.load(data)
  return

save = ->
  return game_.save()

touchDown = (x, y) ->
  game_.touchDown(x, y)
  return

touchMove = (x, y) ->
  game_.touchMove(x, y)
  return

touchUp = (x, y) ->
  game_.touchUp(x, y)
  return
