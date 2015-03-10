Animation = require 'Animation'
FontRenderer = require 'FontRenderer'
Hand = require 'Hand'
Pile = require 'Pile'
{Blackout, State, OK} = require 'Blackout'

AI_TICK_RATE_MS = 1000
LOG_FONT = "unispace"

class Game
  constructor: (@native, @width, @height) ->
    @log("Game constructed: #{@width}x#{@height}")
    @fontRenderer = new FontRenderer this
    @zones = []
    @nextAITick = AI_TICK_RATE_MS
    @colors =
      red:   { r: 1, g: 0, b: 0, a: 1 }
      white: { r: 1, g: 1, b: 1, a: 1 }

    @blackout = new Blackout this, {
      rounds: "13|13|13|13"
      players: [
        { id: 1, name: 'Player' }
      ]
    }
    @blackout.addAI()
    @blackout.addAI()
    @blackout.addAI()
    @log "next: " + @blackout.next()
    @log "player 0's hand: " + JSON.stringify(@blackout.players[0].hand)
    @lastErr = ''
    @renderCommands = []

    @hand = new Hand this, @width, @height
    @pile = new Pile this, @width, @height, @hand

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

    # probably want to remove this
    if @blackout.next() == OK
      @hand.set @blackout.players[0].hand

  touchMove: (x, y) ->
    @hand.move(x, y)

  touchUp: (x, y) ->
    @hand.up(x, y)

  # -----------------------------------------------------------------------------------------------------
  # card handling

  play: (cardToPlay, x, y, r, cardIndex) ->
    @log "(game) playing card #{cardToPlay}"

    if @blackout.state == State.BID
      if @blackout.turn == 0
        @log "bidding #{cardIndex}"
        @lastErr = @blackout.bid {
          id: 1
          bid: cardIndex
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
        @pile.hint cardToPlay, x, y, r

  # -----------------------------------------------------------------------------------------------------
  # main loop

  update: (dt) ->
    @zones.length = 0 # forget about zones from the last frame. we're about to make some new ones!

    updated = false
    if @pile.update(dt)
      updated = true
    if @pile.readyForNextTrick()
      @nextAITick -= dt
      if @nextAITick <= 0
        @nextAITick = AI_TICK_RATE_MS
        if @blackout.aiTick()
          updated = true
    if @hand.update(dt)
      updated = true

    trickTakerName = ""
    if @blackout.prevTrickTaker != -1
      trickTakerName = @blackout.players[@blackout.prevTrickTaker].name
    @pile.set @blackout.trickID, @blackout.pile, @blackout.prev, trickTakerName

    return updated

  render: ->
    # Reset render commands
    @renderCommands.length = 0

    textHeight = @height / 30
    textPadding = textHeight / 5

    # left side
    headline = "State: #{@blackout.state}, Turn: #{@blackout.players[@blackout.turn].name} Err: #{@lastErr}"
    @fontRenderer.render LOG_FONT, textHeight, headline, 0, 0, 0, 0, @colors.red
    for line, i in @blackout.log
      @fontRenderer.render LOG_FONT, textHeight, line, 0, (i+1) * (textHeight + textPadding), 0, 0, @colors.white

    # right side
    for player, i in @blackout.players
      @fontRenderer.render LOG_FONT, textHeight, player.name, @width, i * (textHeight + textPadding), 1, 0, @colors.white

    @pile.render()
    @hand.render()

    return @renderCommands

  # -----------------------------------------------------------------------------------------------------
  # rendering and zones

  drawImage: (texture, sx, sy, sw, sh, dx, dy, dw, dh, rot, anchorx, anchory, r, g, b, a, cb) ->
    @renderCommands.push [texture, sx, sy, sw, sh, dx, dy, dw, dh, rot, anchorx, anchory, r, g, b, a]

    if cb?
      # caller wants to remember where this was drawn, and wants to be called back if it is ever touched
      # This is called a "zone". Since zones are traversed in reverse order, the natural overlap of
      # a series of renders is respected accordingly.
      anchorOffsetX = -1 * anchorx * dw
      anchorOffsetY = -1 * anchory * dh
      zone =
        # center (X,Y) and reversed rotation, used to put the coordinate in local space to the zone
        cx:  dx
        cy:  dy
        rot: rot * -1
        # the axis aligned bounding box used for detection of a localspace coord
        l:   anchorOffsetX
        t:   anchorOffsetY
        r:   anchorOffsetX + dw
        b:   anchorOffsetY + dh
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
