package main

import rl "vendor:raylib"

Tool :: enum {
    MouseTool,
    NodeTool,
    NormalPathTool,
    TransferPathTool,
}

canvas_handle_input :: proc() {
    switch canvas.tool_selected {
    case .NodeTool:
        canvas_handle_node_tool_input()
    case .NormalPathTool, .TransferPathTool:
        canvas_handle_path_tool_input()
    case .MouseTool:
        canvas_handle_mouse_tool_input()
    }
}

canvas_change_tool :: proc(tool: Tool) {
    canvas.tool_selected = tool
}

canvas_handle_mouse_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := point_from_vector(canvas.possible_node_position)

        monoselection := !rl.IsKeyDown(.LEFT_CONTROL) && !rl.IsKeyDown(.RIGHT_CONTROL)
        if monoselection {
            canvas_unselect_all_nodes()
        }

        possible_node, ok := canvas.nodes[possible_point]
        if !ok do return

        possible_node.selected = true
    }

    if rl.IsKeyPressed(.DELETE) {
        canvas_delete_all_selected_nodes()
    }

    if rl.IsKeyPressed(.SPACE) {
        canvas_set_begining_nodes()
    }

    if rl.IsKeyPressed(.UP) {
        canvas_inc_all_selected_nodes()
    }

    if rl.IsKeyPressed(.DOWN) {
        canvas_dec_all_selected_nodes()
    }
}

canvas_handle_node_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        canvas_create_new_node(canvas.possible_node_position)
    }
}

canvas_handle_path_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := point_from_vector(canvas.possible_node_position)
        possible_node, ok := canvas.nodes[possible_point]

        if !ok {
            canvas.selected_node_for_path = nil
            return
        }

        if canvas.selected_node_for_path == nil {
            canvas.selected_node_for_path = possible_node
        } else {
            if canvas.selected_node_for_path == possible_node do return

            path_type: PathType
            #partial switch canvas.tool_selected {
            case .NormalPathTool: path_type = .Normal
            case .TransferPathTool: path_type = .Transfer
            }

            path := path_new(canvas.selected_node_for_path, possible_node, path_type)
            node_add_path(canvas.selected_node_for_path, path)
            canvas.selected_node_for_path = nil
        }
    }
}
