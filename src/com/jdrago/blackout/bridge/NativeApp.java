package com.jdrago.blackout.bridge;

public interface NativeApp {
    public void drawImage(String textureName, float srcX, float srcY, float srcW, float srcH, float dstX, float dstY, float dstW, float dstH, float rot, float anchorX, float anchorY);
    public void log(String s);
}
