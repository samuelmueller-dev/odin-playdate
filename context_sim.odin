#+build !freestanding
package playdate

import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:log"

playdate_logger_proc :: proc(logger_data: rawptr, level: runtime.Logger_Level, text: string, options: runtime.Logger_Options, location := #caller_location) {
    system := (^Api_System_Procs)(logger_data)

    sb_backing: [1024]byte
    buf := strings.builder_from_bytes(sb_backing[:len(sb_backing) - 1])

    if .Level in options {
        fmt.sbprint(&buf, _Level_Headers[uint(level) / 10])
    }

    if log.Full_Timestamp_Opts & options != nil {
        fmt.sbprint(&buf, "[")
        sec       := system.get_seconds_since_epoch(nil)
        date_time :  Date_Time
        system.convert_epoch_to_date_time(sec, &date_time)
        if .Date in options { fmt.sbprintf(&buf, "%d-%02d-%02d ", date_time.year, date_time.month, date_time.day)}
        if .Time in options { fmt.sbprintf(&buf, "%02d:%02d:%02d", date_time.hour, date_time.minute, date_time.second)}
        fmt.sbprintf(&buf, "] ")
    }

    log.do_location_header(options, &buf, location)

    fmt.sbprintf(&buf, "%v", text)

    output_cstr := strings.unsafe_string_to_cstring(strings.to_string(buf))

    switch level {
        case .Debug, .Info, .Warning:
            system.log_to_console(output_cstr)
        case .Error, .Fatal:
            system.error(output_cstr)
    }
}

playdate_assertion_failure_proc :: proc (prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
    buffer: [1024]byte
    sb := strings.builder_from_bytes(buffer[:])

    fmt.sbprintf(&sb, "%s(%d:%d) %s", loc.file_path, loc.line, loc.column, prefix)

    if len(message) > 0 {
        fmt.sbprintf(&sb, ": %s", message)
    }

    log.fatal(strings.to_string(sb))
    runtime.trap()
}
