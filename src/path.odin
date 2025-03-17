package main

import rl "vendor:raylib"
import "core:math"
import "core:log"
import "core:time"

Direction :: enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
}

Path :: struct {
    start, end: ^Node,
    distance: i16,

    active: bool,

    ping_count: i16
}

path_new :: proc(start, end: ^Node) -> ^Path {
    path := new(Path)

    path.start = start
    path.end = end

    path.active = false
    path.ping_count = 0

    path_set_distance(path)

    return path
}

path_free :: proc(path: ^Path) {
    log.debug("Freeing path")
    free(path)
}

path_set_distance :: proc(path: ^Path) {
    distance_x := math.abs(path.end.point.x - path.start.point.x)
    distance_y := math.abs(path.end.point.y - path.start.point.y)

    path.distance = distance_x + distance_y
}

path_draw :: proc(path: ^Path) {
    start_position := point_get_position(path.start.point)
    end_position := point_get_position(path.end.point)

    draw_path(
        start_position,
        end_position,
        path.active,
    )
}

path_update :: proc(path: ^Path) {
    if !path.active do return

    path.ping_count += 1

    if path.ping_count >= path.distance {
        path_deactivate(path)
        node_play(path.end)
    }
}

path_deactivate :: proc(path: ^Path) {
    path.active = false
    path.ping_count = 0
}

path_activate :: proc(path: ^Path) {
    path.ping_count = 0
    path.active = true
    canvas_add_active_path(path)
}
