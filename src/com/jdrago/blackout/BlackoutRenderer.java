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

    private static final int FLOAT_SIZE_BYTES = 4;
    private static final int INT_SIZE_BYTES = 4;
    private static final int FLOATS_PER_VERT = 10;
    private static final int VERTS_PER_QUAD = 6;
    private static final int TRIANGLE_VERTICES_DATA_STRIDE_BYTES = FLOATS_PER_VERT * FLOAT_SIZE_BYTES;
    private static final int TRIANGLE_VERTICES_DATA_POS_OFFSET = 0;
    private static final int TRIANGLE_VERTICES_DATA_UV_OFFSET = 4;
    private static final int TRIANGLE_VERTICES_DATA_COLOR_OFFSET = 6;
    private static final int TEXTURE_COUNT = 5;

    private static final String VERTEX_SHADER =
        "attribute vec4 aPosition;\n" +
        "attribute vec2 aTextureCoord;\n" +
        "attribute vec4 aColor;\n" +
        "varying vec2 vTextureCoord;\n" +
        "varying vec4 vColor;\n" +
        "void main() {\n" +
        "  gl_Position = aPosition;\n" +
        "  vTextureCoord = aTextureCoord;\n" +
        "  vColor = aColor;\n" +
        "}\n";

    private static final String FRAGMENT_SHADER =
        "precision mediump float;\n" +
        "varying vec2 vTextureCoord;\n" +
        "varying vec4 vColor;\n" +
        "uniform sampler2D sTexture;\n" +
        "void main() {\n" +
        "vec4 t = texture2D(sTexture, vTextureCoord);" +
        "gl_FragColor.rgba = vColor.rgba * t.rgba;\n" +
        "}\n";


    // --------------------------------------------------------------------------------------------
    // Texture

    public class Texture
    {
        String name;
        int id;
        double width;
        double height;

        int quadCount;
        float[] vertData_;
        int vertDataSize_;
        private FloatBuffer verts_;

        public void prepare()
        {
            if(quadCount == 0)
                return;

            int floatsNeeded = quadCount * FLOATS_PER_VERT * VERTS_PER_QUAD;
            if(vertDataSize_ < floatsNeeded)
            {
                // resize vertex buffers to accomodate
                Log.d(TAG, "Texture '"+name+"' reserving "+quadCount+" quads worth");
                vertDataSize_ = floatsNeeded;
                vertData_ = new float[vertDataSize_];
                verts_ = ByteBuffer.allocateDirect(vertDataSize_ * FLOAT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
            }
            verts_.position(0);
        }
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
    // private FloatBuffer verts_;
    private int shaderProgram_;
    // private int viewProjMatrixHandle_;
    private int posHandle_;
    private int texHandle_;
    private int vertColorHandle_;
    private long frameCounter_;
    private long frameCounterLastTime_;
    private boolean needsRender_;
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

        // verts_ = ByteBuffer.allocateDirect(FLOATS_PER_VERT * VERTS_PER_QUAD * FLOAT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
        frameCounter_ = 0;
        frameCounterLastTime_ = FRAME_COUNTER_INTERVAL_MS;
        renderDataSize_ = 0;
        needsRender_ = true;

        Log.d(TAG, "Renderer MaxFPS: "+MAX_FPS+", MinMSPerFrame: "+MIN_MS_PER_FRAME);
    }

    // called after surface creation, but up top as it lists all available textures
    public void loadTextures()
    {
        textures_ = new Texture[TEXTURE_COUNT];
        textures_[0] = loadPNG("cards", R.raw.cards);
        textures_[1] = loadPNG("darkforest", R.raw.darkforest);
        textures_[2] = loadPNG("chars", R.raw.chars);
        textures_[3] = loadPNG("mainmenu", R.raw.mainmenu);
        textures_[4] = loadPNG("pausemenu", R.raw.pausemenu);
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
        needsRender_ = false;

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

            Trace.beginSection("touch"); try {
            V8Array parameters = new V8Array(v8_);
            parameters.push(touch.x);
            parameters.push(touch.y);
            v8_.executeVoidFunction(functionName, parameters);
            } finally { Trace.endSection(); }

            needsRender_ = true;
        }

        V8Array parameters = new V8Array(v8_);
        parameters.push(dt);
        Trace.beginSection("update");
        if(v8_.executeBooleanFunction("update", parameters))
            needsRender_ = true;
        Trace.endSection();
    }

    public boolean needsRender()
    {
        return needsRender_;
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
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        GLES20.glDepthFunc(GLES20.GL_LEQUAL);
        GLES20.glDepthMask(true);

        for(int i = 0; i < TEXTURE_COUNT; i++)
        {
            textures_[i].quadCount = 0;
        }

        int qi = 0; // quad index
        for(int i = 0; i < quadCount; i++, qi += 16)
        {
            int textureIndex = (int)renderData_[qi+0];
            if(textureIndex < 0)
                textureIndex = 0;
            if(textureIndex >= TEXTURE_COUNT)
                textureIndex = TEXTURE_COUNT - 1;
            textures_[textureIndex].quadCount++;
        }

        // Log.d(TAG, "Quads by texture:");
        for(int i = 0; i < TEXTURE_COUNT; i++)
        {
            // Log.d(TAG, "** "+textures_[i].name+": "+textures_[i].quadCount);
            textures_[i].prepare();
            textures_[i].quadCount = 0;
        }

        int currentTextureID = -1;
        qi = 0; // quad index
        float nextZ = -30;
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

            Trace.beginSection("drawImage");

            int textureIndex = (int)renderData_[qi+0];
            if(textureIndex < 0)
                textureIndex = 0;
            if(textureIndex >= TEXTURE_COUNT)
                textureIndex = TEXTURE_COUNT - 1;
            Texture texture = textures_[textureIndex];

            float uvL = (float)(renderData_[qi+1] / texture.width);
            float uvT = (float)(renderData_[qi+2] / texture.height);
            float uvR = (float)((renderData_[qi+1] + renderData_[qi+3]) / texture.width);
            float uvB = (float)((renderData_[qi+2] + renderData_[qi+4]) / texture.height);
            float fR = (float)renderData_[qi+12];
            float fG = (float)renderData_[qi+13];
            float fB = (float)renderData_[qi+14];
            float fA = (float)renderData_[qi+15];
            float[] vertData = {
                // X, Y, Z, W, U, V, R, G, B, A
                0, 0, nextZ, 1, uvL, uvT, fR, fG, fB, fA,
                1, 0, nextZ, 1, uvR, uvT, fR, fG, fB, fA,
                1, 1, nextZ, 1, uvR, uvB, fR, fG, fB, fA,
                1, 1, nextZ, 1, uvR, uvB, fR, fG, fB, fA,
                0, 1, nextZ, 1, uvL, uvB, fR, fG, fB, fA,
                0, 0, nextZ, 1, uvL, uvT, fR, fG, fB, fA
            };

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

            int vertexOffset = 0;
            Matrix.multiplyMV(vertData, vertexOffset, viewProjMatrix_, 0, vertData, vertexOffset);
            vertexOffset += FLOATS_PER_VERT;
            Matrix.multiplyMV(vertData, vertexOffset, viewProjMatrix_, 0, vertData, vertexOffset);
            vertexOffset += FLOATS_PER_VERT;
            Matrix.multiplyMV(vertData, vertexOffset, viewProjMatrix_, 0, vertData, vertexOffset);
            vertexOffset += FLOATS_PER_VERT;
            Matrix.multiplyMV(vertData, vertexOffset, viewProjMatrix_, 0, vertData, vertexOffset);
            vertexOffset += FLOATS_PER_VERT;
            Matrix.multiplyMV(vertData, vertexOffset, viewProjMatrix_, 0, vertData, vertexOffset);
            vertexOffset += FLOATS_PER_VERT;
            Matrix.multiplyMV(vertData, vertexOffset, viewProjMatrix_, 0, vertData, vertexOffset);

            texture.verts_.put(vertData);
            texture.quadCount++;
            nextZ += 1;

            Trace.endSection();
        }

        for(int i = 0; i < TEXTURE_COUNT; i++)
        {
            Texture texture = textures_[i];
            if(texture.quadCount == 0)
                continue;

            // Log.d(TAG, "rendering "+texture.quadCount+" quads with texture "+texture.name);

            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture.id);

            texture.verts_.position(TRIANGLE_VERTICES_DATA_POS_OFFSET);
            GLES20.glVertexAttribPointer(posHandle_, 3, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, texture.verts_);
            checkGlError("glVertexAttribPointer posHandle_");
            GLES20.glEnableVertexAttribArray(posHandle_);
            checkGlError("glEnableVertexAttribArray posHandle_");

            texture.verts_.position(TRIANGLE_VERTICES_DATA_UV_OFFSET);
            GLES20.glVertexAttribPointer(texHandle_, 2, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, texture.verts_);
            checkGlError("glVertexAttribPointer texHandle_");
            GLES20.glEnableVertexAttribArray(texHandle_);
            checkGlError("glEnableVertexAttribArray texHandle_");

            texture.verts_.position(TRIANGLE_VERTICES_DATA_COLOR_OFFSET);
            GLES20.glVertexAttribPointer(vertColorHandle_, 4, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, texture.verts_);
            checkGlError("glVertexAttribPointer vertColorHandle_");
            GLES20.glEnableVertexAttribArray(vertColorHandle_);
            checkGlError("glEnableVertexAttribArray vertColorHandle_");

            GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, texture.quadCount * VERTS_PER_QUAD);
            checkGlError("glDrawArrays");
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
        GLES20.glClearDepthf(1.0f);
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

        vertColorHandle_ = GLES20.glGetAttribLocation(shaderProgram_, "aColor");
        checkGlError("glGetAttribLocation vertColorHandle");
        if (vertColorHandle_ == -1)
        {
            throw new RuntimeException("Could not get attrib location for vertColorHandle");
        }

        // viewProjMatrixHandle_ = GLES20.glGetUniformLocation(shaderProgram_, "uMVPMatrix");
        // checkGlError("glGetUniformLocation uMVPMatrix");
        // if (viewProjMatrixHandle_ == -1)
        // {
        //     throw new RuntimeException("Could not get attrib location for uMVPMatrix");
        // }

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
        float near = -20.0f;
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

    public Texture loadPNG(String name, int res)
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
        texture.name = name;
        texture.id = id;
        texture.width = (double)bitmap.getWidth();
        texture.height = (double)bitmap.getHeight();
        texture.vertDataSize_ = 0;
        bitmap.recycle();
        return texture;
    }
}
