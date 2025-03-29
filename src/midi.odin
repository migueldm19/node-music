package main

import "core:math"
import "core:time"
import "core:log"
import "core:fmt"
import rl "vendor:raylib"
import pm "vendor:portmidi"

Note :: distinct u8

NOTE_STRINGS: []cstring = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

note_to_string :: proc(note: Note) -> cstring {
    note_idx:i8 = i8(note) / 10 - 1
	return fmt.ctprintf("%v%v", NOTE_STRINGS[note % 12], note_idx)
}

midi_time_proc :: proc "c" (time_info: rawptr = nil) -> pm.Timestamp {
    now := time.now()
    return pm.Timestamp(now._nsec / 1000000)
}

midi_output_stream: pm.Stream

midi_init :: proc() {
    log.debug("Initializing midi output stream")
    err: pm.Error
    err = pm.Initialize(); if err != .NoError {
        log.errorf("Error initializing PortMidi: %v", err)
        return
    }
    output_device := pm.GetDefaultOutputDeviceID()

    err = pm.OpenOutput(&midi_output_stream, output_device, nil, 0, midi_time_proc, nil, 0)
    if err != .NoError {
        log.errorf("Error opening default PortMidi output: %v", err)
    }
}

midi_deinit :: proc() {
    log.debug("Deinitializing midi output stream")
    pm.Close(midi_output_stream)
    pm.Terminate()
}

midi_play_note :: proc(note: Note) {
    note_on: pm.Event
    note_on.timestamp = midi_time_proc()
    note_on.message = pm.MessageCompose(0x90, i32(note), 127)

    pm.Write(midi_output_stream, &note_on, 1)
}

midi_stop_note :: proc(note: Note) {
    note_off: pm.Event
    note_off.timestamp = midi_time_proc()
    note_off.message = pm.MessageCompose(0x80, i32(note), 0)

    pm.Write(midi_output_stream, &note_off, 1)
}
