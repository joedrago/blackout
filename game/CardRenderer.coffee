CARD_IMAGE_W = 120
CARD_IMAGE_H = 162
CARD_IMAGE_OFF_X = 4
CARD_IMAGE_OFF_Y = 4
CARD_IMAGE_ADV_X = CARD_IMAGE_W
CARD_IMAGE_ADV_Y = CARD_IMAGE_H
CARD_RENDER_SCALE = 0.4            # card height coefficient from the screen's height
CARD_HAND_CURVE_DIST_FACTOR = 1    # factor with screen height to figure out center of arc. bigger number is less arc

# taken from http://stackoverflow.com/questions/1211212/how-to-calculate-an-angle-from-three-points
# uses law of cosines to figure out the hand arc angle
findAngle = (p0, p1, p2) ->
    a = Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2)
    b = Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2)
    c = Math.pow(p2.x - p0.x, 2) + Math.pow(p2.y - p0.y, 2)
    return Math.acos( (a+b-c) / Math.sqrt(4*a*b) )

calcDistance = (p0, p1) ->
  return Math.sqrt(Math.pow(p1.x - p0.x, 2) + Math.pow(p1.y - p0.y, 2))

class CardRenderer
  constructor: (@game, @screenWidth, @screenHeight) ->
    @cardHeight = Math.floor(@screenHeight * CARD_RENDER_SCALE)
    @cardWidth  = Math.floor(@cardHeight * CARD_IMAGE_W / CARD_IMAGE_H)

    arcMargin = @cardWidth
    arcVerticalBias = @cardHeight / 50
    bottomLeft  = { x: arcMargin,                y: arcVerticalBias + @screenHeight }
    bottomRight = { x: @screenWidth - arcMargin, y: arcVerticalBias + @screenHeight }
    @handCenter = { x: @screenWidth / 2,         y: arcVerticalBias + @screenHeight + (CARD_HAND_CURVE_DIST_FACTOR * @screenHeight) }
    @handAngle = findAngle(bottomLeft, @handCenter  , bottomRight) # * (180 / Math.PI)
    @handDistance = calcDistance(bottomLeft, @handCenter)
    @handAngleAdvance = @handAngle / 13
    @game.log "Hand distance #{@handDistance}, angle #{@handAngle} (screen height #{@screenHeight})"

  renderCard: (v, x, y, rot, cb) ->
    rot = 0 if not rot
    rank = Math.floor(v % 13)
    suit = Math.floor(v / 13)
    @game.blit "cards",
      CARD_IMAGE_OFF_X + (CARD_IMAGE_ADV_X * rank), CARD_IMAGE_OFF_Y + (CARD_IMAGE_ADV_Y * suit), CARD_IMAGE_W, CARD_IMAGE_H,
      x, y, @cardWidth, @cardHeight,
      rot, 0.5, 0.5, cb

  renderHand: (hand, cb) ->
    return if hand.length == 0

    angleSpread = @handAngleAdvance * hand.length   # how much of the angle we plan on using
    angleLeftover = @handAngle - angleSpread        # amount of angle we're not using, and need to pad sides with evenly
    currentAngle = -1 * (@handAngle / 2)            # move to the left side of our angle
    currentAngle += angleLeftover / 2               # ... and advance past half of the padding
    currentAngle += @handAngleAdvance / 2           # ... and center the cards in the angle
    index = 0
    for v in hand
      x = @handCenter.x - Math.cos((Math.PI / 2) + currentAngle) * @handDistance
      y = @handCenter.y - Math.sin((Math.PI / 2) + currentAngle) * @handDistance
      do (cb, index) =>
        @renderCard v, x, y, currentAngle, ->
          cb(index)
      currentAngle += @handAngleAdvance
      index++

module.exports = CardRenderer
