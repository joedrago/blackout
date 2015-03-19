package com.jdrago.blackout;

import com.jdrago.blackout.GLTextureView;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Point;
import android.opengl.GLES20;
import android.opengl.GLUtils;
import android.opengl.Matrix;
import android.os.Trace;
import android.util.Log;

import com.eclipsesource.v8.V8;
import com.eclipsesource.v8.V8Array;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;
import java.io.IOException;
import java.io.InputStream;
import java.lang.Thread;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.HashMap;

import javax.microedition.khronos.opengles.GL10;

public class BlackoutRenderer implements GLTextureView.Renderer
{
    // --------------------------------------------------------------------------------------------
    // Constants

    static private final String TAG = "Blackout";

    static private final int MAX_FPS = 30;
    static public  final int MIN_MS_PER_FRAME = 1000 / MAX_FPS;
    static private final int FRAME_COUNTER_INTERVAL_MS = 10 * 1000;
    static private final int FAST_FRAMES_AFTER_UPDATED = 6;

    private static final int FLOAT_SIZE_BYTES = 4;
    private static final int INT_SIZE_BYTES = 4;
    private static final int TRIANGLE_VERTICES_DATA_STRIDE_BYTES = 5 * FLOAT_SIZE_BYTES;
    private static final int TRIANGLE_VERTICES_DATA_POS_OFFSET = 0;
    private static final int TRIANGLE_VERTICES_DATA_UV_OFFSET = 3;
    private static final int[] QUAD_INDICES = {0, 1, 2, 2, 3, 0};
    private static final int TEXTURE_COUNT = 6;

    private static final String VERTEX_SHADER =
            "uniform mat4 uMVPMatrix;\n" +
                    "attribute vec4 aPosition;\n" +
                    "attribute vec2 aTextureCoord;\n" +
                    "uniform vec4 u_color;\n" +
                    "varying vec2 vTextureCoord;\n" +
                    "void main() {\n" +
                    "  gl_Position = uMVPMatrix * aPosition;\n" +
                    "  vTextureCoord = aTextureCoord;\n" +
                    "}\n";

    private static final String FRAGMENT_SHADER =
            "precision mediump float;\n" +
                    "varying vec2 vTextureCoord;\n" +
                    "uniform sampler2D sTexture;\n" +
                    "uniform vec4 u_color;\n" +
                    "void main() {\n" +
                    "vec4 t = texture2D(sTexture, vTextureCoord);" +
                    "gl_FragColor.rgba = u_color.rgba * t.rgba;\n" +
                    "}\n";


    // --------------------------------------------------------------------------------------------
    // Texture

    public class Texture
    {
        int id;
        double width;
        double height;
    };

    // --------------------------------------------------------------------------------------------
    // Touch events

    public enum TouchType
    {
        DOWN,
        MOVE,
        UP
    }

    public class Touch
    {
        public Touch(TouchType atype, double ax, double ay)
        {
            type = atype;
            x = ax;
            y = ay;
        }
        public TouchType type;
        public double x;
        public double y;
    };

    // --------------------------------------------------------------------------------------------
    // Member variables

    // Basic information given/calculated during construction
    Context context_;
    private BlackoutActivity activity_;
    private BlackoutView view_;
    String script_;
    private int width_;
    private int height_;

    // Javascript engine internals
    private V8 v8_;
    ConcurrentLinkedQueue<Touch> inputQueue_;
    private long lastTime_;

    // Render internals
    private Texture textures_[];
    private float[] viewProjMatrix_ = new float[16];
    private float[] projMatrix_ = new float[16];
    private float[] modelMatrix_ = new float[16];
    private float[] viewMatrix_ = new float[16];
    private FloatBuffer verts_;
    private IntBuffer indices_;
    private int shaderProgram_;
    private int viewProjMatrixHandle_;
    private int posHandle_;
    private int texHandle_;
    private int vertColorHandle_;
    private long frameCounter_;
    private long frameCounterLastTime_;
    private int fastRenderFrames_;
    private double[] renderData_;
    private int renderDataSize_;

    // --------------------------------------------------------------------------------------------
    // Constructor

