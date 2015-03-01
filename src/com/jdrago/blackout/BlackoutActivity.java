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

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        immerse();

        BlackoutApp game = new BlackoutApp();
        Script script = new Script();
        script.startup(game);
    }

    @Override
    protected void onResume()
    {
        Log.d(TAG, "Resuming");

        super.onResume();
        immerse();
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
