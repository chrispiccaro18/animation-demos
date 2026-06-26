#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define MY_HIGHP_OR_MEDIUMP highp
#else
    #define MY_HIGHP_OR_MEDIUMP mediump
#endif

// 2D Gaussian blur — single pass, reads one canvas and writes another.
// Avoids the texture-barrier hazard of the separable H-then-V approach.

extern MY_HIGHP_OR_MEDIUMP vec2 canvasSize;
extern MY_HIGHP_OR_MEDIUMP float radius;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 screenCoord) {
    MY_HIGHP_OR_MEDIUMP vec2 p = radius / canvasSize;

    // 7-tap 1D Gaussian weights applied as outer product (w[x] * w[y]).
    // 1D weights: 0.0625, 0.1250, 0.2000, 0.2250, 0.2000, 0.1250, 0.0625 (sum = 1.0)
    // 2D sum = 1.0^2 = 1.0
    vec4 s = vec4(0.0);

    s += Texel(tex, texcoord + p * vec2(-3.0, -3.0)) * 0.003906;
    s += Texel(tex, texcoord + p * vec2(-2.0, -3.0)) * 0.007813;
    s += Texel(tex, texcoord + p * vec2(-1.0, -3.0)) * 0.012500;
    s += Texel(tex, texcoord + p * vec2( 0.0, -3.0)) * 0.014063;
    s += Texel(tex, texcoord + p * vec2( 1.0, -3.0)) * 0.012500;
    s += Texel(tex, texcoord + p * vec2( 2.0, -3.0)) * 0.007813;
    s += Texel(tex, texcoord + p * vec2( 3.0, -3.0)) * 0.003906;

    s += Texel(tex, texcoord + p * vec2(-3.0, -2.0)) * 0.007813;
    s += Texel(tex, texcoord + p * vec2(-2.0, -2.0)) * 0.015625;
    s += Texel(tex, texcoord + p * vec2(-1.0, -2.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2( 0.0, -2.0)) * 0.028125;
    s += Texel(tex, texcoord + p * vec2( 1.0, -2.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2( 2.0, -2.0)) * 0.015625;
    s += Texel(tex, texcoord + p * vec2( 3.0, -2.0)) * 0.007813;

    s += Texel(tex, texcoord + p * vec2(-3.0, -1.0)) * 0.012500;
    s += Texel(tex, texcoord + p * vec2(-2.0, -1.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2(-1.0, -1.0)) * 0.040000;
    s += Texel(tex, texcoord + p * vec2( 0.0, -1.0)) * 0.045000;
    s += Texel(tex, texcoord + p * vec2( 1.0, -1.0)) * 0.040000;
    s += Texel(tex, texcoord + p * vec2( 2.0, -1.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2( 3.0, -1.0)) * 0.012500;

    s += Texel(tex, texcoord + p * vec2(-3.0,  0.0)) * 0.014063;
    s += Texel(tex, texcoord + p * vec2(-2.0,  0.0)) * 0.028125;
    s += Texel(tex, texcoord + p * vec2(-1.0,  0.0)) * 0.045000;
    s += Texel(tex, texcoord + p * vec2( 0.0,  0.0)) * 0.050625;
    s += Texel(tex, texcoord + p * vec2( 1.0,  0.0)) * 0.045000;
    s += Texel(tex, texcoord + p * vec2( 2.0,  0.0)) * 0.028125;
    s += Texel(tex, texcoord + p * vec2( 3.0,  0.0)) * 0.014063;

    s += Texel(tex, texcoord + p * vec2(-3.0,  1.0)) * 0.012500;
    s += Texel(tex, texcoord + p * vec2(-2.0,  1.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2(-1.0,  1.0)) * 0.040000;
    s += Texel(tex, texcoord + p * vec2( 0.0,  1.0)) * 0.045000;
    s += Texel(tex, texcoord + p * vec2( 1.0,  1.0)) * 0.040000;
    s += Texel(tex, texcoord + p * vec2( 2.0,  1.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2( 3.0,  1.0)) * 0.012500;

    s += Texel(tex, texcoord + p * vec2(-3.0,  2.0)) * 0.007813;
    s += Texel(tex, texcoord + p * vec2(-2.0,  2.0)) * 0.015625;
    s += Texel(tex, texcoord + p * vec2(-1.0,  2.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2( 0.0,  2.0)) * 0.028125;
    s += Texel(tex, texcoord + p * vec2( 1.0,  2.0)) * 0.025000;
    s += Texel(tex, texcoord + p * vec2( 2.0,  2.0)) * 0.015625;
    s += Texel(tex, texcoord + p * vec2( 3.0,  2.0)) * 0.007813;

    s += Texel(tex, texcoord + p * vec2(-3.0,  3.0)) * 0.003906;
    s += Texel(tex, texcoord + p * vec2(-2.0,  3.0)) * 0.007813;
    s += Texel(tex, texcoord + p * vec2(-1.0,  3.0)) * 0.012500;
    s += Texel(tex, texcoord + p * vec2( 0.0,  3.0)) * 0.014063;
    s += Texel(tex, texcoord + p * vec2( 1.0,  3.0)) * 0.012500;
    s += Texel(tex, texcoord + p * vec2( 2.0,  3.0)) * 0.007813;
    s += Texel(tex, texcoord + p * vec2( 3.0,  3.0)) * 0.003906;

    return s * color;
}
