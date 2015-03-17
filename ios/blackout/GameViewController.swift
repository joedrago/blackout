import UIKit
import Metal
import QuartzCore
import JavaScriptCore

let MaxBuffers = 1

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
    var viewMatrix_: Matrix4! = nil
    var lastTick_: NSDate?

    var textures_: [MetalTexture]! = nil
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
        var dt = lastTick_!.timeIntervalSinceNow * -1000.0
        lastTick_ = NSDate()

        let updateFunction = jsContext_.objectForKeyedSubscript("update")
        let result = updateFunction.callWithArguments([dt])
        // var updated: Bool = result.toBool()
        // println("updated: \(updated)")
    }

    func jsRender(renderEncoder: MTLRenderCommandEncoder)
    {
        if lastTick_ == nil
        {
            return
        }

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
                let textureID: Int = Int(doubles[index+0].intValue)
                let srcX:    Float  = Float(doubles[index +  1].doubleValue)
                let srcY:    Float  = Float(doubles[index +  2].doubleValue)
                let srcW:    Float  = Float(doubles[index +  3].doubleValue)
                let srcH:    Float  = Float(doubles[index +  4].doubleValue)
                let dstX:    Float  = Float(doubles[index +  5].doubleValue)
                let dstY:    Float  = Float(doubles[index +  6].doubleValue)
                let dstW:    Float  = Float(doubles[index +  7].doubleValue)
                let dstH:    Float  = Float(doubles[index +  8].doubleValue)
                let rot:     Float  = Float(doubles[index +  9].doubleValue)
                let anchorX: Float  = Float(doubles[index + 10].doubleValue)
                let anchorY: Float  = Float(doubles[index + 11].doubleValue)
                let red:     Float  = Float(doubles[index + 12].doubleValue)
                let green:   Float  = Float(doubles[index + 13].doubleValue)
                let blue:    Float  = Float(doubles[index + 14].doubleValue)
                let alpha:   Float  = Float(doubles[index + 15].doubleValue)

                let texture = textures_[textureID]
                renderEncoder.setFragmentTexture(texture.texture, atIndex: 0)
                if let samplerState = samplerState_ {
                    renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
                }

                let tw: Float = Float(texture.width);
                let th: Float = Float(texture.height);
                let uvL = srcX / tw;
                let uvT = srcY / th;
                let uvR = (srcX + srcW) / tw;
                let uvB = (srcY + srcH) / th;

                let anchorOffsetX: Float = anchorX * dstW * -1.0;
                let anchorOffsetY: Float = anchorY * dstH * -1.0;

                var vertexData = [
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

                var modelMatrix = viewMatrix_.copy()
                modelMatrix.translate(dstX, y: dstY, z: 0)
                modelMatrix.rotateAroundX(0, y: 0, z: rot)
                modelMatrix.translate(anchorOffsetX, y: anchorOffsetY, z: 0)
                modelMatrix.scale(dstW, y: dstH, z: 1)

                var uniformBuffer = device_.newBufferWithLength(sizeof(Float) * ((Matrix4.numberOfElements() * 2) + 4), options: nil)
                var bufferPointer = uniformBuffer?.contents()
                memcpy(bufferPointer!, modelMatrix.raw(), UInt(sizeof(Float)*Matrix4.numberOfElements()))
                let floats: [Float] = [red, green, blue, alpha]
                memcpy(bufferPointer! + sizeof(Float)*Matrix4.numberOfElements(), floats, UInt(sizeof(Float)*4)) // uniform color
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
                renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6, instanceCount: 2)

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
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.Add;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.Add;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.SourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.SourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.OneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactor.OneMinusSourceAlpha;

        var pipelineError : NSError?
        pipelineState_ = device_.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor, error: &pipelineError)
        if (pipelineState_ == nil) {
            println("Failed to create pipeline state, error \(pipelineError)")
        }

        textures_ = []
        textures_.append(MetalTexture(resourceName: "cards", ext: "png", mipmapped: true))
        textures_.append(MetalTexture(resourceName: "darkforest", ext: "png", mipmapped: true))
        textures_.append(MetalTexture(resourceName: "chars", ext: "png", mipmapped: true))
        textures_.append(MetalTexture(resourceName: "howto1", ext: "png", mipmapped: true))
        textures_.append(MetalTexture(resourceName: "howto2", ext: "png", mipmapped: true))
        textures_.append(MetalTexture(resourceName: "howto3", ext: "png", mipmapped: true))
        for texture in textures_
        {
            texture.loadTexture(device: device_, commandQ: commandQueue_, flip: true)
        }

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

        viewMatrix_ = Matrix4()
        let halfX: Float = 2048.0 / 2.0
        let halfY: Float = 1536.0 / 2.0
        viewMatrix_.scale(1.0 / halfX, y: -1.0 / halfY, z: 1)
        viewMatrix_.translate(-1.0 * halfX, y: -1.0 * halfY, z: 0)

        lastTick_ = NSDate()
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

        jsRender(renderEncoder)

        // renderEncoder.setFragmentTexture(textures_[1].texture, atIndex: 0)
        // if let samplerState = samplerState_ {
        //     renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
        // }

        // let uvL: Float = 0;
        // let uvT: Float = 0;
        // let uvR: Float = 1;
        // let uvB: Float = 1;

        // var vertexData = Array<Float>()
        // vertexData += [
        //     0, 0, 1, uvL, uvT,
        //     1, 0, 1, uvR, uvT,
        //     1, 1, 1, uvR, uvB,

        //     1, 1, 1, uvR, uvB,
        //     0, 1, 1, uvL, uvB,
        //     0, 0, 1, uvL, uvT
        // ]

        // let dataSize = vertexData.count * sizeofValue(vertexData[0])
        // var vertexBuffer = device_.newBufferWithBytes(vertexData, length: dataSize, options: nil)
        // renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, atIndex: 0)

        // var modelMatrix = viewMatrix_.copy()
        // modelMatrix.translate(100, y: 100, z: 0)
        // modelMatrix.rotateAroundX(0, y: 0, z: 3.14 / 3.0)
        // modelMatrix.translate(-100, y: -100, z: 0)
        // modelMatrix.scale(200, y: 200, z: 1)

        // var uniformBuffer = device_.newBufferWithLength(sizeof(Float) * ((Matrix4.numberOfElements() * 2) + 4), options: nil)
        // var bufferPointer = uniformBuffer?.contents()
        // memcpy(bufferPointer!, modelMatrix.raw(), UInt(sizeof(Float)*Matrix4.numberOfElements()))
        // let floats: [Float] = [1,1,1,1]
        // memcpy(bufferPointer! + sizeof(Float)*Matrix4.numberOfElements(), floats, UInt(sizeof(Float)*4)) // uniform color
        // renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        // renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 6, instanceCount: 2)

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
