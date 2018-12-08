//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

const std = @import("std");
const assert = std.debug.assert;

pub const Oid = @import("oids.zig").Oid;
pub const Value = std.json.Value;

const rpc_version = "\"jsonrpc\":\"2.0\"";

pub fn jsonToString(
    self: Value,
    comptime fmt: []const u8,
    context: var,
    comptime FmtError: type,
    output: fn (@typeOf(context), []const u8) FmtError!void,
) FmtError!void {
    switch (self) {
        Value.Null => {
            return std.fmt.format(context, FmtError, output, "null");
        },
        Value.Bool => |inner| {
            return std.fmt.format(context, FmtError, output, "{}", inner);
        },
        Value.Integer => |inner| {
            return std.fmt.format(context, FmtError, output, "{}", inner);
        },
        Value.Float => |inner| {
            return std.fmt.format(context, FmtError, output, "{.5}", inner);
        },
        Value.String => |inner| {
            return std.fmt.format(context, FmtError, output, "\"{}\"", inner);
        },
        Value.Array => |inner| {
            var not_first = false;
            try std.fmt.format(context, FmtError, output, "[");
            for (inner.toSliceConst()) |value| {
                if (not_first) {
                    try std.fmt.format(context, FmtError, output, ",");
                }
                not_first = true;
                try jsonToString(value, fmt, context, FmtError, output);
            }
            return std.fmt.format(context, FmtError, output, "]");
        },
        Value.Object => |inner| {
            var not_first = false;
            try std.fmt.format(context, FmtError, output, "{{");
            var it = inner.iterator();

            while (it.next()) |entry| {
                if (not_first) {
                    try std.fmt.format(context, FmtError, output, ",");
                }
                not_first = true;
                try std.fmt.format(context, FmtError, output, "\"{}\":", entry.key);
                try jsonToString(entry.value, fmt, context, FmtError, output);
            }
            return std.fmt.format(context, FmtError, output, "}}");
        },
    }
}

pub const Request = union(enum) {
    Call: CallObj,
    Notification: NotificationObj,

    pub const CallObj = struct {
        method: []const u8,
        params: ?Value,
        id: Oid,
    };

    pub const NotificationObj = struct {
        method: []const u8,
        params: ?Value,
    };

    pub fn call(method: []const u8, params: ?Value) Request {
        return Request {
            .Call = CallObj {
                .method = method, 
                .params = params,
                .id = Oid.new(),
            }
        };
    }

    pub fn notify(method: []const u8, params: ?Value) Request {
        return Request {
            .Notification = NotificationObj {
                .method = method, 
                .params = params,
            }
        };
    }

    pub fn format(
        self: Request,
        comptime fmt: []const u8,
        context: var,
        comptime FmtError: type,
        output: fn (@typeOf(context), []const u8) FmtError!void,
    ) FmtError!void {
        switch (self) {
            Request.Call => |c| {
                if (c.params) |p| {
                    try std.fmt.format(context, FmtError, output, "{}{},\"method\":\"{}\",\"params\":", "{", rpc_version, c.method);
                    try jsonToString(p, fmt, context, FmtError, output);
                    try std.fmt.format(context, FmtError, output, ",\"id\":\"{}\"{}", c.id, "}");
                } else {
                    return std.fmt.format(context, FmtError, output,
                        "{}{},\"method\":\"{}\",\"id\":\"{}\"{}",
                        "{", rpc_version, c.method, c.id, "}"
                    );
                }
            },
            Request.Notification => |n| {
                if (n.params) |p| {
                    try std.fmt.format(context, FmtError, output, "{}{},\"method\":\"{}\",\"params\":", "{", rpc_version, n.method);
                    try jsonToString(p, fmt, context, FmtError, output);
                    try std.fmt.format(context, FmtError, output, "{}", "}");
                } else {
                    return std.fmt.format(context, FmtError, output,
                        "{}{},\"method\":\"{}\"{}",
                        "{", rpc_version, n.method, "}"
                    );
                }
            }
        }
    }
};

