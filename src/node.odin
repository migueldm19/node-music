package main

import rl "vendor:raylib"
import "core:log"

Node :: struct {
    point: Point,
    sound: rl.Sound,

    next_paths: [dynamic]^Path,

    selected: bool,
    deleted: bool,
    begining: bool,
    current_note: Note,
}

node_new :: proc(point: Point) -> ^Node {
    node := new(Node)
    node.point = point

    node.sound = get_note_sound(.LA)
    node.current_note = .LA

    node.next_paths = make([dynamic]^Path)

    return node
}

node_free :: proc(node: ^Node) {
    log.info("Freeing node")

    rl.UnloadSound(node.sound)

    for path in node.next_paths {
        path_free(path)
    }

    delete(node.next_paths)
    free(node)
}

node_change_note :: proc(node: ^Node, note: Note) {
    rl.UnloadSound(node.sound)
    node.sound = get_note_sound(note)
    node.current_note = note
}

node_inc_note :: proc(node: ^Node) {
    node.current_note += Note(1)
    if node.current_note == .NOTES_END {
        node.current_note = .NOTES_BEGINING + Note(1)
    }

    node_change_note(node, node.current_note)
}

node_dec_note :: proc(node: ^Node) {
    node.current_note -= Note(1)
    if node.current_note == .NOTES_BEGINING {
        node.current_note = .NOTES_END - Note(1)
    }

    node_change_note(node, node.current_note)
}

node_draw :: proc(node: ^Node) {
    using node

    position := point_get_position(point)

    color := BEGIN_NODE_COLOR if begining else NODE_COLOR

    if(rl.IsSoundPlaying(sound)) {
        rl.DrawCircleV(
            position,
            NODE_RADIUS,
            color
        )
    } else {
        rl.DrawCircleLinesV(
            position,
            NODE_RADIUS,
            color
        )
    }

    note_text_position_x := i32(position.x) + NODE_RADIUS + NODE_NOTE_TEXT_OFFSET
    note_text_position_y := i32(position.y) - NODE_RADIUS - NODE_NOTE_TEXT_OFFSET

    rl.DrawText(
        note_to_string(current_note),
        note_text_position_x,
        note_text_position_y,
        NODE_NOTE_TEXT_SIZE,
        rl.BLACK
    )

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

node_draw_being_edited :: proc(node: ^Node) {
    using node
    position := point_get_position(point)

    rl.DrawCircle(
        i32(position.x),
        i32(position.y),
        NODE_RADIUS,
        rl.ColorAlpha(NODE_BEING_EDITED_COLOR, 0.3)
    )
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
    }
}