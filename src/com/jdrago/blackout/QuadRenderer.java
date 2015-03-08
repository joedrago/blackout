package com.jdrago.blackout;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.GLUtils;
import android.opengl.Matrix;
import android.os.Trace;
import android.util.Log;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;
import java.util.ArrayList;

class QuadRenderer implements GLSurfaceView.Renderer
{
    public class Texture
    {
        int id;
        int width;
        int height;
    };

    class Quad
    {
        float srcX;
        float srcY;
        float srcW;
        float srcH;
        float dstX;
        float dstY;
        float dstW;
        float dstH;
        float rot;
        float anchorX;
        float anchorY;
        float r;
        float g;
        float b;
        float a;
    };

    // to be implemented by a derived class
    public void loadTextures() {}
    public void onDrawFrame(GL10 glUnused) {}

    public QuadRenderer(Context context)
    {
        context_ = context;
        verts_ = ByteBuffer.allocateDirect(20 * FLOAT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
        indices_ = ByteBuffer.allocateDirect(quadIndicesData_.length * INT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asIntBuffer();
        indices_.put(quadIndicesData_).position(0);
    }

    public void renderBegin(float r, float g, float b)
    {
        GLES20.glClearColor(r, g, b, 1.0f);
        GLES20.glClear(GLES20.GL_DEPTH_BUFFER_BIT | GLES20.GL_COLOR_BUFFER_BIT);
        GLES20.glUseProgram(shaderProgram_);
        checkGlError("glUseProgram");
    }

    public void renderEnd()
    {
    }

    public Texture getTexture(String textureName)
    {
        // override this
        return null;
    }

    public void drawImage(String textureName, float srcX, float srcY, float srcW, float srcH, float dstX, float dstY, float dstW, float dstH, float rot, float anchorX, float anchorY, float r, float g, float b, float a)
    {
        Trace.beginSection("drawImage"); try {

        Texture texture = getTexture(textureName);

        GLES20.glEnable(GLES20.GL_BLEND);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA);
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0);

        float uvL = srcX / (float)texture.width;
        float uvT = srcY / (float)texture.height;
        float uvR = (srcX + srcW) / (float)texture.width;
        float uvB = (srcY + srcH) / (float)texture.height;

        float[] vertData = {
            // X, Y, Z, U, V
            0, 0, 0, uvL, uvT,
            1, 0, 0, uvR, uvT,
            1, 1, 0, uvR, uvB,
            0, 1, 0, uvL, uvB};
        verts_.position(0);
        verts_.put(vertData);

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, texture.id);
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

        float anchorOffsetX = -1 * anchorX * dstW;
        float anchorOffsetY = -1 * anchorY * dstH;
        Matrix.setIdentityM(modelMatrix_, 0);
        Matrix.translateM(modelMatrix_, 0, dstX, dstY, 0);
        Matrix.rotateM(modelMatrix_, 0, rot * 180.0f / (float)Math.PI, 0, 0, 1);
        Matrix.translateM(modelMatrix_, 0, anchorOffsetX, anchorOffsetY, 0);
        Matrix.scaleM(modelMatrix_, 0, dstW, dstH, 0);
        Matrix.multiplyMM(viewProjMatrix_, 0, viewMatrix_, 0, modelMatrix_, 0);
        Matrix.multiplyMM(viewProjMatrix_, 0, projMatrix_, 0, viewProjMatrix_, 0);

        GLES20.glUniformMatrix4fv(viewProjMatrixHandle_, 1, false, viewProjMatrix_, 0);
        GLES20.glUniform4f(vertColorHandle_, r, g, b, a);
        GLES20.glDrawElements(GLES20.GL_TRIANGLES, 6, GLES20.GL_UNSIGNED_INT, indices_);
        checkGlError("glDrawElements");

        } finally { Trace.endSection(); }
    }

    public void onSurfaceChanged(GL10 glUnused, int width, int height)
    {
        width_ = width;
        height_ = height;

        float density = context_.getResources().getDisplayMetrics().density;
        Log.d(TAG, "onSurfaceChanged("+width_+", "+height_+", "+density+")");

        // Ignore the passed-in GL10 interface, and use the GLES20
        // class's static methods instead.
        GLES20.glViewport(0, 0, width, height);

        float left = 0.0f;
        float right = width;
        float bottom = height;
        float top = 0.0f;
        float near = 0.0f;
        float far = 20.0f;
        Matrix.orthoM(projMatrix_, 0, left, right, bottom, top, near, far);
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
        texture.width = bitmap.getWidth();
        texture.height = bitmap.getHeight();
        bitmap.recycle();
        return texture;
    }

    public void onSurfaceCreated(GL10 glUnused, EGLConfig config)
    {
        // Ignore the passed-in GL10 interface, and use the GLES20
        // class's static methods instead.
        shaderProgram_ = createProgram(vertShader_, fragShader_);
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

    private void checkGlError(String op)
    {
        int error;
        while ((error = GLES20.glGetError()) != GLES20.GL_NO_ERROR)
        {
            Log.e(TAG, op + ": glError " + error);
            throw new RuntimeException(op + ": glError " + error);
        }
    }

    public int width()
    {
        return width_;
    }

    public int height()
    {
        return height_;
    }

    private static final int FLOAT_SIZE_BYTES = 4;
    private static final int INT_SIZE_BYTES = 4;
    private static final int TRIANGLE_VERTICES_DATA_STRIDE_BYTES = 5 * FLOAT_SIZE_BYTES;
    private static final int TRIANGLE_VERTICES_DATA_POS_OFFSET = 0;
    private static final int TRIANGLE_VERTICES_DATA_UV_OFFSET = 3;

    private FloatBuffer verts_;

    private final int[] quadIndicesData_ = {0, 1, 2, 2, 3, 0};
    private IntBuffer indices_;

    private final String vertShader_ =
            "uniform mat4 uMVPMatrix;\n" +
                    "attribute vec4 aPosition;\n" +
                    "attribute vec2 aTextureCoord;\n" +
                    "uniform vec4 u_color;\n" +
                    "varying vec2 vTextureCoord;\n" +
                    "void main() {\n" +
                    "  gl_Position = uMVPMatrix * aPosition;\n" +
                    "  vTextureCoord = aTextureCoord;\n" +
                    "}\n";

    private final String fragShader_ =
            "precision mediump float;\n" +
                    "varying vec2 vTextureCoord;\n" +
                    "uniform sampler2D sTexture;\n" +
                    "uniform vec4 u_color;\n" +
                    "void main() {\n" +
                    "vec4 t = texture2D(sTexture, vTextureCoord);" +
                    "gl_FragColor.rgba = u_color.rgba * t.rgba;\n" +
                    "}\n";

    private float[] viewProjMatrix_ = new float[16];
    private float[] projMatrix_ = new float[16];
    private float[] modelMatrix_ = new float[16];
    private float[] viewMatrix_ = new float[16];

    private int shaderProgram_;
    private int viewProjMatrixHandle_;
    private int posHandle_;
    private int texHandle_;
    private int vertColorHandle_;

    private int width_;
    private int height_;

    private Context context_;
    private static String TAG = "QuadRenderer";
}
