// hud.glsl
//
// Animated background for the futuristic theme slot: a quiet control-centre
// HUD. A Ghostty custom shader (Shadertoy dialect).
//
//   - a faint dot matrix over the whole window, with a slow wave through it
//   - an instrument dial at the right-hand side (where code rarely reaches):
//     tick ring, counter-rotating arc segments, a radar sweep, one amber arc
//   - thin brackets in the four corners
//   - a small flash on each character you type (see typed() below), and the
//     dial pulses with every keystroke, so it follows your typing rhythm
//   - a hairline that streaks from the old cursor position to the new one
//     when the cursor jumps
//   - the dial is drawn in the cursor's colour. Neovim changes that colour
//     with the mode and when the file has errors (lua/core/cursor.lua), which
//     is how the editor's state reaches this shader
//   - it dims while the window is unfocused and powers up when focus returns
//
// It is meant to sit behind the code, not compete with it:
//   - it only paints where the terminal shows its background colour, so text,
//     the statusline and the cursor line stay exactly as Neovim drew them;
//   - it fades out around text, so code always sits on a calm patch.
//
// Neovim switches this on and off with the theme (lua/core/terminal.lua).
// Tweak the constants below, then open shaders/preview.html?shader=hud.glsl
// in a browser, or switch theme away and back in Ghostty.

const float INTENSITY = 1.0;   // overall brightness; 0.6 = subtler, 1.5 = louder
const float SPEED     = 1.0;   // how fast everything turns
const float CLEAR     = 0.90;  // how much it fades around text: 0 = not at all, 1 = fully
const float TYPING    = 1.0;   // the flash on typed characters; 0 = off
const float PULSE     = 1.0;   // how much the dial reacts to typing; 0 = not at all
const float TRAIL     = 1.0;   // the streak on cursor jumps; 0 = off
const float SLEEP     = 0.40;  // brightness while the window is unfocused
const float DIAL_SIZE = 0.30;  // dial radius, as a fraction of the window height
const float DIAL_X    = 0.40;  // dial centre: distance from the right edge (same unit)
const vec3  MAIN_COL  = vec3(0.37, 0.95, 1.00);  // cyan
const vec3  DEEP_COL  = vec3(0.22, 0.52, 1.00);  // blue, for the quieter parts
const vec3  WARN_COL  = vec3(1.00, 0.70, 0.30);  // amber, used once

const float TAU = 6.2831853;

// A circle outline of radius r0 and thickness w (px = one pixel, for smooth edges).
float ring(float r, float r0, float w, float px) {
    return 1.0 - smoothstep(w * 0.5, w * 0.5 + px, abs(r - r0));
}

// Splits a circle into n equal segments and keeps the first `duty` of each.
float segments(float ang, float n, float duty, float rot) {
    float f = fract((ang + rot) / TAU * n);
    float e = 0.004 * n;
    return smoothstep(0.0, e, f) * (1.0 - smoothstep(duty, duty + e, f));
}

// Seconds since the last typed character, or -1 if the last cursor change was
// not typing. "Typed" means the cursor moved a little to the right on the same
// row, so stepping right with `l` counts too, while jumps and deletions do not.
// (A shader keeps no memory: it only knows the latest cursor change.)
float sinceTyped() {
    float h = iCurrentCursor.w;                    // cell height
    vec2 move = iCurrentCursor.xy - iPreviousCursor.xy;
    if (h <= 0.0 || move.x <= 0.0 || move.x > 1.6 * h || abs(move.y) > 0.25 * h) return -1.0;
    float dt = iTime - iTimeCursorChange;
    return dt < 0.0 ? -1.0 : dt;
}

// The dial's colour: the cursor's, or cyan if the terminal reports none.
vec3 accent() {
    vec3 c = iCurrentCursorColor.rgb;
    return (c.r + c.g + c.b) < 0.15 ? MAIN_COL : c;
}

// 0..1: how "awake" the HUD is. Ramps up over a second after the window
// gains focus (and when the shader first loads); 0 while unfocused.
float awake() {
    if (iFocus == 0) return 0.0;
    return smoothstep(0.0, 1.0, iTime - iTimeFocus);
}

