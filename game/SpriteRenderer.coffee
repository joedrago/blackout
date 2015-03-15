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
      howto1:    { texture: "howto1",  x: 0, y:  0, w: 1280, h: 720 }
      howto2:    { texture: "howto2",  x: 0, y:  0, w: 1280, h: 720 }
      howto3:    { texture: "howto3",  x: 0, y:  0, w: 1280, h: 720 }

      # characters
      mario:     { texture: "chars", x:  20, y:   0, w: 151, h: 308 }
      luigi:     { texture: "chars", x: 171, y:   0, w: 151, h: 308 }
      peach:     { texture: "chars", x: 335, y:   0, w: 164, h: 308 }
      daisy:     { texture: "chars", x: 504, y:   0, w: 164, h: 308 }
      yoshi:     { texture: "chars", x: 668, y:   0, w: 180, h: 308 }
      toad:      { texture: "chars", x: 849, y:   0, w: 157, h: 308 }
      bowser:    { texture: "chars", x:  11, y: 322, w: 151, h: 308 }
      bowserjr:  { texture: "chars", x: 225, y: 322, w: 144, h: 308 }
      koopa:     { texture: "chars", x: 372, y: 322, w: 128, h: 308 }
      rosalina:  { texture: "chars", x: 500, y: 322, w: 173, h: 308 }
      shyguy:    { texture: "chars", x: 691, y: 322, w: 154, h: 308 }
      toadette:  { texture: "chars", x: 847, y: 322, w: 158, h: 308 }

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