    public BlackoutRenderer(Context context, BlackoutActivity activity, BlackoutView view, Point displaySize, String script)
    {
        context_ = context;
        activity_ = activity;
        view_ = view;
        script_ = script;
        width_ = displaySize.x;
        height_ = displaySize.y;

        inputQueue_ = new ConcurrentLinkedQueue<Touch>();
        lastTime_ = System.currentTimeMillis();

        initializeV8(context_, script_);
        jsStartup();

        verts_ = ByteBuffer.allocateDirect(20 * FLOAT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
        indices_ = ByteBuffer.allocateDirect(QUAD_INDICES.length * INT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asIntBuffer();
        indices_.put(QUAD_INDICES).position(0);
        frameCounter_ = 0;
        frameCounterLastTime_ = FRAME_COUNTER_INTERVAL_MS;
        renderDataSize_ = 0;
        fastRenderFrames_ = 1;

        Log.d(TAG, "Renderer MaxFPS: "+MAX_FPS+", MinMSPerFrame: "+MIN_MS_PER_FRAME);
    }

    // called after surface creation, but up top as it lists all available textures
    public void loadTextures()
    {
        textures_ = new Texture[TEXTURE_COUNT];
        textures_[0] = loadPNG(R.raw.cards);
        textures_[1] = loadPNG(R.raw.darkforest);
        textures_[2] = loadPNG(R.raw.chars);
        textures_[3] = loadPNG(R.raw.howto1);
        textures_[4] = loadPNG(R.raw.howto2);
        textures_[5] = loadPNG(R.raw.howto3);
    }

    // --------------------------------------------------------------------------------------------
    // Main loop

    public void onDrawFrame(GL10 glUnused)
    {
        // Cap our framerate to MAX_FPS by measuring the time it took
        // to get back in this function and taking a break before rendering again
        long now = System.currentTimeMillis();
        long dt = now - lastTime_;

        // Comment out this block to disable frame limiting
        {
            Trace.beginSection("wait to limit FPS");
            if(dt < MIN_MS_PER_FRAME)
            {
               try
               {
                   Thread.sleep(MIN_MS_PER_FRAME - dt);
               }
               catch(InterruptedException e)
               {
                   Thread.currentThread().interrupt();
               }
            }

            // post-sleep, update now and dt again
            now = System.currentTimeMillis();
            dt = now - lastTime_;
            Trace.endSection();
        }

        lastTime_ = now;

        frameCounter_++;
        frameCounterLastTime_ -= dt;
        if(frameCounterLastTime_ <= 0)
        {
            if(frameCounter_ > 2 * (FRAME_COUNTER_INTERVAL_MS / 1000))
                Log.d(TAG, "Rendered "+frameCounter_+" frames in last "+(FRAME_COUNTER_INTERVAL_MS + frameCounterLastTime_) + "ms");

            frameCounter_ = 0;
            frameCounterLastTime_ = FRAME_COUNTER_INTERVAL_MS;
        }

        jsUpdate((double)dt);

        renderBegin(0.0f, 0.25f, 0.0f);
        jsRender();
        renderEnd();
    }

    // --------------------------------------------------------------------------------------------
    // V8 Initialization

    public void initializeV8(Context context, String script)
    {
        Log.d(TAG, "Loading script, "+script.length()+" chars");

        v8_ = V8.createV8Runtime(null, context.getApplicationInfo().dataDir);
        v8_.registerJavaMethod(this, "nativeLog", "nativeLog", new Class<?>[] { String.class });
        v8_.executeVoidScript(script);
    }

    // --------------------------------------------------------------------------------------------
    // Calls into JS

    public void jsUpdate(double dt)
    {
        Touch touch;
        while((touch = inputQueue_.poll()) != null)
        {
            String functionName;
            switch(touch.type)
            {
                case DOWN: functionName = "touchDown"; break;
                case UP:   functionName = "touchUp";   break;
                default:
                case MOVE: functionName = "touchMove"; break;
            };

            Trace.beginSection("touch");
            V8Array parameters = new V8Array(v8_);
            parameters.push(touch.x);
            parameters.push(touch.y);
            v8_.executeVoidFunction(functionName, parameters);
            Trace.endSection();

            fastRenderFrames_ = FAST_FRAMES_AFTER_UPDATED;
        }

        V8Array parameters = new V8Array(v8_);
        parameters.push(dt);
        Trace.beginSection("update");
        if(v8_.executeBooleanFunction("update", parameters))
            fastRenderFrames_ = FAST_FRAMES_AFTER_UPDATED;
        Trace.endSection();
    }

    public boolean needsRender()
    {
        if(fastRenderFrames_ > 0)
        {
            fastRenderFrames_--;
            return true;
        }
        return false;
    }

    public void jsStartup()
    {
        V8Array parameters = new V8Array(v8_);
        parameters.push(width_);
        parameters.push(height_);
        v8_.executeVoidFunction("startup", parameters);
    }

    public void jsRender()
    {
        Trace.beginSection("render");
        V8Array parameters = new V8Array(v8_);

        Trace.beginSection("js render");
        V8Array renderCommands = v8_.executeArrayFunction("render", parameters);
        Trace.endSection();

        Trace.beginSection("native render");

        if(renderDataSize_ < renderCommands.length())
        {
            renderDataSize_ = renderCommands.length();
            renderData_ = new double[renderDataSize_];
        }

        int quadCount = renderCommands.length() >> 4; // 16 doubles per quad
        // Log.d(TAG, "drawing "+quadCount+" quads");

        Trace.beginSection("get doubles");
        renderCommands.getDoubles(0, renderCommands.length(), renderData_);
        Trace.endSection();

        GLES20.glEnable(GLES20.GL_BLEND);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA);
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0);

        int currentTextureID = -1;
        int qi = 0; // quad index
        for(int i = 0; i < quadCount; i++, qi += 16)
        {
            // Indices:
            //  0: texture ID
            //  1: srcX
            //  2: srcY
            //  3: srcW
            //  4: srcH
            //  5: dstX
            //  6: dstY
            //  7: dstW
            //  8: dstH
            //  9: rot
            // 10: anchorX
            // 11: anchorY
            // 12: red
            // 13: green
            // 14: blue
            // 15: alpha

            // switch to vertex colors (stop using uniform color)
            //
            // give each Texture class:
            // verts_
            // vertData_
            // vertDataSize_
            // tempCount
            //
            // then scan the incoming double array, counting up the quads per texture
            // resize all texture vertData_ accordingly
            // walk double array, populating vert buffers
            // for each texture do a single verts_.put(),

            Trace.beginSection("drawImage");

            int textureIndex = (int)renderData_[qi+0];
            if(textureIndex < 0)
                textureIndex = 0;
            if(textureIndex >= TEXTURE_COUNT)
                textureIndex = TEXTURE_COUNT - 1;
            Texture texture = textures_[textureIndex];
            if(currentTextureID != texture.id)
            {
                currentTextureID = texture.id;
                GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, currentTextureID);
            }

            float uvL = (float)(renderData_[qi+1] / texture.width);
            float uvT = (float)(renderData_[qi+2] / texture.height);
            float uvR = (float)((renderData_[qi+1] + renderData_[qi+3]) / texture.width);
            float uvB = (float)((renderData_[qi+2] + renderData_[qi+4]) / texture.height);

            float[] vertData = {
                // X, Y, Z, U, V
                0, 0, 0, uvL, uvT,
                1, 0, 0, uvR, uvT,
                1, 1, 0, uvR, uvB,
                0, 1, 0, uvL, uvB};
            verts_.position(0);
            verts_.put(vertData);

            verts_.position(TRIANGLE_VERTICES_DATA_POS_OFFSET);
            GLES20.glVertexAttribPointer(posHandle_, 3, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, verts_);
            checkGlError("glVertexAttribPointer maPosition");
            verts_.position(TRIANGLE_VERTICES_DATA_UV_OFFSET);
            GLES20.glEnableVertexAttribArray(posHandle_);
            checkGlError("glEnableVertexAttribArray posHandle");
            GLES20.glVertexAttribPointer(texHandle_, 2, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, verts_);
            checkGlError("glVertexAttribPointer texHandle");
            GLES20.glEnableVertexAttribArray(texHandle_);
            checkGlError("glEnableVertexAttribArray texHandle");

            float anchorOffsetX = (float)(-1 * renderData_[qi+10] * renderData_[qi+7]);
            float anchorOffsetY = (float)(-1 * renderData_[qi+11] * renderData_[qi+8]);
            float degrees = (float)(renderData_[qi+9] * 180.0f / Math.PI);

            Matrix.setIdentityM(modelMatrix_, 0);
            Matrix.translateM(modelMatrix_, 0, (float)renderData_[qi+5], (float)renderData_[qi+6], 0);
            Matrix.rotateM(modelMatrix_, 0, degrees, 0, 0, 1);
            Matrix.translateM(modelMatrix_, 0, anchorOffsetX, anchorOffsetY, 0);
            Matrix.scaleM(modelMatrix_, 0, (float)renderData_[qi+7], (float)renderData_[qi+8], 0);
            Matrix.multiplyMM(viewProjMatrix_, 0, viewMatrix_, 0, modelMatrix_, 0);
            Matrix.multiplyMM(viewProjMatrix_, 0, projMatrix_, 0, viewProjMatrix_, 0);

            GLES20.glUniformMatrix4fv(viewProjMatrixHandle_, 1, false, viewProjMatrix_, 0);
            GLES20.glUniform4f(vertColorHandle_, (float)renderData_[qi+12], (float)renderData_[qi+13], (float)renderData_[qi+14], (float)renderData_[qi+15]);
            GLES20.glDrawElements(GLES20.GL_TRIANGLES, 6, GLES20.GL_UNSIGNED_INT, indices_);
            checkGlError("glDrawElements");

            Trace.endSection();
        }

