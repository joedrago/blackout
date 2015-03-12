package com.jdrago.blackout;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Point;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Display;
import android.view.View;
import android.view.Window;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;

public class BlackoutActivity extends Activity
{
    private static final String TAG = "Blackout";

    private BlackoutView view_;
    Point displaySize_;
    private double coordinateScale_;
    boolean paused_;
    Handler uiHandler_;
    Runnable mainLoop_;

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        coordinateScale_ = 1;
        paused_ = true;

        Display display = getWindowManager().getDefaultDisplay();
        displaySize_ = new Point();
        display.getRealSize(displaySize_);

        Log.d(TAG, "BlackoutActivity::onCreate(): displaySize: "+displaySize_.x+","+displaySize_.y);
        view_ = new BlackoutView(getApplication(), this, displaySize_, loadScript(R.raw.script));
        setContentView(view_);
        immerse();

        // The main loop is implemented as a Runnable that either runs once a second when idling,
        // or runs at BlackoutRenderer.MAX_FPS if in the middle of an animation or a drag.
        uiHandler_ = new Handler(Looper.getMainLooper());
        mainLoop_ = new Runnable() {
            @Override
            public void run() {
                if (isFinishing()) {
                    return;
                }
                if(paused_)
                    return;

                // Update and render happen in this call
                view_.requestRender();

                if(view_.renderer().needsRender())
                {
                    uiHandler_.postDelayed(this, BlackoutRenderer.MIN_MS_PER_FRAME);
                }
                else
                {
                    uiHandler_.postDelayed(this, 1000);
                }
            }
        };
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus)
    {
        super.onWindowFocusChanged(hasFocus);

        View content = getWindow().findViewById(Window.ID_ANDROID_CONTENT);
        double touchWidth = content.getWidth();
        double touchHeight = content.getHeight();

        // This awful hack is because Android loves to pretend I'm in portrait during a lockscreen.
        double biggestDimension = touchWidth;
        if(biggestDimension < touchHeight)
            biggestDimension = touchHeight;

        coordinateScale_ = displaySize_.x / biggestDimension;
        Log.d(TAG, "touchSize: "+touchWidth+","+touchHeight+" [biggestDimension: "+biggestDimension+"] coordinateScale: "+coordinateScale_);
    }

    @Override
    protected void onPause()
    {
        super.onPause();
        Log.d(TAG, "onPause");

        String state = view_.renderer().jsSave();
        Log.d(TAG, "save state: "+state.length()+" bytes");
        Log.d(TAG, "save state: "+state);

        SharedPreferences.Editor editor = getPreferences(MODE_PRIVATE).edit();
        editor.putString("state", state);
        editor.apply();

        view_.onPause();
        paused_ = true;
    }

    @Override
    protected void onResume()
    {
        super.onResume();
        Log.d(TAG, "onResume");

        String state = getPreferences(MODE_PRIVATE).getString("state", "");
        Log.d(TAG, "load state: "+state.length()+" bytes");
        Log.d(TAG, "load state: "+state);

        view_.renderer().jsLoad(state);

        view_.onResume();
        paused_ = false;
        immerse();
        kick();
    }

    public void onBackPressed()
    {
        // This stops the back button from destroying this Activity
        moveTaskToBack(true);
    }

    protected void kick()
    {
        // Makes the mainLoop_ runnable immediately fire (instead of waiting up to a second for it)
        uiHandler_.removeCallbacks(mainLoop_);
        uiHandler_.post(mainLoop_);
    }

    void immerse()
    {
        this.getWindow().getDecorView().setSystemUiVisibility(
              View.SYSTEM_UI_FLAG_LAYOUT_STABLE
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.INVISIBLE);
    }

    public void touchDown(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        view_.renderer().jsTouchDown(x, y);
        kick();
    }

    public void touchMove(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        view_.renderer().jsTouchMove(x, y);
        kick();
    }

    public void touchUp(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        view_.renderer().jsTouchUp(x, y);
        kick();
    }

    public String loadScript(int resId)
    {
        InputStream inputStream = getApplication().getResources().openRawResource(resId);

        InputStreamReader inputreader = new InputStreamReader(inputStream);
        BufferedReader buffreader = new BufferedReader(inputreader);
        String line;
        StringBuilder text = new StringBuilder();

        try {
            while (( line = buffreader.readLine()) != null) {
                text.append(line);
                text.append('\n');
            }
        } catch (IOException e) {
            return null;
        }
        return text.toString();
    }
}
