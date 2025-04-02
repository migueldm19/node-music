package canvas

import rl "vendor:raylib"
import imgui "../../deps/odin-imgui"
import "core:math"
import "core:log"
import "core:sync"
import "core:encoding/json"
import "core:io"
import "core:os"
import "core:slice"

import "../midi"
import "../graph"
import "../config"

Canvas :: struct {
    camera: rl.Camera2D,

    window_height: i32,
    window_width: i32,

    config: CanvasConfiguration,

    nodes: map[graph.Point]^graph.Node,
    node_delete_queue: [dynamic]^graph.Node,

    active_paths: [dynamic]^graph.Path,
    active_paths_mutex: sync.Mutex,

    possible_node_position: rl.Vector2,

    tool_selected: Tool,

    selected_node_for_path: ^graph.Node,

    playing: bool,
}

CanvasConfiguration :: struct {
    subdivision: i32,
    bpm: i32,
}

canvas: ^Canvas

CanvasData :: struct {
    config: CanvasConfiguration,
    nodes: [dynamic]graph.NodeData,
}

get_data :: proc() -> CanvasData {
    log.debug("Generating canvas data")
    nodes_data := make([dynamic]graph.NodeData, 0, len(canvas.nodes))

    for _, node in canvas.nodes {
        append(&nodes_data, graph.node_get_data(node))
    }

    return CanvasData{ nodes=nodes_data, config=canvas.config }
}

data_delete :: proc(canvas_data: CanvasData) {
    for node in canvas_data.nodes {
        graph.node_data_delete(node)
    }
    delete(canvas_data.nodes)
}

init :: proc() {
    canvas = new(Canvas)

    canvas.window_height = rl.GetScreenHeight()
    canvas.window_width = rl.GetScreenWidth()

    canvas.camera.zoom = 1.0
    canvas.camera.target = {f32(canvas.window_width) / 2.0, f32(canvas.window_height) / 2.0}
    canvas.camera.offset = {f32(canvas.window_width) / 2.0, f32(canvas.window_height) / 2.0}
    canvas.camera.rotation = 0.0

    canvas.config.subdivision = 4
    canvas.config.bpm = 60

    canvas.nodes = make(map[graph.Point]^graph.Node)
    canvas.node_delete_queue = make([dynamic]^graph.Node)

    canvas.active_paths = make([dynamic]^graph.Path, 0, 30)
}

deinit :: proc() {
    log.debug("Freeing canvas")

    stop_playing()
    for _, node in canvas.nodes {
        graph.node_free(node)
    }

    delete(canvas.nodes)
    delete(canvas.node_delete_queue)
    delete(canvas.active_paths)
    free(canvas)
    canvas = nil
}

load_from_data :: proc(canvas_data: CanvasData) {
    nodes_by_id := make(map[graph.NodeID]^graph.Node)
    defer delete(nodes_by_id)

    for node_data in canvas_data.nodes {
        nodes_by_id[node_data.id] = add_node(node_data)
    }

    for node_data in canvas_data.nodes {
        for path_data in node_data.next_paths {
            start_node := nodes_by_id[path_data.start]
            new_path := graph.path_new(start_node, nodes_by_id[path_data.end], path_data.type, path_data.probability)
            graph.node_add_path(start_node, new_path)
        }
    }

    canvas.config = canvas_data.config
}

load_from_file :: proc(path: string) {
    data, ok := os.read_entire_file(path)
    defer delete(data)

    if !ok {
        log.warnf("Error reading file %v", path)
        return
    }

    log.debugf("Unmarshaling canvas data")
    canvas_data: CanvasData
    err : json.Unmarshal_Error= json.unmarshal(data, &canvas_data)
    defer data_delete(canvas_data)

    if err != nil {
        log.warnf("Error unmarshalling data: %v", err)
        return
    }

    deinit()
    init()
    load_from_data(canvas_data)
}

serialize :: proc(path: string) {
    canvas_data := get_data()
    defer data_delete(canvas_data)

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

draw :: proc() {
    rl.ClearBackground(config.BG_COLOR)
    rl.BeginMode2D(canvas.camera)
        draw_grid()
        draw_possible_elements()
        draw_nodes()
    rl.EndMode2D()
    gui_draw_and_update()
}

stop_playing_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.playing do graph.node_stop_playing(node)
    }
}