        Trace.endSection();
        renderCommands.release();
        Trace.endSection();
    }

    public void jsLoad(String s)
    {
        V8Array parameters = new V8Array(v8_);
        parameters.push(s);
        v8_.executeVoidFunction("load", parameters);
    }

    public String jsSave()
    {
        String s = "";
        V8Array parameters = new V8Array(v8_);
        s = v8_.executeStringFunction("save", parameters);
        return s;
    }

    public void jsTouchDown(double x, double y)
    {
        Touch touch = new Touch(TouchType.DOWN, x, y);
        inputQueue_.offer(touch);
    }

    public void jsTouchMove(double x, double y)
    {
        Touch touch = new Touch(TouchType.MOVE, x, y);
        inputQueue_.offer(touch);
    }

    public void jsTouchUp(double x, double y)
    {
        Touch touch = new Touch(TouchType.UP, x, y);
        inputQueue_.offer(touch);
    }

    // --------------------------------------------------------------------------------------------
    // Calls from JS

    public void nativeLog(String s)
    {
        Log.d(TAG, "nativeLog: " + s);
    }

    // --------------------------------------------------------------------------------------------
    // Render internals

    public void renderBegin(float r, float g, float b)
    {
        GLES20.glViewport(0, 0, width_, height_);
        GLES20.glClearColor(r, g, b, 1.0f);
        GLES20.glClear(GLES20.GL_DEPTH_BUFFER_BIT | GLES20.GL_COLOR_BUFFER_BIT);
        GLES20.glUseProgram(shaderProgram_);
        checkGlError("glUseProgram");
    }

    public void renderEnd()
    {
    }

    public void onSurfaceCreated(GL10 glUnused, EGLConfig config)
    {
        // Ignore the passed-in GL10 interface, and use the GLES20
        // class's static methods instead.
        shaderProgram_ = createProgram(VERTEX_SHADER, FRAGMENT_SHADER);
        if (shaderProgram_ == 0)
        {
            return;
        }
        posHandle_ = GLES20.glGetAttribLocation(shaderProgram_, "aPosition");
        checkGlError("glGetAttribLocation aPosition");
        if (posHandle_ == -1)
        {
            throw new RuntimeException("Could not get attrib location for aPosition");
        }
        texHandle_ = GLES20.glGetAttribLocation(shaderProgram_, "aTextureCoord");
        checkGlError("glGetAttribLocation aTextureCoord");
        if (texHandle_ == -1)
        {
            throw new RuntimeException("Could not get attrib location for aTextureCoord");
        }

        viewProjMatrixHandle_ = GLES20.glGetUniformLocation(shaderProgram_, "uMVPMatrix");
        checkGlError("glGetUniformLocation uMVPMatrix");
        if (viewProjMatrixHandle_ == -1)
        {
            throw new RuntimeException("Could not get attrib location for uMVPMatrix");
        }

        vertColorHandle_ = GLES20.glGetUniformLocation(shaderProgram_, "u_color");
        checkGlError("glGetUniformLocation vertColorHandle");
        if (vertColorHandle_ == -1)
        {
            throw new RuntimeException("Could not get attrib location for vertColorHandle");
        }

        loadTextures();

        Matrix.setLookAtM(viewMatrix_, 0,
                0, 0, 10,         // eye
                0f, 0f, 0f,       // center
                0f, 1.0f, 0.0f);  // up
    }

    public void onSurfaceDestroyed(GL10 glUnused)
    {
    }

    public void onSurfaceChanged(GL10 glUnused, int width, int height)
    {
        width_ = width;
        height_ = height;

        float density = context_.getResources().getDisplayMetrics().density;
        Log.d(TAG, "onSurfaceChanged("+width_+", "+height_+", "+density+")");

        // Ignore the passed-in GL10 interface, and use the GLES20
        // class's static methods instead.
        GLES20.glViewport(0, 0, width_, height_);

        float left = 0.0f;
        float right = width;
        float bottom = height;
        float top = 0.0f;
        float near = 0.0f;
        float far = 20.0f;
        Matrix.orthoM(projMatrix_, 0, left, right, bottom, top, near, far);
    }

    private int loadShader(int shaderType, String source)
    {
        int shader = GLES20.glCreateShader(shaderType);
        if (shader != 0)
        {
            GLES20.glShaderSource(shader, source);
            GLES20.glCompileShader(shader);
            int[] compiled = new int[1];
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0);
            if (compiled[0] == 0)
            {
                Log.e(TAG, "Could not compile shader " + shaderType + ":");
                Log.e(TAG, GLES20.glGetShaderInfoLog(shader));
                GLES20.glDeleteShader(shader);
                shader = 0;
            }
        }
        return shader;
    }

    private int createProgram(String vertexSource, String fragmentSource)
    {
        int vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexSource);
        if (vertexShader == 0)
        {
            return 0;
        }

        int pixelShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource);
        if (pixelShader == 0)
        {
            return 0;
        }

        int program = GLES20.glCreateProgram();
        if (program != 0)
        {
            GLES20.glAttachShader(program, vertexShader);
            checkGlError("glAttachShader");
            GLES20.glAttachShader(program, pixelShader);
            checkGlError("glAttachShader");
            GLES20.glLinkProgram(program);
            int[] linkStatus = new int[1];
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0);
            if (linkStatus[0] != GLES20.GL_TRUE)
            {
                Log.e(TAG, "Could not link program: ");
                Log.e(TAG, GLES20.glGetProgramInfoLog(program));
                GLES20.glDeleteProgram(program);
                program = 0;
            }
        }
        return program;
    }

    // --------------------------------------------------------------------------------------------
    // Helper functions

    private void checkGlError(String op)
    {
        int error;
        while ((error = GLES20.glGetError()) != GLES20.GL_NO_ERROR)
        {
            Log.e(TAG, op + ": glError " + error);
            throw new RuntimeException(op + ": glError " + error);
        }
    }

    public Texture loadPNG(int res)
    {
        int[] textures = new int[1];
        GLES20.glGenTextures(1, textures, 0);

        int id = textures[0];
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, id);

        GLES20.glTexParameterf(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST);
        GLES20.glTexParameterf(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);

        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_REPEAT);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_REPEAT);

        InputStream is = context_.getResources().openRawResource(res);
        Bitmap bitmap;
        try
        {
            bitmap = BitmapFactory.decodeStream(is);
        } finally
        {
            try
            {
                is.close();
            } catch (IOException e)
            {
                // Ignore.
            }
        }

        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0);

        Texture texture = new Texture();
        texture.id = id;
        texture.width = (double)bitmap.getWidth();
        texture.height = (double)bitmap.getHeight();
        bitmap.recycle();
        return texture;
    }
}
