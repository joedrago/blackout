package com.jdrago.blackout;

import com.jdrago.blackout.bridge.*;

import android.content.Context;
import android.opengl.GLSurfaceView;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.util.Log;

import javax.microedition.khronos.opengles.GL10;

class BlackoutView extends GLSurfaceView
{
    public BlackoutRenderer renderer_;

    public BlackoutView(Context context, Script script)
    {
        super(context);
        setEGLContextClientVersion(2);
        script_ = script;
        renderer_ = new BlackoutRenderer(context);
        setRenderer(renderer_);
    }

    public boolean onTouchEvent(MotionEvent event)
    {
        int action = event.getAction();
        double x = event.getX(0);
        double y = event.getY(0);
        switch(action)
        {
            case MotionEvent.ACTION_DOWN:
                script_.touchDown(x, y);
                break;
            case MotionEvent.ACTION_MOVE:
                script_.touchMove(x, y);
                break;
            case MotionEvent.ACTION_UP:
                script_.touchUp(x, y);
                break;
        }
        return true;
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
    private Script script_;
}