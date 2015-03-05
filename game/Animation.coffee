class Animation
  constructor: (data) ->
    @speed = data.speed
    @req = {}
    @cur = {}
    for k,v of data
      if k != 'speed'
        @req[k] = v
        @cur[k] = v

  update: (dt) ->
    # rotation
    if @cur.r?
      if @req.r != @cur.r
        # sanitize requested rotation
        twoPi = Math.PI * 2
        negTwoPi = -1 * twoPi
        @req.r -= twoPi while @req.r >= twoPi
        @req.r += twoPi while @req.r <= negTwoPi
        # pick a direction and turn
        dr = @req.r - @cur.r
        dist = Math.abs(dr)
        sign = Math.sign(dr)
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

    # scale (NYI)

    # translation
    if @cur.x? and @cur.y?
      if (@req.x != @cur.x) or (@req.y != @cur.y)
        vec =
          x: @req.x - @cur.x
          y: @req.y - @cur.y
        dist = Math.sqrt((vec.x * vec.x) + (vec.y * vec.y))
        maxDist = dt * @speed.t / 1000
        if dist < maxDist
          # we can finish this frame
          @cur.x = @req.x
          @cur.y = @req.y
        else
          # move as much as possible
          @cur.x += (vec.x / dist) * maxDist
          @cur.y += (vec.y / dist) * maxDist

module.exports = Animation
