import UIKit
import Metal
import QuartzCore
import JavaScriptCore

let MaxBuffers = 3
let ConstantBufferSize = 1024*1024

let vertexData:[Float] =
[
    -1.0, -1.0, 0.0, 1.0,
    -1.0,  1.0, 0.0, 1.0,
    1.0, -1.0, 0.0, 1.0,

    1.0, -1.0, 0.0, 1.0,
    -1.0,  1.0, 0.0, 1.0,
    1.0,  1.0, 0.0, 1.0,

    -0.0, 0.25, 0.0, 1.0,
    -0.25, -0.25, 0.0, 1.0,
    0.25, -0.25, 0.0, 1.0
]

let vertexColorData:[Float] =
[
    0.0, 0.0, 1.0, 1.0,
    0.0, 0.0, 1.0, 1.0,
    0.0, 0.0, 1.0, 1.0,

    0.0, 0.0, 1.0, 1.0,
    0.0, 0.0, 1.0, 1.0,
    0.0, 0.0, 1.0, 1.0,

    0.0, 0.0, 1.0, 1.0,
    0.0, 1.0, 0.0, 1.0,
    1.0, 0.0, 0.0, 1.0
]

class GameViewController: UIViewController
{
    // --------------------------------------------------------------------------------------------
    // Javascript guts

    var jsContext_: JSContext! = nil

    // --------------------------------------------------------------------------------------------
    // Render internals
    let device = { MTLCreateSystemDefaultDevice() }()
    let metalLayer = { CAMetalLayer() }()
    var commandQueue: MTLCommandQueue! = nil
    var timer: CADisplayLink! = nil
    var pipelineState: MTLRenderPipelineState! = nil
    var vertexBuffer: MTLBuffer! = nil
    var vertexColorBuffer: MTLBuffer! = nil
    let inflightSemaphore = dispatch_semaphore_create(MaxBuffers)
    var bufferIndex = 0

    // offsets used in animation
    var xOffset:[Float] = [ -1.0, 1.0, -1.0 ]
    var yOffset:[Float] = [ 1.0, 0.0, -1.0 ]
    var xDelta:[Float] = [ 0.002, -0.001, 0.003 ]
    var yDelta:[Float] = [ 0.001,  0.002, -0.001 ]

    // --------------------------------------------------------------------------------------------
    // Functions exposed to JS

    func nativeLog(str: String)
    {
        println(str)
    }

    // --------------------------------------------------------------------------------------------
    // JS functions used by native code

    func initializeJSC()
    {
        // Initialize JSC
        jsContext_ = JSContext()
        jsContext_.evaluateScript("var num = 5 + 5")

        // Create nativeLog function
        var that = self
        let nativeLogBinding: @objc_block String -> () = { input in
            that.nativeLog(input);
        }
        jsContext_.setObject(unsafeBitCast(nativeLogBinding, AnyObject.self), forKeyedSubscript:"nativeLog")

        // Load script.js into JSC
        if let path = NSBundle.mainBundle().pathForResource("script", ofType: "js") {
            println("found a script.js file: \(path)")
            let data = String(contentsOfFile: path, encoding: NSUTF8StringEncoding, error: nil)
            jsContext_.evaluateScript(data)
        }
    }

    func jsStartup(width: Double, _ height: Double)
    {
        if(jsContext_ != nil)
        {
            return
        }

        initializeJSC()

        println("about to call startup(\(width), \(height))")
        let startupFunction = jsContext_.objectForKeyedSubscript("startup")
        let result = startupFunction.callWithArguments([width, height])
    }

    func jsUpdate()
    {
        let updateFunction = jsContext_.objectForKeyedSubscript("update")
        let result = updateFunction.callWithArguments([16])
        // var updated: Bool = result.toBool()
        // println("updated: \(updated)")
    }

