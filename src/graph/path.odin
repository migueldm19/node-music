package graph

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"
import "core:log"
import "core:time"
import "core:sync"

Direction :: enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
}

PathType :: enum {
    Normal,
    Transfer,
}

Path :: struct {
    start: ^Node,
    end: ^Node,

    distance: i16,
    probability: f32,
    type: PathType,

    active: bool,
    active_mutex: sync.Mutex,

    ping_count: i16,
}

PathData :: struct {
    start: NodeID,
    end: NodeID,
    type: PathType,
    probability: f32,
}

path_data :: proc(path: ^Path) -> PathData {
    log.debugf("Generating path %v -> %v data", path.start.id, path.end.id)
    return PathData {
        start = path.start.id,
        end = path.end.id,
        type = path.type,
        probability = path.probability,
    }
}

path_new :: proc(start, end: ^Node, type: PathType, probability: f32 = 1.0) -> ^Path {
    path := new(Path)

    path.start = start
    path.end = end
    path.type = type
    path.probability = probability
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
        path.type,
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
    sync.mutex_lock(&path.active_mutex)
    defer sync.mutex_unlock(&path.active_mutex)
    path.active = false
    path.ping_count = 0
    node_stop_playing(path.start)
}

path_activate :: proc(path: ^Path) {
    sync.mutex_lock(&path.active_mutex)
    defer sync.mutex_unlock(&path.active_mutex)
    if path.probability < 1.0 {
        if rand.float32() > path.probability do return
    }
    switch path.type {
    case .Normal: {
        path.ping_count = 0
        path.active = true
    }
    case .Transfer: {
        node_play(path.end)
    }
    }
}
