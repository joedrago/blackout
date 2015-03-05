Animation = require 'Animation'
CardRenderer = require 'CardRenderer'

class Game
  constructor: (@native, @width, @height) ->
    @log("Game constructed: #{@width}x#{@height}")
    @cardRenderer = new CardRenderer this, @width, @height
    @zones = []

    @hand = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    @anim = new Animation {
      speed: { r: Math.PI * 4, s: 0.5, t: 2 * @width }
      x: 100
      y: 100
      r: 0
    }

  log: (s) ->
    @native.log(s)

  blit: (textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY, cb) ->
    @native.blit(textureName, srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY)
    if cb?
      # caller wants to remember where this was drawn, and wants to be called back if it is ever touched
      # This is called a "zone". Since zones are traversed in reverse order, the natural overlap of
      # a series of blits is respected accordingly.
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

  load: (data) ->
    @log "load: #{data}"

  save: ->
    @log "save"
    return "{}"

  makeHand: (index) ->
    for v in [0...13]
      if v == index
        @hand[v] = 13
      else
        @hand[v] = v

  touchDown: (x, y) ->
    if not @checkZones(x, y)
      @makeHand(-1)

    @dragging = true

    @anim.req.x = x
    @anim.req.y = y
    @anim.req.r = (y / @height) * (Math.PI * 2)

  touchMove: (x, y) ->
    if @dragging
      if not @checkZones(x, y)
        @makeHand(-1)

  touchUp: (x, y) ->
    @dragging = false

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
      zone.cb()
      return true
    return false

  update: (dt) ->
    @zones.length = 0 # forget about zones from the last frame. we're about to make some new ones!
    @cardRenderer.renderHand @hand, (index) =>
      @makeHand(index)

    @anim.update dt
    @cardRenderer.renderCard 51, @anim.cur.x, @anim.cur.y, @anim.cur.r

module.exports = Game
