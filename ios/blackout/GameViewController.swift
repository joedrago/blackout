import UIKit
import Metal
import QuartzCore
import JavaScriptCore

let MaxBuffers = 3

class GameViewController: UIViewController
{
    // --------------------------------------------------------------------------------------------
    // Javascript guts

    var jsContext_: JSContext! = nil

    // --------------------------------------------------------------------------------------------
    // Render internals
    let device_ = { MTLCreateSystemDefaultDevice() }()
    let metalLayer = { CAMetalLayer() }()
    var commandQueue_: MTLCommandQueue! = nil
    var timer_: CADisplayLink! = nil
    var pipelineState_: MTLRenderPipelineState! = nil
    let frameSignal_ = dispatch_semaphore_create(MaxBuffers)
    var bufferIndex_ = 0

    var texture_: MetalTexture! = nil
    lazy var samplerState_: MTLSamplerState? = GameViewController.defaultSampler(self.device_)

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
        }
    }

    // --------------------------------------------------------------------------------------------
    // GameViewController mumbojumbo

    override func viewDidLoad()
    {
        super.viewDidLoad()

        metalLayer.device = device_
        metalLayer.pixelFormat = .BGRA8Unorm
        metalLayer.framebufferOnly = true

        self.resize()

        view.layer.addSublayer(metalLayer)
        view.opaque = true
        view.backgroundColor = nil

        commandQueue_ = device_.newCommandQueue()
        commandQueue_.label = "main command queue"

        let defaultLibrary = device_.newDefaultLibrary()
        let fragmentProgram = defaultLibrary?.newFunctionWithName("posTextureUColorFragment")
        let vertexProgram = defaultLibrary?.newFunctionWithName("posTextureUColorVertex")

        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm

        var pipelineError : NSError?
        pipelineState_ = device_.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        if (pipelineState_ == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }

        texture_ = MetalTexture(resourceName: "cards", ext: "png", mipmapped: true)
        texture_.loadTexture(device: device_, commandQ: commandQueue_, flip: false)

        // // generate a large enough buffer to allow streaming vertices for 3 semaphore controlled frames
        // vertexBuffer = device_.newBufferWithLength(ConstantBufferSize, options: nil)
        // vertexBuffer.label = "vertices"

        // let vertexColorSize = vertexData.count * sizeofValue(vertexColorData[0])
        // vertexColorBuffer = device_.newBufferWithBytes(vertexColorData, length: vertexColorSize, options: nil)
        // vertexColorBuffer.label = "colors"

        timer_ = CADisplayLink(target: self, selector: Selector("renderLoop"))
        timer_.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
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
        timer_.invalidate()
    }

    func renderLoop() {
        autoreleasepool {
            self.render()
        }
    }

    func render() {

        // use semaphore to encode 3 frames ahead
        dispatch_semaphore_wait(frameSignal_, DISPATCH_TIME_FOREVER)

        jsUpdate()
        jsRender()

        let commandBuffer = commandQueue_.commandBuffer()
        commandBuffer.label = "Frame command buffer"

        let drawable = metalLayer.nextDrawable()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = .Store

        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)!
        renderEncoder.label = "render encoder"
        renderEncoder.setRenderPipelineState(pipelineState_)
        renderEncoder.setCullMode(MTLCullMode.None)


        // everything between these markers needs to happen multiple times
        // ---

        renderEncoder.setFragmentTexture(texture_.texture, atIndex: 0)
        if let samplerState = samplerState_ {
            renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
        }

        let uvL: Float = 0;
        let uvT: Float = 0;
        let uvR: Float = 1;
        let uvB: Float = 1;

        var vertexData = Array<Float>()
        vertexData += [
            0, 0, 1, uvL, uvT,
            1, 0, 1, uvR, uvT,
            1, 1, 1, uvR, uvB,

            1, 1, 1, uvR, uvB,
            0, 1, 1, uvL, uvB,
            0, 0, 1, uvL, uvT
        ]

        let dataSize = vertexData.count * sizeofValue(vertexData[0])
        var vertexBuffer = device_.newBufferWithBytes(vertexData, length: dataSize, options: nil)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)

        // var projectionMatrix = Matrix4.makeOrthoLeft(0, right: 2048, bottom: 1536, top: 0, nearZ: 0.0, farZ: 20.0)
        var projectionMatrix = Matrix4.makeOrthoLeft(-100, right: 100, bottom: 100, top: -100, nearZ: 0.01, farZ: 20.0)

        var modelMatrix = Matrix4()
        modelMatrix.translate(-1, y: -1, z: 0)
        modelMatrix.scale(2, y: 2, z: 1)

        var uniformBuffer = device_.newBufferWithLength(sizeof(Float) * ((Matrix4.numberOfElements() * 2) + 4), options: nil)
        var bufferPointer = uniformBuffer?.contents()
        memcpy(bufferPointer!, modelMatrix.raw(), UInt(sizeof(Float)*Matrix4.numberOfElements()))
        memcpy(bufferPointer! + sizeof(Float)*Matrix4.numberOfElements(), projectionMatrix.raw(), UInt(sizeof(Float)*Matrix4.numberOfElements()))
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6, instanceCount: 2)

        // ---



        renderEncoder.endEncoding()

        // use completion handler to signal the semaphore when this frame is completed allowing the encoding of the next frame to proceed
        // use capture list to avoid any retain cycles if the command buffer gets retained anywhere besides this stack frame
        commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                dispatch_semaphore_signal(strongSelf.frameSignal_)
            }
            return
        }

        // bufferIndex_ matches the current semaphore controled frame index to ensure writing occurs at the correct region in the vertex buffer
        bufferIndex_ = (bufferIndex_ + 1) % MaxBuffers

        commandBuffer.presentDrawable(drawable)
        commandBuffer.commit()
    }

    class func defaultSampler(device: MTLDevice) -> MTLSamplerState
    {
        var pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();

        if let sampler = pSamplerDescriptor
        {
            sampler.minFilter             = MTLSamplerMinMagFilter.Nearest
            sampler.magFilter             = MTLSamplerMinMagFilter.Nearest
            sampler.mipFilter             = MTLSamplerMipFilter.Nearest
            sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = MTLSamplerAddressMode.ClampToEdge
            sampler.tAddressMode          = MTLSamplerAddressMode.ClampToEdge
            sampler.rAddressMode          = MTLSamplerAddressMode.ClampToEdge
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0
            sampler.lodMaxClamp           = FLT_MAX
        }
        else
        {
            println(">> ERROR: Failed creating a sampler descriptor!")
        }
        return device.newSamplerStateWithDescriptor(pSamplerDescriptor!)
    }
}
