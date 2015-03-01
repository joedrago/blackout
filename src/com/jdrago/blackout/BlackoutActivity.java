package com.jdrago.blackout;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import com.jdrago.blackout.bridge.*;

class BlackoutApp implements NativeApp
{
    private static final String TAG = "Blackout";

    public void log(String s)
    {
        Log.v(TAG, s);
    }
}

public class BlackoutActivity extends Activity
{
    private static final String TAG = "Blackout";
    private BlackoutApp app_;
    private Script script_;

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        immerse();

        String state = "";
        if(savedInstanceState != null)
        {
            state = savedInstanceState.getString("state");
        }

        app_ = new BlackoutApp();
        script_ = new Script();
        script_.startup(app_);

        Log.d(TAG, "about to call load with: "+state);
        script_.load(state);
    }

    @Override
    protected void onPause()
    {
        Log.d(TAG, "onPause (native)");

        super.onPause();
    }

    @Override
    protected void onResume()
    {
        Log.d(TAG, "onResume (native)");

        super.onResume();
        immerse();
    }

    protected void onSaveInstanceState(Bundle savedInstanceState)
    {
        super.onSaveInstanceState(savedInstanceState);

        Log.d(TAG, "onSaveInstanceState (native)");

        String state = script_.save();
        Log.d(TAG, "recording saved state: " + state);
        savedInstanceState.putString("state", state);
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
}
