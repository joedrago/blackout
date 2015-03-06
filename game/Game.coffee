Animation = require 'Animation'
FontRenderer = require 'FontRenderer'
Hand = require 'Hand'
{Blackout, State, OK} = require 'Blackout'

AI_TICK_RATE_MS = 1000
LOG_FONT = "unispace"

class Game
  constructor: (@native, @width, @height) ->
    @log("Game constructed: #{@width}x#{@height}")
    @fontRenderer = new FontRenderer this
    @zones = []
    @nextAITick = AI_TICK_RATE_MS

    @blackout = new Blackout this, {
      rounds: "13|13|13|13"
      players: [
        { id: 1, name: 'joe' }
      ]
    }
    @blackout.addAI()
    @blackout.addAI()
    @blackout.addAI()
    @log "next: " + @blackout.next()
    @log "player 0's hand: " + JSON.stringify(@blackout.players[0].hand)
    @lastErr = ''

    @hand = new Hand this, @width, @height
    @hand.set @blackout.players[0].hand

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
    @log "touchDown (CS) #{x},#{y}"
    @checkZones(x, y)

  touchMove: (x, y) ->
    @hand.move(x, y)

  touchUp: (x, y) ->
    @hand.up(x, y)

  # -----------------------------------------------------------------------------------------------------
  # card handling

  play: (cardToPlay, x, y, r) ->
    @log "(game) playing card #{cardToPlay}"

    if @blackout.state == State.BID
      @blackout.bid {
        id: 1
        bid: 0
        ai: false
      }

    if @blackout.state == State.TRICK
      ret = @blackout.play {
        id: 1
        which: cardToPlay
      }
      @lastErr = ret
      if ret == OK
        @hand.set @blackout.players[0].hand


    if 0 # you are allowed to play this card
      # this should be replaced with the actual blackout engine giving you a new hand
      newCards = []
      for card in @hand.cards
        if card != cardToPlay
          newCards.push card

      if newCards.length == 0
        newCards = (v for v in [30..42])
      @hand.set newCards

  # -----------------------------------------------------------------------------------------------------
  # main loop

  update: (dt) ->
    @zones.length = 0 # forget about zones from the last frame. we're about to make some new ones!

    updated = false
    @nextAITick -= dt
    if @nextAITick <= 0
      @nextAITick = AI_TICK_RATE_MS
      if @blackout.aiTick()
        updated = true
    if @hand.update(dt)
      updated = true

    return updated

  render: ->
    textHeight = @height / 30
    textPadding = textHeight / 2

    # left side
    headline = "State: #{@blackout.state}, Turn: #{@blackout.players[@blackout.turn].name} Err: #{@lastErr}"
    @fontRenderer.renderString LOG_FONT, textHeight, headline, 0, 0, 0, 0
    for line, i in @blackout.log
      @fontRenderer.renderString LOG_FONT, textHeight, line, 0, (i+1) * (textHeight + textPadding), 0, 0

    # right side
    for player, i in @blackout.players
      @fontRenderer.renderString LOG_FONT, textHeight, player.name, @width, i * (textHeight + textPadding), 1, 0

    @hand.render()

  # -----------------------------------------------------------------------------------------------------
  # rendering and zones

  drawImage: (textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY, cb) ->
    @native.drawImage(textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY)
    if cb?
      # caller wants to remember where this was drawn, and wants to be called back if it is ever touched
      # This is called a "zone". Since zones are traversed in reverse order, the natural overlap of
      # a series of renders is respected accordingly.
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
