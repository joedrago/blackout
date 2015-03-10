calcSign = (v) ->
  if v == 0
    return 0
  else if v < 0
    return -1
  return 1

class Animation
  constructor: (data) ->
    @speed = data.speed
    @req = {}
    @cur = {}
    for k,v of data
      if k != 'speed'
        @req[k] = v
        @cur[k] = v

  # 'finishes' all animations
  warp: ->
    if @cur.r?
      @cur.r = @req.r
    if @cur.s?
      @cur.s = @req.s
    if @cur.x? and @cur.y?
      @cur.x = @req.x
      @cur.y = @req.y

  animating: ->
    if @cur.r?
      if @req.r != @cur.r
        return true
    if @cur.s?
      if @req.s != @cur.s
        return true
    if @cur.x? and @cur.y?
      if (@req.x != @cur.x) or (@req.y != @cur.y)
        return true
    return false

  update: (dt) ->
    updated = false
    # rotation
    if @cur.r?
      if @req.r != @cur.r
        updated = true
        # sanitize requested rotation
        twoPi = Math.PI * 2
        negTwoPi = -1 * twoPi
        @req.r -= twoPi while @req.r >= twoPi
        @req.r += twoPi while @req.r <= negTwoPi
        # pick a direction and turn
        dr = @req.r - @cur.r
        dist = Math.abs(dr)
        sign = calcSign(dr)
        if dist > Math.PI
          # spin the other direction, it is closer
          dist = twoPi - dist
          sign *= -1
        maxDist = dt * @speed.r / 1000
        if dist < maxDist
          # we can finish this frame
          @cur.r = @req.r
        else
          @cur.r += maxDist * sign

    # scale
    if @cur.s?
      if @req.s != @cur.s
        updated = true
        # pick a direction and turn
        ds = @req.s - @cur.s
        dist = Math.abs(ds)
        sign = calcSign(ds)
        maxDist = dt * @speed.s / 1000
        if dist < maxDist
          # we can finish this frame
          @cur.s = @req.s
        else
          @cur.s += maxDist * sign

    # translation
    if @cur.x? and @cur.y?
      if (@req.x != @cur.x) or (@req.y != @cur.y)
        updated = true
        vecX = @req.x - @cur.x
        vecY = @req.y - @cur.y
        dist = Math.sqrt((vecX * vecX) + (vecY * vecY))
        maxDist = dt * @speed.t / 1000
        if dist < maxDist
          # we can finish this frame
          @cur.x = @req.x
          @cur.y = @req.y
        else
          # move as much as possible
          @cur.x += (vecX / dist) * maxDist
          @cur.y += (vecY / dist) * maxDist

    return updated

module.exports = Animation
