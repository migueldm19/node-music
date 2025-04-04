package graph

import rl "vendor:raylib"

import "../config"

Point :: struct {
    x: i16,
    y: i16,
}

point_from_vector :: proc(position: rl.Vector2) -> Point {
    x := position.x / config.NODE_SEPARATION
    y := position.y / config.NODE_SEPARATION

    return Point{i16(x), i16(y)}
}

point_get_position :: proc(point: Point) -> rl.Vector2 {
    x := point.x * config.NODE_SEPARATION
    y := point.y * config.NODE_SEPARATION

    return rl.Vector2{f32(x), f32(y)}
}