stop_playing :: proc() {
    canvas.playing = false

    stop_playing_nodes()
    for path in canvas.active_paths {
        graph.path_deactivate(path)
    }
    clear(&canvas.active_paths)
    midi.stop_all_notes()
}

start_playing :: proc() {
    canvas.playing = true
    for _, node in canvas.nodes {
        if node.begining {
            graph.node_play(node)
        }
    }
}

draw_possible_elements :: proc() {
    switch canvas.tool_selected {
    case .MouseTool:
        draw_possible_selection()
    case .NodeTool:
        draw_possible_node()
    case .NormalPathTool, .TransferPathTool:
        draw_possible_path()
        draw_possible_selection()
    }
}

draw_nodes :: proc() {
    for _, node in canvas.nodes {
        graph.node_draw(node)
    }
}

draw_grid :: proc() {
    camera_position: rl.Vector2 = canvas.camera.target - canvas.camera.offset
    step_size := f32(config.NODE_SEPARATION * canvas.config.subdivision)

    zoom_offset: f32
    if canvas.camera.zoom < 1 {
        zoom_offset = config.ZOOM_OFFSET_GRID / canvas.camera.zoom
    }

    offset_x := math.mod_f32(camera_position.x - zoom_offset, f32(step_size))
    offset_y := math.mod_f32(camera_position.y - zoom_offset, f32(step_size))

    // Vertical lines
    for i := camera_position.x - offset_x - zoom_offset;
    i < f32(canvas.window_width) + camera_position.x + zoom_offset;
    i += step_size {
        rl.DrawLineV(
            {i, camera_position.y - zoom_offset},
            {i, f32(canvas.window_height) + camera_position.y + zoom_offset},
            config.LINES_COLOR
        )
    }

    // Horizontal lines
    for i := camera_position.y - offset_y - zoom_offset;
    i < f32(canvas.window_height) + camera_position.y + zoom_offset;
    i += step_size {
        rl.DrawLineV(
            {camera_position.x - zoom_offset, i},
            {f32(canvas.window_width) + camera_position.x + zoom_offset, i},
            config.LINES_COLOR
        )
    }

    offset_x = math.mod_f32(camera_position.x - zoom_offset, f32(config.NODE_SEPARATION))
    offset_y = math.mod_f32(camera_position.y - zoom_offset, f32(config.NODE_SEPARATION))

    // Points
    for i:= camera_position.x - offset_x - zoom_offset;
    i < f32(canvas.window_width) + camera_position.x + zoom_offset;
    i += config.NODE_SEPARATION {
        for j:= camera_position.y - offset_y - zoom_offset;
        j < f32(canvas.window_height) + camera_position.y + zoom_offset;
        j += config.NODE_SEPARATION {
            rl.DrawCircleV({i, j}, config.POINTS_SIZE, config.POINTS_COLOR)
        }
        for j:= camera_position.y - offset_y - zoom_offset;
        j > -zoom_offset - camera_position.x;
        j -= config.NODE_SEPARATION {
            rl.DrawCircleV({i, j}, config.POINTS_SIZE, config.POINTS_COLOR)
        }
    }
}

draw_possible_selection :: proc() {
    possible_point := graph.point_from_vector(canvas.possible_node_position)
    possible_node, ok := canvas.nodes[possible_point]

    if !ok do return

    pos := graph.point_get_position(possible_node.point) - config.NODE_RADIUS

    rl.DrawRectangleRoundedLines(
        rl.Rectangle{pos.x, pos.y, config.NODE_RADIUS * 2, config.NODE_RADIUS * 2},
        0.5,
        4,
        3,
        rl.SKYBLUE
    )
}

draw_possible_node :: proc() {
    rl.DrawCircleLinesV(canvas.possible_node_position, config.NODE_RADIUS / 2, config.NODE_COLOR)
}

draw_possible_path :: proc() {
    if canvas.selected_node_for_path != nil {
    start_position := graph.point_get_position(canvas.selected_node_for_path.point)
        end_position := get_relative_mouse_position()
        type: graph.PathType = .Normal if canvas.tool_selected == .NormalPathTool else .Transfer
        graph.draw_path(start_position, end_position, type)
    }
}

