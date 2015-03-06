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
    renderParams =
      texture: font
      src: { x: 0, y: 0, w: 0, h: 0} # filled in during the loop
      dst: { x: 0, y: 0, w: 0, h: 0} # filled in during the loop
      rot: 0
      anchor:
        x: 0
        y: 0
      cb: cb

    for ch, i in str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      renderParams.src.x = glyph.x
      renderParams.src.y = glyph.y
      renderParams.src.w = glyph.width
      renderParams.src.h = glyph.height
      renderParams.dst.x = currX + (glyph.xoffset * scale) + anchorOffsetX
      renderParams.dst.y = y + (glyph.yoffset * scale) + anchorOffsetY
      renderParams.dst.w = glyph.width * scale
      renderParams.dst.h = glyph.height * scale
      @game.drawImage renderParams
      currX += glyph.xadvance * scale

module.exports = FontRenderer
