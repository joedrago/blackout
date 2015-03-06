package com.jdrago.blackout;

import com.jdrago.blackout.bridge.*;

import android.content.Context;
import android.util.Log;

import java.lang.Thread;
import java.util.HashMap;
import javax.microedition.khronos.opengles.GL10;

public class BlackoutRenderer extends QuadRenderer
{
    //static private final int MAX_FPS = 60;
    //static private final int MIN_MS_PER_FRAME = 1000 / MAX_FPS;

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
        textures_.put("font", loadPNG(R.raw.font));
    }

    public void drawImage(String textureName, float srcX, float srcY, float srcW, float srcH, float dstX, float dstY, float dstW, float dstH, float rot, float anchorX, float anchorY)
    {
        drawImage(textures_.get(textureName), srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY);
    }

    public void onDrawFrame(GL10 glUnused)
    {
        frameCounter_++;
        Log.d(TAG, "onDrawFrame: "+frameCounter_);

        //// Cap our framerate at 30fps by measuring the time it took
        //// to get back in this function and taking a break before rendering again
        //long now = System.currentTimeMillis();
        //long dt = now - lastTime_;
        //if(dt < MIN_MS_PER_FRAME)
        //{
        //    try {
        //        Thread.sleep(MIN_MS_PER_FRAME - dt);
        //    } catch(InterruptedException e) {
        //        // Restore the interrupted status
        //        Thread.currentThread().interrupt();
        //    }
        //}
        //lastTime_ = System.currentTimeMillis();

        boolean needsRender = activity_.update();
        renderBegin(0.0f, 0.0f, 0.0f);
        activity_.render();
        renderEnd();

        if(needsRender) {
            Log.d(TAG, "needsRender from onDrawFrame");
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