// `beat` is 1 right on a keystroke and decays to 0 in about half a second;
// `age` is the time since that keystroke (or -1). `draw` (0..1) is how much of
// each arc is drawn, for the power-up.
vec3 dial(vec2 q, float t, float px, float beat, float age, float draw) {
    float R = DIAL_SIZE;
    float r = length(q);
    if (r > R * 1.15) return vec3(0.0);
    float ang = atan(q.y, q.x);
    vec3 col = vec3(0.0);
    // Away from cyan (insert, visual, errors) the quieter blue parts lean
    // towards the accent too, so the whole dial reads as one colour.
    vec3 MAIN = accent();
    vec3 DEEP = mix(DEEP_COL, MAIN * 0.75, smoothstep(0.15, 0.6, distance(MAIN, MAIN_COL)));

    // Outer hairline and the tick ring just inside it (every 6th tick longer).
    col += DEEP * ring(r, R, 0.0015, px) * 0.30;
    float tick = segments(ang, 72.0, 0.12, 0.0);
    float longTick = segments(ang, 12.0, 0.02, 0.0);
    float band = smoothstep(R * 0.905, R * 0.905 + px, r) * (1.0 - smoothstep(R * 0.95, R * 0.95 + px, r));
    float longBand = smoothstep(R * 0.87, R * 0.87 + px, r) * (1.0 - smoothstep(R * 0.95, R * 0.95 + px, r));
    col += MAIN * (tick * band * 0.22 + longTick * longBand * 0.40);

    // Three arc rings turning at different speeds, in alternating directions.
    col += MAIN * ring(r, R * 0.76, 0.0045, px) * segments(ang, 3.0, 0.72 * draw, t * 0.12) * 0.34;
    col += DEEP * ring(r, R * 0.60, 0.0020, px) * segments(ang, 5.0, 0.55 * draw, -t * 0.20) * 0.42;
    col += MAIN * ring(r, R * 0.42, 0.0080, px) * segments(ang, 2.0, 0.34 * draw, t * 0.33) * 0.30;
    // The one warm accent: a short amber arc riding the middle ring.
    col += WARN_COL * ring(r, R * 0.66, 0.0035, px) * segments(ang, 1.0, 0.09, -t * 0.20) * 0.45;

    // Radar sweep inside the middle ring: a bright edge with a fading trail.
    float sweep = fract((ang - t * 0.45) / TAU);
    float inside = 1.0 - smoothstep(R * 0.58, R * 0.60, r);
    col += MAIN * pow(sweep, 7.0) * inside * 0.10;

    // Core: a small ring and a dot that breathes.
    col += MAIN * ring(r, R * 0.13, 0.0025, px) * 0.40;
    col += MAIN * (1.0 - smoothstep(R * 0.035, R * 0.035 + px, r)) * (0.30 + 0.15 * sin(t * 1.4));
    // Soft glow so the dial does not look pasted on.
    col += DEEP * exp(-r * r / (R * R * 0.35)) * 0.035;

    // Typing: every keystroke lifts the whole dial a little, lights the core,
    // and sends one faint ripple out from the centre, like a level meter.
    col *= 1.0 + 0.55 * beat;
    col += MAIN * exp(-r * r / (R * R * 0.06)) * 0.10 * beat;
    if (age >= 0.0 && age < 0.7) {
        float k = age / 0.7;
        col += MAIN * ring(r, R * (0.13 + 0.80 * k), 0.0020, px) * 0.30 * (1.0 - k) * (1.0 - k) * PULSE;
    }

    return col;
}

vec3 scene(vec2 fragCoord, float t) {
    // Centred coordinates in units of the window height; x spans +-ext.x.
    vec2 p = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    vec2 ext = vec2(0.5 * iResolution.x / iResolution.y, 0.5);
    float px = 1.5 / iResolution.y;
    vec3 col = vec3(0.0);

    // Dot matrix, with a slow diagonal wave of brightness passing through.
    float cell = 0.042;
    vec2 gp = p / cell;
    float pip = 1.0 - smoothstep(0.0016, 0.0016 + px, length(fract(gp) - 0.5) * cell);
    vec2 id = floor(gp);
    float wave = 0.5 + 0.5 * sin((id.x + id.y) * 0.35 - t * 0.6 * SPEED);
    col += DEEP_COL * pip * (0.10 + 0.14 * wave * wave);

    // The dial, at the right-hand side and vertically centred.
    float age = sinceTyped();
    float beat = age < 0.0 ? 0.0 : exp(-age / 0.22) * PULSE;
    float power = awake();
    col += dial(p - vec2(ext.x - DIAL_X, 0.0), t * SPEED, px, beat, age, 0.2 + 0.8 * (iFocus == 0 ? 1.0 : power));

    // Corner brackets.
    vec2 c = ext - abs(p) - 0.028;               // distance in from the corner, per axis
    float arm = 0.055;
    float bracket = max(
        (1.0 - smoothstep(0.0, px, abs(c.x))) * step(0.0, c.y) * step(c.y, arm),
        (1.0 - smoothstep(0.0, px, abs(c.y))) * step(0.0, c.x) * step(c.x, arm));
    col += MAIN_COL * bracket * 0.32;

    return col * INTENSITY * mix(SLEEP, 1.0, power);
}

