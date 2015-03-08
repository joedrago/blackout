Game = require 'Game'

game_ = null

startup = (width, height) ->
  nativeApp =
    log: nativeLog
  game_ = new Game(nativeApp, width, height)
  return

shutdown = ->
  return

update = (dt) ->
  return game_.update(dt)

render = ->
  return game_.render()

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
