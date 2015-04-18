//
//  MetalTexture.swift
//  MetalKernelsPG
//
//  Created by Andrew K. on 10/20/14.
//  Copyright (c) 2014 Andrew K. All rights reserved.
//

import UIKit

class MetalTexture: NSObject {

  var texture: MTLTexture!
  var target: MTLTextureType!
  var width: Int
  var height: Int
  var depth: UInt!
  var format: MTLPixelFormat!
  var hasAlpha: Bool!
  var path: String!
  var ismipmapped: Bool!
  let bytesPerPixel:Int = 4
  let bitsPerComponent:Int = 8

  //MARK: - Creation
  init(resourceName: String,ext: String, mipmapped:Bool){

    path = NSBundle.mainBundle().pathForResource(resourceName, ofType: ext)
    width    = 0
    height   = 0
    depth    = 1
    format   = MTLPixelFormat.RGBA8Unorm
    target   = MTLTextureType.Type2D
    texture  = nil
    ismipmapped = mipmapped

    super.init()
  }

  func loadTexture(#device: MTLDevice, commandQ: MTLCommandQueue, flip: Bool){

    var image = UIImage(contentsOfFile: path)?.CGImage
    var colorSpace = CGColorSpaceCreateDeviceRGB()

    width = CGImageGetWidth(image)
    height = CGImageGetHeight(image)

    var rowBytes = width * bytesPerPixel

    var context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, rowBytes, colorSpace, CGBitmapInfo(CGImageAlphaInfo.PremultipliedLast.rawValue))
    
    var bounds = CGRect(x: 0, y: 0, width: Int(width), height: Int(height))
    CGContextClearRect(context, bounds)

    if flip == false{
      CGContextTranslateCTM(context, 0, CGFloat(self.height))
      CGContextScaleCTM(context, 1.0, -1.0)
    }

    CGContextDrawImage(context, bounds, image)

    var texDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(width), height: Int(height), mipmapped: ismipmapped)
    target = texDescriptor.textureType
    texture = device.newTextureWithDescriptor(texDescriptor)

    var pixelsData = CGBitmapContextGetData(context)
    var region = MTLRegionMake2D(0, 0, Int(width), Int(height))
    texture.replaceRegion(region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(rowBytes))

    if (ismipmapped == true){
      generateMipMapLayersUsingSystemFunc(texture, device: device, commandQ: commandQ, block: { (buffer) -> Void in
        // println("mips generated")
      })
    }

    // println("mipCount:\(texture.mipmapLevelCount)")
  }



  class func textureCopy(#source:MTLTexture,device: MTLDevice, mipmapped: Bool) -> MTLTexture {
    var texDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.BGRA8Unorm, width: Int(source.width), height: Int(source.height), mipmapped: mipmapped)
    var copyTexture = device.newTextureWithDescriptor(texDescriptor)


    var region = MTLRegionMake2D(0, 0, Int(source.width), Int(source.height))
    var pixelsData = malloc(Int(source.width * source.height * 4))
    source.getBytes(pixelsData, bytesPerRow: Int(source.width) * 4, fromRegion: region, mipmapLevel: 0)
    copyTexture.replaceRegion(region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(source.width) * 4)
    return copyTexture
  }

  class func copyMipLayer(#source:MTLTexture, destination:MTLTexture, mipLvl: Int){
    var q = Int(powf(2, Float(mipLvl)))
    var mipmappedWidth = max(Int(source.width)/q,1)
    var mipmappedHeight = max(Int(source.height)/q,1)

    var region = MTLRegionMake2D(0, 0, mipmappedWidth, mipmappedHeight)
    var pixelsData = malloc(Int(mipmappedHeight * mipmappedWidth * 4))
    source.getBytes(pixelsData, bytesPerRow: mipmappedWidth * 4, fromRegion: region, mipmapLevel: mipLvl)
    destination.replaceRegion(region, mipmapLevel: mipLvl, withBytes: pixelsData, bytesPerRow: mipmappedWidth * 4)
    free(pixelsData)
  }

  //MARK: - Generating UIImage from texture mip layers
  func image(#mipLevel: Int) -> UIImage{

    var p = bytesForMipLevel(mipLevel: mipLevel)
    var q = Int(powf(2, Float(mipLevel)))
    var mipmappedWidth = max(width / q,1)
    var mipmappedHeight = max(height / q,1)
    var rowBytes = mipmappedWidth * 4

    var colorSpace = CGColorSpaceCreateDeviceRGB()

    var context = CGBitmapContextCreate(p, mipmappedWidth, mipmappedHeight, 8, rowBytes, colorSpace, CGBitmapInfo(CGImageAlphaInfo.PremultipliedLast.rawValue))
    var imgRef = CGBitmapContextCreateImage(context)
    var image = UIImage(CGImage: imgRef)
    return image!
  }

  func image() -> UIImage{
    return image(mipLevel: 0)
  }

  //MARK: - Getting raw bytes from texture mip layers
  func bytesForMipLevel(#mipLevel: Int) -> UnsafeMutablePointer<Void>{
    var q = Int(powf(2, Float(mipLevel)))
    var mipmappedWidth = max(Int(width) / q,1)
    var mipmappedHeight = max(Int(height) / q,1)

    var rowBytes = Int(mipmappedWidth * 4)

    var region = MTLRegionMake2D(0, 0, mipmappedWidth, mipmappedHeight)
    var pointer = malloc(Int(rowBytes * mipmappedHeight))
    texture.getBytes(pointer, bytesPerRow: rowBytes, fromRegion: region, mipmapLevel: mipLevel)
    return pointer
  }

  func bytes() -> UnsafeMutablePointer<Void>{
    return bytesForMipLevel(mipLevel: 0)
  }

  func generateMipMapLayersUsingSystemFunc(texture: MTLTexture, device: MTLDevice, commandQ: MTLCommandQueue,block: MTLCommandBufferHandler){

    var commandBuffer = commandQ.commandBuffer()

    commandBuffer.addCompletedHandler(block)

    var blitCommandEncoder = commandBuffer.blitCommandEncoder()

    blitCommandEncoder.generateMipmapsForTexture(texture)
    blitCommandEncoder.endEncoding()

    commandBuffer.commit()
  }

}
