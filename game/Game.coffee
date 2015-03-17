Animation = require 'Animation'
Button = require 'Button'
FontRenderer = require 'FontRenderer'
SpriteRenderer = require 'SpriteRenderer'
Menu = require 'Menu'
Hand = require 'Hand'
Pile = require 'Pile'
{Blackout, State, OK, aiCharacters} = require 'Blackout'

class Game
  constructor: (@native, @width, @height) ->
    @log("Game constructed: #{@width}x#{@height}")
    @fontRenderer = new FontRenderer this
    @spriteRenderer = new SpriteRenderer this
    @font = "darkforest"
    @zones = []
    @nextAITick = 1000 # will be set by options
    @center =
      x: @width / 2
      y: @height / 2
    @aaHeight = @width * 9 / 16
    console.log "height: #{@height}. height if screen was 16:9 (aspect adjusted): #{@aaHeight}"
    @pauseButtonSize = @aaHeight / 15
    @colors =
      white:      { r:   1, g:   1, b:   1, a:   1 }
      black:      { r:   0, g:   0, b:   0, a:   1 }
      red:        { r:   1, g:   0, b:   0, a:   1 }
      orange:     { r:   1, g: 0.5, b:   0, a:   1 }
      gold:       { r:   1, g:   1, b:   0, a:   1 }
      buttontext: { r:   1, g:   1, b:   1, a:   1 }
      lightgray:  { r: 0.5, g: 0.5, b: 0.5, a:   1 }
      background: { r:   0, g: 0.2, b:   0, a:   1 }
      logbg:      { r: 0.1, g:   0, b:   0, a:   1 }
      arrow:      { r:   1, g:   1, b:   1, a:   1 }
      arrowclose: { r:   1, g: 0.5, b:   0, a: 0.3 }
      handarea:   { r:   0, g: 0.1, b:   0, a: 1.0 }
      overlay:    { r:   0, g:   0, b:   0, a: 0.6 }
      mainmenu:   { r: 0.1, g: 0.1, b: 0.1, a:   1 }
      pausemenu:  { r: 0.1, g: 0.0, b: 0.1, a:   1 }
      bid:        { r:   0, g: 0.6, b:   0, a:   1 }

    @textures =
      "cards": 0
      "darkforest": 1
      "chars": 2
      "howto1": 3
      "howto2": 4
      "howto3": 5

    @blackout = null # don't start in a game
    @lastErr = ''
    @paused = false
    @howto = 0
    @renderCommands = []

    @bid = 0
    @bidButtonSize = @aaHeight / 8
    @bidTextSize = @aaHeight / 6
    bidButtonDistance = @bidButtonSize * 3
    @bidButtonY = @center.y - (@bidButtonSize)
    @bidUI = #(@game, @spriteNames, @font, @textHeight, @x, @y, @text, @cb)
      minus: new Button this, ['minus0', 'minus1'], @font, @bidButtonSize, @center.x - bidButtonDistance, @bidButtonY, (click) =>
        if click
          @adjustBid(-1)
        return ''
      plus:  new Button this, ['plus0', 'plus1'],   @font, @bidButtonSize, @center.x + bidButtonDistance, @bidButtonY, (click) =>
        if click
          @adjustBid(1)
        return ''

    @optionMenus =
      rounds: [
        { text: "8 rounds of 13", data: "13|13|13|13|13|13|13|13" }
        { text: "4 rounds of 13", data: "13|13|13|13" }
        { text: "3 to 13", data: "3|4|5|6|7|8|9|10|11|12|13" }
        { text: "3 to 13 by odds", data: "3|5|7|9|11|13" }
        { text: "Marathon", data: "M" }
      ]
      speeds: [
        { text: "AI Speed: Slow", speed: 2000 }
        { text: "AI Speed: Medium", speed: 1000 }
        { text: "AI Speed: Fast", speed: 500 }
        { text: "AI Speed: Ultra", speed: 250 }
      ]
    @options =
      players: 4
      roundIndex: 0
      speedIndex: 1
      sound: true

    @mainMenu = new Menu this, "Blackout!", "solid", @colors.mainmenu, [
      (click) =>
        if click
          @howto = 1
        return "How To Play"
      (click) =>
        if click
          @options.roundIndex = (@options.roundIndex + 1) % @optionMenus.rounds.length
        return @optionMenus.rounds[@options.roundIndex].text
      (click) =>
        if click
          @options.players++
          if @options.players > 4
            @options.players = 3
        return "#{@options.players} Players"
      (click) =>
        if click
          @options.speedIndex = (@options.speedIndex + 1) % @optionMenus.speeds.length
        return @optionMenus.speeds[@options.speedIndex].text
      (click) =>
        if click
          @options.sound = !@options.sound
        return "Sound: #{if @options.sound then "Enabled" else "Disabled"}"
      (click) =>
        if click
          @newGame()
        return "Start"
    ]

    @pauseMenu = new Menu this, "Paused", "solid", @colors.pausemenu, [
      (click) =>
        if click
          @paused = false
        return "Resume Game"
      (click) =>
        if click
          @howto = 1
        return "How To Play"
      (click) =>
        if click
          @options.speedIndex = (@options.speedIndex + 1) % @optionMenus.speeds.length
        return @optionMenus.speeds[@options.speedIndex].text
      (click) =>
        if click
          @options.sound = !@options.sound
        return "Sound: #{if @options.sound then "Enabled" else "Disabled"}"
      (click) =>
        if click
          @blackout = null
          @paused = false
        return "Quit Game"
    ]

  # -----------------------------------------------------------------------------------------------------
  # logging

  log: (s) ->
    @native.log(s)

  # -----------------------------------------------------------------------------------------------------
  # load / save

  load: (json) ->
    @log "(CS) loading state"
    try
      state = JSON.parse json
    catch
      @log "load failed to parse state: #{json}"
      return
    if state.options
      for k, v of state.options
        @options[k] = v

    if state.blackout
      @log "recreating game from savedata"
      @blackout = new Blackout this, {
        state: state.blackout
      }
      @prepareGame()

  save: ->
    # @log "(CS) saving state"
    state = {
      options: @options
    }
    if @blackout?
      state.blackout = @blackout.save()
    return JSON.stringify state

  # -----------------------------------------------------------------------------------------------------

  aiTickRate: ->
    return @optionMenus.speeds[@options.speedIndex].speed

  newGame: ->
    @blackout = new Blackout this, {
      rounds: @optionMenus.rounds[@options.roundIndex].data
      players: [
        { id: 1, name: 'Player' }
      ]
    }
    for p in [1...@options.players]
      @blackout.addAI()
    @log "next: " + @blackout.next()
    @log "player 0's hand: " + JSON.stringify(@blackout.players[0].hand)

    @prepareGame()

  prepareGame: ->
    @hand = new Hand this
    @pile = new Pile this, @hand
    @hand.set @blackout.players[0].hand

  makeHand: (index) ->
    for v in [0...13]
      if v == index
        @hand[v] = 13
      else
        @hand[v] = v

  # -----------------------------------------------------------------------------------------------------
  # input handling

  touchDown: (x, y) ->
    # @log("touchDown #{x},#{y}")
    @checkZones(x, y)

  touchMove: (x, y) ->
    if @blackout != null
      @hand.move(x, y)

  touchUp: (x, y) ->
    if @blackout != null
      @hand.up(x, y)

  # -----------------------------------------------------------------------------------------------------
  # bid handling

  adjustBid: (amount) ->
    return if @blackout == null
    @bid = @bid + amount
    if @bid < 0
      @bid = 0
    if @bid > @blackout.tricks
      @bid = @blackout.tricks

  attemptBid: ->
    return if @blackout == null
    @adjustBid(0)
    if @blackout.state == State.BID
      if @blackout.turn == 0
        @log "bidding #{@bid}"
        @lastErr = @blackout.bid {
          id: 1
          bid: @bid
          ai: false
        }

  # -----------------------------------------------------------------------------------------------------
  # headline (game state in top left)

  prettyErrorTable: {
    bidOutOfRange:      "You are somehow bidding an impossible value. The game must be broken."
    dealerFucked:       "Dealer restriction: You may not make total bids match total tricks."
    doNotHave:          "You are somehow attempting to play a card you don't own. The game must be broken."
    forcedHigherInSuit: "You have a higher value in the lead suit. You must play it. (Rule 2)"
    forcedInSuit:       "You have at least one of the lead suit. You must play it. (Rule 1)"
    gameOver:           "The game is over.  The game must be broken."
    indexOutOfRange:    "You don't have that index. The game must be broken."
    lowestCardRequired: "You must start the round with the lowest card you have."
    nextIsConfused:     "Interal error. The game must be broken."
    noNext:             "Interal error. The game must be broken."
    notBiddingNow:      "You are trying to bid during the wrong phase."
    notEnoughPlayers:   "Cannot start the game without more players."
    notInTrick:         "You are trying to play a card during the wrong phase."
    notYourTurn:        "It isn't your turn."
    trumpNotBroken:     "Trump isn't broken yet. Lead with a non-spade."
  }

  prettyError: ->
    pretty = @prettyErrorTable[@lastErr]
    return pretty if pretty
    return @lastErr

  calcHeadline: ->
    return "" if @blackout == null

    headline = ""
    switch @blackout.state
      when State.BID
        headline = "Waiting for `ff7700`#{@blackout.players[@blackout.turn].name}`` to `ffff00`bid``"
      when State.TRICK
        headline = "Waiting for `ff7700`#{@blackout.players[@blackout.turn].name}`` to `ffff00`play``"
      when State.ROUNDSUMMARY
        headline = "Waiting for next round..."
      when State.POSTGAMESUMMARY
        headline = "Game over!"

    errText = ""
    if (@lastErr.length > 0) and (@lastErr != OK)
      errText = "  ERROR: `ff0000`#{@prettyError()}"
      headline += errText

    return headline

  # -----------------------------------------------------------------------------------------------------
  # game over information

  gameOverText: ->
    return ["Game Over!"] if @blackout == null

    if @blackout.marathonMode()
      return ["Marathon over!", "Survived #{@blackout.nextRound - 1} rounds"]

    lowestScore = @blackout.players[0].score
    for player in @blackout.players
      if lowestScore > player.score
        lowestScore = player.score

    winners = []
    for player in @blackout.players
      if player.score == lowestScore
        winners.push player.name

    if winners.length == 1
      return ["#{winners[0]} wins!"]

    return ["Tie: #{winners.join(',')}"]

  # -----------------------------------------------------------------------------------------------------
  # card handling

  play: (cardToPlay, x, y, r, cardIndex) ->
    if @blackout.state == State.TRICK
      @log "(game) playing card #{cardToPlay}"
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
    if @updateMainMenu(dt)
      updated = true
    if @updateGame(dt)
      updated = true

    return updated

  updateMainMenu: (dt) ->
    updated = false
    if @mainMenu.update(dt)
      updated = true
    return updated

  updateGame: (dt) ->
    return false if @blackout == null

    updated = false
    if @pile.update(dt)
      updated = true
    if @pile.readyForNextTrick()
      @nextAITick -= dt
      if @nextAITick <= 0
        @nextAITick = @aiTickRate()
        if @blackout.aiTick()
          updated = true
    if @hand.update(dt)
      updated = true

    trickTakerName = ""
    if @blackout.prevTrickTaker != -1
      trickTakerName = @blackout.players[@blackout.prevTrickTaker].name
    @pile.set @blackout.trickID, @blackout.pile, @blackout.pileWho, @blackout.prev, @blackout.prevWho, trickTakerName, @blackout.players.length, @blackout.turn

    if @pauseMenu.update(dt)
      updated = true

    @adjustBid(0)
    if @bidUI.minus.update(dt)
      updated = true
    if @bidUI.plus.update(dt)
      updated = true

    return updated

  render: ->
    # Reset render commands
    @renderCommands.length = 0

    if @howto > 0
      @renderHowto()
    else if @blackout == null
      @renderMainMenu()
    else
      @renderGame()

    return @renderCommands

  renderHowto: ->
    howtoTexture = "howto#{@howto}"
    @log "rendering #{howtoTexture}"
    @spriteRenderer.render "solid", 0, 0, @width, @height, 0, 0, 0, @colors.black
    @spriteRenderer.render howtoTexture, 0, 0, @width, @aaHeight, 0, 0, 0, @colors.white
    arrowWidth = @width / 20
    arrowOffset = arrowWidth * 4
    color = if @howto == 1 then @colors.arrowclose else @colors.arrow
    @spriteRenderer.render "arrowL", @center.x - arrowOffset, @height, arrowWidth, 0, 0, 0.5, 1, color, =>
      @howto--
      if @howto < 0
        @howto = 0
    color = if @howto == 3 then @colors.arrowclose else @colors.arrow
    @spriteRenderer.render "arrowR", @center.x + arrowOffset, @height, arrowWidth, 0, 0, 0.5, 1, color, =>
      @howto++
      if @howto > 3
        @howto = 0

  renderMainMenu: ->
    @mainMenu.render()

  renderGame: ->

    # background
    @spriteRenderer.render "solid", 0, 0, @width, @height, 0, 0, 0, @colors.background

    textHeight = @aaHeight / 30
    textPadding = textHeight / 5
    characterHeight = @aaHeight / 5
    scoreHeight = textHeight

    # Log
    for line, i in @blackout.log
      @fontRenderer.render @font, textHeight, line, 0, (i+1) * (textHeight + textPadding), 0, 0, @colors.white

    if @blackout.marathonMode()
      @fontRenderer.render @font, textHeight, "MARATHON MODE", @width - @pauseButtonSize, 0, 1, 0, @colors.orange

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
      character = aiCharacters[aiPlayers[0].charID]
      characterWidth = @spriteRenderer.calcWidth(character.sprite, characterHeight)
      @spriteRenderer.render character.sprite, characterMargin, @hand.playCeiling, 0, characterHeight, 0, 0, 1, @colors.white
      @renderScore aiPlayers[0], aiPlayers[0].index == @blackout.turn, scoreHeight, characterMargin + (characterWidth / 2), @hand.playCeiling - textPadding, 0.5, 0
    # top side
    if aiPlayers[1] != null
      character = aiCharacters[aiPlayers[1].charID]
      @spriteRenderer.render character.sprite, @center.x, 0, 0, characterHeight, 0, 0.5, 0, @colors.white
      @renderScore aiPlayers[1], aiPlayers[1].index == @blackout.turn, scoreHeight, @center.x, characterHeight, 0.5, 0
    # right side
    if aiPlayers[2] != null
      character = aiCharacters[aiPlayers[2].charID]
      characterWidth = @spriteRenderer.calcWidth(character.sprite, characterHeight)
      @spriteRenderer.render character.sprite, @width - characterMargin, @hand.playCeiling, 0, characterHeight, 0, 1, 1, @colors.white
      @renderScore aiPlayers[2], aiPlayers[2].index == @blackout.turn, scoreHeight, @width - (characterMargin + (characterWidth / 2)), @hand.playCeiling - textPadding, 0.5, 0

    @pile.render()

    if (@blackout.state == State.POSTGAMESUMMARY) and @pile.resting()
      lines = @gameOverText()
      gameOverSize = @aaHeight / 8
      gameOverY = @center.y
      if lines.length > 1
        gameOverY -= (gameOverSize >> 1)
      @fontRenderer.render @font, gameOverSize, lines[0], @center.x, gameOverY, 0.5, 0.5, @colors.orange
      if lines.length > 1
        gameOverY += gameOverSize
        @fontRenderer.render @font, gameOverSize, lines[1], @center.x, gameOverY, 0.5, 0.5, @colors.orange

      restartQuitSize = @aaHeight / 12
      shadowDistance = restartQuitSize / 8
      @fontRenderer.render @font, restartQuitSize, "Restart", shadowDistance + @center.x / 2, shadowDistance + @height - restartQuitSize, 0.5, 1, @colors.black, =>
      @fontRenderer.render @font, restartQuitSize, "Restart", @center.x / 2, @height - restartQuitSize, 0.5, 1, @colors.gold, =>
        @newGame()
      @fontRenderer.render @font, restartQuitSize, "Quit", shadowDistance + @center.x + (@center.x / 2), shadowDistance + @height - restartQuitSize, 0.5, 1, @colors.black, =>
      @fontRenderer.render @font, restartQuitSize, "Quit", @center.x + (@center.x / 2), @height - restartQuitSize, 0.5, 1, @colors.gold, =>
        @blackout = null

    if (@blackout.state == State.ROUNDSUMMARY) and @pile.resting()
      @fontRenderer.render @font, @aaHeight / 8, "Tap for next round ...", @center.x, @center.y, 0.5, 0.5, @colors.orange, =>
        if @blackout.next() == OK
          @hand.set @blackout.players[0].hand

    if (@blackout.state == State.BID) and (@blackout.turn == 0)
      @bidUI.minus.render()
      @bidUI.plus.render()
      @fontRenderer.render @font, @bidTextSize, "#{@bid}", @center.x, @bidButtonY - (@bidTextSize * 0.1), 0.5, 0.5, @colors.white, =>
        @attemptBid()
      bidButtonHeight = @aaHeight / 12
      bidSize = @fontRenderer.size(@font, bidButtonHeight, "Bid")
      @spriteRenderer.render "solid", @center.x, (@bidButtonY + @bidTextSize) + (bidSize.h * 0.2), bidSize.w * 3, bidSize.h * 1.5, 0, 0.5, 0.5, @colors.bid, =>
        @attemptBid()
      @fontRenderer.render @font, bidButtonHeight, "Bid", @center.x, @bidButtonY + @bidTextSize, 0.5, 0.5, @colors.white

    # card area
    # @spriteRenderer.render "solid", 0, @height, @width, @height - @hand.playCeiling, 0, 0, 1, @colors.handarea
    @hand.render()
    @renderScore @blackout.players[0], 0 == @blackout.turn, scoreHeight, @center.x, @height, 0.5, 1

    # Headline (includes error)
    @fontRenderer.render @font, textHeight, @calcHeadline(), 0, 0, 0, 0, @colors.lightgray

    @spriteRenderer.render "pause", @width, 0, 0, @pauseButtonSize, 0, 1, 0, @colors.white, =>
      @paused = true

    if @paused
      @pauseMenu.render()

    return

  renderScore: (player, myTurn, scoreHeight, x, y, anchorx, anchory) ->
    if myTurn
      nameColor = "`ff7700`"
    else
      nameColor = ""
    nameString = " #{nameColor}#{player.name}``: #{player.score} "
    if player.bid == -1
      scoreString = "[ -- ]"
    else
      if player.tricks < player.bid
        trickColor = "ffff33"
      else if player.tricks == player.bid
        trickColor = "33ff33"
      else
        trickColor = "ff3333"
      scoreString = "[ `#{trickColor}`#{player.tricks}``/#{player.bid} ]"

    nameSize = @fontRenderer.size(@font, scoreHeight, nameString)
    scoreSize = @fontRenderer.size(@font, scoreHeight, scoreString)
    if nameSize.w > scoreSize.w
      scoreSize.w = nameSize.w
    nameY = y
    scoreY = y
    if anchory > 0
      nameY -= scoreHeight
    else
      scoreY += scoreHeight
    @spriteRenderer.render "solid", x, y, scoreSize.w, scoreSize.h * 2, 0, anchorx, anchory, @colors.overlay
    @fontRenderer.render @font, scoreHeight, nameString, x, nameY, anchorx, anchory, @colors.white
    @fontRenderer.render @font, scoreHeight, scoreString, x, scoreY, anchorx, anchory, @colors.white

  # -----------------------------------------------------------------------------------------------------
  # rendering and zones

  drawImage: (texture, sx, sy, sw, sh, dx, dy, dw, dh, rot, anchorx, anchory, r, g, b, a, cb) ->
    @renderCommands.push @textures[texture], sx, sy, sw, sh, dx, dy, dw, dh, rot, anchorx, anchory, r, g, b, a

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
