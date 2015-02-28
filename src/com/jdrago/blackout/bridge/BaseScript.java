package com.jdrago.blackout.bridge;

public interface BaseScript {
      public void startup(NativeApp nativeApp);
      public void shutdown();
      public void update();
}
