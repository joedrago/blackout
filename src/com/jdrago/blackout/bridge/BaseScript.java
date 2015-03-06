package com.jdrago.blackout.bridge;

public interface BaseScript {
      public void startup(NativeApp nativeApp, int width, int height);
      public void shutdown();
      public boolean update(Double dt);
      public void render();
      public void load(String s);
      public String save();
      public void touchDown(Double x, Double y);
      public void touchMove(Double x, Double y);
      public void touchUp(Double x, Double y);
}
