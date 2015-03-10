Animation = require 'Animation'

SETTLE_MS = 1500

class Pile
  constructor: (@game, @width, @height, @hand) ->
    @pile = []
    @trick = []
    @anims = {}
    @pileID = -1
    @trickTaker = ""
    @settleTimer = 0
    @trickColor = { r: 1, g: 1, b: 0, a: 1}

  set: (pileID, pile, trick, trickTaker) ->
    if (@pileID != pileID) and (trick.length > 0)
      # @game.log "Pile.set #{pileID} #{JSON.stringify(pile)} #{JSON.stringify(trick)} #{trickTaker}"
      @pile = trick.slice(0) # the pile has become the trick, stash it off one last time
      @pileID = pileID
      @settleTimer = SETTLE_MS

    # don't stomp the pile we're drawing until it is done settling and can fly off the screen
    if @settleTimer == 0
      @pile = pile.slice(0)
      @trick = trick.slice(0)
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
    for card in @pile
      seen[card]++
      if not @anims[card]
        @anims[card] = new Animation {
          speed: @hand.cardSpeed
          x: -1 * (@hand.cardWidth / 2)
          y: -1 * (@hand.cardWidth / 2)
          r: -1 * Math.PI / 2
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
    for v, index in @pile
      anim = @anims[v]
      anim.req.x = (@width / 2) + (index * (@hand.cardWidth / 3))
      anim.req.y = @hand.cardHeight / 2
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
