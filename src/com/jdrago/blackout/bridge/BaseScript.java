package com.jdrago.blackout.bridge;

public interface BaseScript {
      public void startup(NativeApp nativeApp);
      public void shutdown();
      public void update();
      public void load(String s);
      public String save();
      public void touchDown(Double x, Double y);
      public void touchMove(Double x, Double y);
      public void touchUp(Double x, Double y);
}
