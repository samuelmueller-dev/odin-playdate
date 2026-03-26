package playdate

import "base:runtime"
import "core:mem"

NO_PLAYDATE_TEMP_ALLOCATOR :: #config(NO_PLAYDATE_TEMP_ALLOCATOR, false)

@(private)
_Level_Headers := [?]string{
    0 = "[DEBUG] ",
    1 = "[INFO ] ",
    2 = "[WARN ] ",
    3 = "[ERROR] ",
    4 = "[FATAL] ",
}

// Get a context configured for Playdate applications.
playdate_context_create :: proc "contextless" (api: ^Api) -> runtime.Context {
    ctx: runtime.Context

    when !ODIN_DISABLE_ASSERT {
        ctx.assertion_failure_proc = playdate_assertion_failure_proc
    }

    ctx.allocator                = playdate_allocator(api)
    ctx.temp_allocator.procedure = playdate_temp_allocator_proc

    when !NO_PLAYDATE_TEMP_ALLOCATOR {
        context = ctx
        temp_alloc := new(Playdate_Temp_Allocator)
        playdate_temp_allocator_init(temp_alloc, runtime.DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE, ctx.allocator)
        ctx.temp_allocator.data = temp_alloc
    }

    ctx.logger = playdate_logger(api)
    return ctx
}

playdate_context_destroy :: proc "contextless" (ctx: ^runtime.Context) {
    when !NO_PLAYDATE_TEMP_ALLOCATOR {
        context = ctx^
        temp_alloc := (^Playdate_Temp_Allocator)(ctx.temp_allocator.data)
        runtime.arena_destroy(&temp_alloc.arena)
        free(temp_alloc)
    }
}

playdate_allocator :: proc "contextless" (api: ^Api) -> runtime.Allocator {
    return runtime.Allocator {
        procedure = playdate_allocator_proc,
        data      = rawptr(api.system.realloc),
    }
}

Playdate_Temp_Allocator :: struct {
    arena: runtime.Arena,
}

playdate_temp_allocator_init :: proc(s: ^Playdate_Temp_Allocator, size: int, backing_allocator := context.allocator) {
    _ = runtime.arena_init(&s.arena, uint(size), backing_allocator)
}

playdate_temp_allocator_destroy :: proc(s: ^Playdate_Temp_Allocator) {
    if s != nil {
        runtime.arena_destroy(&s.arena)
        s^ = {}
    }
}

playdate_temp_allocator_proc :: proc(allocator_data: rawptr, mode: runtime.Allocator_Mode,
                                    size, alignment: int,
                                    old_memory: rawptr, old_size: int, loc := #caller_location) -> (data: []byte, err: runtime.Allocator_Error) {
    s := (^Playdate_Temp_Allocator)(allocator_data)
    return runtime.arena_allocator_proc(&s.arena, mode, size, alignment, old_memory, old_size, loc)
}

@(require_results)
playdate_temp_allocator_temp_begin :: proc(allocator := context.temp_allocator, loc := #caller_location) -> (temp: runtime.Arena_Temp) {
    temp_alloc := (^Playdate_Temp_Allocator)(allocator.data)
    temp = runtime.arena_temp_begin(&temp_alloc.arena, loc)
    return
}

playdate_temp_allocator_temp_end :: proc(temp: runtime.Arena_Temp, loc := #caller_location) {
    runtime.arena_temp_end(temp, loc)
}

playdate_temp_allocator :: proc "contextless" (allocator: ^Playdate_Temp_Allocator) -> runtime.Allocator {
    return runtime.Allocator {
        procedure = playdate_temp_allocator_proc,
        data      = allocator,
    }
}

playdate_logger :: proc "contextless" (api: ^Api) -> runtime.Logger {
    return runtime.Logger {
        procedure    = playdate_logger_proc,
        data         = rawptr(api.system),
        lowest_level = .Debug,
        options      = {.Level},
    }
}

playdate_allocator_proc :: proc (allocator_data: rawptr, mode: runtime.Allocator_Mode,
                        size, alignment: int,
                        old_memory: rawptr, old_size: int, loc := #caller_location) -> (data: []byte, err: runtime.Allocator_Error) {
    ok: bool = true
    size := u32(size)

    realloc_proc :: #type proc "c" (ptr: rawptr, size: u32) -> [^]byte
    realloc := realloc_proc(allocator_data)

    switch mode {
        case .Alloc, .Alloc_Non_Zeroed:
            ptr := realloc(nil, u32(size))
            if ptr == nil {
                err = .Out_Of_Memory
                data = nil
            } else {
                err = .None
                data = ptr[:size]
            }
        case .Free:
            _ = realloc(old_memory, 0)
        case .Free_All:
            return nil, .Mode_Not_Implemented
        case .Resize_Non_Zeroed:
            fallthrough
        case .Resize:
            ptr := realloc(old_memory, u32(size))
            if ptr == nil {
                err = .Out_Of_Memory
                data = nil
            } else {
                err = .None
                data = ptr[:size]
            }
        case .Query_Features:
            set := (^runtime.Allocator_Mode_Set)(old_memory)
            if set != nil {
                set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Resize, .Query_Features}
            }
        case .Query_Info:
            return nil, .Mode_Not_Implemented
    }
    return
}
