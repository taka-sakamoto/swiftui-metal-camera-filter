//
//  Shaders.metal
//  MetalCameraFilter
//
//  Created by Takayuki Sakamoto on 2026/04/23.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct FilterUniforms {
    int filterType;
    float intensity;
};

struct VertexUniforms {
    float aspectScale;
};

vertex VertexOut vertexShader(
    uint vertexID [[vertex_id]],
    constant VertexUniforms& uniforms [[buffer(0)]]
    ) {
    float4 positions[4] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4( 1.0,  1.0, 0.0, 1.0)
    };
    
    float2 texCoords[4] = {
        
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
         
    };
    
    VertexOut out;
    out.position = positions[vertexID];
    
    out.position.x *= uniforms.aspectScale;
    //out.position.y /= uniforms.aspectScale;
    
    out.texCoord = texCoords[vertexID];
    
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> cameraTexture [[texture(0)]],
    constant FilterUniforms& uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(
        mag_filter::linear,
        min_filter::linear
    );
    
    float4 color = cameraTexture.sample(textureSampler, in.texCoord);
    
    // Normal
    if (uniforms.filterType == 0) {
        return color;
    }
    
    // Sepia
    if (uniforms.filterType == 1) {
        float3 sepiaColor;
        sepiaColor.r = dot(color.rbg, float3(0.393, 0.769, 0.189));
        sepiaColor.g = dot(color.rgb, float3(0.349, 0.686, 0.168));
        sepiaColor.b = dot(color.rgb, float3(0.272, 0.534, 0.131));
        
        color.rgb = mix(color.rgb, sepiaColor,uniforms.intensity);
        return color;
    }
    
    // Mono
    if (uniforms.filterType == 2) {
        float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
        float3 monoColor = float3(gray);
        
        color.rgb = mix(color.rgb, monoColor,uniforms.intensity);
        return color;
    }
    
    // Invert
    if (uniforms.filterType == 3) {
        float3 invertColor = 1.0 - color.rgb;
        
        color.rgb = mix(color.rgb, invertColor, uniforms.intensity);
        return color;
    }
    
    return color;
}
