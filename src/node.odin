package main

import rl "vendor:raylib"
import "core:log"

Node :: struct {
    point: Point,

    next_paths: [dynamic]^Path,

    selected: bool,
    deleted: bool,
    begining: bool,
    playing: bool,

    current_note: Note,
}

node_new :: proc(point: Point) -> ^Node {
    node := new(Node)
    node.point = point

    node.current_note = .LA

    node.next_paths = make([dynamic]^Path)

    return node
}

node_free :: proc(node: ^Node) {
    log.debug("Freeing node")

    for path in node.next_paths {
        path_free(path)
    }

    delete(node.next_paths)
    free(node)
}

node_change_note :: proc(node: ^Node, note: Note) {
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
    position := point_get_position(node.point)

    color := BEGIN_NODE_COLOR if node.begining else NODE_COLOR

    if(node.playing) {
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

    if node.selected {
        position = position - NODE_RADIUS

        rl.DrawRectangleRoundedLines(
            rl.Rectangle{position.x, position.y, NODE_RADIUS * 2, NODE_RADIUS * 2},
            0.5,
            4,
            2.0,
            rl.BLUE
        )
    }

    for path in node.next_paths {
        path_draw(path)
    }
}

node_draw_being_edited :: proc(node: ^Node) {
    position := point_get_position(node.point)

    rl.DrawCircle(
        i32(position.x),
        i32(position.y),
        NODE_RADIUS,
        rl.ColorAlpha(NODE_BEING_EDITED_COLOR, 0.3)
    )
}

node_add_path :: proc(node: ^Node, path: ^Path) {
    append(&node.next_paths, path)
}

node_play :: proc(node: ^Node) {
    midi_play_note(node.current_note)
    node.playing = true

    if len(node.next_paths) == 0 {
        canvas_schedule_node_stop(node)
    }

    for path in node.next_paths {
        path_activate(path)
    }
}

node_stop_playing :: proc(node: ^Node) {
    node.playing = false
    midi_stop_note(node.current_note)
}

node_update :: proc(node: ^Node) {
    for path, idx in node.next_paths {
        if path.end.deleted {
            path_free(path)
            unordered_remove(&node.next_paths, idx)
        }
    }
}
