#+build freestanding
package playdate

import "base:runtime"

// Minimal logger for device — no fmt/strings/log dependency
playdate_logger_proc :: proc(logger_data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location) {
    system := (^Api_System_Procs)(logger_data)
    if len(text) > 0 && len(text) < 1023 {
        buf: [1024]byte
        for i in 0 ..< len(text) {
            buf[i] = text[i]
        }
        buf[len(text)] = 0
        system.log_to_console(cstring(raw_data(buf[:])))
    }
}

playdate_assertion_failure_proc :: proc (prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
    runtime.trap()
}
