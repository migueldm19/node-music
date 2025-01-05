package main

import rl "vendor:raylib"

ARROW_POINT_LEN :: 10

draw_arrow_point :: proc(arrow_point: rl.Vector2, dir: Direction, color: rl.Color) {
    p1 := arrow_point
    p2 := arrow_point

    switch dir {
    case .UP:
        p1.x -= ARROW_POINT_LEN
        p1.y += ARROW_POINT_LEN
        p2.x += ARROW_POINT_LEN
        p2.y += ARROW_POINT_LEN
    case .DOWN:
        p1.x -= ARROW_POINT_LEN
        p1.y -= ARROW_POINT_LEN
        p2.x += ARROW_POINT_LEN
        p2.y -= ARROW_POINT_LEN
    case .LEFT:
        p1.x += ARROW_POINT_LEN
        p1.y -= ARROW_POINT_LEN
        p2.x += ARROW_POINT_LEN
        p2.y += ARROW_POINT_LEN
    case .RIGHT:
        p1.x -= ARROW_POINT_LEN
        p1.y -= ARROW_POINT_LEN
        p2.x -= ARROW_POINT_LEN
        p2.y += ARROW_POINT_LEN
    }

    rl.DrawLineV(p1, arrow_point, color)
    rl.DrawLineV(p2, arrow_point, color)
}

get_direction :: proc(start_position, end_position: rl.Vector2) -> Direction {
    using Direction

    dir := LEFT if start_position.x > end_position.x else RIGHT

    if start_position.y != end_position.y {
        dir = UP if start_position.y > end_position.y else DOWN
    }

    return dir
}

draw_path :: proc(start, end: rl.Vector2, direction: Direction) {
    start_position := start
    end_position := end

    if start_position.x != end_position.x {
        rl.DrawLine(
            i32(start_position.x),
            i32(start_position.y),
            i32(end_position.x),
            i32(start_position.y),
            PATH_COLOR
        )
        start_position = rl.Vector2{end_position.x, start_position.y}
    }

    switch direction {
    case .LEFT: end_position.x += NODE_RADIUS
    case .RIGHT: end_position.x -= NODE_RADIUS
    case .UP: end_position.y += NODE_RADIUS
    case .DOWN: end_position.y -= NODE_RADIUS
    }

    if start_position.y != end_position.y {
        rl.DrawLine(
            i32(start_position.x),
            i32(start_position.y),
            i32(start_position.x),
            i32(end_position.y),
            PATH_COLOR
        );
    }

    draw_arrow_point(end_position, direction, PATH_COLOR)
}