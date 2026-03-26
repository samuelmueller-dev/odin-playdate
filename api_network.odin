package playdate

import "core:c"

// Opaque connection types
HTTP_Connection :: distinct Opaque_Struct
TCP_Connection  :: distinct Opaque_Struct

// Network error codes
Net_Err :: enum i32 {
	OK                  =   0,
	No_Device           =  -1,
	Busy                =  -2,
	Write_Error         =  -3,
	Write_Busy          =  -4,
	Write_Timeout       =  -5,
	Read_Error          =  -6,
	Read_Busy           =  -7,
	Read_Timeout        =  -8,
	Read_Overflow       =  -9,
	Frame_Error         = -10,
	Bad_Response        = -11,
	Error_Response      = -12,
	Reset_Timeout       = -13,
	Buffer_Too_Small    = -14,
	Unexpected_Response = -15,
	Not_Connected_To_AP = -16,
	Not_Implemented     = -17,
	Connection_Closed   = -18,
}

Wifi_Status :: enum c.int {
	Not_Connected = 0,
	Connected     = 1,
	Not_Available = 2,
}

Access_Reply :: enum c.int {}

// Callback types
Access_Request_Callback    :: #type proc "c" (allowed: b32, userdata: rawptr)
HTTP_Connection_Callback   :: #type proc "c" (connection: ^HTTP_Connection)
HTTP_Header_Callback       :: #type proc "c" (connection: ^HTTP_Connection, key: cstring, value: cstring)
TCP_Connection_Callback    :: #type proc "c" (connection: ^TCP_Connection, err: Net_Err)
TCP_Open_Callback          :: #type proc "c" (connection: ^TCP_Connection, err: Net_Err, userdata: rawptr)
Net_Enabled_Callback       :: #type proc "c" (err: Net_Err)

// =================================================================

Api_HTTP_Procs :: struct {
	request_access:               proc "c" (server: cstring, port: c.int, use_ssl: b32, purpose: cstring, callback: Access_Request_Callback, userdata: rawptr) -> Access_Reply,

	new_connection:               proc "c" (server: cstring, port: c.int, use_ssl: b32) -> ^HTTP_Connection,
	retain:                       proc "c" (connection: ^HTTP_Connection) -> ^HTTP_Connection,
	release:                      proc "c" (connection: ^HTTP_Connection),

	set_connect_timeout:          proc "c" (connection: ^HTTP_Connection, ms: c.int),
	set_keep_alive:               proc "c" (connection: ^HTTP_Connection, keep_alive: b32),
	set_byte_range:               proc "c" (connection: ^HTTP_Connection, start: c.int, end: c.int),
	set_userdata:                 proc "c" (connection: ^HTTP_Connection, userdata: rawptr),
	get_userdata:                 proc "c" (connection: ^HTTP_Connection) -> rawptr,

	get:                          proc "c" (connection: ^HTTP_Connection, path: cstring, headers: cstring, header_len: c.size_t) -> Net_Err,
	post:                         proc "c" (connection: ^HTTP_Connection, path: cstring, headers: cstring, header_len: c.size_t, body: cstring, body_len: c.size_t) -> Net_Err,
	query:                        proc "c" (connection: ^HTTP_Connection, method: cstring, path: cstring, headers: cstring, header_len: c.size_t, body: cstring, body_len: c.size_t) -> Net_Err,
	get_error:                    proc "c" (connection: ^HTTP_Connection) -> Net_Err,
	get_progress:                 proc "c" (connection: ^HTTP_Connection, read: ^c.int, total: ^c.int),
	get_response_status:          proc "c" (connection: ^HTTP_Connection) -> c.int,
	get_bytes_available:          proc "c" (connection: ^HTTP_Connection) -> c.size_t,
	set_read_timeout:             proc "c" (connection: ^HTTP_Connection, ms: c.int),
	set_read_buffer_size:         proc "c" (connection: ^HTTP_Connection, bytes: c.int),
	read:                         proc "c" (connection: ^HTTP_Connection, buf: rawptr, buf_len: c.uint) -> c.int,
	close:                        proc "c" (connection: ^HTTP_Connection),

	set_header_received_callback: proc "c" (connection: ^HTTP_Connection, callback: HTTP_Header_Callback),
	set_headers_read_callback:    proc "c" (connection: ^HTTP_Connection, callback: HTTP_Connection_Callback),
	set_response_callback:        proc "c" (connection: ^HTTP_Connection, callback: HTTP_Connection_Callback),
	set_request_complete_callback: proc "c" (connection: ^HTTP_Connection, callback: HTTP_Connection_Callback),
	set_connection_closed_callback: proc "c" (connection: ^HTTP_Connection, callback: HTTP_Connection_Callback),
}

// =================================================================

Api_TCP_Procs :: struct {
	request_access:               proc "c" (server: cstring, port: c.int, use_ssl: b32, purpose: cstring, callback: Access_Request_Callback, userdata: rawptr) -> Access_Reply,
	new_connection:               proc "c" (server: cstring, port: c.int, use_ssl: b32) -> ^TCP_Connection,
	retain:                       proc "c" (connection: ^TCP_Connection) -> ^TCP_Connection,
	release:                      proc "c" (connection: ^TCP_Connection),
	get_error:                    proc "c" (connection: ^TCP_Connection) -> Net_Err,

	set_connect_timeout:          proc "c" (connection: ^TCP_Connection, ms: c.int),
	set_userdata:                 proc "c" (connection: ^TCP_Connection, userdata: rawptr),
	get_userdata:                 proc "c" (connection: ^TCP_Connection) -> rawptr,

	open:                         proc "c" (connection: ^TCP_Connection, callback: TCP_Open_Callback, userdata: rawptr) -> Net_Err,
	close:                        proc "c" (connection: ^TCP_Connection) -> Net_Err,

	set_connection_closed_callback: proc "c" (connection: ^TCP_Connection, callback: TCP_Connection_Callback),

	set_read_timeout:             proc "c" (connection: ^TCP_Connection, ms: c.int),
	set_read_buffer_size:         proc "c" (connection: ^TCP_Connection, bytes: c.int),
	get_bytes_available:          proc "c" (connection: ^TCP_Connection) -> c.size_t,

	read:                         proc "c" (connection: ^TCP_Connection, buffer: rawptr, length: c.size_t) -> c.int,
	write:                        proc "c" (connection: ^TCP_Connection, buffer: rawptr, length: c.size_t) -> c.int,
}

// =================================================================

Api_Network_Procs :: struct {
	http:        ^Api_HTTP_Procs,
	tcp:         ^Api_TCP_Procs,

	get_status:  proc "c" () -> Wifi_Status,
	set_enabled: proc "c" (flag: b32, callback: Net_Enabled_Callback),

	_reserved:   [3]uintptr,
}
