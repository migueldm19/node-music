package graph

import rl "vendor:raylib"

import "../config"

ARROW_POINT_LEN :: 10

draw_arrow_point :: proc(arrow_point: rl.Vector2, dir: Direction, thickness: f32, color: rl.Color) {
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

    rl.DrawLineEx(p1, arrow_point, thickness, color)
    rl.DrawLineEx(p2, arrow_point, thickness, color)
}

get_direction :: proc(start_position, end_position: rl.Vector2) -> Direction {
    using Direction

    dir := LEFT if start_position.x > end_position.x else RIGHT

    if start_position.y != end_position.y {
        dir = UP if start_position.y > end_position.y else DOWN
    }

    return dir
}

draw_path :: proc(start, end: rl.Vector2, type: PathType, active: bool = false) {
    switch type {
    case .Normal: draw_normal_path(start, end, active)
    case .Transfer: draw_transfer_path(start, end)
    }
}

draw_transfer_path :: proc(start, end: rl.Vector2) {
    rl.DrawLineEx(start, end, config.PATH_THICKNESS, config.TRANSFER_PATH_COLOR)
    rl.DrawCircleLinesV(start, 8, config.TRANSFER_PATH_COLOR)
    rl.DrawCircleLinesV(end, 5, config.TRANSFER_PATH_COLOR)
}

draw_normal_path :: proc(start, end: rl.Vector2, active: bool = false) {
    start_position := start
    end_position := end

    direction := get_direction(start, end)

    color := config.ACTIVE_PATH_COLOR if active else config.UNACTIVE_PATH_COLOR

    if start_position.x != end_position.x {
        rl.DrawLineEx(
            start_position,
            {end_position.x, start_position.y},
            config.PATH_THICKNESS,
            color
        )
        start_position = rl.Vector2{end_position.x, start_position.y}
    }

    switch direction {
    case .LEFT: end_position.x += config.NODE_RADIUS
    case .RIGHT: end_position.x -= config.NODE_RADIUS
    case .UP: end_position.y += config.NODE_RADIUS
    case .DOWN: end_position.y -= config.NODE_RADIUS
    }

    if start_position.y != end_position.y {
        rl.DrawLineEx(
            start_position,
            {start_position.x, end_position.y},
            config.PATH_THICKNESS,
            color
        );
    }

    draw_arrow_point(end_position, direction, config.PATH_THICKNESS, color)
}
