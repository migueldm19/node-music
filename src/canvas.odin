package main

import rl "vendor:raylib"
import imgui "../deps/odin-imgui"
import "core:math"
import "core:log"
import "core:sync"
import "core:encoding/json"
import "core:io"
import "core:os"

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
    node_stop_queue: [dynamic]^Node,

    active_paths: [dynamic]^Path,
    active_paths_mutex: sync.Mutex,

    possible_node_position: rl.Vector2,

    tool_selected: Tool,

    selected_node_for_path: ^Node,
    selected_node: ^Node,

    playing: bool,
}

canvas: ^Canvas

CanvasData :: struct {
    nodes: [dynamic]NodeData,
}

canvas_get_data :: proc() -> CanvasData {
    log.debug("Generating canvas data")
    nodes_data := make([dynamic]NodeData, 0, len(canvas.nodes))

    for _, node in canvas.nodes {
        append(&nodes_data, node_get_data(node))
    }

    return CanvasData{ nodes=nodes_data }
}

canvas_data_delete :: proc(canvas_data: CanvasData) {
    for node in canvas_data.nodes {
        node_data_delete(node)
    }
    delete(canvas_data.nodes)
}

canvas_init :: proc() {
    canvas = new(Canvas)

    canvas.window_height = rl.GetScreenHeight()
    canvas.window_width = rl.GetScreenWidth()

    canvas.camera.zoom = 1.0
    canvas.camera.target = {f32(canvas.window_width) / 2.0, f32(canvas.window_height) / 2.0}
    canvas.camera.offset = {f32(canvas.window_width) / 2.0, f32(canvas.window_height) / 2.0}
    canvas.camera.rotation = 0.0

    canvas.subdivision = SUBDIVISION

    canvas.nodes = make(map[Point]^Node)
    canvas.node_delete_queue = make([dynamic]^Node)
    canvas.node_stop_queue = make([dynamic]^Node)

    canvas.active_paths = make([dynamic]^Path, 0, 30)
}

canvas_deinit :: proc() {
    log.debug("Freeing canvas")

    canvas_stop_playing()
    for _, node in canvas.nodes {
        node_free(node)
    }

    delete(canvas.nodes)
    delete(canvas.node_delete_queue)
    delete(canvas.node_stop_queue)
    delete(canvas.active_paths)
    free(canvas)
    canvas = nil
}

canvas_load_from_data :: proc(canvas_data: CanvasData) {
    nodes_by_id := make(map[NodeID]^Node)
    defer delete(nodes_by_id)

    for node_data in canvas_data.nodes {
        nodes_by_id[node_data.id] = canvas_add_node(node_data)
    }

    for node_data in canvas_data.nodes {
        for path_data in node_data.next_paths {
            start_node := nodes_by_id[path_data.start]
            new_path := path_new(start_node, nodes_by_id[path_data.end])
            node_add_path(start_node, new_path)
        }
    }
}

canvas_load_file :: proc(path: string) {
    data, ok := os.read_entire_file(path)
    defer delete(data)

    if !ok {
        log.warnf("Error reading file %v", path)
        return
    }

    log.debugf("Unmarshaling canvas data")
    canvas_data: CanvasData
    err : json.Unmarshal_Error= json.unmarshal(data, &canvas_data)
    defer canvas_data_delete(canvas_data)

    if err != nil {
        log.warnf("Error unmarshalling data: %v", err)
        return
    }

    canvas_deinit()
    canvas_init()
    canvas_load_from_data(canvas_data)
}

canvas_serialize :: proc(path: string) {
    canvas_data := canvas_get_data()
    defer canvas_data_delete(canvas_data)

    log.debugf("Marshaling canvas data")

    when ODIN_DEBUG {
        data, err := json.marshal(canvas_data, {pretty=true})
    } else {
        data, err := json.marshal(canvas_data)
    }

    defer delete(data)

    switch v in err {
    case io.Error:
        if v != .None {
            log.warnf("IO Error trying to serialize canvas: %v", v)
            return
        }
    case json.Marshal_Data_Error:
        if v != .None {
            log.warnf("Marshal Error trying to serialize canvas: %v", err)
            return
        }
    }

    log.debugf("Writing canvas data to %v", path)
    ok := os.write_entire_file(path, data)
    if !ok {
        log.warnf("Error writing to file %v", path)
    }
}

canvas_draw :: proc() {
    rl.ClearBackground(BG_COLOR)
    rl.BeginMode2D(canvas.camera)
        canvas_draw_grid()
        canvas_draw_possible_elements()
        canvas_draw_nodes()
    rl.EndMode2D()
    canvas_gui_draw_and_update()
}

canvas_stop_playing_nodes :: proc() {
    node_stop_slice := canvas.node_stop_queue[:]
    clear(&canvas.node_stop_queue)

    for node in node_stop_slice {
        node_stop_playing(node)
    }
}

