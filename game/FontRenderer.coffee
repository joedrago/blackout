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
    renderParams =
      texture: args.font
      src: { x: 0, y: 0, w: 0, h: 0} # filled in during the loop
      dst: { x: 0, y: 0, w: 0, h: 0} # filled in during the loop
      rot: 0
      anchor:
        x: 0
        y: 0
      cb: args.cb
      color: args.color

    if not renderParams.color
      renderParams.color = { r: 1, g: 1, b: 1, a: 1 }

    for ch, i in args.str
      code = ch.charCodeAt(0)
      glyph = metrics.glyphs[code]
      continue if not glyph
      renderParams.src.x = glyph.x
      renderParams.src.y = glyph.y
      renderParams.src.w = glyph.width
      renderParams.src.h = glyph.height
      renderParams.dst.x = currX + (glyph.xoffset * scale) + anchorOffsetX
      renderParams.dst.y = args.y + (glyph.yoffset * scale) + anchorOffsetY
      renderParams.dst.w = glyph.width * scale
      renderParams.dst.h = glyph.height * scale
      @game.drawImage renderParams
      currX += glyph.xadvance * scale

module.exports = FontRenderer
