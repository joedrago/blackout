Animation = require 'Animation'
FontRenderer = require 'FontRenderer'
SpriteRenderer = require 'SpriteRenderer'
Hand = require 'Hand'
Pile = require 'Pile'
{Blackout, State, OK} = require 'Blackout'

AI_TICK_RATE_MS = 1000
LOG_FONT = "unispace"

class Game
  constructor: (@native, @width, @height) ->
    @log("Game constructed: #{@width}x#{@height}")
    @fontRenderer = new FontRenderer this
    @spriteRenderer = new SpriteRenderer this
    @zones = []
    @nextAITick = AI_TICK_RATE_MS
    @colors =
      red:        { r:   1, g:   0, b:   0, a:   1 }
      white:      { r:   1, g:   1, b:   1, a:   1 }
      background: { r:   0, g: 0.2, b:   0, a:   1 }
      logbg:      { r: 0.1, g:   0, b:   0, a:   1 }
      facebg:     { r:   0, g:   0, b:   0, a: 0.3 }
      handarea:   { r:   0, g: 0.1, b:   0, a: 1.0 }
      overlay:    { r:   0, g:   0, b:   0, a: 0.7 }

    @blackout = new Blackout this, {
      rounds: "13|13"
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
    @pile.set @blackout.trickID, @blackout.pile, @blackout.pileWho, @blackout.prev, @blackout.prevWho, trickTakerName, @blackout.players.length, @blackout.turn

    return updated

  render: ->
    # Reset render commands
    @renderCommands.length = 0

    # background
    @spriteRenderer.render "solid", 0, 0, @width, @height, 0, 0, 0, @colors.background

    textHeight = @height / 30
    textPadding = textHeight / 5

    # Log
    # @spriteRenderer.render "solid", 0, 0, @width * 0.4, (textHeight + textPadding) * 8, 0, 0, 0, @colors.logbg
    headline = "State: #{@blackout.state}, Turn: #{@blackout.players[@blackout.turn].name} Err: #{@lastErr}"
    @fontRenderer.render LOG_FONT, textHeight, headline, 0, 0, 0, 0, @colors.red
    for line, i in @blackout.log
      @fontRenderer.render LOG_FONT, textHeight, line, 0, (i+1) * (textHeight + textPadding), 0, 0, @colors.white

    aiPlayers = [null, null, null]
    if @blackout.players.length == 2
      aiPlayers[1] = @blackout.players[1]
    else if @blackout.players.length == 3
      aiPlayers[0] = @blackout.players[1]
      aiPlayers[2] = @blackout.players[2]
    else # 4 player
      aiPlayers[0] = @blackout.players[1]
      aiPlayers[1] = @blackout.players[2]
      aiPlayers[2] = @blackout.players[3]

    characterHeight = @height / 5
    scoreHeight = @height / 30

    # left side
    if aiPlayers[0] != null
      # (font, height, str, x, y, anchorx, anchory, color, cb)
      @spriteRenderer.render aiPlayers[0].character.sprite, 0, @hand.playCeiling, 0, characterHeight, 0, 0, 1, @colors.white
      scoreString = @calcScoreString(aiPlayers[0])
      scoreSize = @fontRenderer.size(LOG_FONT, scoreHeight, scoreString)
      @spriteRenderer.render "solid", 0, @hand.playCeiling - textPadding, scoreSize.w, scoreSize.h, 0, 0, 1, @colors.overlay
      @fontRenderer.render LOG_FONT, scoreHeight, scoreString, 0, @hand.playCeiling - textPadding, 0, 1, @colors.white
    # top side
    if aiPlayers[1] != null
      @spriteRenderer.render aiPlayers[1].character.sprite, @width / 2, 0, 0, characterHeight, 0, 0.5, 0, @colors.white
      scoreString = @calcScoreString(aiPlayers[1])
      scoreSize = @fontRenderer.size(LOG_FONT, scoreHeight, scoreString)
      @spriteRenderer.render "solid", @width / 2, characterHeight, scoreSize.w, scoreSize.h, 0, 0.5, 1, @colors.overlay
      @fontRenderer.render LOG_FONT, scoreHeight, scoreString, @width / 2, characterHeight, 0.5, 1, @colors.white
    # right side
    if aiPlayers[2] != null
      @spriteRenderer.render aiPlayers[2].character.sprite, @width, @hand.playCeiling, 0, characterHeight, 0, 1, 1, @colors.white
      scoreString = @calcScoreString(aiPlayers[2])
      scoreSize = @fontRenderer.size(LOG_FONT, scoreHeight, scoreString)
      @spriteRenderer.render "solid", @width, @hand.playCeiling - textPadding, scoreSize.w, scoreSize.h, 0, 1, 1, @colors.overlay
      @fontRenderer.render LOG_FONT, scoreHeight, scoreString, @width, @hand.playCeiling - textPadding, 1, 1, @colors.white

    # # right side
    # for player, i in @blackout.players
    #   @fontRenderer.render LOG_FONT, textHeight, player.name, @width, i * (textHeight + textPadding), 1, 0, @colors.white

    @pile.render()

    # card area
    @spriteRenderer.render "solid", 0, @height, @width, @height - @hand.playCeiling, 0, 0, 1, @colors.handarea
    @hand.render()

    scoreX = @width / 2
    scoreY = @height

    scoreString = @calcScoreString(@blackout.players[0])
    scoreSize = @fontRenderer.size(LOG_FONT, scoreHeight, scoreString)
    @spriteRenderer.render "solid", @width / 2, @height, scoreSize.w, scoreSize.h, 0, 0.5, 1, @colors.overlay
    @fontRenderer.render LOG_FONT, scoreHeight, scoreString, @width / 2, @height, 0.5, 1, @colors.white

    return @renderCommands

  calcScoreString: (player) ->
    if player.bid == -1
      return " #{player.name} [ -- ] "
    return " #{player.name} [ #{player.tricks}/#{player.bid} ] "

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