    func jsRender()
    {
        let renderFunction = jsContext_.objectForKeyedSubscript("render")
        let result = renderFunction.callWithArguments([])
        var doubles: NSArray = result.toArray()
        if(doubles.count > 0)
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

            let quadCount: Int = doubles.count >> 4
            var index: Int = 0

            for quadIndex in 0 ... quadCount - 1
            {
                let textureID: Int32 = doubles[index+0].intValue
                let srcX:    Double = doubles[index +  1].doubleValue
                let srcY:    Double = doubles[index +  2].doubleValue
                let srcW:    Double = doubles[index +  3].doubleValue
                let srcH:    Double = doubles[index +  4].doubleValue
                let dstX:    Double = doubles[index +  5].doubleValue
                let dstY:    Double = doubles[index +  6].doubleValue
                let dstW:    Double = doubles[index +  7].doubleValue
                let dstH:    Double = doubles[index +  8].doubleValue
                let rot:     Double = doubles[index +  9].doubleValue
                let anchorX: Double = doubles[index + 10].doubleValue
                let anchorY: Double = doubles[index + 11].doubleValue
                let red:     Double = doubles[index + 12].doubleValue
                let green:   Double = doubles[index + 13].doubleValue
                let blue:    Double = doubles[index + 14].doubleValue
                let alpha:   Double = doubles[index + 15].doubleValue

                // println("rendering with textureID \(textureID) [\(srcX), \(srcY), \(srcW), \(srcH)] -> [\(dstX), \(dstY), \(dstW), \(dstH)]")

                index += 16
            }

            // var d:Double = doubles[0].doubleValue
            // println("render: \(doubles.count) \(d)")
        }
    }

    // --------------------------------------------------------------------------------------------
    // GameViewController mumbojumbo

    override func viewDidLoad()
    {
        super.viewDidLoad()

        metalLayer.device = device
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true

        self.resize()

        view.layer.addSublayer(metalLayer)
        view.opaque = true
        view.backgroundColor = nil

        commandQueue = device.newCommandQueue()
        commandQueue.label = "main command queue"

        let defaultLibrary = device.newDefaultLibrary()
        let fragmentProgram = defaultLibrary?.newFunctionWithName("passThroughFragment")
        let vertexProgram = defaultLibrary?.newFunctionWithName("passThroughVertex")

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm

        var pipelineError : NSError?
        pipelineState = device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        if (pipelineState == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }

        // generate a large enough buffer to allow streaming vertices for 3 semaphore controlled frames
        vertexBuffer = device.newBufferWithLength(ConstantBufferSize, options: nil)
        vertexBuffer.label = "vertices"

        let vertexColorSize = vertexData.count * sizeofValue(vertexColorData[0])
        vertexColorBuffer = device.newBufferWithBytes(vertexColorData, length: vertexColorSize, options: nil)
        vertexColorBuffer.label = "colors"

        timer = CADisplayLink(target: self, selector: Selector("renderLoop"))
        timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }

    override func viewDidLayoutSubviews() {
        self.resize()

        var w: Double = Double(metalLayer.drawableSize.width)
        var h: Double = Double(metalLayer.drawableSize.height)
        println("size: \(w), \(h)")
        jsStartup(w, h)

        var modelTransformationMatrix = Matrix4()
    }

    func resize() {
        if (view.window == nil) {
            return
        }

        let window = view.window!
        let nativeScale = window.screen.nativeScale
        view.contentScaleFactor = nativeScale
        metalLayer.frame = view.layer.frame

        var drawableSize = view.bounds.size
        drawableSize.width = drawableSize.width * CGFloat(view.contentScaleFactor)
        drawableSize.height = drawableSize.height * CGFloat(view.contentScaleFactor)

        metalLayer.drawableSize = drawableSize
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    deinit {
        timer.invalidate()
    }

    func renderLoop() {
        autoreleasepool {
            self.render()
        }
    }

    func render() {

        // use semaphore to encode 3 frames ahead
        dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)

        // self.update()

        jsUpdate()
        jsRender()

        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"

        let drawable = metalLayer.nextDrawable()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store

        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)!
        renderEncoder.label = "render encoder"

        renderEncoder.pushDebugGroup("draw morphing triangle")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 256*bufferIndex, atIndex: 0)
        renderEncoder.setVertexBuffer(vertexColorBuffer, offset:0 , atIndex: 1)
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 9, instanceCount: 1)

        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()

        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.inflightSemaphore)
            }
            return
        }

        // bufferIndex matches the current semaphore controled frame index to ensure writing occurs at the correct region in the vertex buffer
        bufferIndex = (bufferIndex + 1) % MaxBuffers

        commandBuffer.presentDrawable(drawable)
        commandBuffer.commit()
    }

    func update() {

        // vData is pointer to the MTLBuffer's Float data contents
        let pData = vertexBuffer.contents()
        let vData = UnsafeMutablePointer<Float>(pData + 256*bufferIndex)

        // reset the vertices to default before adding animated offsets
        vData.initializeFrom(vertexData)

        // Animate triangle offsets
        let lastTriVertex = 24
        let vertexSize = 4
        for j in 0..<MaxBuffers {
            // update the animation offsets
            xOffset[j] += xDelta[j]

            if(xOffset[j] >= 1.0 || xOffset[j] <= -1.0) {
                xDelta[j] = -xDelta[j]
                xOffset[j] += xDelta[j]
            }

            yOffset[j] += yDelta[j]

            if(yOffset[j] >= 1.0 || yOffset[j] <= -1.0) {
                yDelta[j] = -yDelta[j]
                yOffset[j] += yDelta[j]
            }

            // Update last triangle position with updated animated offsets
            let pos = lastTriVertex + j*vertexSize
            vData[pos] = xOffset[j]
            vData[pos+1] = yOffset[j]
        }
    }
}