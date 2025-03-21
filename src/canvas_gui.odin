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
import "core:c"

PLAY_BUTTON :: "#131#"
STOP_BUTTON :: "#133#"

canvas_gui_draw_and_update :: proc() {
    canvas_gui_tool_selection()
    canvas_gui_play_stop()

    canvas_gui_begin()
        canvas_gui_menu_bar()
        canvas_gui_node()
    canvas_gui_end()
}

canvas_gui_menu_bar :: proc() {
    openSavePopup: bool

    if imgui.BeginMainMenuBar() {
        if imgui.BeginMenu("File") {
            openSavePopup = imgui.MenuItem("Save", "Ctrl+S")
            imgui.EndMenu()
        }

        if openSavePopup do imgui.OpenPopup("Path")
        canvas_gui_save_menu()

        imgui.EndMainMenuBar()
    }
}

canvas_gui_save_menu :: proc() {
    if imgui.BeginPopupModal("Path", nil, {.AlwaysAutoResize}) {
        if imgui.Button("Save") {
            canvas_serialize("canvas.json")
        }
        if imgui.Button("Close") {
            imgui.CloseCurrentPopup()
        }
        imgui.EndPopup()
    }
}

canvas_gui_tool_selection :: proc() {
    rl.GuiToggleGroup(rl.Rectangle{100, 100, 120, 30}, TOOLS, (^i32)(&canvas.tool_selected))
}

canvas_gui_play_stop :: proc() {
	if canvas.playing {
        if rl.GuiButton(rl.Rectangle{800, 30, 30, 30}, STOP_BUTTON) {
            canvas_stop_playing()
        }
    } else {
        if rl.GuiButton(rl.Rectangle{800, 30, 30, 30}, PLAY_BUTTON) {
            canvas_start_playing()
        }
    }
}

canvas_gui_node :: proc() {
    if node := canvas.selected_node; node != nil {
        if imgui.Begin("Node") {
            if imgui.Button("Increase note") do node_inc_note(node)
            imgui.Text(note_to_string(node.current_note))
            if imgui.Button("Decrease note") do node_dec_note(node)
            imgui.Checkbox("Begining", &node.begining)
        }
        imgui.End()
    }
}

canvas_gui_init :: proc() {
    log.debug("Initializing ImGui")
    imgui.CreateContext()
    window := rl.GetWindowHandle()
    imgui_impl_glfw.InitForOpenGL(cast(glfw.WindowHandle) window, true)
    imgui_impl_opengl3.Init("#version 150")
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
