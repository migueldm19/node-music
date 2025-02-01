package main

import rl "vendor:raylib"

PLAY_BUTTON :: "#131#"
STOP_BUTTON :: "#133#"

canvas_gui_draw_and_update :: proc() {
    canvas_gui_tool_selection()
    canvas_gui_play_stop()
}

canvas_gui_tool_selection :: proc() {
	rl.GuiToggleGroup(rl.Rectangle{30, 30, 120, 30}, TOOLS, (^i32)(&canvas.tool_selected))
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