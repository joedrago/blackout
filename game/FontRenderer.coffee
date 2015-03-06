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
      totalWidth += glyph.xadvance * scale

    anchorOffsetX = -1 * anchorX * totalWidth
    anchorOffsetY = -1 * anchorY * totalHeight
    currX = x
    for ch, i in str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      @game.drawImage {
        texture: font
        src:
          x: glyph.x
          y: glyph.y
          w: glyph.width
          h: glyph.height
        dst:
          x: currX + (glyph.xoffset * scale) + anchorOffsetX
          y: y + (glyph.yoffset * scale) + anchorOffsetY
          w: glyph.width * scale
          h: glyph.height * scale
        rot: 0
        anchor:
          x: 0
          y: 0
        cb: cb
      }
      currX += glyph.xadvance * scale

module.exports = FontRenderer
