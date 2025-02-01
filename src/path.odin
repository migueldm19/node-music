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
    log.info("Freeing path")
    free(path)
}

path_set_distance :: proc(path: ^Path) {
    using path

    distance_x := math.abs(end.point.x - start.point.x)
    distance_y := math.abs(end.point.y - start.point.y)

    path.distance = distance_x + distance_y
}

path_draw :: proc(path: ^Path) {
    using path

    start_position := point_get_position(start.point)
    end_position := point_get_position(end.point)

    draw_path(
        start_position,
        end_position,
        active,
    )
}

path_update :: proc(path: ^Path) {
    using path

    if !path.active do return

    ping_count += 1

    if ping_count >= distance {
        path_deactivate(path)
        node_play(end)
    }
}

path_deactivate :: proc(path: ^Path) {
    path.active = false
    path.ping_count = 0
}

path_activate :: proc(path: ^Path) {
    path.ping_count = 0
    path.active = true
    log.info("Adding path to active paths array")
    canvas_add_active_path(path)
}