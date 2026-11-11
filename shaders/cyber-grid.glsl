// cyber-grid.glsl
//
// Animated background for the Cyberdream theme slot. A Ghostty custom shader
// (Shadertoy dialect): a faint neon grid corridor, floor and ceiling receding
// to a horizon in the middle of the window, under a slow drifting haze.
//
// It is meant to sit behind the code, not compete with it:
//   - it only paints where the terminal shows its background colour, so text,
//     the statusline and the cursor line stay exactly as Neovim drew them;
//   - it fades out around text, so the lines of code sit on a calm patch and
//     the grid lives in the empty parts of the window.
//
// Neovim switches this on and off with the theme (lua/core/terminal.lua).
// Tweak the constants below, then open shaders/preview.html to see the result
// in a browser, or just switch theme in Ghostty.

const float INTENSITY = 1.0;   // overall brightness; 0.6 = subtler, 1.5 = louder
const float SPEED     = 1.0;   // how fast the grid moves towards you
const float GRID      = 1.0;   // grid density; lower = fewer, wider cells
const float CLEAR     = 0.85;  // how much it fades around text: 0 = not at all, 1 = fully
const vec3  NEAR_COL  = vec3(0.37, 0.95, 1.00);  // cyan, at the window edges
const vec3  FAR_COL   = vec3(1.00, 0.37, 0.63);  // pink, at the horizon

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.03;
        a *= 0.5;
    }
    return v;
}

vec3 scene(vec2 fragCoord, float t) {
    // Centred coordinates; p.y runs from -0.5 (one edge) to 0.5 (the other).
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    float h = abs(p.y);                       // distance from the horizon

    // Perspective: the further from the horizon, the closer to the viewer.
    float depth = 1.3 / (h + 0.04);
    vec2 g = vec2(p.x * depth * 1.3, depth + t * 0.22 * SPEED) * GRID * 0.6;

    // Thin lines of constant on-screen width (fwidth = change of g per pixel).
    vec2 w = fwidth(g) * 1.1;
    vec2 d = abs(fract(g - 0.5) - 0.5);
    vec2 core = 1.0 - smoothstep(vec2(0.0), w, d);   // the crisp line
    vec2 glow = exp(-d / (w * 3.0));                 // soft halo around it
    float line = max(core.x, core.y) + 0.20 * max(glow.x, glow.y);

    // Near the horizon the lines would turn to mush: fade them out there,
    // which also keeps the middle of the window (where you read) calm.
    float fade = smoothstep(0.10, 0.48, h);
    // A slow, shallow breathing instead of a hard pulse.
    float breathe = 0.85 + 0.15 * sin(g.y * 0.5 - t * 0.5 * SPEED);

    vec3 lineCol = mix(FAR_COL, NEAR_COL, smoothstep(0.08, 0.45, h));
    vec3 col = lineCol * line * fade * breathe * 0.16;

    // Horizon glow.
    col += FAR_COL * exp(-h * 18.0) * 0.035;

    // Slow drifting haze so the dark areas are not dead flat.
    float haze = fbm(p * 1.6 + vec2(t * 0.02, -t * 0.014));
    col += mix(NEAR_COL, vec3(0.45, 0.30, 0.95), haze) * haze * haze * 0.045;

    return col * INTENSITY;
}

// 1 where the pixel at uv is plain background, 0 on text and coloured cells.
float isBackground(vec2 uv) {
    return 1.0 - smoothstep(0.02, 0.10, distance(texture(iChannel0, uv).rgb, iBackgroundColor));
}

// How much text is around this pixel, 0..1: two rings of samples, roughly one
// and two text lines away.
float textNearby(vec2 fragCoord) {
    float r = 0.016 * iResolution.y;
    float sum = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = 6.2831853 * (float(i) + 0.5) / 8.0;
        vec2 dir = vec2(cos(a), sin(a));
        sum += 1.0 - isBackground((fragCoord + dir * r) / iResolution.xy);
        sum += 0.6 * (1.0 - isBackground((fragCoord + dir * r * 2.3) / iResolution.xy));
    }
    return smoothstep(0.0, 1.6, sum);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    float calm = 1.0 - CLEAR * textNearby(fragCoord);
    fragColor = vec4(term.rgb + scene(fragCoord, iTime) * isBackground(uv) * calm, term.a);
}
