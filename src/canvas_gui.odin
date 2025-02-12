package main

import rl "vendor:raylib"
import mu "vendor:microui"
import "core:log"
import "core:unicode/utf8"

PLAY_BUTTON :: "#131#"
STOP_BUTTON :: "#133#"

canvas_gui_draw_and_update :: proc() {
    canvas_gui_tool_selection()
    canvas_gui_play_stop()

    canvas_gui_get_input()

    ctx := &canvas.gui_state.mu_ctx

    mu.begin(ctx)

    canvas_gui_node()

    mu.end(ctx)
    canvas_gui_render()
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

canvas_gui_node :: proc() {
    ctx := &canvas.gui_state.mu_ctx
    if canvas.selected_node != nil {
        if mu.window(ctx, "Node", {40, 40, 300, 450}, mu.Options{.NO_CLOSE}) {

        }
    }
}

canvas_gui_init :: proc() {
    using canvas

    gui_state.pixels = make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
    for alpha, i in mu.default_atlas_alpha {
        gui_state.pixels[i] = {0xff, 0xff, 0xff, alpha}
    }

    image := rl.Image {
        data = raw_data(gui_state.pixels),
        width = mu.DEFAULT_ATLAS_WIDTH,
        height = mu.DEFAULT_ATLAS_HEIGHT,
        mipmaps = 1,
        format = .UNCOMPRESSED_R8G8B8A8,
    }
    gui_state.atlas_texture = rl.LoadTextureFromImage(image)

    mu.init(&gui_state.mu_ctx)

    gui_state.mu_ctx.text_width = mu.default_atlas_text_width
    gui_state.mu_ctx.text_height = mu.default_atlas_text_height
}

canvas_gui_deinit :: proc() {
    using canvas

    //rl.UnloadTexture(gui_state.atlas_texture) TODO: investigate seg fault
    delete(gui_state.pixels)
}

canvas_gui_get_input :: proc() {
    canvas_gui_get_input_text()
    canvas_gui_get_input_mouse()
    canvas_gui_get_input_keyboard()
}

canvas_gui_get_input_text :: proc() {
    ctx := &canvas.gui_state.mu_ctx

    text_input: [512]byte = ---
    text_input_offset := 0
    for text_input_offset < len(text_input) {
        ch := rl.GetCharPressed()
        if ch == 0 {
            break
        }
        b, w := utf8.encode_rune(ch)
        copy(text_input[text_input_offset:], b[:w])
        text_input_offset += w
    }
    mu.input_text(ctx, string(text_input[:text_input_offset]))
}

canvas_gui_get_input_mouse :: proc() {
    ctx := &canvas.gui_state.mu_ctx

    mouse_pos := [2]i32{rl.GetMouseX(), rl.GetMouseY()}
    mu.input_mouse_move(ctx, mouse_pos.x, mouse_pos.y)
    mu.input_scroll(ctx, 0, i32(rl.GetMouseWheelMove() * -30))

    @static buttons_to_key := [?]struct{
        rl_button: rl.MouseButton,
        mu_button: mu.Mouse,
    }{
        {.LEFT, .LEFT},
        {.RIGHT, .RIGHT},
        {.MIDDLE, .MIDDLE},
    }

    for button in buttons_to_key {
        if rl.IsMouseButtonPressed(button.rl_button) {
            mu.input_mouse_down(ctx, mouse_pos.x, mouse_pos.y, button.mu_button)
        } else if rl.IsMouseButtonReleased(button.rl_button) {
            mu.input_mouse_up(ctx, mouse_pos.x, mouse_pos.y, button.mu_button)
        }
    }
}

canvas_gui_get_input_keyboard :: proc() {
    ctx := &canvas.gui_state.mu_ctx

    @static keys_to_check := [?]struct{
        rl_key: rl.KeyboardKey,
        mu_key: mu.Key,
    }{
        {.LEFT_SHIFT,    .SHIFT},
        {.RIGHT_SHIFT,   .SHIFT},
        {.LEFT_CONTROL,  .CTRL},
        {.RIGHT_CONTROL, .CTRL},
        {.LEFT_ALT,      .ALT},
        {.RIGHT_ALT,     .ALT},
        {.ENTER,         .RETURN},
        {.KP_ENTER,      .RETURN},
        {.BACKSPACE,     .BACKSPACE},
    }

    for key in keys_to_check {
        if rl.IsKeyPressed(key.rl_key) {
            mu.input_key_down(ctx, key.mu_key)
        } else if rl.IsKeyReleased(key.rl_key) {
            mu.input_key_up(ctx, key.mu_key)
        }
    }
}

canvas_gui_render :: proc() {
    ctx := &canvas.gui_state.mu_ctx

    render_texture :: proc(rect: mu.Rect, pos: [2]i32, color: mu.Color) {
        source := rl.Rectangle{
            f32(rect.x),
            f32(rect.y),
            f32(rect.w),
            f32(rect.h),
        }
        position := rl.Vector2{f32(pos.x), f32(pos.y)}

        rl.DrawTextureRec(canvas.gui_state.atlas_texture, source, position, transmute(rl.Color)color)
    }

    rl.BeginScissorMode(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight())
    defer rl.EndScissorMode()

    command_backing: ^mu.Command
    for variant in mu.next_command_iterator(ctx, &command_backing) {
        switch cmd in variant {
        case ^mu.Command_Text:
            pos := [2]i32{cmd.pos.x, cmd.pos.y}
            for ch in cmd.str do if ch&0xc0 != 0x80 {
                r := min(int(ch), 127)
                rect := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
                render_texture(rect, pos, cmd.color)
                pos.x += rect.w
            }
        case ^mu.Command_Rect:
            rl.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, transmute(rl.Color)cmd.color)
        case ^mu.Command_Icon:
            rect := mu.default_atlas[cmd.id]
            x := cmd.rect.x + (cmd.rect.w - rect.w)/2
            y := cmd.rect.y + (cmd.rect.h - rect.h)/2
            render_texture(rect, {x, y}, cmd.color)
        case ^mu.Command_Clip:
            rl.EndScissorMode()
            rl.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
        case ^mu.Command_Jump:
            unreachable()
        }
    }
}