update :: proc() {
    update_camera()
    update_possible_node_position()

    imgui_io := imgui.GetIO()

    if !imgui_io.WantCaptureMouse && !imgui_io.WantCaptureKeyboard {
        handle_input()
    }

    for _, node in canvas.nodes {
        graph.node_update(node)
        for path in node.next_paths {
            if path.active do add_active_path(path)
        }
    }

    clear_node_delete_queue()
    if len(canvas.active_paths) == 0 && canvas.playing {
        stop_playing()
    }
}

inc_all_selected_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.selected {
            graph.node_inc_note(node)
        }
    }
}


dec_all_selected_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.selected {
            graph.node_dec_note(node)
        }
    }
}

set_begining_nodes :: proc() {
    for _, node in canvas.nodes {
        if node.selected {
            node.begining = !node.begining
        }
    }
}

unselect_all_nodes :: proc() {
    for _, node in canvas.nodes {
        node.selected = false
    }
}

delete_all_selected_nodes :: proc() {
    stop_playing()
    for point, node in canvas.nodes {
        if node.selected {
            node.deleted = true
            delete_key(&canvas.nodes, point)
            append(&canvas.node_delete_queue, node)
        }
    }
}

clear_node_delete_queue :: proc() {
    for node in canvas.node_delete_queue {
        graph.node_free(node)
    }

    clear(&canvas.node_delete_queue)
}

create_new_node :: proc(position: rl.Vector2) {
    possible_point := graph.point_from_vector(position)

    if !(possible_point in canvas.nodes) {
        new_node := graph.node_new(possible_point)
        canvas.nodes[possible_point] = new_node
    }
}

add_node :: proc(node_data: graph.NodeData) -> ^graph.Node {
    new_node := graph.node_new_from_data(node_data)
    canvas.nodes[new_node.point] = new_node
    return new_node
}

update_camera :: proc() {
    canvas.camera.zoom += (f32(rl.GetMouseWheelMove()) * config.ZOOM_SPEED)

    if canvas.camera.zoom > config.MAX_ZOOM do canvas.camera.zoom = config.MAX_ZOOM
    if canvas.camera.zoom < config.MIN_ZOOM do canvas.camera.zoom = config.MIN_ZOOM

    if rl.IsMouseButtonDown(.MIDDLE) {
        canvas.camera.target -= rl.GetMouseDelta()
    }
}

update_possible_node_position :: proc() {
    pos := get_relative_mouse_position()

    offset_x := math.mod_f32(pos.x, f32(config.NODE_SEPARATION))
    offset_y := math.mod_f32(pos.y, f32(config.NODE_SEPARATION))

    if math.abs(offset_x) > config.NODE_SEPARATION / 2 {
        offset_x = -(config.NODE_SEPARATION - offset_x) if offset_x > 0 else (config.NODE_SEPARATION + offset_x)
    }
    pos.x -= offset_x

    if math.abs(offset_y) > config.NODE_SEPARATION / 2 {
        offset_y = -(config.NODE_SEPARATION - offset_y) if offset_y > 0 else (config.NODE_SEPARATION + offset_y)
    }
    pos.y -= offset_y

    canvas.possible_node_position = pos
}

get_relative_mouse_position :: proc() -> rl.Vector2 {
    return rl.GetScreenToWorld2D(rl.GetMousePosition(), canvas.camera)
}

add_active_path :: proc(path: ^graph.Path) {
    sync.mutex_lock(&canvas.active_paths_mutex)
    defer sync.mutex_unlock(&canvas.active_paths_mutex)
    if !slice.any_of(canvas.active_paths[:], path) do append(&canvas.active_paths, path)
}

metronome_ping :: proc() {
    if canvas == nil do return

    stop_playing_nodes()
    active_paths_slice := canvas.active_paths[:]
    clear(&canvas.active_paths)

    for path in active_paths_slice {
        graph.path_update(path)
        if path.active {
            add_active_path(path)
        }
    }
}

get_config :: proc() -> CanvasConfiguration {
    return canvas.config
}
