SomeClass = require 'SomeClass'

app_ = null
state_ =
  count: 0

log = (s) ->
  if app_ != null
    app_.log(s)

startup = (app) ->
  app_ = app
  log("startup")

  derp = new SomeClass

shutdown = ->
  log("shutdown")

update = ->
  log("update")

load = (data) ->
  log("load: #{data}")
  if data.length > 0
    state_ = JSON.parse(data)
  log("load: state is now #{JSON.stringify(state_)}")

save = ->
  log("save")
  state_.count++
  return JSON.stringify(state_)
