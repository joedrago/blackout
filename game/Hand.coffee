Animation = require 'Animation'

CARD_IMAGE_W = 120
CARD_IMAGE_H = 162
CARD_IMAGE_OFF_X = 4
CARD_IMAGE_OFF_Y = 4
CARD_IMAGE_ADV_X = CARD_IMAGE_W
CARD_IMAGE_ADV_Y = CARD_IMAGE_H
CARD_RENDER_SCALE = 0.4                  # card height coefficient from the screen's height
CARD_HAND_CURVE_DIST_FACTOR = 1.5        # factor with screen height to figure out center of arc. bigger number is less arc
CARD_HOLDING_ROT_ORDER = Math.PI / 12    # desired rotation of the card when being dragged around for ordering's sake
CARD_HOLDING_ROT_PLAY = Math.PI / 2      # desired rotation of the card when being dragged around with intent to play
CARD_PLAY_CEILING = 0.45                 # how much of the top of the screen represents "I want to play this" vs "I want to reorder"

NO_CARD = -1

# taken from http://stackoverflow.com/questions/1211212/how-to-calculate-an-angle-from-three-points
# uses law of cosines to figure out the hand arc angle
findAngle = (p0, p1, p2) ->
    a = Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2)
    b = Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2)
    c = Math.pow(p2.x - p0.x, 2) + Math.pow(p2.y - p0.y, 2)
    return Math.acos( (a+b-c) / Math.sqrt(4*a*b) )

calcDistance = (p0, p1) ->
  return Math.sqrt(Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2))

calcDistanceSquared = (x0, y0, x1, y1) ->
  return Math.pow(x1 - x0, 2) + Math.pow(y1 - y0, 2)

