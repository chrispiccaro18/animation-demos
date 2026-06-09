#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
  #define MY_HIGHP_OR_MEDIUMP highp
#else
  #define MY_HIGHP_OR_MEDIUMP mediump
#endif

extern MY_HIGHP_OR_MEDIUMP vec2 mouse_screen_pos;
extern MY_HIGHP_OR_MEDIUMP float hovering;
extern MY_HIGHP_OR_MEDIUMP float screen_scale;
extern MY_HIGHP_OR_MEDIUMP float card_angle;
extern MY_HIGHP_OR_MEDIUMP float card_center_x;
extern MY_HIGHP_OR_MEDIUMP float card_center_y;
extern MY_HIGHP_OR_MEDIUMP float slot_depth;

#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    float wOffset = 0.0;

    if (hovering > 0.0) {
        vec2 mouse_to_card = (mouse_screen_pos - vec2(card_center_x, card_center_y)) / screen_scale;
        float mouse_card_dist = clamp(length(vec2(mouse_to_card.x, mouse_to_card.y * 0.5)), 0.2, 1.0);

        vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy)/screen_scale;
        float scale = 0.25 * -0.03 * hovering * (length(mouse_offset)*length(mouse_offset)) / (2. - mouse_card_dist);

        float angle_scale = hovering * card_angle * (vertex_position.x - card_center_x) / screen_scale * 0.05;

        wOffset += scale + angle_scale;
    }

    if (slot_depth > 0.0) {
        // top of card narrows (larger W), bottom widens (smaller W) — perspective tilt into slot
        float yOffset = (vertex_position.y - card_center_y) / screen_scale;
        wOffset += slot_depth * -yOffset * 0.2;
        // wOffset += slot_depth * -yOffset * 0.08;
    }

    return transform_projection * vertex_position + vec4(0, 0, 0, wOffset);
}
#endif
