# Odin-Playdate

Odin-lang API bindings for the [Playdate SDK](https://play.date/dev/). Tested with Playdate SDK 3.0.3 and Playdate OS 3.0.4.

Supports both **simulator** and **device (ARM hardware)** builds from the same codebase.

## Features

- Custom allocator for Playdate memory allocations (`new()`, `make()`, etc work as expected)
- Custom logger for Playdate logging system
- WiFi networking — TCP client and HTTP bindings
- Device (ARM) build support — context split for freestanding ARM targets without pulling in `core:fmt`, `core:strings`, or `core:log`

## Prerequisites

1. Download the [Playdate SDK](https://play.date/dev/) for your development platform.
2. Set the `PLAYDATE_SDK_PATH` environment variable to the install directory.
3. For device builds: `brew install arm-none-eabi-gcc`

## Creating a Playdate Application

Export the Playdate event handler:

```odin
import "base:runtime"
import playdate "ext:odin-playdate"

global_ctx: runtime.Context
_pd: ^playdate.Api

@(export)
eventHandler :: proc "c" (api: ^playdate.Api, event: playdate.System_Event, arg: u32) -> i32 {
    #partial switch event {
    case .Init:
        global_ctx = playdate.playdate_context_create(api)
        context = global_ctx
        _pd = api
        api.system.set_update_callback(update, nil)
    case .Terminate:
        playdate.playdate_context_destroy(&global_ctx)
    }
    return 0
}

update :: proc "c" (user_data: rawptr) -> playdate.Update_Result {
    context = global_ctx
    _pd.graphics.clear({solid = .White})
    _pd.graphics.draw_text("Hello from Odin!", 16, nil, 120, 100)
    return .Update_Display
}
```

## Networking

TCP and HTTP client bindings are available via `api.network`.

```odin
// Check WiFi
status := _pd.network.get_status()
if status != .Connected do return

// Connect TCP
conn := _pd.network.tcp.new_connection("192.168.1.100", 9001, false)
_pd.network.tcp.open(conn, on_connected, nil)

on_connected :: proc "c" (connection: ^playdate.TCP_Connection, err: playdate.Net_Err, userdata: rawptr) {
    if err != .OK do return

    // Write
    msg := "hello"
    _pd.network.tcp.write(connection, raw_data(msg), len(msg))

    // Read
    avail := _pd.network.tcp.get_bytes_available(connection)
    if avail > 0 {
        buf: [256]u8
        n := _pd.network.tcp.read(connection, &buf, len(buf))
    }
}
```

The Playdate SDK only supports TCP client connections — no server sockets, no UDP, no listen/accept.

For a working example, see [playdate-nettest](https://github.com/samuelmueller-dev/playdate-nettest) — a standalone RTT measurement tool that runs on Playdate hardware.

## Compiling for the Simulator

```sh
# macOS
odin build src/ -out:intermediate/pdex.dylib \
    -build-mode:shared \
    -default-to-nil-allocator \
    -collection:ext=libs

# Windows
odin build src/ -out:intermediate/pdex.dll \
    -build-mode:shared \
    -default-to-nil-allocator \
    -collection:ext=libs

# Package and run
$PLAYDATE_SDK_PATH/bin/pdc intermediate/ out/Game.pdx
$PLAYDATE_SDK_PATH/bin/PlaydateSimulator out/Game.pdx
```

The `-collection:ext=libs` flag tells Odin where to find the `odin-playdate` package (assuming it's at `libs/odin-playdate/`).

## Compiling for Playdate Hardware (ARM)

Cross-compile to ARM Cortex-M7, link with the SDK's setup shim, and package with `pdc`.

```sh
# 1. Compile Odin to ARM object
odin build src/ \
    -target:freestanding_arm32 \
    -build-mode:obj \
    -microarch:cortex-m7 \
    -target-features:"no-movt" \
    -no-entry-point \
    -default-to-nil-allocator \
    -no-thread-local \
    -disable-red-zone \
    -define:NO_PLAYDATE_TEMP_ALLOCATOR=true \
    -collection:ext=libs \
    -out:build/pdex.o

# 2. Compile SDK setup shim + runtime stubs
arm-none-eabi-gcc -mthumb -mcpu=cortex-m7 -mfloat-abi=hard -mfpu=fpv5-sp-d16 \
    -DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -O2 \
    -ffunction-sections -fdata-sections -mword-relocations -fno-common \
    -ffreestanding -nostdinc \
    -isystem "$(arm-none-eabi-gcc -print-file-name=include)" \
    -isystem tools/device_stubs \
    -I $PLAYDATE_SDK_PATH/C_API \
    -c $PLAYDATE_SDK_PATH/C_API/buildsupport/setup.c -o build/setup.o

arm-none-eabi-gcc -mthumb -mcpu=cortex-m7 -mfloat-abi=hard -mfpu=fpv5-sp-d16 \
    -DTARGET_PLAYDATE=1 -DTARGET_EXTENSION=1 -O2 \
    -ffreestanding -c tools/device_stubs/stubs.c -o build/stubs.o

# 3. Link
arm-none-eabi-ar rcs build/libc.a
arm-none-eabi-ar rcs build/libm.a

arm-none-eabi-ld \
    -T $PLAYDATE_SDK_PATH/C_API/buildsupport/link_map.ld \
    --gc-sections --no-warn-mismatch --emit-relocs \
    -L "$(arm-none-eabi-gcc -mthumb -mcpu=cortex-m7 -mfloat-abi=hard -mfpu=fpv5-sp-d16 -print-libgcc-file-name | xargs dirname)" \
    -L build \
    build/setup.o build/stubs.o build/pdex.o \
    -lgcc -o build/pdex.elf

# 4. Package
$PLAYDATE_SDK_PATH/bin/pdc build/ out/Game.pdx

# 5. Deploy (USB Data Disk mode)
cp -R out/Game.pdx /Volumes/PLAYDATE/Games/
```

You'll need runtime stubs for `memcpy`, `memmove`, `memset`, `strlen`, `strcmp`, `memcmp`, `__aeabi_read_tp` (TLS), and ARM unwind routines. See [playdate-nettest/tools/device_stubs/](https://github.com/samuelmueller-dev/playdate-nettest/tree/main/tools/device_stubs) for a working reference.

The `-target-features:"no-movt"` flag is required — it forces LLVM to generate `R_ARM_ABS32` relocations (literal pools) instead of `movw`/`movt` pairs, which the Playdate's device loader cannot process.

### Context Split

The context system automatically selects the right implementation based on build target:
- `context_sim.odin` (`#+build !freestanding`) — full logger with `core:fmt`/`core:strings`/`core:log`
- `context_device.odin` (`#+build freestanding`) — minimal logger, no heavy imports

### Device Build Flags

- `-define:NO_PLAYDATE_TEMP_ALLOCATOR=true` — **required for device builds**. The Playdate's `realloc` returns unzeroed heap memory after the pdx loader runs, which triggers an arena assertion. This flag disables the arena-based temp allocator.
- `-define:DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE=<n_bytes>` — resize the temp allocator arena (default: 4MB, only relevant for simulator builds)

## API Status

| Package       | Bindings | Notes |
|---------------|:--------:|-------|
| `display`     | ✓        |       |
| `file`        | ✓        |       |
| `graphics`    | ✓        |       |
| `json`        | ✓        |       |
| `lua`         | ✓        |       |
| `network`     | ✓        | TCP client + HTTP. No server/listen (SDK limitation). |
| `scoreboards` | ✓        | Only approved games can use Scoreboards API. |
| `sound`       | ✓        |       |
| `sprite`      | ✓        |       |
| `system`      | ✓        |       |
