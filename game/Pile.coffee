Animation = require 'Animation'

class Pile
  constructor: (@game, @width, @height, @hand) ->
    @cards = []
    @prevCards = []
    @anims = {}

  set: (cards, prevCards) ->
    @cards = cards.slice(0)
    @prevCards = prevCards.slice(0)
    @syncAnims()

  # immediately warp all cards to where they should be
  warp: ->
    for card,anim of @anims
      anim.warp()

  syncAnims: ->
    seen = {}
    for card in @cards
      seen[card]++
      if not @anims[card]
        @anims[card] = new Animation {
          speed: @hand.cardSpeed
          x: -1 * (@hand.cardWidth / 2)
          y: -1 * (@hand.cardWidth / 2)
          r: -1 * Math.PI
        }
    for card in @prevCards
      seen[card]++
      if not @anims[card]
        @anims[card] = new Animation {
          speed: @hand.cardSpeed
          x: -1 * (@hand.cardWidth / 2)
          y: -1 * (@hand.cardWidth / 2)
          r: -1 * Math.PI
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
    for v, index in @cards
      anim = @anims[v]
      anim.req.x = (@width / 2) + (index * (@hand.cardWidth / 3))
      anim.req.y = @hand.cardHeight / 2
      anim.req.r = 0
    for _, index in @prevCards
      i = @prevCards.length - index - 1
      v = @prevCards[i]
      anim = @anims[v]
      anim.req.x = (@width + (@hand.cardWidth / 2)) - ((index+1) * (@hand.cardWidth / 5))
      anim.req.y = @hand.cardHeight / 2
      anim.req.r = 0

  update: (dt) ->
    updated = false
    for card,anim of @anims
      if anim.update(dt)
        updated = true
    return updated

  render: ->
    for v, index in @cards
      anim = @anims[v]
      @hand.renderCard v, anim.cur.x, anim.cur.y, anim.cur.r
    for v, index in @prevCards
      anim = @anims[v]
      @hand.renderCard v, anim.cur.x, anim.cur.y, anim.cur.r

module.exports = Pile