class Hand
  constructor: (@game, @screenWidth, @screenHeight) ->
    @cards = []
    @anims = {}
    @positionCache = {}

    @dragIndexStart = NO_CARD
    @dragIndexCurrent = NO_CARD
    @dragX = 0
    @dragY = 0

    # render / anim metrics
    @cardSpeed =
      r: Math.PI * 2
      s: 0.5
      t: 2 * @screenWidth
    @playCeiling = CARD_PLAY_CEILING * @screenHeight
    @cardHeight = Math.floor(@screenHeight * CARD_RENDER_SCALE)
    @cardWidth  = Math.floor(@cardHeight * CARD_IMAGE_W / CARD_IMAGE_H)
    arcMargin = @cardWidth / 1.5
    arcVerticalBias = @cardHeight / 50
    bottomLeft  = { x: arcMargin,                y: arcVerticalBias + @screenHeight }
    bottomRight = { x: @screenWidth - arcMargin, y: arcVerticalBias + @screenHeight }
    @handCenter = { x: @screenWidth / 2,         y: arcVerticalBias + @screenHeight + (CARD_HAND_CURVE_DIST_FACTOR * @screenHeight) }
    @handAngle = findAngle(bottomLeft, @handCenter  , bottomRight) # * (180 / Math.PI)
    @handDistance = calcDistance(bottomLeft, @handCenter)
    @handAngleAdvance = @handAngle / 13
    @game.log "Hand distance #{@handDistance}, angle #{@handAngle} (screen height #{@screenHeight})"

  set: (cards) ->
    @cards = cards.slice(0)
    @syncAnims()
    @warp()

  syncAnims: ->
    seen = {}
    for card in @cards
      seen[card]++
      if not @anims[card]
        @anims[card] = new Animation {
          speed: @cardSpeed
          x: 0
          y: 0
          r: 0
        }
    toRemove = []
    for card,anim of @anims
      if not seen.hasOwnProperty(card)
        toRemove.push card
    for card in toRemove
      @game.log "removing anim for #{card}"
      delete @anims[card]

    @updatePositions()

  calcDrawnHand: ->
    drawnHand = []
    for card,i in @cards
      if i != @dragIndexStart
        drawnHand.push card

    if @dragIndexCurrent != NO_CARD
      drawnHand.splice @dragIndexCurrent, 0, @cards[@dragIndexStart]
    return drawnHand

  wantsToPlayDraggedCard: ->
    return false if @dragIndexStart == NO_CARD
    return @dragY < @playCeiling

  updatePositions: ->
    drawnHand = @calcDrawnHand()
    wantsToPlay = @wantsToPlayDraggedCard()
    desiredRotation = CARD_HOLDING_ROT_ORDER
    positionCount = drawnHand.length
    if wantsToPlay
      desiredRotation = CARD_HOLDING_ROT_PLAY
      positionCount--
    positions = @calcPositions(positionCount)
    drawIndex = 0
    for card,i in drawnHand
      anim = @anims[card]
      if i == @dragIndexCurrent
        anim.req.x = @dragX
        anim.req.y = @dragY
        anim.req.r = desiredRotation
        if not wantsToPlay
          drawIndex++
      else
        pos = positions[drawIndex]
        anim.req.x = pos.x
        anim.req.y = pos.y
        anim.req.r = pos.r
        drawIndex++

  # immediately warp all cards to where they should be
  warp: ->
    for card,anim of @anims
      anim.warp()

  # reorder the hand based on the drag location of the held card
  reorder: ->
    return if @dragIndexStart == NO_CARD
    return if @cards.length < 2 # nothing to reorder
    positions = @calcPositions(@cards.length)
    closestIndex = 0
    closestDist = @screenWidth * @screenHeight # something impossibly large
    for pos, index in positions
      dist = calcDistanceSquared(pos.x, pos.y, @dragX, @dragY)
      if closestDist > dist
        closestDist = dist
        closestIndex = index
    @dragIndexCurrent = closestIndex

  down: (@dragX, @dragY, index) ->
    @up(@dragX, @dragY) # ensure we let go of the previous card in case the events are dumb
    @game.log "picking up card index #{index}"
    @dragIndexStart = index
    @dragIndexCurrent = index
    @updatePositions()

  move: (@dragX, @dragY) ->
    return if @dragIndexStart == NO_CARD
    #@game.log "dragging around card index #{@dragIndexCurrent}"
    @reorder()
    @updatePositions()

  up: (@dragX, @dragY) ->
    return if @dragIndexStart == NO_CARD
    @reorder()
    if @wantsToPlayDraggedCard()
      @game.log "trying to play a #{@cards[@dragIndexStart]} from index #{@dragIndexStart}"
      card = @cards[@dragIndexStart]
      anim = @anims[card]
      @dragIndexStart = NO_CARD
      @dragIndexCurrent = NO_CARD
      @game.play card, anim.cur.x, anim.cur.y, anim.cur.r
    else
      @game.log "trying to reorder #{@cards[@dragIndexStart]} into index #{@dragIndexCurrent}"
      @cards = @calcDrawnHand() # is this right?

    @dragIndexStart = NO_CARD
    @dragIndexCurrent = NO_CARD
    @updatePositions()

  update: (dt) ->
    updated = false
    for card,anim of @anims
      if anim.update(dt)
        updated = true
    return updated

  render: ->
    return if @cards.length == 0
    drawnHand = @calcDrawnHand()
    for v, index in drawnHand
      continue if v == NO_CARD
      anim = @anims[v]
      do (anim, index) =>
        @renderCard v, anim.cur.x, anim.cur.y, anim.cur.r, (clickX, clickY) =>
          @down(clickX, clickY, index)

  renderCard: (v, x, y, rot, cb) ->
    rot = 0 if not rot
    rank = Math.floor(v % 13)
    suit = Math.floor(v / 13)
    @game.drawImage {
      texture: "cards"
      src:
        x: CARD_IMAGE_OFF_X + (CARD_IMAGE_ADV_X * rank)
        y: CARD_IMAGE_OFF_Y + (CARD_IMAGE_ADV_Y * suit)
        w: CARD_IMAGE_W
        h: CARD_IMAGE_H
      dst:
        x: x
        y: y
        w: @cardWidth
        h: @cardHeight
      rot: rot
      anchor:
        x: 0.5
        y: 0.5
      cb: cb
    }

  calcPositions: (handSize) ->
    if @positionCache.hasOwnProperty(handSize)
      return @positionCache[handSize]

    angleSpread = @handAngleAdvance * handSize      # how much of the angle we plan on using
    angleLeftover = @handAngle - angleSpread        # amount of angle we're not using, and need to pad sides with evenly
    currentAngle = -1 * (@handAngle / 2)            # move to the left side of our angle
    currentAngle += angleLeftover / 2               # ... and advance past half of the padding
    currentAngle += @handAngleAdvance / 2           # ... and center the cards in the angle

    positions = []
    for i in [0...handSize]
      x = @handCenter.x - Math.cos((Math.PI / 2) + currentAngle) * @handDistance
      y = @handCenter.y - Math.sin((Math.PI / 2) + currentAngle) * @handDistance
      currentAngle += @handAngleAdvance
      positions.push {
        x: x
        y: y
        r: currentAngle
      }

    @positionCache[handSize] = positions
    return positions

  renderHand: ->
    return if @hand.length == 0
    for v,index in @hand
      do (index) =>
        @renderCard v, x, y, currentAngle, (clickX, clickY) =>
          @down(clickX, clickY, index)

module.exports = Hand
