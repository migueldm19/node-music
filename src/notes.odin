package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

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

N_SAMPLES :: 1000
RATE : u32: 3000
AMPLITUDE :: 5

sinusoid_sample :: proc(amplitude, angular_frequency: f32, sample: u32, initial_phase: f32 = 0.0) -> f32 {
	return amplitude * math.cos(angular_frequency * f32(sample) + initial_phase)
}

get_wave :: proc(frequency: f32) -> [dynamic]f32 {
	wav : [dynamic]f32 = make([dynamic]f32, N_SAMPLES)

	w := (2 * math.PI * frequency) / f32(RATE)

	for i in 0..<N_SAMPLES {
		wav[i] = sinusoid_sample(AMPLITUDE, w, u32(i))
	}

	return wav
}

NOTES: [Note][dynamic]f32

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

notes_init :: proc() {
	NOTES[.DO] = get_wave(261.63)
	NOTES[.DOS] = get_wave(277.18)
	NOTES[.RE] = get_wave(293.66)
	NOTES[.RES] = get_wave(311.13)
	NOTES[.MI] = get_wave(329.63)
	NOTES[.FA] = get_wave(349.23)
	NOTES[.FAS] = get_wave(369.99)
	NOTES[.SOL] = get_wave(392.00)
	NOTES[.SOLS] = get_wave(415.30)
	NOTES[.LA] = get_wave(440.00)
	NOTES[.LAS] = get_wave(466.16)
	NOTES[.SI] = get_wave(493.88)
}

notes_free :: proc() {
	delete(NOTES[.DO])
	delete(NOTES[.DOS])
	delete(NOTES[.RE])
	delete(NOTES[.RES])
	delete(NOTES[.MI])
	delete(NOTES[.FA])
	delete(NOTES[.FAS])
	delete(NOTES[.SOL])
	delete(NOTES[.SOLS])
	delete(NOTES[.LA])
	delete(NOTES[.LAS])
	delete(NOTES[.SI])
}

get_note_sound :: proc(note: Note) -> rl.Sound {
	return rl.LoadSoundFromWave(
		rl.Wave {
			frameCount = N_SAMPLES,
			sampleRate = RATE,
			sampleSize = 32,
			channels =   1,
			data =       raw_data(NOTES[note])
		}
	)
}
