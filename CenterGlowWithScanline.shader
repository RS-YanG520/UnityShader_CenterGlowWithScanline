Shader "Custom/CenterGlowWithScanline"
{
    Properties
    {
        _MainColor ("Main Color", Color) = (0.2, 0.8, 1.0, 1.0)
        _CenterAlpha ("Center Opacity", Range(0, 1)) = 0.8
        _EdgeAlpha ("Edge Opacity", Range(0, 1)) = 0.0
        _EdgeWidth ("Edge Fade Width", Range(0.01, 0.5)) = 0.2
        _DistanceFade ("End Distance Fade", Range(0.01, 1.0)) = 0.3
        _AspectRatio ("Aspect Ratio", Float) = 1.0

        // --- 新增动态条纹参数 ---
        _ScanlineColor ("Scanline Color", Color) = (1, 1, 1, 1) // 条纹颜色（通常是白色或亮青色）
        _ScanlineSpeed ("Scanline Speed", Float) = 1.0          // 扫描速度（负值则从右往左）
        _ScanlineDensity ("Scanline Density", Float) = 5.0      // 条纹密度（一共有几个条纹）
        _ScanlineWidth ("Scanline Width", Range(0.01, 1.0)) = 0.2 // 条纹宽度（占波长的比例）
        _ScanlineIntensity ("Scanline Intensity", Range(0, 2)) = 1.0 // 条纹亮度/不透明度倍数
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        LOD 100

        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            fixed4 _MainColor;
            float _CenterAlpha;
            float _EdgeAlpha;
            float _EdgeWidth;
            float _DistanceFade;
            float _AspectRatio;

            fixed4 _ScanlineColor;
            float _ScanlineSpeed;
            float _ScanlineDensity;
            float _ScanlineWidth;
            float _ScanlineIntensity;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 1. 计算基础透明度 (中间实，两边虚)
                float distFromCenter = abs(i.uv.x - 0.5) * _AspectRatio;
                float horizontalAlpha = 1.0 - smoothstep(0.0, _EdgeWidth, distFromCenter);
                float verticalFade = 1.0 - smoothstep(1.0 - _DistanceFade, 1.0, i.uv.y);
                float baseAlpha = lerp(_EdgeAlpha, _CenterAlpha, horizontalAlpha) * verticalFade;

                // 2. 计算动态条纹 (Scanline)
                // 核心公式：sin( (UV + Time * Speed) * Density )
                // 这里我们假设 V 轴是长度方向，条纹沿着 V 轴移动
                float scanPhase = (i.uv.y + _Time.y * _ScanlineSpeed) * _ScanlineDensity;

                // 使用 sin 生成波浪，并将其映射到 0~1 的区间
                float scanWave = sin(scanPhase);

                // 将波形转换为条纹遮罩：使用 smoothstep 根据 _ScanlineWidth 切割波形
                // 当 scanWave 大于 (1 - _ScanlineWidth) 时，显示条纹
                float scanMask = smoothstep(1.0 - _ScanlineWidth, 1.0, scanWave);

                // 3. 混合颜色和透明度
                fixed4 finalColor = _MainColor;

                // 条纹区域的颜色叠加（让条纹更亮，偏白）
                finalColor.rgb = lerp(finalColor.rgb, _ScanlineColor.rgb, scanMask * _ScanlineIntensity);

                // 条纹区域的透明度增强（让条纹在光带中更实一点）
                finalColor.a = baseAlpha + (scanMask * _ScanlineIntensity * (1.0 - baseAlpha));

                // 限制 Alpha 不超过 1
                finalColor.a = saturate(finalColor.a);

                return finalColor;
            }
            ENDCG
        }
    }
}
