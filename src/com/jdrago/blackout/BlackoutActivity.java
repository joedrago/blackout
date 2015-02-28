package com.jdrago.blackout;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

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
    /** Called when the activity is first created. */
    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.main);

        BlackoutGame game = new BlackoutGame();
        Script script = new Script();
        script.startup(game);
    }
}
