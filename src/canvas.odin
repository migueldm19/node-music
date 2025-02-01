package main

import rl "vendor:raylib"
import "core:math"
import "core:log"

Tool :: enum i32 {
    MOUSE_TOOL,
    NODE_TOOL,
    PATH_TOOL,
}

Canvas :: struct {
    camera: rl.Camera2D,

    window_height: i32,
    window_width: i32,

    subdivision: int,

    nodes: map[Point]^Node,
    node_delete_queue: [dynamic]^Node,

    active_paths: [dynamic]^Path,

    possible_node_position: rl.Vector2,

    tool_selected: Tool,

    selected_node_for_path: ^Node,

    playing: bool,
}

canvas: ^Canvas

canvas_init :: proc() {
    canvas = new(Canvas)
    using canvas

    window_height = rl.GetScreenHeight()
    window_width = rl.GetScreenWidth()

    camera.zoom = 1.0
    camera.target = {f32(window_width) / 2.0, f32(window_height) / 2.0}
    camera.offset = {f32(window_width) / 2.0, f32(window_height) / 2.0}
    camera.rotation = 0.0

    subdivision = SUBDIVISION

    nodes = make(map[Point]^Node)
    node_delete_queue = make([dynamic]^Node)

    active_paths = make([dynamic]^Path, 0, 30)
}

canvas_deinit :: proc() {
    using canvas
    log.info("Freeing canvas")

    for _, node in nodes {
        node_free(node)
    }

    delete(nodes)
    delete(node_delete_queue)
    delete(active_paths)
    free(canvas)
}

canvas_draw :: proc() {
    rl.ClearBackground(BG_COLOR)
    rl.BeginMode2D(canvas.camera)
        canvas_draw_grid()
        canvas_draw_possible_elements()
        canvas_draw_nodes()
    rl.EndMode2D()
    canvas_draw_and_update_ui()
}

canvas_draw_and_update_ui :: proc() {
    // Tool selection
    rl.GuiToggleGroup(rl.Rectangle{30, 30, 120, 30}, TOOLS, (^i32)(&canvas.tool_selected))

    if canvas.playing {
        if rl.GuiButton(rl.Rectangle{800, 30, 30, 30}, "Stop") {
            canvas_stop_playing()
        }
    } else {
        if rl.GuiButton(rl.Rectangle{800, 30, 30, 30}, "Play") {
            canvas.playing = true
            for _, node in canvas.nodes {
                if node.begining {
                    node_play(node)
                }
            }
        }
    }

}

canvas_stop_playing :: proc() {
    canvas.playing = false
    for path in canvas.active_paths {
        path_deactivate(path)
    }
    clear(&canvas.active_paths)
}

canvas_draw_possible_elements :: proc() {
    switch canvas.tool_selected {
    case .MOUSE_TOOL:
        canvas_draw_possible_selection()
    case .NODE_TOOL:
        canvas_draw_possible_node()
    case .PATH_TOOL:
        canvas_draw_possible_path()
        canvas_draw_possible_selection()
    }
}

canvas_draw_nodes :: proc() {
    for _, node in canvas.nodes {
        node_draw(node)
    }
}

canvas_draw_grid :: proc() {
    using canvas

    camera_position: rl.Vector2 = camera.target - camera.offset
    step_size := f32(NODE_SEPARATION * subdivision)
    zoom_offset := ZOOM_OFFSET_GRID / camera.zoom

    offset_x := math.mod_f32(camera_position.x, f32(step_size))
    offset_y := math.mod_f32(camera_position.y, f32(step_size))

    // Vertical lines
    for i := camera_position.x - offset_x;
    i < f32(window_width) + camera_position.x + zoom_offset;
    i += step_size {
        rl.DrawLineV(
            {i, camera_position.y - zoom_offset},
            {i, f32(window_height) + camera_position.y + zoom_offset},
            LINES_COLOR
        )
    }

    // Horizontal lines
    for i := camera_position.y - offset_y;
    i < f32(window_height) + camera_position.y + zoom_offset;
    i += step_size {
        rl.DrawLineV(
            {camera_position.x - zoom_offset, i},
            {f32(window_width) + camera_position.x + zoom_offset, i},
            LINES_COLOR
        )
    }

    offset_x = math.mod_f32(camera_position.x, f32(NODE_SEPARATION))
    offset_y = math.mod_f32(camera_position.y, f32(NODE_SEPARATION))

    // Points
    for i:= camera_position.x - offset_x;
    i < f32(window_width) + camera_position.x + zoom_offset;
    i += NODE_SEPARATION {
        for j:= camera_position.y - offset_y;
        j < f32(window_height) + camera_position.y + zoom_offset;
        j += NODE_SEPARATION {
            rl.DrawCircleV({i, j}, POINTS_SIZE, POINTS_COLOR)
        }
        for j:= camera_position.y - offset_y;
        j > -zoom_offset - camera_position.x;
        j -= NODE_SEPARATION {
            rl.DrawCircleV({i, j}, POINTS_SIZE, POINTS_COLOR)
        }
    }
}

