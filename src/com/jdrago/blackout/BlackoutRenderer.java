package com.jdrago.blackout;

import com.jdrago.blackout.bridge.*;

import android.content.Context;
import android.util.Log;

import java.util.HashMap;
import javax.microedition.khronos.opengles.GL10;

public class BlackoutRenderer extends QuadRenderer
{
    public BlackoutRenderer(Context context, BlackoutActivity activity)
    {
        super(context);

        activity_ = activity;
        textures_ = new HashMap<String, Texture>();
        Log.d(TAG, "created textures_");
    }

    public void loadTextures()
    {
        textures_.put("cards", loadPNG(R.raw.cards));
    }

    public void blit(String textureName, int srcX, int srcY, int srcW, int srcH, int dstX, int dstY, int dstW, int dstH, float rot, float anchorX, float anchorY)
    {
        blit(textures_.get(textureName), srcX, srcY, srcW, srcH, dstX, dstY, dstW, dstH, rot, anchorX, anchorY);
    }

    public void onDrawFrame(GL10 glUnused)
    {
        renderBegin(0.0f, 0.0f, 0.0f);
        activity_.update();
        renderEnd();
    }

    private static String TAG = "Blackout";
    private HashMap<String, Texture> textures_;
    private BlackoutActivity activity_;
}