CARD_IMAGE_W = 120
CARD_IMAGE_H = 162
CARD_IMAGE_OFF_X = 4
CARD_IMAGE_OFF_Y = 4
CARD_IMAGE_ADV_X = CARD_IMAGE_W
CARD_IMAGE_ADV_Y = CARD_IMAGE_H
CARD_RENDER_SCALE = 0.35 # card height coefficient from the screen's height

class Game
  constructor: (@native, @width, @height) ->
    @cardHeight = Math.floor(@height * CARD_RENDER_SCALE)
    @cardWidth  = Math.floor(@cardHeight * CARD_IMAGE_W / CARD_IMAGE_H)

    @x = @width / 2
    @y = @height / 2
    @which = 0

  load: (data) ->
    @native.log "load: #{data}"

  save: ->
    @native.log "save"
    return "{}"

  touchDown: (@x, @y) ->
    @which = (@which + 1) % 52
  touchMove: (@x, @y) ->
  touchUp: (@x, @y) ->

  renderCard: (v, x, y) ->
    rank = Math.floor(v % 13)
    suit = Math.floor(v / 13)
    @native.blit "cards",
      CARD_IMAGE_OFF_X + (CARD_IMAGE_ADV_X * rank), CARD_IMAGE_OFF_Y + (CARD_IMAGE_ADV_Y * suit), CARD_IMAGE_W, CARD_IMAGE_H,
      x, y, @cardWidth, @cardHeight,
      0, 0, 0

  update: ->
    @renderCard(@which, @x - (@cardWidth / 2), @y - (@cardHeight / 2))

module.exports = Game
