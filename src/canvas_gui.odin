package main

import rl "vendor:raylib"
import glfw "vendor:glfw"
import imgui "../deps/odin-imgui"
import "../deps/odin-imgui/imgui_impl_opengl3"
import "../deps/odin-imgui/imgui_impl_glfw"
import "core:log"
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:c"

canvas_gui_draw_and_update :: proc() {
    canvas_gui_begin()
        canvas_gui_main_menu()
        canvas_gui_menu_bar()
        canvas_gui_node()
    canvas_gui_end()
}

canvas_gui_menu_bar :: proc() {
    openSavePopup: bool
    openLoadPopup: bool

    if imgui.BeginMainMenuBar() {
        if imgui.BeginMenu("File") {
            openSavePopup = imgui.MenuItem("Save", "Ctrl+S") // TODO: shortcuts
            openLoadPopup = imgui.MenuItem("Open", "Ctrl+O")
            imgui.EndMenu()
        }

        if openSavePopup do imgui.OpenPopup("Save path")
        if openLoadPopup do imgui.OpenPopup("Load path")

        canvas_gui_save_menu()
        canvas_gui_load_menu()

        imgui.EndMainMenuBar()
    }
}

//TODO: See how to input text for path (or open file manager)
canvas_gui_save_menu :: proc() {
    if imgui.BeginPopupModal("Save path", nil, {.AlwaysAutoResize}) {
        if imgui.Button("Save") {
            canvas_serialize("canvas.json")
            imgui.CloseCurrentPopup()
        }
        imgui.SameLine()
        if imgui.Button("Close") {
            imgui.CloseCurrentPopup()
        }
        imgui.EndPopup()
    }
}

canvas_gui_load_menu :: proc() {
    if imgui.BeginPopupModal("Load path", nil, {.AlwaysAutoResize}) {
        if imgui.Button("Load") {
            canvas_load_file("canvas.json")
            imgui.CloseCurrentPopup()
        }
        imgui.SameLine()
        if imgui.Button("Close") {
            imgui.CloseCurrentPopup()
        }
        imgui.EndPopup()
    }
}

canvas_gui_main_menu:: proc() {
    //TODO: Change with logos?
    if imgui.Begin("Main menu") {
        canvas_gui_play_stop()
        canvas_gui_tool_selection()
    }
    imgui.End()
}

canvas_gui_tool_selection :: proc() {
    imgui.Text("Tools")
    if imgui.RadioButton("Mouse", canvas.tool_selected == .MouseTool) {
        canvas_change_tool(.MouseTool)
    }
    if imgui.RadioButton("Node", canvas.tool_selected == .NodeTool) {
        canvas_change_tool(.NodeTool)
    }
    if imgui.RadioButton("Path", canvas.tool_selected == .NormalPathTool) {
        canvas_change_tool(.NormalPathTool)
    }
    imgui.SameLine()
    if imgui.RadioButton("Transfer", canvas.tool_selected == .TransferPathTool) {
        canvas_change_tool(.TransferPathTool)
    }
}

canvas_gui_play_stop :: proc() {
    if canvas.playing {
        if imgui.Button("Stop") {
            canvas_stop_playing()
        }
    } else {
        if imgui.Button("Play") {
            canvas_start_playing()
        }
    }
}

possible_notes_for_node: [128]cstring
canvas_gui_node :: proc() {
    for _, node in canvas.nodes {
        if !node.selected do continue

        if imgui.Begin(fmt.ctprintf("Node %v", node.id)) {
            canvas_gui_node_properties(node)
            canvas_gui_note_selection(node)
            canvas_gui_egress_paths(node)
        }
        imgui.End()
    }
}

canvas_gui_node_properties :: proc(node: ^Node) {
    if imgui.CollapsingHeader("Properties", {.DefaultOpen}) {
        imgui.Checkbox("Begining", &node.begining)
        channel: c.int = i32(node.channel)
        imgui.InputInt("Channel", &channel)
        channel = channel & 0xF
        node.channel = u8(channel)
    }
}

canvas_gui_note_selection :: proc(node: ^Node) {
    if imgui.CollapsingHeader("Note selection", {.DefaultOpen}) {
        imgui.Checkbox("Random notes", &node.random_note)
        if !node.random_note {
            selected_note: c.int = i32(node.current_note)
            imgui.ComboChar(
                possible_notes_for_node[node.current_note],
                &selected_note,
                raw_data(possible_notes_for_node[:]),
                128
            )

            if imgui.IsItemEdited() {
                log.debugf("selected %v", selected_note)
                node_change_note(node, Note(selected_note))
            }
        }
    }
}

canvas_gui_egress_paths :: proc(node: ^Node) {
    if len(node.next_paths) == 0 do return
    if imgui.CollapsingHeader("Egress paths", {.DefaultOpen}) {
        for path in node.next_paths {
            if imgui.CollapsingHeader(fmt.ctprint("Path to node", path.end.id)) {
                imgui.InputFloat("Probability", &path.probability, 0.05, 0.0, "%.2f")
                if path.probability > 1.0 do path.probability = 1.0
                if path.probability < 0.0 do path.probability = 0.0
            }
        }
    }
}

canvas_gui_init :: proc() {
    log.debug("Initializing ImGui")
    imgui.CreateContext()
    window := rl.GetWindowHandle()
    imgui_impl_glfw.InitForOpenGL(cast(glfw.WindowHandle) window, true)
    imgui_impl_opengl3.Init("#version 150")

    notes_str : [128]string
    for i in 0..<128 {
        possible_notes_for_node[i] = note_to_string(Note(i))
    }
}

canvas_gui_deinit :: proc() {
    log.debug("Deinitializing ImGui opengl")
    defer imgui_impl_opengl3.Shutdown()
    // log.debug("Deinitializing ImGui glfw")
    // imgui_impl_glfw.Shutdown()
    log.debug("Deinitializing ImGui context")
    //imgui.DestroyContext()
}

canvas_gui_begin :: proc() {
    imgui_impl_opengl3.NewFrame()
	imgui_impl_glfw.NewFrame()
    imgui.NewFrame()
}

canvas_gui_end :: proc() {
    imgui.Render()
    imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())
}
