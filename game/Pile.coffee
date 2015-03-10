Animation = require 'Animation'

SETTLE_MS = 1500

class Pile
  constructor: (@game, @width, @height, @hand) ->
    @pile = []
    @pileWho = []
    @trick = []
    @trickWho = []
    @anims = {}
    @pileID = -1
    @trickTaker = ""
    @settleTimer = 0
    @trickColor = { r: 1, g: 1, b: 0, a: 1}
    @playerCount = 2

    centerX = (@width / 2)
    centerY = (@height / 2)
    halfCardX = @hand.cardWidth
    halfCardY = @hand.cardHeight / 2
    @pileLocations =
      2: [
        { x: centerX, y: centerY + halfCardY } # bottom
        { x: centerX, y: centerY - halfCardY } # top
      ]
      3: [
        { x: centerX, y: centerY + halfCardY } # bottom
        { x: centerX - halfCardX, y: centerY } # left
        { x: centerX + halfCardX, y: centerY } # right
      ]
      4: [
        { x: centerX, y: centerY + halfCardY } # bottom
        { x: centerX - halfCardX, y: centerY } # left
        { x: centerX, y: centerY - halfCardY } # top
        { x: centerX + halfCardX, y: centerY } # right
      ]
    @throwLocations =
      2: [
        { x: centerX, y: @height } # bottom
        { x: centerX, y: 0 } # top
      ]
      3: [
        { x: centerX, y: @height } # bottom
        { x: 0, y: centerY + halfCardY } # left
        { x: @width, y: centerY + halfCardY } # right
      ]
      4: [
        { x: centerX, y: @height } # bottom
        { x: 0, y: centerY + halfCardY } # left
        { x: centerX, y: 0 } # top
        { x: @width, y: centerY + halfCardY } # right
      ]

  set: (pileID, pile, pileWho, trick, trickWho, trickTaker, @playerCount, firstThrow) ->
    if (@pileID != pileID) and (trick.length > 0)
      @pile = trick.slice(0) # the pile has become the trick, stash it off one last time
      @pileWho = trickWho.slice(0)
      @pileID = pileID
      @settleTimer = SETTLE_MS

    # don't stomp the pile we're drawing until it is done settling and can fly off the screen
    if @settleTimer == 0
      @pile = pile.slice(0)
      @pileWho = pileWho.slice(0)
      @trick = trick.slice(0)
      @trickWho = trickWho.slice(0)
      @trickTaker = trickTaker

    @syncAnims()

  hint: (v, x, y, r) ->
    @anims[v] = new Animation {
      speed: @hand.cardSpeed
      x: x
      y: y
      r: r
    }

  syncAnims: ->
    seen = {}
    locations = @throwLocations[@playerCount]
    for card, index in @pile
      seen[card]++
      if not @anims[card]
        who = @pileWho[index]
        location = locations[who]
        @anims[card] = new Animation {
          speed: @hand.cardSpeed
          x: location.x # -1 * (@hand.cardWidth / 2)
          y: location.y # -1 * (@hand.cardWidth / 2)
          r: -1 * Math.PI / 4
        }
    for card in @trick
      seen[card]++
      if not @anims[card]
        @anims[card] = new Animation {
          speed: @hand.cardSpeed
          x: -1 * (@hand.cardWidth / 2)
          y: -1 * (@hand.cardWidth / 2)
          r: -1 * Math.PI / 2
        }
    toRemove = []
    for card,anim of @anims
      if not seen.hasOwnProperty(card)
        toRemove.push card
    for card in toRemove
      @game.log "removing anim for #{card}"
      delete @anims[card]

    @updatePositions()

  updatePositions: ->
    locations = @pileLocations[@playerCount]
    for v, index in @pile
      anim = @anims[v]
      loc = @pileWho[index]
      anim.req.x = locations[loc].x # (@width / 2) + (index * (@hand.cardWidth / 3))
      anim.req.y = locations[loc].y # @hand.cardHeight / 2
      anim.req.r = 0

    for _, index in @trick
      i = @trick.length - index - 1
      v = @trick[i]
      anim = @anims[v]
      anim.req.x = (@width + (@hand.cardWidth / 2)) - ((index+1) * (@hand.cardWidth / 5))
      anim.req.y = @hand.cardHeight / 2
      anim.req.r = 0

  readyForNextTrick: ->
    return (@settleTimer == 0)

  update: (dt) ->
    updated = false

    if @settleTimer > 0
      updated = true
      @settleTimer -= dt
      if @settleTimer < 0
        @settleTimer = 0

    for card,anim of @anims
      if anim.update(dt)
        updated = true

    return updated

  render: ->
    for v, index in @pile
      anim = @anims[v]
      @hand.renderCard v, anim.cur.x, anim.cur.y, anim.cur.r

    for v in @trick
      anim = @anims[v]
      @hand.renderCard v, anim.cur.x, anim.cur.y, anim.cur.r

    if (@trick.length > 0) and (@trickTaker.length > 0)
      anim = @anims[@trick[0]]
      if anim?
        @game.fontRenderer.render "square", @height / 30, @trickTaker, @width, anim.cur.y + (@hand.cardHeight / 2), 1, 0, @trickColor


module.exports = Pile
