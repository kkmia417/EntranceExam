Shader "kkmia/AcrylicPanelUnlit"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _EdgeColor ("Edge Color", Color) = (1,1,1,1)
        _Opacity ("Opacity", Range(0,1)) = 0.16

        _FresnelPower ("Fresnel Power", Range(0.2,16)) = 5
        _EdgeIntensity ("Edge Intensity", Range(0,2)) = 0.6

        _NoiseScale ("Noise Scale", Range(1,200)) = 80
        _NoiseStrength ("Noise Strength", Range(0,0.2)) = 0.05
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        Pass
        {
            Name "ForwardUnlit"
            Tags { "LightMode"="UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _EdgeColor;
                float _Opacity;
                float _FresnelPower;
                float _EdgeIntensity;
                float _NoiseScale;
                float _NoiseStrength;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS    : TEXCOORD0;
                float3 viewDirWS   : TEXCOORD1;
                float2 uv          : TEXCOORD2;
            };

            // Small, cheap hash + value-noise (good enough for acrylic "micro texture")
            float hash21(float2 p)
            {
                // deterministic hash in [0,1)
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 34.345);
                return frac(p.x * p.y);
            }

            float valueNoise(float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);

                float a = hash21(i);
                float b = hash21(i + float2(1,0));
                float c = hash21(i + float2(0,1));
                float d = hash21(i + float2(1,1));

                // smoothstep curve
                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs nrmInputs = GetVertexNormalInputs(IN.normalOS);

                OUT.positionHCS = posInputs.positionCS;
                OUT.normalWS = normalize(nrmInputs.normalWS);

                float3 posWS = posInputs.positionWS;
                OUT.viewDirWS = normalize(GetWorldSpaceViewDir(posWS));
                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float3 N = normalize(IN.normalWS);
                float3 V = normalize(IN.viewDirWS);

                // Fresnel (edge glow)
                float fresnel = pow(saturate(1.0 - dot(N, V)), _FresnelPower);
                float edge = fresnel * _EdgeIntensity;

                // Micro noise tint (very subtle)
                float n = valueNoise(IN.uv * _NoiseScale);
                float noise = (n - 0.5) * 2.0 * _NoiseStrength; // [-strength, +strength]

                float3 baseCol = _BaseColor.rgb;
                float3 edgeCol = _EdgeColor.rgb * edge;

                float3 col = baseCol + edgeCol + noise;

                // Keep it clean (avoid negative or too bright)
                col = saturate(col);

                return half4(col, saturate(_Opacity));
            }
            ENDHLSL
        }
    }
    FallBack Off
}