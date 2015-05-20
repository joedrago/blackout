class SpriteRenderer
  constructor: (@game) ->
    @sprites =
      # generic sprites
      solid:     { texture: "chars", x:  55, y: 723, w:  10, h:  10 }
      pause:     { texture: "chars", x: 602, y: 707, w: 122, h: 125 }
      button0:   { texture: "chars", x: 140, y: 777, w: 422, h:  65 }
      button1:   { texture: "chars", x: 140, y: 698, w: 422, h:  65 }
      plus0:     { texture: "chars", x: 745, y: 664, w: 116, h: 118 }
      plus1:     { texture: "chars", x: 745, y: 820, w: 116, h: 118 }
      minus0:    { texture: "chars", x: 895, y: 664, w: 116, h: 118 }
      minus1:    { texture: "chars", x: 895, y: 820, w: 116, h: 118 }
      arrowL:    { texture: "chars", x:  33, y: 858, w: 204, h: 156 }
      arrowR:    { texture: "chars", x: 239, y: 852, w: 208, h: 155 }

      # menu backgrounds
      mainmenu:  { texture: "mainmenu",  x: 0, y: 0, w: 1280, h: 720 }
      pausemenu: { texture: "pausemenu", x: 0, y: 0, w: 1280, h: 720 }

      # howto
      howto1:    { texture: "howto1",  x: 0, y:  0, w: 1920, h: 1080 }
      howto2:    { texture: "howto2",  x: 0, y:  0, w: 1920, h: 1080 }
      howto3:    { texture: "howto3",  x: 0, y:  0, w: 1920, h: 1080 }

      # characters
      chester:   { texture: "faces", x:   8, y:   7, w:  83, h:  83 }
      joe:       { texture: "faces", x: 101, y:   7, w:  83, h:  83 }
      vinnie:    { texture: "faces", x: 196, y:   8, w:  83, h:  82 }

      sal:       { texture: "faces", x: 289, y:   8, w:  83, h:  83 }
      jane:      { texture: "faces", x: 382, y:   9, w:  83, h:  82 }
      patrick:   { texture: "faces", x: 474, y:  11, w:  83, h:  82 }
      jimbo:     { texture: "faces", x: 567, y:  10, w:  83, h:  83 }
      ryan:      { texture: "faces", x: 663, y:  12, w:  83, h:  82 }
      brandon:   { texture: "faces", x: 755, y:  12, w:  83, h:  82 }
      tori:      { texture: "faces", x: 845, y:  12, w:  83, h:  82 }

  calcWidth: (spriteName, height) ->
    sprite = @sprites[spriteName]
    return 1 if not sprite
    return height * sprite.w / sprite.h

  render: (spriteName, dx, dy, dw, dh, rot, anchorx, anchory, color, cb) ->
    sprite = @sprites[spriteName]
    return if not sprite
    if (dw == 0) and (dh == 0)
      # this probably shouldn't ever be used.
      dw = sprite.x
      dh = sprite.y
    else if dw == 0
      dw = dh * sprite.w / sprite.h
    else if dh == 0
      dh = dw * sprite.h / sprite.w
    @game.drawImage sprite.texture, sprite.x, sprite.y, sprite.w, sprite.h, dx, dy, dw, dh, rot, anchorx, anchory, color.r, color.g, color.b, color.a, cb
    return

module.exports = SpriteRenderer
