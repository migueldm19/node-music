package main

import "core:thread"
import "core:time"
import "core:log"
import "core:fmt"

metronome_thread: ^thread.Thread

metronome_thread_init :: proc() {
   	log.debug("Starting metronome thread")
   	metronome_thread = thread.create(metronome_thread_proc)
   	metronome_thread.init_context = context
   	assert(metronome_thread != nil)
   	thread.start(metronome_thread)
}

metronome_thread_deinit :: proc() {
    log.debug("Terminating metronome thread")
    thread.terminate(metronome_thread, 0)
    thread.destroy(metronome_thread)
}

sleep_time: time.Duration

metronome_update_sleep_time :: proc() {
    config := canvas_get_config()
    nanoseconds_between_subbeats : = ((60.0 / f32(config.bpm)) / f32(config.subdivision)) * 1000000000
    sleep_time = time.Duration(nanoseconds_between_subbeats)  * time.Nanosecond
}

metronome_thread_proc :: proc(t: ^thread.Thread) {
    metronome_update_sleep_time()
    log.info("Metronome thread started. Duration between subbeats =", sleep_time)

    for {
        time.accurate_sleep(sleep_time)
        canvas_metronome_ping()
    }
}
