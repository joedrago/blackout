package com.jdrago.blackout;

import android.content.Context;
import android.util.Log;

import java.util.HashMap;
import javax.microedition.khronos.opengles.GL10;

public class BlackoutRenderer extends QuadRenderer
{
    public BlackoutRenderer(Context context)
    {
        super(context);

        textures_ = new HashMap<String, Integer>();
    }

    public void loadTextures()
    {
        textures_.put("cards", loadPNG(R.raw.cards));
    }

    public void update()
    {
    }

    public void onDrawFrame(GL10 glUnused)
    {
        update();

        renderBegin(1.0f, 0.1f, 0.1f);

        // lots of renderQuad calls

        renderEnd();
    }

    public void touchDown(int x, int y)
    {
    }

    private static String TAG = "Blackout";
    private HashMap<String, Integer> textures_;
}