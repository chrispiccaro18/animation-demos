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

#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position )
{
    if (hovering <= 0.0){
        return transform_projection * vertex_position;
    }
    vec2 mouse_to_card = (mouse_screen_pos - vec2(card_center_x, card_center_y)) / screen_scale;
    float mouse_card_dist = clamp(length(vec2(mouse_to_card.x, mouse_to_card.y * 0.5)), 0.2, 1.0);
    // float mouse_card_dist = clamp(length(vec2(mouse_to_card.x, mouse_to_card.y * 0.75)), 0.2, 1.15);
    // float mouse_card_dist = clamp(length(vec2(mouse_to_card.x, mouse_to_card.y * 0.75)), 0.3, 1.25);

    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy)/screen_scale;
    float scale = 0.25 * -0.03* hovering*(length(mouse_offset)*length(mouse_offset))/(2. - mouse_card_dist);
    // float scale = 0.15 * -0.03* hovering*(length(mouse_offset)*length(mouse_offset))/(2. - mouse_card_dist);
    // float scale = 0.3 * -0.03* hovering*(length(mouse_offset)*length(mouse_offset))/(2. - mouse_card_dist);

    // vec2 vertex_offset = (vertex_position.xy - vec2(card_center_x, card_center_y)) / screen_scale;
    // vec2 card_local_x  = vec2(cos(card_angle), sin(card_angle));
    // float local_x      = dot(vertex_offset, card_local_x);
    // float angle_scale  = hovering * max(0.0, card_angle * local_x) * 0.1;

    float angle_scale = hovering * card_angle * (vertex_position.x - card_center_x) / screen_scale * 0.05;

    return transform_projection * vertex_position + vec4(0,0,0,scale + angle_scale);
}
#endif
