SomeClass = require 'SomeClass'

gGame = null

log = (s) ->
  if gGame != null
    gGame.log(s)

startup = (game) ->
  gGame = game
  log("startup")

  derp = new SomeClass

shutdown = ->
  log("shutdown")

update = ->
  log("update")
