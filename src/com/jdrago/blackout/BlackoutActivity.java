package com.jdrago.blackout;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.View;

import com.jdrago.blackout.bridge.*;

class BlackoutGame implements NativeApp
{
    private static final String TAG = "BlackoutGame";

    public void log(String s)
    {
        Log.v(TAG, "BlackoutGame: " + s);
    }
}

public class BlackoutActivity extends Activity
{
    private static final String TAG = "Blackout";

    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);
        immerse();

        BlackoutGame game = new BlackoutGame();
        Script script = new Script();
        script.startup(game);
    }

    @Override
    protected void onResume()
    {
        Log.d(TAG, "Resuming the App");

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