pub const Response = union(enum) {
    Error: ErrorObj,
    Ok: OkObj,

    pub const ErrorObj = struct {
        code: ErrorCode,
        message: []const u8,
        data: ?Value,
    };

    pub const OkObj = struct {
        result: Value,
        id: Oid,
    };

    pub fn ok(result: Value, id: Oid) Response {
        return Response {
            .Ok = OkObj {
                .result = result,
                .id = id,
            }
        };
    }

    pub fn err(code: ErrorCode, data: ?Value) Response {
        return Response {
            .Error = ErrorObj {
                .code = code,
                .message = code.getMsg(),
                .data = data,
            }
        };
    }

    pub fn format(
        self: Response,
        comptime fmt: []const u8,
        context: var,
        comptime FmtError: type,
        output: fn (@typeOf(context), []const u8) FmtError!void,
    ) FmtError!void {
        switch (self) {
            Response.Ok => |o| {
                try std.fmt.format(context, FmtError, output, "{}{},\"result\":", "{", rpc_version);
                try jsonToString(o.result, fmt, context, FmtError, output);
                try std.fmt.format(context, FmtError, output, ",\"id\":\"{}\"{}", o.id, "}");
            },
            Response.Error => |e| {
                if (e.data) |d| {
                    try std.fmt.format(context, FmtError, output,
                        "{}{},\"error\":{}\"code\":{},\"message\":\"{}\",\"data\":",
                        "{", rpc_version, "{", e.code.toInt(), e.message
                    );
                    try jsonToString(d, fmt, context, FmtError, output);
                    try std.fmt.format(context, FmtError, output, ",\"id\":null{}", "}");
                } else {
                    try std.fmt.format(context, FmtError, output,
                        "{}{},\"error\":{}\"code\":{},\"message\":\"{}\"{},\"id\":null{}",
                        "{", rpc_version, "{", e.code.toInt(), e.message, "}", "}"
                    );
                }
            }
        }
    }
};

pub const ErrorCode = union(enum) {
    ParserError: void,
    InvalidRequest: void,
    MethodNotFound: void,
    InvalidParams: void,
    InternalError: void,
    ServerError: isize,
    Custom: CustomErr,

    pub const CustomErr = struct {
        err: anyerror,
        message: []const u8,
    };

    fn toInt(self: ErrorCode) isize {
        return switch (self) {
            ErrorCode.ParserError => -32700,
            ErrorCode.InvalidRequest => -32600,
            ErrorCode.MethodNotFound => -32601,
            ErrorCode.InvalidParams => -32602,
            ErrorCode.InternalError => -32603,
            ErrorCode.ServerError => |c| c,
            ErrorCode.Custom => |c| @intCast(isize, @errorToInt(c.err)),
        };
    }

    pub fn getMsg(self: ErrorCode) []const u8 {
        return switch (self) {
            ErrorCode.ParserError => "Parse error",
            ErrorCode.InvalidRequest => "Invalid Request",
            ErrorCode.MethodNotFound => "Method not found",
            ErrorCode.InvalidParams => "Invalid params",
            ErrorCode.InternalError => "Internal error",
            ErrorCode.ServerError => "Server error",
            ErrorCode.Custom => |c| c.message,
        };
    }
};

test "Request.Call" {
    var out_slice: [5000]u8 = undefined;
    var slice_stream = std.io.SliceOutStream.init(out_slice[0..]);
    var params = blk: {
        var slice = []Value{ Value { .Integer = 1 }, Value { .Integer = 2 } };
        break :blk std.ArrayList(Value).fromOwnedSlice(std.debug.global_allocator, slice[0..]);
    };
    try slice_stream.stream.print("{}", Request.call("example.call", Value { .Array = params }));
    assert(std.json.validate(slice_stream.getWritten()));
}

test "Request.Notification" {
    var out_slice = []u8{0} ** 500;
    var slice_stream = std.io.SliceOutStream.init(out_slice[0..]);
    var params = blk: {
        var slice = []Value{ Value { .Integer = 1 }, Value { .Integer = 2 } };
        break :blk std.ArrayList(Value).fromOwnedSlice(std.debug.global_allocator, slice[0..]);
    };
    try slice_stream.stream.print("{}", Request.notify("example.notification", Value { .Array = params }));
    assert(std.json.validate(slice_stream.getWritten()));
}

test "Response.Ok" {
    var out_slice = []u8{0} ** 500;
    var slice_stream = std.io.SliceOutStream.init(out_slice[0..]);
    try slice_stream.stream.print("{}", Response.ok(Value.Null,Oid.new()));
    assert(std.json.validate(slice_stream.getWritten()));
}

test "Response.Error" {
    var out_slice = []u8{0} ** 500;
    var slice_stream = std.io.SliceOutStream.init(out_slice[0..]);
    try slice_stream.stream.print("{}", Response.err(ErrorCode.InternalError, null));
    assert(std.json.validate(slice_stream.getWritten()));
}
