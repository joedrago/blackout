fontmetrics = require 'fontmetrics'

class FontRenderer
  constructor:  (@game) ->

  render: (font, height, str, x, y, anchorx, anchory, color, cb) ->
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

    anchorOffsetX = -1 * anchorx * totalWidth
    anchorOffsetY = -1 * anchory * totalHeight
    currX = x

    if not color
      color = { r: 1, g: 1, b: 1, a: 1 }

    for ch, i in str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      @game.drawImage font,
      glyph.x, glyph.y, glyph.width, glyph.height,
      currX + (glyph.xoffset * scale) + anchorOffsetX, y + (glyph.yoffset * scale) + anchorOffsetY, glyph.width * scale, glyph.height * scale,
      0, 0, 0,
      color.r, color.g, color.b, color.a, cb
      currX += glyph.xadvance * scale

module.exports = FontRenderer
