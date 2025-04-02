package canvas

import rl "vendor:raylib"

import "../graph"

Tool :: enum {
    MouseTool,
    NodeTool,
    NormalPathTool,
    TransferPathTool,
}

handle_input :: proc() {
    switch canvas.tool_selected {
    case .NodeTool:
        handle_node_tool_input()
    case .NormalPathTool, .TransferPathTool:
        handle_path_tool_input()
    case .MouseTool:
        handle_mouse_tool_input()
    }
}

change_tool :: proc(tool: Tool) {
    canvas.tool_selected = tool
}

handle_mouse_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := graph.point_from_vector(canvas.possible_node_position)

        monoselection := !rl.IsKeyDown(.LEFT_CONTROL) && !rl.IsKeyDown(.RIGHT_CONTROL)
        if monoselection {
            unselect_all_nodes()
        }

        possible_node, ok := canvas.nodes[possible_point]
        if !ok do return

        possible_node.selected = true
    }

    if rl.IsKeyPressed(.DELETE) {
        delete_all_selected_nodes()
    }

    if rl.IsKeyPressed(.SPACE) {
        set_begining_nodes()
    }

    if rl.IsKeyPressed(.UP) {
        inc_all_selected_nodes()
    }

    if rl.IsKeyPressed(.DOWN) {
        dec_all_selected_nodes()
    }
}

handle_node_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        create_new_node(canvas.possible_node_position)
    }
}

handle_path_tool_input :: proc() {
    if rl.IsMouseButtonPressed(.LEFT) {
        possible_point := graph.point_from_vector(canvas.possible_node_position)
        possible_node, ok := canvas.nodes[possible_point]

        if !ok {
            canvas.selected_node_for_path = nil
            return
        }

        if canvas.selected_node_for_path == nil {
            canvas.selected_node_for_path = possible_node
        } else {
            if canvas.selected_node_for_path == possible_node do return

            path_type: graph.PathType
            #partial switch canvas.tool_selected {
            case .NormalPathTool: path_type = .Normal
            case .TransferPathTool: path_type = .Transfer
            }

            path := graph.path_new(canvas.selected_node_for_path, possible_node, path_type)
            graph.node_add_path(canvas.selected_node_for_path, path)
            canvas.selected_node_for_path = nil
        }
    }
}
