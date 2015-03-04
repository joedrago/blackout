CardRenderer = require 'CardRenderer'

class Game
  constructor: (@native, @width, @height) ->
    @native.log("Game constructed: #{@width}x#{@height}")
    @cardRenderer = new CardRenderer @native, @width, @height

    @x = @width / 2
    @y = @height / 2
    @which = 0
    @dragging = false

    @handSize = 13
    @hand = (v for v in [0...13])

  load: (data) ->
    @native.log "load: #{data}"

  save: ->
    @native.log "save"
    return "{}"

  touchDown: (@x, @y) ->
    @dragging = true
    @which = (@which + 1) % 52

    @handSize--
    @handSize = 13 if @handSize == 0
    @hand = (v for v in [0...@handSize])

  touchMove: (x, y) ->
    if @dragging
      @x = x
      @y = y
  touchUp: (@x, @y) ->
    @dragging = false

  update: ->
    @cardRenderer.renderHand @hand

module.exports = Game
