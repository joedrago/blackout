package com.jdrago.blackout;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.GLUtils;
import android.opengl.Matrix;
import android.util.Log;

import javax.microedition.khronos.egl.EGLConfig;
import javax.microedition.khronos.opengles.GL10;
import java.io.IOException;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

class QuadRenderer implements GLSurfaceView.Renderer
{
    public QuadRenderer(Context context)
    {
        context_ = context;
        whiteVerts_ = ByteBuffer.allocateDirect(whiteVertData_.length * FLOAT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
        whiteVerts_.put(whiteVertData_).position(0);
        digitVerts_ = ByteBuffer.allocateDirect(digitVertData_.length * FLOAT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asFloatBuffer();
        digitVerts_.put(digitVertData_).position(0);
        quadIndices_ = ByteBuffer.allocateDirect(quadIndicesData_.length * INT_SIZE_BYTES).order(ByteOrder.nativeOrder()).asIntBuffer();
        quadIndices_.put(quadIndicesData_).position(0);
        digitBuffer_ = new int[16];
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

    public void onDrawFrame(GL10 glUnused)
    {
    }

    public enum QuadRenderType
    {
        QRT_BOX,
        QRT_INT,
        QRT_FLOAT
    };

    class Quad
    {
        public Quad()
        {
            type = QuadRenderType.QRT_BOX;
            v = 0;
            x = 0;
            y = 0;
            w = 1;
            h = 1;
            r = 1;
            g = 1;
            b = 1;
        }

        public Quad(QuadRenderType atype, float av, int ax, int ay, int aw, int ah, float ar, float ag, float ab, float aa)
        {
            type = atype;
            v = av;
            x = ax;
            y = ay;
            w = aw;
            h = ah;
            r = ar;
            g = ag;
            b = ab;
            a = aa;
        }

        QuadRenderType type;
        float v;
        int x;
        int y;
        int w;
        int h;
        float r;
        float g;
        float b;
        float a;
    }

    public void renderQuad(Quad q)
    {
        GLES20.glEnable(GLES20.GL_BLEND);
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA);
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0);

        int x = q.x;
        int digitCount = 0;
        int textureID = whiteID_;
        FloatBuffer verts = whiteVerts_;
        if(q.type == QuadRenderType.QRT_BOX)
        {
            digitBuffer_[0] = 0;
            digitCount = 1;
        }
        else
        {
            textureID = digitID_;
            verts = digitVerts_;

            if(q.w == 0)
            {
                q.w = (int)(q.h * (DIGIT_W / DIGIT_H));
            }

            float tempf = q.v;
            if(q.type == QuadRenderType.QRT_FLOAT)
            {
                tempf *= 1000.0f;
            }
            int v = (int)tempf;
            do
            {
                int t = v % 10;
                v = (v - t) / 10;
                digitBuffer_[digitCount++] = t;
                if((q.type == QuadRenderType.QRT_FLOAT) && (digitCount == 3))
                {
                    digitBuffer_[digitCount++] = 10;
                }
            }
            while(v > 0);

            if((q.type == QuadRenderType.QRT_FLOAT) && (digitCount == 4))
            {
                digitBuffer_[digitCount++] = 0; // leading zero
            }

            // WORST HACK EVER
            if(q.type == QuadRenderType.QRT_FLOAT)
            {
                x -= digitCount * q.w; // right align
            }
            else
            {
                x -= (digitCount * q.w) / 2; // center align
            }
        }

        for(int i = 0; i < digitCount; i++)
        {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureID);
            verts.position(TRIANGLE_VERTICES_DATA_POS_OFFSET);
            GLES20.glVertexAttribPointer(posHandle_, 3, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, verts);
            checkGlError("glVertexAttribPointer maPosition");
            verts.position(TRIANGLE_VERTICES_DATA_UV_OFFSET);
            GLES20.glEnableVertexAttribArray(posHandle_);
            checkGlError("glEnableVertexAttribArray posHandle");
            GLES20.glVertexAttribPointer(texHandle_, 2, GLES20.GL_FLOAT, false, TRIANGLE_VERTICES_DATA_STRIDE_BYTES, verts);
            checkGlError("glVertexAttribPointer texHandle");
            GLES20.glEnableVertexAttribArray(texHandle_);
            checkGlError("glEnableVertexAttribArray texHandle");

            Matrix.setIdentityM(modelMatrix_, 0);
            Matrix.translateM(modelMatrix_, 0, x, q.y, 0);
            Matrix.scaleM(modelMatrix_, 0, q.w, q.h, 0);
            Matrix.multiplyMM(viewProjMatrix_, 0, viewMatrix_, 0, modelMatrix_, 0);
            Matrix.multiplyMM(viewProjMatrix_, 0, projMatrix_, 0, viewProjMatrix_, 0);

            GLES20.glUniformMatrix4fv(viewProjMatrixHandle_, 1, false, viewProjMatrix_, 0);
            GLES20.glUniform4f(vertColorHandle_, q.r, q.g, q.b, q.a);
            GLES20.glUniform2f(uvOffsetHandle_, digitBuffer_[(digitCount - i) - 1] * DIGIT_UV_W, 0.0f);
            GLES20.glDrawElements(GLES20.GL_TRIANGLES, 6, GLES20.GL_UNSIGNED_INT, quadIndices_);
            checkGlError("glDrawArrays");

            x += q.w;
        }
    }

