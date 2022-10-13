//
//  FrameView.metal
//  LightKitDev
//
//  Created by sukidhar on 22/08/22.
//

#include <metal_stdlib>
#include "Types.h"
using namespace metal;

typedef struct {
    float4 position [[ position ]];
    float2 texture_coordinates;
} FragmentCoordinate;

vertex FragmentCoordinate graphics_vertex(const device packed_float2* vertex_data [[ buffer(0) ]],
                                          const device packed_float2* texture_data [[ buffer(1) ]],
                                          uint vid [[ vertex_id ]]) {
    FragmentCoordinate coordinate;
    coordinate.position = float4(vertex_data[vid], 0.0, 1.0);
    coordinate.texture_coordinates = texture_data[vid];
    return coordinate;
}

fragment float4 graphics_fragment(FragmentCoordinate coordinate [[ stage_in ]],
                                  texture2d<float, access::sample> texture [[ texture(0) ]]) {
    constexpr sampler s;
    return texture.sample(s, coordinate.texture_coordinates);
}

typedef struct {
    float2 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
} ImageVertex;

vertex FragmentCoordinate graphics_vertex_ycbcr(ImageVertex in [[stage_in]]) {
    FragmentCoordinate coordinate;
    coordinate.position = float4(in.position, 0.0, 1.0);
    coordinate.texture_coordinates = in.texCoord;
    return coordinate;
}

fragment float4 graphics_fragment_ycbcr(FragmentCoordinate in [[stage_in]],
                                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
                                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {
    
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    const float4x4 ycbcrToRGBTransform = float4x4(
        float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
        float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
        float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
        float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate
    float4 ycbcr = float4(capturedImageTextureY.sample(colorSampler, in.texture_coordinates).r,
                          capturedImageTextureCbCr.sample(colorSampler, in.texture_coordinates).rg, 1.0);
    
    // Return converted RGB color
    return ycbcrToRGBTransform * ycbcr;
}
