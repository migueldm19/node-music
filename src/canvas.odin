package main

import rl "vendor:raylib"
import "core:math"

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

    possible_node_position: rl.Vector2,

    tool_selected: Tool,

    selected_node_for_path: ^Node,
}

canvas_new :: proc() -> ^Canvas {
    canvas := new(Canvas)
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

    n1 := node_new(Point{6, 3})
    n2 := node_new(Point{5, 5})
    n3 := node_new(Point{7, 4})

    p1 := path_new(n1, n2)
    p2 := path_new(n2, n3)
    p3 := path_new(n3, n1)

    node_add_path(n1, p1)
    node_add_path(n1, p2)
    node_add_path(n3, p3)

    nodes[n1.point] = n1
    nodes[n2.point] = n2
    nodes[n3.point] = n3

    node_play(n1)

    return canvas
}

canvas_free :: proc(canvas: ^Canvas) {
    using canvas

    for _, node in nodes {
        node_free(node)
    }

    delete(nodes)
    delete(node_delete_queue)
    free(canvas)
}

canvas_draw :: proc(canvas: ^Canvas) {
    rl.ClearBackground(BG_COLOR)
    rl.BeginMode2D(canvas.camera)
        canvas_draw_grid(canvas)
        canvas_draw_possible_elements(canvas)
        canvas_draw_nodes(canvas)
    rl.EndMode2D()
    canvas_draw_and_update_ui(canvas)
}

canvas_draw_and_update_ui :: proc(canvas: ^Canvas) {
    rl.GuiToggleGroup({30, 30, 120, 30}, TOOLS, (^i32)(&canvas.tool_selected))
}

canvas_draw_possible_elements :: proc(canvas: ^Canvas) {
    switch canvas.tool_selected {
    case .MOUSE_TOOL:
        canvas_draw_possible_selection(canvas)
    case .NODE_TOOL:
        canvas_draw_possible_node(canvas)
    case .PATH_TOOL:
        canvas_draw_possible_path(canvas)
        canvas_draw_possible_selection(canvas)
    }
}

canvas_draw_nodes :: proc(canvas: ^Canvas) {
    for _, node in canvas.nodes {
        node_draw(node)
    }
}

canvas_draw_grid :: proc(canvas: ^Canvas) {
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

canvas_draw_possible_selection :: proc(canvas: ^Canvas) {
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

canvas_draw_possible_node :: proc(canvas: ^Canvas) {
    rl.DrawCircleLinesV(canvas.possible_node_position, NODE_RADIUS / 2, NODE_COLOR)
}

canvas_draw_possible_path :: proc(canvas: ^Canvas) {
    using canvas

    if selected_node_for_path != nil {
        start_position := point_get_position(selected_node_for_path.point)
        end_position := canvas_get_relative_mouse_position(canvas)

        dir := get_direction(start_position, end_position)
        draw_path(start_position, end_position, dir)
    }
}

canvas_update :: proc(canvas: ^Canvas) {
    using canvas

    canvas_update_camera(canvas)
    canvas_update_possible_node_position(canvas)

    canvas_handle_input(canvas)

    for _, node in nodes {
        node_update(node)
    }

    canvas_clear_node_delete_queue(canvas)
}

canvas_handle_input :: proc(canvas: ^Canvas) {
    switch canvas.tool_selected {
    case .NODE_TOOL:
        canvas_handle_node_tool_input(canvas)
    case .PATH_TOOL:
        canvas_handle_path_tool_input(canvas)
    case .MOUSE_TOOL:
        canvas_handle_mouse_tool_input(canvas)
    }
}

canvas_handle_mouse_tool_input :: proc(canvas: ^Canvas) {
    using canvas

    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := point_from_vector(possible_node_position)

        if !rl.IsKeyDown(.LEFT_CONTROL) && !rl.IsKeyDown(.RIGHT_CONTROL) {
            canvas_unselect_all_nodes(canvas)
        }

        possible_node, ok := nodes[possible_point]
        if !ok do return

        possible_node.selected = true
    }
    
    if rl.IsKeyPressed(.DELETE) {
        canvas_delete_all_selected_nodes(canvas)
    }
}

canvas_unselect_all_nodes :: proc(canvas: ^Canvas) {
    for _, node in canvas.nodes {
        node.selected = false
    }
}

canvas_delete_all_selected_nodes :: proc(canvas: ^Canvas) {
    for point, node in canvas.nodes {
        if node.selected {
            node.deleted = true
            delete_key(&canvas.nodes, point)
            append(&canvas.node_delete_queue, node)
        }
    }
}

canvas_clear_node_delete_queue :: proc(canvas: ^Canvas) {
    for node in canvas.node_delete_queue {
        node_free(node)
    }

    clear(&canvas.node_delete_queue)
}

canvas_handle_node_tool_input :: proc(canvas: ^Canvas) {
    if rl.IsMouseButtonPressed(.LEFT) {
        canvas_create_new_node(canvas, canvas.possible_node_position)
    }
}

canvas_create_new_node :: proc(canvas: ^Canvas, position: rl.Vector2) {
    possible_point := point_from_vector(position)

    if !(possible_point in canvas.nodes) {
        new_node := node_new(possible_point)
        canvas.nodes[possible_point] = new_node
    }
}

canvas_handle_path_tool_input :: proc(canvas: ^Canvas) {
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

canvas_update_camera :: proc(canvas: ^Canvas) {
    using canvas

    camera.zoom += (f32(rl.GetMouseWheelMove()) * ZOOM_SPEED)

    if camera.zoom > MAX_ZOOM do camera.zoom = MAX_ZOOM
    if camera.zoom < MIN_ZOOM do camera.zoom = MIN_ZOOM

    if rl.IsMouseButtonDown(.MIDDLE) {
        camera.target -= rl.GetMouseDelta()
    }
}

canvas_update_possible_node_position :: proc(canvas: ^Canvas) {
    pos := canvas_get_relative_mouse_position(canvas)

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

canvas_get_relative_mouse_position :: proc(canvas: ^Canvas) -> rl.Vector2 {
    using canvas

    camera_position := camera.target - camera.offset
    position := rl.GetMousePosition()

    return position + camera_position
}