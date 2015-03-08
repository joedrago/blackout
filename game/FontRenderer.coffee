fontmetrics = require 'fontmetrics'

class FontRenderer
  constructor:  (@game) ->

  render: (args) ->
    # font, height, str, x, y, anchor.[xy], cb
    metrics = fontmetrics[args.font]
    return if not metrics
    scale = args.height / metrics.height

    totalWidth = 0
    totalHeight = metrics.height * scale
    for ch, i in args.str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      totalWidth += glyph.xadvance * scale

    anchorOffsetX = -1 * args.anchor.x * totalWidth
    anchorOffsetY = -1 * args.anchor.y * totalHeight
    currX = args.x

    # if not renderParams.color
    #   renderParams.color = { r: 1, g: 1, b: 1, a: 1 }

    for ch, i in args.str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      @game.drawImage args.font,
      glyph.x, glyph.y, glyph.width, glyph.height,
      currX + (glyph.xoffset * scale) + anchorOffsetX, args.y + (glyph.yoffset * scale) + anchorOffsetY, glyph.width * scale, glyph.height * scale,
      0, 0, 0,
      1,1,1,1
      currX += glyph.xadvance * scale

module.exports = FontRenderer
