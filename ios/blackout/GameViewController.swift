//
//  GameViewController.swift
//  blackout
//
//  Created by Joe Drago on 3/15/15.
//  Copyright (c) 2015 Joe Drago. All rights reserved.
//

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

class GameViewController: UIViewController {
    
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
    
    var jsContext: JSContext! = nil
    
    func nativeLog(str: String)
    {
        NSLog(str)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        jsContext = JSContext()
        jsContext.evaluateScript("var num = 5 + 5")

        var that = self
        let nativeLogBinding: @objc_block String -> () = { input in
            that.nativeLog(input);
        }
        jsContext.setObject(unsafeBitCast(nativeLogBinding, AnyObject.self), forKeyedSubscript:"nativeLog")

        if let path = NSBundle.mainBundle().pathForResource("script", ofType: "js") {
            println("found a script.js file: \(path)")
            let data = String(contentsOfFile: path, encoding: NSUTF8StringEncoding, error: nil)
            jsContext.evaluateScript(data)
        }
        let renderFunction = jsContext.objectForKeyedSubscript("render")
        let result = renderFunction.callWithArguments([])
        var doubles: NSArray = result.toArray()
        var d:Double = doubles[0].doubleValue
        println("Render Called: \(doubles.count) \(d)")
        
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
        
        self.update()
        
        let commandBuffer = commandQueue.commandBuffer()
        commandBuffer.label = "Frame command buffer"
        
        let drawable = metalLayer.nextDrawable()
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .Clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)
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