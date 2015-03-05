Animation = require 'Animation'
FontRenderer = require 'FontRenderer'
Hand = require 'Hand'

class Game
  constructor: (@native, @width, @height) ->
    @log("Game constructed: #{@width}x#{@height}")
    @fontRenderer = new FontRenderer this
    @zones = []

    @hand = new Hand this, @width, @height
    @hand.set (v for v in [30..42])

    @flyaway = new Animation {
      speed: @hand.cardSpeed
      x: 0
      y: 0
      r: 0
    }

    # @hand = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    # @anim = new Animation {
    #   speed: { r: Math.PI * 2, s: 0.5, t: 2 * @width }
    #   x: 100
    #   y: 100
    #   r: 0
    # }

  # -----------------------------------------------------------------------------------------------------
  # logging

  log: (s) ->
    @native.log(s)

  # -----------------------------------------------------------------------------------------------------
  # load / save

  load: (data) ->
    @log "load: #{data}"

  save: ->
    @log "save"
    return "{}"

  # -----------------------------------------------------------------------------------------------------

  makeHand: (index) ->
    for v in [0...13]
      if v == index
        @hand[v] = 13
      else
        @hand[v] = v

  # -----------------------------------------------------------------------------------------------------
  # input handling

  touchDown: (x, y) ->
    @checkZones(x, y)

  touchMove: (x, y) ->
    @hand.move(x, y)

    # if @dragging
    #   if not @checkZones(x, y)
    #     @makeHand(-1)

    # @anim.req.x = x
    # @anim.req.y = y
    # @anim.req.r = (y / @height) * (Math.PI * 2)

  touchUp: (x, y) ->
    @hand.up(x, y)

  # -----------------------------------------------------------------------------------------------------
  # card handling

  play: (cardToPlay, x, y, r) ->
    @log "(game) playing card #{cardToPlay}"

    if 1 # you are allowed to play this card
      # this should be replaced with the actual blackout engine giving you a new hand
      newCards = []
      for card in @hand.cards
        if card != cardToPlay
          newCards.push card

      if newCards.length == 0
        newCards = (v for v in [30..42])
      @hand.set newCards

      @flyaway.card = cardToPlay
      @flyaway.req.x = x
      @flyaway.req.y = y
      @flyaway.req.r = r
      @flyaway.warp()
      @flyaway.req.x = @width / 2
      @flyaway.req.y = -1 * (@height / 4)
      @flyaway.req.r = Math.PI # derp?

  # -----------------------------------------------------------------------------------------------------
  # main loop

  update: (dt) ->
    @zones.length = 0 # forget about zones from the last frame. we're about to make some new ones!

    @fontRenderer.renderString "font", @height / 20, "Blackout", @width / 2, 0, 0.5, 0

    @hand.update(dt)
    @hand.render()

    @flyaway.update(dt)
    if @flyaway.animating()
      @hand.renderCard @flyaway.card, @flyaway.cur.x, @flyaway.cur.y, @flyaway.cur.r

    # @anim.update dt
    # @cardRenderer.renderCard 51, @anim.cur.x, @anim.cur.y, @anim.cur.r

  # -----------------------------------------------------------------------------------------------------
  # rendering and zones

  blit: (textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY, cb) ->
    @native.blit(textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY)
    if cb?
      # caller wants to remember where this was drawn, and wants to be called back if it is ever touched
      # This is called a "zone". Since zones are traversed in reverse order, the natural overlap of
      # a series of blits is respected accordingly.
      anchorOffsetX = -1 * anchorX * dstW
      anchorOffsetY = -1 * anchorY * dstH
      zone =
        # center (X,Y) and reversed rotation, used to put the coordinate in local space to the zone
        cx:  dstX
        cy:  dstY
        rot: rot * -1
        # the axis aligned bounding box used for detection of a localspace coord
        l:   anchorOffsetX
        t:   anchorOffsetY
        r:   anchorOffsetX + dstW
        b:   anchorOffsetY + dstH
        # callback to call if the zone is clicked on
        cb:  cb
      @zones.push zone

  checkZones: (x, y) ->
    for zone in @zones by -1
      # move coord into space relative to the quad, then rotate it to match
      unrotatedLocalX = x - zone.cx
      unrotatedLocalY = y - zone.cy
      localX = unrotatedLocalX * Math.cos(zone.rot) - unrotatedLocalY * Math.sin(zone.rot)
      localY = unrotatedLocalX * Math.sin(zone.rot) + unrotatedLocalY * Math.cos(zone.rot)
      if (localX < zone.l) or (localX > zone.r) or (localY < zone.t) or (localY > zone.b)
        # outside of oriented bounding box
        continue
      zone.cb(x, y)
      return true
    return false

  # -----------------------------------------------------------------------------------------------------

module.exports = Game
