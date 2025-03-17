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

metronome_thread_proc :: proc(t: ^thread.Thread) {
	nanoseconds_between_subbeats : = ((60.0 / BPM) / SUBDIVISION) * 1000000000 * time.Nanosecond
	log.info("Metronome thread started. Duration between subbeats =", nanoseconds_between_subbeats)

	for {
		time.accurate_sleep(nanoseconds_between_subbeats)
		canvas_metronome_ping()
	}
}