// 1 where the pixel at uv is plain background, 0 on text and coloured cells.
// The tolerance is wide enough that a faint tint (the theme's cursor line)
// still counts as background, so the animation is not cut by a solid bar.
float isBackground(vec2 uv) {
    return 1.0 - smoothstep(0.08, 0.14, distance(texture(iChannel0, uv).rgb, iBackgroundColor));
}

// How much text is around this pixel, 0..1: two rings of samples, roughly one
// and two text lines away.
float textNearby(vec2 fragCoord) {
    float r = 0.016 * iResolution.y;
    float sum = 0.0;
    for (int i = 0; i < 8; i++) {
        float a = TAU * (float(i) + 0.5) / 8.0;
        vec2 dir = vec2(cos(a), sin(a));
        sum += 1.0 - isBackground((fragCoord + dir * r) / iResolution.xy);
        sum += 0.6 * (1.0 - isBackground((fragCoord + dir * r * 2.3) / iResolution.xy));
    }
    return smoothstep(0.0, 1.6, sum);
}

// A brief flash on the character just typed: a soft glow behind it and two
// hairlines, above and below, that slide apart and fade in a third of a second.
vec3 typed(vec2 fragCoord) {
    float age = sinceTyped();
    if (age < 0.0) return vec3(0.0);
    float h = iCurrentCursor.w;
    float cw = 0.5 * h;                            // about one cell wide
    vec2 move = iCurrentCursor.xy - iPreviousCursor.xy;

    float k = age / 0.33;
    if (k > 1.0) return vec3(0.0);
    float fade = (1.0 - k) * (1.0 - k);

    // Centre of the cell the character went into.
    vec2 d = fragCoord - (iPreviousCursor.xy + vec2(0.5 * move.x, -0.5 * h));
    float glow = exp(-dot(d, d) / (0.55 * h * h)) * 0.10;
    float reach = 0.5 * move.x + cw * 1.6 * k;     // the hairlines grow sideways
    float bars = (1.0 - smoothstep(0.6, 1.6, abs(abs(d.y) - 0.5 * h)))
               * (1.0 - smoothstep(reach - cw * 0.5, reach, abs(d.x)));
    return accent() * (glow + bars * 0.45) * fade * TYPING;
}

// A hairline from where the cursor was to where it jumped, brightest at the
// destination; the tail catches up and it is gone in a quarter of a second.
// Only for real jumps: typing, and moves of a line or two, draw nothing.
vec3 trail(vec2 fragCoord) {
    float h = iCurrentCursor.w;
    if (h <= 0.0 || sinceTyped() >= 0.0) return vec3(0.0);
    float k = (iTime - iTimeCursorChange) / 0.28;
    if (k < 0.0 || k > 1.0) return vec3(0.0);

    vec2 a = iPreviousCursor.xy + vec2(0.5 * iPreviousCursor.z, -0.5 * iPreviousCursor.w);
    vec2 b = iCurrentCursor.xy + vec2(0.5 * iCurrentCursor.z, -0.5 * h);
    vec2 ab = b - a;
    float len = length(ab);
    if (len < 2.5 * h) return vec3(0.0);

    float u = clamp(dot(fragCoord - a, ab) / (len * len), 0.0, 1.0);   // 0 at the start, 1 at the cursor
    float dist = length(fragCoord - (a + ab * u));
    float line = 1.0 - smoothstep(0.5, 1.8, dist);
    float lit = smoothstep(k - 0.05, k + 0.25, u);                     // the tail retracts
    return accent() * line * lit * u * (1.0 - k) * 0.55 * TRAIL;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 term = texture(iChannel0, uv);

    float bg = isBackground(uv);
    float calm = 1.0 - CLEAR * textNearby(fragCoord);
    vec3 col = scene(fragCoord, iTime) * calm + typed(fragCoord) + trail(fragCoord);
    fragColor = vec4(term.rgb + col * bg, term.a);
}
