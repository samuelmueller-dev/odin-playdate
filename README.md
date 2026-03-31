# Odin-Playdate

Up to date with Playdate SDK version 2.6

Odin-lang API bindings for the [Playdate SDK](https://play.date/dev/), used to develop games for the Playdate handheld game system.

## Features

- Custom allocator for Playdate memory allocations (`new()`, `make()`, etc should work as expected)
- Custom logger for Playdate logging system (`core:log` procedures should work as expected)
- **WiFi networking** — TCP client and HTTP bindings for online multiplayer, leaderboards, or any network I/O
- **Device (ARM) build support** — context split for freestanding ARM targets (Playdate hardware) without pulling in `core:fmt`, `core:strings`, or `core:log`

## Prerequisites

1. Download the [Playdate SDK](https://play.date/dev/) for your development platform.
2. Make sure you have the `PLAYDATE_SDK_PATH` environment variable set to the directory you installed it to.

## Creating a Playdate application

#### Export the Playdate event handler procedure:

```odin
@(export)
eventHandler :: proc "c" (pd_api: ^playdate.Api, event: playdate.System_Event, arg: u32) -> i32 {}
```

#### Create a context that uses the Playdate's allocator:

```odin
import "base:runtime"
import playdate "ext:odin-playdate"

global_ctx : runtime.Context

// Call on eventHandler .Init
my_init :: proc "contextless" (pd: ^playdate.Api) {
    global_ctx = playdate.playdate_context_create(pd)
}

// Call on eventHandler .Terminate
my_terminate :: proc "contextless" () {
    playdate.playdate_context_destroy(&global_ctx)
}


update :: proc "c" (user_data: rawptr) -> playdate.Update_Result {
    context = global_ctx

    my_slice := make([]string, 99) // allocates using pd.system.realloc
    delete(my_slice)

    return .Update_Display
}
```

From here, follow the official Playdate C guide for Game Initialization.

## Networking

TCP and HTTP client bindings are available via the `network` field on the API struct.

#### TCP client example:

```odin
import playdate "ext:odin-playdate"

// Connect to a server
conn := pd.network.tcp.new_connection("192.168.1.100", 9001, false)
pd.network.tcp.open(conn, my_open_callback, nil)

// In your callback or update loop:
my_open_callback :: proc "c" (connection: ^playdate.TCP_Connection, err: playdate.Net_Err, userdata: rawptr) {
    if err != .OK do return

    // Write data
    msg := "hello"
    pd.network.tcp.write(connection, raw_data(msg), len(msg))

    // Check for available data
    avail := pd.network.tcp.get_bytes_available(connection)
    if avail > 0 {
        buf: [256]u8
        n := pd.network.tcp.read(connection, &buf, len(buf))
    }
}
```

#### Check WiFi status:

```odin
status := pd.network.get_status()
if status == .Connected {
    // WiFi is available
}
```

## Compiling for the Simulator

1. Create an intermediate directory and an output directory
2. Compile your Odin project as a shared library:
```sh
odin build . -out=intermediate/pdex.dll -build-mode:shared -default-to-nil-allocator
```
3. Compile with the Playdate Compiler:
```sh
$PLAYDATE_SDK_PATH/bin/pdc intermediate/ out/Game_Name.pdx
```
4. Run the simulator:
```sh
$PLAYDATE_SDK_PATH/bin/PlaydateSimulator out/Game_Name.pdx
```

## Compiling for Playdate Hardware (ARM)

Compile to an ARM object file using `freestanding_arm32`, then link with the SDK's setup shim and linker script.

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

# 2. Compile SDK setup shim + runtime stubs with arm-none-eabi-gcc
arm-none-eabi-gcc $CFLAGS -c $PLAYDATE_SDK_PATH/C_API/buildsupport/setup.c -o build/setup.o
arm-none-eabi-gcc $CFLAGS -c stubs.c -o build/stubs.o

# 3. Link
arm-none-eabi-ld -T $PLAYDATE_SDK_PATH/C_API/buildsupport/link_map.ld \
    --gc-sections --no-warn-mismatch --emit-relocs \
    build/setup.o build/stubs.o build/pdex.o \
    -lgcc -o build/pdex.elf

# 4. Package
$PLAYDATE_SDK_PATH/bin/pdc build/ out/Game_Name.pdx
```

The context system automatically splits between simulator and device builds using `#+build` tags:
- `context_sim.odin` — full logger with `core:fmt`/`core:strings`/`core:log` (simulator)
- `context_device.odin` — minimal logger, no heavy imports (freestanding ARM)

**Required for device builds:** `-define:NO_PLAYDATE_TEMP_ALLOCATOR=true` — the Playdate's `realloc` returns unzeroed heap memory after the pdx loader runs, which triggers an arena assertion in the temp allocator. Disabling it avoids this.

## Build Flags

- `-define:NO_PLAYDATE_TEMP_ALLOCATOR=true` — skip arena-based temp allocator creation (required for device builds, optional for simulator)
- `-define:DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE=<n_bytes>` — resize the default temporary allocator arena (default: 4MB)

## API Status

| Package       | C bindings | Notes |
|---------------|:----------:|-------|
| `display`     | ➕         |       |
| `file`        | ➕         |       |
| `graphics`    | ➕         |       |
| `json`        | ➕         |       |
| `lua`         | ➕         |       |
| `network`     | ➕         | TCP client + HTTP. No server/listen (SDK limitation). |
| `scoreboards` | ➕         | Only approved games can use Scoreboards API |
| `sound`       | ➕         |       |
| `sprite`      | ➕         |       |
| `system`      | ➕         |       |
