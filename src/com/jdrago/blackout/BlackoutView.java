package com.jdrago.blackout;

import com.jdrago.blackout.bridge.*;

import android.graphics.Point;
import android.content.Context;
import android.opengl.GLSurfaceView;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.util.Log;

import javax.microedition.khronos.opengles.GL10;

class BlackoutView extends GLSurfaceView
{
    public BlackoutView(Context context, BlackoutActivity activity, Point displaySize, String script)
    {
        super(context);
        setEGLContextClientVersion(2);
        activity_ = activity;

        getHolder().setFixedSize(displaySize.x, displaySize.y);
        renderer_ = new BlackoutRenderer(context, activity, this, displaySize, script);
        setRenderer(renderer_);
        setRenderMode(RENDERMODE_WHEN_DIRTY);
    }

    public boolean onTouchEvent(MotionEvent event)
    {
        int action = event.getAction();
        double x = event.getX(0);
        double y = event.getY(0);
        switch(action)
        {
            case MotionEvent.ACTION_DOWN:
                activity_.touchDown(x, y);
                break;
            case MotionEvent.ACTION_MOVE:
                activity_.touchMove(x, y);
                break;
            case MotionEvent.ACTION_UP:
                activity_.touchUp(x, y);
                break;
        }
        return true;
    }

    public BlackoutRenderer renderer()
    {
        return renderer_;
    }

    public boolean menuChoice(int itemID)
    {
        //switch (itemID)
        //{
        //    case R.id.shuffle:
        //        renderer_.shuffle(0);
        //        return true;
        //    case R.id.s3:
        //        renderer_.shuffle(3);
        //        return true;
        //    case R.id.s4:
        //        renderer_.shuffle(4);
        //        return true;
        //    case R.id.s5:
        //        renderer_.shuffle(5);
        //        return true;
        //    case R.id.s6:
        //        renderer_.shuffle(6);
        //        return true;
        //    case R.id.s7:
        //        renderer_.shuffle(7);
        //        return true;
        //    case R.id.s8:
        //        renderer_.shuffle(8);
        //        return true;
        //}
        return false;
    }

    private static String TAG = "Blackout";
    private BlackoutActivity activity_;
    private BlackoutRenderer renderer_;
}