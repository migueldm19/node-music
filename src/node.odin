package main

import rl "vendor:raylib"

Node :: struct {
    point: Point,
    sound: rl.Sound,

    next_paths: [dynamic]^Path,

    selected, deleted: bool,
}

node_new :: proc(point: Point) -> ^Node {
    node := new(Node)
    node.point = point

    node.sound = rl.LoadSound("A4vL.wav")

    node.next_paths = make([dynamic]^Path)

    return node
}

node_free :: proc(node: ^Node) {
    rl.UnloadSound(node.sound)

    for path in node.next_paths {
        path_free(path)
    }

    delete(node.next_paths)
    free(node)
}

node_draw :: proc(node: ^Node) {
    using node

    position := point_get_position(point)

    if(rl.IsSoundPlaying(sound)) {
        rl.DrawCircleV(
            position,
            NODE_RADIUS,
            NODE_COLOR
        )
    } else {
        rl.DrawCircleLinesV(
            position,
            NODE_RADIUS,
            NODE_COLOR
        )
    }

    if selected {
        position = position - NODE_RADIUS

        rl.DrawRectangleRoundedLines(
            rl.Rectangle{position.x, position.y, NODE_RADIUS * 2, NODE_RADIUS * 2},
            0.5,
            4,
            2.0,
            rl.BLUE
        )
    }

    for path in next_paths {
        path_draw(path)
    }
}

node_add_path :: proc(node: ^Node, path: ^Path) {
    using node
    append(&next_paths, path)
}

node_play :: proc(node: ^Node) {
    using node

    rl.PlaySound(sound)

    for path in next_paths {
        path_activate(path)
    }
}

node_update :: proc(node: ^Node) {
    using node 

    for path, idx in next_paths {
        if path.end.deleted {
            path_free(path)
            unordered_remove(&next_paths, idx)
        }
        path_update(path)
    }
}