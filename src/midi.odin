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

MidiCommand :: enum {
    Play,
    Stop,
}

command_codes: [MidiCommand]i32 = {
    .Play = 0x90,
    .Stop = 0x80,
}

midi_stop_all_notes :: proc() {
    log.debug("stopping all midi notes")
    for note in 0..<0x8F {
        for channel in 0..<10 {
            midi_note_command(.Stop, Note(note), u8(channel), 0)
        }
    }
}

midi_note_command :: proc(command: MidiCommand, note: Note, channel: u8, velocity: u8) {
    assert(channel <= 0xF, "Channel should be 16 or less")
    note_command: pm.Event
    note_command.timestamp = midi_time_proc()
    note_command.message = pm.MessageCompose(
        command_codes[command] + i32(channel),
        i32(note),
        i32(velocity)
    )

    pm.Write(midi_output_stream, &note_command, 1)
}
