fontmetrics = require 'fontmetrics'

# taken from http://stackoverflow.com/questions/5623838/rgb-to-hex-and-hex-to-rgb
hexToRgb = (hex, a) ->
    result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
    return null if not result
    return {
        r: parseInt(result[1], 16) / 255,
        g: parseInt(result[2], 16) / 255,
        b: parseInt(result[3], 16) / 255
        a: a
    }

class FontRenderer
  constructor:  (@game) ->
    @white = { r: 1, g: 1, b: 1, a: 1 }

  size: (font, height, str) ->
    metrics = fontmetrics[font]
    return if not metrics
    scale = height / metrics.height

    totalWidth = 0
    totalHeight = metrics.height * scale
    for ch, i in str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      totalWidth += glyph.xadvance * scale

    return {
      w: totalWidth
      h: totalHeight
    }

  render: (font, height, str, x, y, anchorx, anchory, color, cb) ->
    metrics = fontmetrics[font]
    return if not metrics
    scale = height / metrics.height

    totalWidth = 0
    totalHeight = metrics.height * scale
    skipColor = false
    for ch, i in str
      if ch == '`'
        skipColor = !skipColor
      continue if skipColor
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      totalWidth += glyph.xadvance * scale

    anchorOffsetX = -1 * anchorx * totalWidth
    anchorOffsetY = -1 * anchory * totalHeight
    currX = x

    if color
      startingColor = color
    else
      startingColor = @white
    currentColor = startingColor

    colorStart = -1
    for ch, i in str
      if ch == '`'
        if colorStart == -1
          colorStart = i + 1
        else
          len = i - colorStart
          if len
            currentColor = hexToRgb(str.substr(colorStart, i - colorStart), startingColor.a)
          else
            currentColor = startingColor
          colorStart = -1

      continue if colorStart != -1
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      @game.drawImage font,
      glyph.x, glyph.y, glyph.width, glyph.height,
      currX + (glyph.xoffset * scale) + anchorOffsetX, y + (glyph.yoffset * scale) + anchorOffsetY, glyph.width * scale, glyph.height * scale,
      0, 0, 0,
      currentColor.r, currentColor.g, currentColor.b, currentColor.a, cb
      currX += glyph.xadvance * scale

module.exports = FontRenderer
