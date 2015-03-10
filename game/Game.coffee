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
      lightgray:  { r: 0.5, g: 0.5, b: 0.5, a:   1 }
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

    textHeight = @height / 35
    textPadding = textHeight / 5
    characterHeight = @height / 5
    scoreHeight = @height / 35

    # Log
    # @spriteRenderer.render "solid", 0, 0, @width * 0.4, (textHeight + textPadding) * 8, 0, 0, 0, @colors.logbg
    headline = "State: `ffff00`#{@blackout.state}``, Turn: #{@blackout.players[@blackout.turn].name} Err: #{@lastErr}"
    @fontRenderer.render LOG_FONT, textHeight, headline, 0, 0, 0, 0, @colors.lightgray
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

    characterMargin = characterHeight / 2

    # left side
    if aiPlayers[0] != null
      characterWidth = @spriteRenderer.calcWidth(aiPlayers[0].character.sprite, characterHeight)
      @spriteRenderer.render aiPlayers[0].character.sprite, characterMargin, @hand.playCeiling, 0, characterHeight, 0, 0, 1, @colors.white
      @renderScore aiPlayers[0], scoreHeight, characterMargin + (characterWidth / 2), @hand.playCeiling - textPadding, 0.5, 0
    # top side
    if aiPlayers[1] != null
      @spriteRenderer.render aiPlayers[1].character.sprite, @width / 2, 0, 0, characterHeight, 0, 0.5, 0, @colors.white
      @renderScore aiPlayers[1], scoreHeight, @width / 2, characterHeight, 0.5, 0
    # right side
    if aiPlayers[2] != null
      characterWidth = @spriteRenderer.calcWidth(aiPlayers[0].character.sprite, characterHeight)
      @spriteRenderer.render aiPlayers[2].character.sprite, @width - characterMargin, @hand.playCeiling, 0, characterHeight, 0, 1, 1, @colors.white
      @renderScore aiPlayers[2], scoreHeight, @width - (characterMargin + (characterWidth / 2)), @hand.playCeiling - textPadding, 0.5, 0

    @pile.render()

    # card area
    # @spriteRenderer.render "solid", 0, @height, @width, @height - @hand.playCeiling, 0, 0, 1, @colors.handarea
    @hand.render()
    @renderScore @blackout.players[0], scoreHeight, @width / 2, @height, 0.5, 1

    return @renderCommands

  renderScore: (player, scoreHeight, x, y, anchorx, anchory) ->
    nameString = "#{player.name}: #{player.score}"
    if player.bid == -1
      scoreString = "[ -- ]"
    else
      scoreString = "[ #{player.tricks}/#{player.bid} ]"

    nameSize = @fontRenderer.size(LOG_FONT, scoreHeight, nameString)
    scoreSize = @fontRenderer.size(LOG_FONT, scoreHeight, scoreString)
    if nameSize.w > scoreSize.w
      scoreSize.w = nameSize.w
    nameY = y
    scoreY = y
    if anchory > 0
      nameY -= scoreHeight
    else
      scoreY += scoreHeight
    @spriteRenderer.render "solid", x, y, scoreSize.w, scoreSize.h * 2, 0, anchorx, anchory, @colors.overlay
    @fontRenderer.render LOG_FONT, scoreHeight, nameString, x, nameY, anchorx, anchory, @colors.white
    @fontRenderer.render LOG_FONT, scoreHeight, scoreString, x, scoreY, anchorx, anchory, @colors.white

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
