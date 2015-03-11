package com.jdrago.blackout;

import android.app.Activity;
import android.content.res.Configuration;
import android.graphics.Point;
import android.os.Bundle;
import android.os.Handler;
import android.util.Log;
import android.view.Display;
import android.view.View;
import android.view.Window;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

import java.util.Timer;
import java.util.TimerTask;

// import com.jdrago.blackout.bridge.*;
import com.jdrago.blackout.BlackoutView;

public class BlackoutActivity extends Activity
{
    private static final String TAG = "Blackout";

    private BlackoutView view_;
    Point displaySize_;
    private double coordinateScale_;
    boolean paused_;

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        paused_ = true;

        Display display = getWindowManager().getDefaultDisplay();
        displaySize_ = new Point();
        display.getRealSize(displaySize_);

        // Halve the resolution so phones don't choke on the awesome
        displaySize_.x /= 2;
        displaySize_.y /= 2;

        coordinateScale_ = 1;
        Log.d(TAG, "BlackoutActivity::onCreate(): displaySize: "+displaySize_.x+","+displaySize_.y);

        view_ = new BlackoutView(getApplication(), this, displaySize_, loadScript(R.raw.script));
        setContentView(view_);
        immerse();

        // This block of code ensures that we re-render at least once a second (1 FPS).
        final Handler handler = new Handler();
        Timer timer = new Timer(false);
        TimerTask timerTask = new TimerTask() {
            @Override
            public void run() {
                handler.post(new Runnable() {
                    @Override
                    public void run() {
                        if(!paused_)
                            view_.requestRender();
                    }
                });
            }
        };
        timer.scheduleAtFixedRate(timerTask, 1000, 1000);
    }

    @Override
    public void onWindowFocusChanged (boolean hasFocus)
    {
        super.onWindowFocusChanged(hasFocus);

        View content = getWindow().findViewById(Window.ID_ANDROID_CONTENT);
        double touchWidth = content.getWidth();
        double touchHeight = content.getHeight();
        coordinateScale_ = displaySize_.x / touchWidth;
        Log.d(TAG, "touchSize: "+touchWidth+","+touchHeight+" coordinateScale: "+coordinateScale_);
    }

    @Override
    protected void onPause()
    {
        Log.d(TAG, "onPause (native)");

        super.onPause();
        view_.onPause();
        paused_ = true;
    }

    @Override
    protected void onResume()
    {
        Log.d(TAG, "onResume (native)");

        super.onResume();
        view_.onResume();
        immerse();
        paused_ = false;
    }

    protected void onSaveInstanceState(Bundle savedInstanceState)
    {
        super.onSaveInstanceState(savedInstanceState);

        Log.d(TAG, "onSaveInstanceState (native)");

        // String state = jsSave();
        // savedInstanceState.putString("state", state);
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
    }

    public void touchMove(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        view_.renderer().jsTouchMove(x, y);
    }

    public void touchUp(double x, double y)
    {
        x *= coordinateScale_;
        y *= coordinateScale_;
        view_.renderer().jsTouchUp(x, y);
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
