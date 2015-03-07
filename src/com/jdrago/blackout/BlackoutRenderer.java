package com.jdrago.blackout;

import com.jdrago.blackout.bridge.*;

import android.content.Context;
import android.util.Log;

import java.lang.Thread;
import java.util.HashMap;
import javax.microedition.khronos.opengles.GL10;

public class BlackoutRenderer extends QuadRenderer implements NativeApp
{
    static private final int MAX_FPS = 20;
    static private final int MIN_MS_PER_FRAME = 1000 / MAX_FPS;

    public BlackoutRenderer(Context context, BlackoutActivity activity, BlackoutView view)
    {
        super(context);

        activity_ = activity;
        view_ = view;
        textures_ = new HashMap<String, Texture>();
        lastTime_ = System.currentTimeMillis();
        frameCounter_ = 0;

        //Log.d(TAG, "Renderer MaxFPS: "+MAX_FPS+", MinMSPerFrame: "+MIN_MS_PER_FRAME);
    }

    public void loadTextures()
    {
        textures_.put("cards", loadPNG(R.raw.cards));
        textures_.put("unispace", loadPNG(R.raw.unispace));
        textures_.put("square", loadPNG(R.raw.square));
    }

    @Override
    public Texture getTexture(String textureName)
    {
        return textures_.get(textureName);
    }

    public void log(String s)
    {
        Log.v(TAG, s);
    }

    public void onDrawFrame(GL10 glUnused)
    {
        frameCounter_++;
        // Log.d(TAG, "onDrawFrame: "+frameCounter_);

        // Cap our framerate to MAX_FPS by measuring the time it took
        // to get back in this function and taking a break before rendering again
        long now = System.currentTimeMillis();
        long dt = now - lastTime_;
        if(dt < MIN_MS_PER_FRAME)
        {
           try {
               Thread.sleep(MIN_MS_PER_FRAME - dt);
           } catch(InterruptedException e) {
               // Restore the interrupted status
               Thread.currentThread().interrupt();
           }
        }
        lastTime_ = System.currentTimeMillis();

        boolean needsRender = activity_.update();
        renderBegin(0.0f, 0.0f, 0.0f);
        activity_.render();
        renderEnd();

        if(needsRender) {
            // Log.d(TAG, "needsRender from onDrawFrame");
            view_.requestRender();
        }
    }

    private static String TAG = "Blackout";
    private HashMap<String, Texture> textures_;
    private BlackoutActivity activity_;
    private BlackoutView view_;
    private long lastTime_;
    private long frameCounter_;
}