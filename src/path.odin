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

    active: bool,
    distance: i16,
    direction: Direction,
    seconds_between_subbeats: f64,

    activation_time: time.Time,
}

path_new :: proc(start, end: ^Node) -> ^Path {
    path := new(Path)

    path.start = start
    path.end = end

    path.active = false
    path.seconds_between_subbeats = (60.0 / BPM) / f64(SUBDIVISION)

    path_set_distance(path)
    path_set_direction(path)

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

path_set_direction :: proc(path: ^Path) {
    using path
    using Direction

    start_position := point_get_position(start.point)
    end_position := point_get_position(end.point)

    direction = get_direction(start_position, end_position)
}

path_draw :: proc(path: ^Path) {
    using path

    start_position := point_get_position(start.point)
    end_position := point_get_position(end.point)

    draw_path(start_position, end_position, direction)
}

path_update :: proc(path: ^Path) {
    using path

    if !active do return

    elapsed_time := time.since(activation_time)
    elapsed_seconds := time.duration_seconds(elapsed_time)

    if elapsed_seconds > seconds_between_subbeats * f64(distance) {
        node_play(end)
        active = false
    }
}

path_activate :: proc(path: ^Path) {
    using path

    activation_time = time.now()
    active = true
}