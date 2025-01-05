package main

import "core:log"
import "core:mem"
import rl "vendor:raylib"

print_memory_leaks_and_cleanup :: proc(track: ^mem.Tracking_Allocator) {
    if len(track.allocation_map) > 0 {
        log.warnf("=== %v allocations not freed: ===\n", len(track.allocation_map))
        for _, entry in track.allocation_map {
            log.warnf("- %v bytes @ %v\n", entry.size, entry.location)
        }
    }
    if len(track.bad_free_array) > 0 {
        log.warnf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
        for entry in track.bad_free_array {
            log.warnf("- %p @ %v\n", entry.memory, entry.location)
        }
    }
    mem.tracking_allocator_destroy(track)
}

main :: proc() {
    when ODIN_DEBUG {
        context.logger = log.create_console_logger()
        defer log.destroy_console_logger(context.logger)

        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)
        defer print_memory_leaks_and_cleanup(&track)
    }


    rl.InitWindow(1300, 900, "Nodal music")
    rl.InitAudioDevice()

    canvas := canvas_new()
    defer canvas_free(canvas)

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        canvas_draw(canvas)
        canvas_update(canvas)
        rl.EndDrawing()
    }

    rl.CloseAudioDevice()
    rl.CloseWindow()
}
