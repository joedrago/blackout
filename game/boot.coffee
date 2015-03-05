Game = require 'Game'

game_ = null

startup = (app, width, height) ->
  game_ = new Game(app, Number(width), Number(height))
  return

shutdown = ->
  return

update = (dt) ->
  game_.update(Number(dt))
  return

load = (data) ->
  game_.load(data)
  return

save = ->
  return game_.save()

touchDown = (x, y) ->
  game_.touchDown(Number(x), Number(y))
  return

touchMove = (x, y) ->
  game_.touchMove(Number(x), Number(y))
  return

touchUp = (x, y) ->
  game_.touchUp(Number(x), Number(y))
  return