    public void renderQuad(int x, int y, int w, int h, float r, float g, float b, float a)
    {
        renderQuad(new Quad(QuadRenderType.QRT_BOX, 0, x, y, w, h, r, g, b, a));
    }

    public void renderInt(int v, int x, int y, int w, int h, float r, float g, float b, float a)
    {
        renderQuad(new Quad(QuadRenderType.QRT_INT, v, x, y, w, h, r, g, b, a));
    }

    public void renderFloat(float v, int x, int y, int w, int h, float r, float g, float b, float a)
    {
        renderQuad(new Quad(QuadRenderType.QRT_FLOAT, v, x, y, w, h, r, g, b, a));
    }

    public void onSurfaceChanged(GL10 glUnused, int width, int height)
    {
        width_ = width;
        height_ = height;

        // Ignore the passed-in GL10 interface, and use the GLES20
        // class's static methods instead.
        GLES20.glViewport(0, 0, width, height);

//        float ratio = (float) width / height;
//        Matrix.frustumM(projMatrix_, 0, -ratio, ratio, -1, 1, 3, 7);

        float left = 0.0f;
        float right = width;
        float bottom = height;
        float top = 0.0f;
        float near = 0.0f;
        float far = 20.0f;
        Matrix.orthoM(projMatrix_, 0, left, right, bottom, top, near, far);
    }

    public int loadPNG(int res)
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
        bitmap.recycle();
        return id;
    }

    public void loadTextures()
    {
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

        uvOffsetHandle_ = GLES20.glGetUniformLocation(shaderProgram_, "u_uvOffset");
        checkGlError("glGetUniformLocation uvOffset");
        if (uvOffsetHandle_ == -1)
        {
            throw new RuntimeException("Could not get attrib location for uvOffset");
        }

        /*
         * Create our texture. This has to be done each time the
         * surface is created.
         */
        whiteID_ = loadPNG(R.raw.white);
        digitID_ = loadPNG(R.raw.digits);

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

    private final float[] whiteVertData_ = {
            // X, Y, Z, U, V
            0, 0, 0, 0, 0,
            1, 0, 0, 1, 0,
            1, 1, 0, 1, 1,
            0, 1, 0, 0, 1};
    private FloatBuffer whiteVerts_;

    private static final float DIGIT_W = 38.0f;
    private static final float DIGIT_H = 47.0f;
    private static final float DIGIT_UV_W = DIGIT_W / 512.0f;
    private static final float DIGIT_UV_H = DIGIT_H / 512.0f;

    // Digit UVs are for a DIGIT_UV_W x DIGIT_UV_H rect
    private final float[] digitVertData_ = {
            // X, Y, Z, U, V
            0, 0, 0, 0,          0,
            1, 0, 0, DIGIT_UV_W, 0,
            1, 1, 0, DIGIT_UV_W, DIGIT_UV_H,
            0, 1, 0, 0,          DIGIT_UV_H};
    private FloatBuffer digitVerts_;

    private final int[] quadIndicesData_ = {0, 1, 2, 2, 3, 0};
    private IntBuffer quadIndices_;

    private final String vertShader_ =
            "uniform mat4 uMVPMatrix;\n" +
                    "attribute vec4 aPosition;\n" +
                    "attribute vec2 aTextureCoord;\n" +
                    "uniform vec4 u_color;\n" +
                    "uniform vec2 u_uvOffset;\n" +
                    "varying vec2 vTextureCoord;\n" +
                    "void main() {\n" +
                    "  gl_Position = uMVPMatrix * aPosition;\n" +
                    "  vTextureCoord = aTextureCoord + u_uvOffset;\n" +
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
    private int whiteID_;
    private int digitID_;
    private int viewProjMatrixHandle_;
    private int posHandle_;
    private int texHandle_;
    private int vertColorHandle_;
    private int uvOffsetHandle_;

    private int width_;
    private int height_;

    private int[] digitBuffer_;

    private Context context_;
    private static String TAG = "QuadRenderer";
}
