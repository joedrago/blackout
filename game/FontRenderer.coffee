fontmetrics = require 'fontmetrics'

class FontRenderer
  constructor:  (@game) ->

  renderString:  (font, height, str, x, y, anchorX, anchorY, cb) ->
    metrics = fontmetrics[font]
    return if not metrics
    scale = height / metrics.height

    totalWidth = 0
    totalHeight = metrics.height * scale
    for ch, i in str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      totalWidth += metrics.advance * scale

    anchorOffsetX = -1 * anchorX * totalWidth
    anchorOffsetY = -1 * anchorY * totalHeight
    currX = x
    for ch, i in str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      @game.drawImage font,
        glyph.x, glyph.y, glyph.width, glyph.height,
        currX + (glyph.xoffset * scale) + anchorOffsetX, y + (glyph.yoffset * scale) + anchorOffsetY, glyph.width * scale, glyph.height * scale,
        0, 0, 0, cb
      currX += metrics.advance * scale

module.exports = FontRenderer
