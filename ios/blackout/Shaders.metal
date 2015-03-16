//
//  Shaders.metal
//  MetalSwift
//
//  Created by Seth Sowerby on 8/14/14.
//  Copyright (c) 2014 Seth Sowerby. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct PackedVertex
{
    packed_float3 pos;
    packed_float2 tex;
};

struct PosTextureVertex
{
    float4 pos [[position]];
    float2 tex [[user(texturecoord)]];
};

struct Uniforms
{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4 color;
};

vertex PosTextureVertex posTextureUColorVertex(const device PackedVertex* vertices [[ buffer(0) ]],
                                               const device Uniforms&     uniforms [[ buffer(1) ]],
                                               uint                       vid      [[ vertex_id ]])
{
    PackedVertex inVertex = vertices[vid];

    PosTextureVertex outVertex;
    //outVertex.pos = uniforms.projectionMatrix * uniforms.modelMatrix * float4(inVertex.pos, 1);
    outVertex.pos = uniforms.modelMatrix * float4(inVertex.pos, 1);
    //outVertex.pos = float4(inVertex.pos, 1);
    outVertex.tex = float2(inVertex.tex);
    return outVertex;
};

fragment half4 posTextureUColorFragment(PosTextureVertex vert    [[ stage_in ]],
                                        texture2d<half>  texture [[ texture(0) ]],
                                        sampler          samp    [[ sampler(0) ]])
{
    half4 color = texture.sample(samp, vert.tex);
    return color;
};