canvas_draw_possible_selection :: proc() {
    using canvas

    possible_point := point_from_vector(possible_node_position)
    possible_node, ok := nodes[possible_point]

    if !ok do return

    pos := point_get_position(possible_node.point) - NODE_RADIUS

    rl.DrawRectangleRoundedLines(
        rl.Rectangle{pos.x, pos.y, NODE_RADIUS * 2, NODE_RADIUS * 2},
        0.5,
        4,
        3,
        rl.SKYBLUE
    )
}

canvas_draw_possible_node :: proc() {
    rl.DrawCircleLinesV(canvas.possible_node_position, NODE_RADIUS / 2, NODE_COLOR)
}

canvas_draw_possible_path :: proc() {
    using canvas

    if selected_node_for_path != nil {
        start_position := point_get_position(selected_node_for_path.point)
        end_position := canvas_get_relative_mouse_position()

        draw_path(start_position, end_position)
    }
}

canvas_update :: proc() {
    using canvas

    canvas_update_camera()
    canvas_update_possible_node_position()

    canvas_handle_input()

    for _, node in nodes {
        node_update(node)
    }

    canvas_clear_node_delete_queue()
}

canvas_handle_input :: proc() {
    switch canvas.tool_selected {
    case .NODE_TOOL:
        canvas_handle_node_tool_input()
    case .PATH_TOOL:
        canvas_handle_path_tool_input()
    case .MOUSE_TOOL:
        canvas_handle_mouse_tool_input()
    }
}

canvas_handle_mouse_tool_input :: proc() {
    using canvas

    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := point_from_vector(possible_node_position)

        if !rl.IsKeyDown(.LEFT_CONTROL) && !rl.IsKeyDown(.RIGHT_CONTROL) {
            canvas_unselect_all_nodes()
        }

        possible_node, ok := nodes[possible_point]
        if !ok do return

        possible_node.selected = true
    }

    if rl.IsKeyPressed(.DELETE) {
        canvas_delete_all_selected_nodes()
    }

    if rl.IsKeyPressed(.SPACE) {
        canvas_set_begining_nodes()
    }
}

canvas_set_begining_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.selected {
            node.begining = !node.begining
        }
    }
}

canvas_unselect_all_nodes :: proc() {
    for _, node in canvas.nodes {
        node.selected = false
    }
}

canvas_delete_all_selected_nodes :: proc() {
    canvas_stop_playing()
    for point, node in canvas.nodes {
        if node.selected {
            node.deleted = true
            delete_key(&canvas.nodes, point)
            append(&canvas.node_delete_queue, node)
        }
    }
}

canvas_clear_node_delete_queue :: proc() {
    for node in canvas.node_delete_queue {
        node_free(node)
    }

    clear(&canvas.node_delete_queue)
}

canvas_handle_node_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        canvas_create_new_node(canvas.possible_node_position)
    }
}

canvas_create_new_node :: proc(position: rl.Vector2) {
    possible_point := point_from_vector(position)

    if !(possible_point in canvas.nodes) {
        new_node := node_new(possible_point)
        canvas.nodes[possible_point] = new_node
    }
}

canvas_handle_path_tool_input :: proc() {
    using canvas

    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := point_from_vector(possible_node_position)
        possible_node, ok := nodes[possible_point]

        if !ok {
            selected_node_for_path = nil
            return
        }

        if selected_node_for_path == nil {
            selected_node_for_path = possible_node
        } else {
            path := path_new(selected_node_for_path, possible_node)
            node_add_path(selected_node_for_path, path)
            selected_node_for_path = nil
        }
    }
}

canvas_update_camera :: proc() {
    using canvas

    camera.zoom += (f32(rl.GetMouseWheelMove()) * ZOOM_SPEED)

    if camera.zoom > MAX_ZOOM do camera.zoom = MAX_ZOOM
    if camera.zoom < MIN_ZOOM do camera.zoom = MIN_ZOOM

    if rl.IsMouseButtonDown(.MIDDLE) {
        camera.target -= rl.GetMouseDelta()
    }
}

canvas_update_possible_node_position :: proc() {
    pos := canvas_get_relative_mouse_position()

    offset_x := math.mod_f32(pos.x, f32(NODE_SEPARATION))
    offset_y := math.mod_f32(pos.y, f32(NODE_SEPARATION))

    pos.x -= offset_x
    if offset_x > NODE_SEPARATION / 2 {
        pos.x += NODE_SEPARATION
    }

    pos.y -= offset_y
    if offset_y > NODE_SEPARATION / 2 {
        pos.y += NODE_SEPARATION
    }

    canvas.possible_node_position = pos
}

canvas_get_relative_mouse_position :: proc() -> rl.Vector2 {
    using canvas

    camera_position := camera.target - camera.offset
    position := rl.GetMousePosition()

    return position + camera_position
}

canvas_add_active_path :: proc(path: ^Path) {
    append(&canvas.active_paths, path)
}

canvas_metronome_ping :: proc() {
    active_paths_slice := canvas.active_paths[:]
    clear(&canvas.active_paths)

    for path in active_paths_slice {
        path_update(path)
        if path.active {
            canvas_add_active_path(path)
        }
    }
}