canvas_schedule_node_stop :: proc(node: ^Node) {
    append(&canvas.node_stop_queue, node)
}

canvas_stop_playing :: proc() {
    canvas.playing = false

    midi_stop_all_notes()
    for path in canvas.active_paths {
        path_deactivate(path)
    }
    clear(&canvas.active_paths)
}

canvas_start_playing :: proc() {
    canvas.playing = true
    for _, node in canvas.nodes {
        if node.begining {
            node_play(node)
        }
    }
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

    if canvas.selected_node != nil {
        node_draw_being_edited(canvas.selected_node)
    }
}

canvas_draw_grid :: proc() {
    camera_position: rl.Vector2 = canvas.camera.target - canvas.camera.offset
    step_size := f32(NODE_SEPARATION * canvas.subdivision)
    zoom_offset := ZOOM_OFFSET_GRID / canvas.camera.zoom

    offset_x := math.mod_f32(camera_position.x, f32(step_size))
    offset_y := math.mod_f32(camera_position.y, f32(step_size))

    // Vertical lines
    for i := camera_position.x - offset_x;
    i < f32(canvas.window_width) + camera_position.x + zoom_offset;
    i += step_size {
        rl.DrawLineV(
            {i, camera_position.y - zoom_offset},
            {i, f32(canvas.window_height) + camera_position.y + zoom_offset},
            LINES_COLOR
        )
    }

    // Horizontal lines
    for i := camera_position.y - offset_y;
    i < f32(canvas.window_height) + camera_position.y + zoom_offset;
    i += step_size {
        rl.DrawLineV(
            {camera_position.x - zoom_offset, i},
            {f32(canvas.window_width) + camera_position.x + zoom_offset, i},
            LINES_COLOR
        )
    }

    offset_x = math.mod_f32(camera_position.x, f32(NODE_SEPARATION))
    offset_y = math.mod_f32(camera_position.y, f32(NODE_SEPARATION))

    // Points
    for i:= camera_position.x - offset_x;
    i < f32(canvas.window_width) + camera_position.x + zoom_offset;
    i += NODE_SEPARATION {
        for j:= camera_position.y - offset_y;
        j < f32(canvas.window_height) + camera_position.y + zoom_offset;
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
    possible_point := point_from_vector(canvas.possible_node_position)
    possible_node, ok := canvas.nodes[possible_point]

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
    if canvas.selected_node_for_path != nil {
    start_position := point_get_position(canvas.selected_node_for_path.point)
        end_position := canvas_get_relative_mouse_position()

        draw_path(start_position, end_position)
    }
}

canvas_update :: proc() {
    canvas_update_camera()
    canvas_update_possible_node_position()

    canvas_handle_input()

    for _, node in canvas.nodes {
        node_update(node)
    }

    canvas_clear_node_delete_queue()
    if len(canvas.active_paths) == 0 {
        canvas_stop_playing()
    }
}

canvas_inc_all_selected_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.selected {
            node_inc_note(node)
        }
    }
}


canvas_dec_all_selected_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.selected {
            node_dec_note(node)
        }
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

            if node == canvas.selected_node {
                canvas.selected_node = nil
            }
        }
    }
}

canvas_clear_node_delete_queue :: proc() {
    for node in canvas.node_delete_queue {
        node_free(node)
    }

    clear(&canvas.node_delete_queue)
}

canvas_create_new_node :: proc(position: rl.Vector2) {
    possible_point := point_from_vector(position)

    if !(possible_point in canvas.nodes) {
        new_node := node_new(possible_point)
        canvas.nodes[possible_point] = new_node
    }
}

canvas_add_node :: proc(node_data: NodeData) -> ^Node {
    new_node := node_new_from_data(node_data)
    canvas.nodes[new_node.point] = new_node
    return new_node
}

canvas_update_camera :: proc() {
    canvas.camera.zoom += (f32(rl.GetMouseWheelMove()) * ZOOM_SPEED)

    if canvas.camera.zoom > MAX_ZOOM do canvas.camera.zoom = MAX_ZOOM
    if canvas.camera.zoom < MIN_ZOOM do canvas.camera.zoom = MIN_ZOOM

    if rl.IsMouseButtonDown(.MIDDLE) {
        canvas.camera.target -= rl.GetMouseDelta()
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
    camera_position := canvas.camera.target - canvas.camera.offset
    position := rl.GetMousePosition()

    return position + camera_position
}

canvas_add_active_path :: proc(path: ^Path) {
    sync.mutex_lock(&canvas.active_paths_mutex)
    append(&canvas.active_paths, path)
    sync.mutex_unlock(&canvas.active_paths_mutex)
}

canvas_metronome_ping :: proc() {
    if canvas == nil do return

    canvas_stop_playing_nodes()
    active_paths_slice := canvas.active_paths[:]
    clear(&canvas.active_paths)

    for path in active_paths_slice {
        path_update(path)
        if path.active {
            canvas_add_active_path(path)
        }
    }
}
