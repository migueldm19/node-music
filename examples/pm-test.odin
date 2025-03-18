package main

import "core:fmt"
import "core:time"
import pm "vendor:portmidi"

time_proc :: proc "c" (time_info: rawptr = nil) -> pm.Timestamp {
    now := time.now()
    return pm.Timestamp(now._nsec / 1000000)
}

main :: proc() {
    err := pm.Initialize(); if err != .NoError {
        fmt.printf("Error initializing PortMidi: %v", err)
        return
    }
    defer pm.Terminate()

    output_device := pm.GetDefaultOutputDeviceID()
    output_stream : pm.Stream
    pm.OpenOutput(&output_stream, output_device, nil, 0, time_proc, nil, 0)


    // Send a Note On (Channel 1, Note 64, Velocity 127)
    note_on: pm.Event
    note_on.timestamp = time_proc()
    note_on.message = pm.MessageCompose(0x90, 64, 127)

    fmt.println("Sending note 64")
    pm.Write(output_stream, &note_on, 1)

    time.sleep(1 * time.Second)

    note_off: pm.Event
    note_off.timestamp = time_proc()
    note_off.message = pm.MessageCompose(0x80, 64, 0)

    fmt.println("Sending note off")
    pm.Write(output_stream, &note_off, 1)
}
