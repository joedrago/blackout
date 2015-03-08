Game = require 'Game'

game_ = null

startup = (width, height) ->
  nativeApp =
    log: nativeLog
    drawImage: nativeDrawImage
  game_ = new Game(nativeApp, Number(width), Number(height))
  return

shutdown = ->
  return

update = (dt) ->
  return game_.update(Number(dt))

render = ->
  return game_.render()

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
