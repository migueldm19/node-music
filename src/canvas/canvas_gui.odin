package canvas

import rl "vendor:raylib"
import glfw "vendor:glfw"
import imgui "../../deps/odin-imgui"
import "../../deps/odin-imgui/imgui_impl_opengl3"
import "../../deps/odin-imgui/imgui_impl_glfw"
import "core:log"
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:c"

import "../midi"
import "../graph"
import "../config"

gui_draw_and_update :: proc() {
    gui_begin()
        gui_main_menu()
        gui_menu_bar()
        gui_node()
    gui_end()
}

gui_menu_bar :: proc() {
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

        gui_save_menu()
        gui_load_menu()

        imgui.EndMainMenuBar()
    }
}

//TODO: See how to input text for path (or open file manager)
gui_save_menu :: proc() {
    if imgui.BeginPopupModal("Save path", nil, {.AlwaysAutoResize}) {
        if imgui.Button("Save") {
            serialize("canvas.json")
            imgui.CloseCurrentPopup()
        }
        imgui.SameLine()
        if imgui.Button("Close") {
            imgui.CloseCurrentPopup()
        }
        imgui.EndPopup()
    }
}

gui_load_menu :: proc() {
    if imgui.BeginPopupModal("Load path", nil, {.AlwaysAutoResize}) {
        if imgui.Button("Load") {
            load_from_file("canvas.json")
            imgui.CloseCurrentPopup()
        }
        imgui.SameLine()
        if imgui.Button("Close") {
            imgui.CloseCurrentPopup()
        }
        imgui.EndPopup()
    }
}

gui_main_menu:: proc() {
    //TODO: Change with logos?
    if imgui.Begin("Main menu") {
        gui_play_stop()
        gui_main_config()
        gui_tool_selection()
    }
    imgui.End()
}

gui_main_config :: proc() {
    new_config := canvas.config
    imgui.InputInt("BPM", &new_config.bpm)
    imgui.InputInt("Subdivision", &new_config.subdivision)
    if new_config.bpm != canvas.config.bpm &&
       new_config.bpm > 0 &&
       new_config.bpm <= config.MAX_BPM {
        canvas.config.bpm = new_config.bpm
        metronome_update_sleep_time()
    }
    if new_config.subdivision != canvas.config.subdivision &&
       new_config.subdivision > 0 &&
       new_config.subdivision <= config.MAX_SUBDIVISION {
        canvas.config.subdivision = new_config.subdivision
        metronome_update_sleep_time()
    }
}

gui_tool_selection :: proc() {
    imgui.Text("Tools")
    if imgui.RadioButton("Mouse", canvas.tool_selected == .MouseTool) {
        change_tool(.MouseTool)
    }
    if imgui.RadioButton("Node", canvas.tool_selected == .NodeTool) {
        change_tool(.NodeTool)
    }
    if imgui.RadioButton("Path", canvas.tool_selected == .NormalPathTool) {
        change_tool(.NormalPathTool)
    }
    imgui.SameLine()
    if imgui.RadioButton("Transfer", canvas.tool_selected == .TransferPathTool) {
        change_tool(.TransferPathTool)
    }
}

gui_play_stop :: proc() {
    if canvas.playing {
        if imgui.Button("Stop") {
            stop_playing()
        }
    } else {
        if imgui.Button("Play") {
            start_playing()
        }
    }
}

possible_notes_for_node: [128]cstring
gui_node :: proc() {
    for _, node in canvas.nodes {
        if !node.selected do continue

        if imgui.Begin(fmt.ctprintf("Node %v", node.id)) {
            gui_node_properties(node)
            gui_note_selection(node)
            gui_egress_paths(node)
        }
        imgui.End()
    }
}

gui_node_properties :: proc(node: ^graph.Node) {
    if imgui.CollapsingHeader("Properties", {.DefaultOpen}) {
        imgui.Checkbox("Begining", &node.begining)
        channel: c.int = i32(node.channel)
        imgui.InputInt("Channel", &channel)
        channel = channel & 0xF
        node.channel = u8(channel)
    }
}

gui_note_selection :: proc(node: ^graph.Node) {
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
                graph.node_change_note(node, midi.Note(selected_note))
            }
        }
    }
}

gui_egress_paths :: proc(node: ^graph.Node) {
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

gui_init :: proc() {
    log.debug("Initializing ImGui")
    imgui.CreateContext()
    window := rl.GetWindowHandle()
    imgui_impl_glfw.InitForOpenGL(cast(glfw.WindowHandle) window, true)
    imgui_impl_opengl3.Init("#version 150")

    notes_str : [128]string
    for i in 0..<128 {
        possible_notes_for_node[i] = midi.note_to_string(midi.Note(i))
    }
}

gui_deinit :: proc() {
    log.debug("Deinitializing ImGui opengl")
    defer imgui_impl_opengl3.Shutdown()
    // log.debug("Deinitializing ImGui glfw")
    // imgui_impl_glfw.Shutdown()
    log.debug("Deinitializing ImGui context")
    //imgui.DestroyContext()
}

gui_begin :: proc() {
    imgui_impl_opengl3.NewFrame()
	imgui_impl_glfw.NewFrame()
    imgui.NewFrame()
}

gui_end :: proc() {
    imgui.Render()
    imgui_impl_opengl3.RenderDrawData(imgui.GetDrawData())
}
