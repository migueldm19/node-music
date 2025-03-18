package main

import "core:math"
import "core:time"
import "core:log"
import rl "vendor:raylib"
import pm "vendor:portmidi"

Note :: enum {
	NOTES_BEGINING,
	DO,
	DOS,
	RE,
	RES,
	MI,
	FA,
	FAS,
	SOL,
	SOLS,
	LA,
	LAS,
	SI,
	NOTES_END,
}

NOTES := [Note]i32 {
    .NOTES_BEGINING = -1,
    .DO = 60,
    .DOS = 61,
    .RE = 62,
    .RES = 63,
    .MI = 64,
    .FA = 65,
    .FAS = 66,
    .SOL = 67,
    .SOLS = 68,
    .LA = 69,
    .LAS = 70,
    .SI = 71,
    .NOTES_END = -1,
}

NOTE_STRINGS := [Note]cstring {
	.NOTES_BEGINING = "None",
	.DO = "Do",
	.DOS = "Do#/Reb",
	.RE = "Re",
	.RES = "Re#/Mib",
	.MI = "Mi",
	.FA = "Fa",
	.FAS = "Fa#/Solb",
	.SOL = "Sol",
	.SOLS = "Sol#/Lab",
	.LA = "La",
	.LAS = "La#/Sib",
	.SI = "Si",
	.NOTES_END = "None",
}

note_to_string :: proc(note: Note) -> cstring {
	return NOTE_STRINGS[note]
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
    note_on.message = pm.MessageCompose(0x90, NOTES[note], 127)

    pm.Write(midi_output_stream, &note_on, 1)
}

midi_stop_note :: proc(note: Note) {
    note_off: pm.Event
    note_off.timestamp = midi_time_proc()
    note_off.message = pm.MessageCompose(0x80, NOTES[note], 0)

    pm.Write(midi_output_stream, &note_off, 1)
}
