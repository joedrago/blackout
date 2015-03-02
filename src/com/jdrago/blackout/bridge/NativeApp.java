package com.jdrago.blackout.bridge;

public interface NativeApp {
    public void blit(String textureName, int srcX, int srcY, int srcW, int srcH, int dstX, int dstY, int dstW, int dstH, float rot, float anchorX, float anchorY);
    public void log(String s);
}
