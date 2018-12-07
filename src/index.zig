//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

const std = @import("std");

pub const Oid = @import("oids.zig").Oid;
pub const Value = std.json.Value;

const rpc_version = "\"jsonrpc\":\"2.0\"";

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
                    return std.fmt.format(context, FmtError, output,
                        "{}{},\"method\":\"{}\",\"params\":{},\"id\":\"{}\"{}",
                        "{", rpc_version, c.method, p.dump(), c.id, "}"
                    );
                } else {
                    return std.fmt.format(context, FmtError, output,
                        "{}{},\"method\":\"{}\",\"id\":\"{}\"{}",
                        "{", rpc_version, c.method, c.id, "}"
                    );
                }
            },
            Request.Notification => |n| {
                if (n.params) |p| {
                    return std.fmt.format(context, FmtError, output,
                        "{}{},\"method\":\"{}\",\"params\":{}{}",
                        "{", rpc_version, n.method, p.dump(), "}"
                    );
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
                return std.fmt.format(context, FmtError, output,
                    "{}{},\"result\":{},\"id\":\"{}\"{}",
                    "{", rpc_version, o.result.dump(), o.id, "}"
                );
            },
            Response.Error => |e| {
                if (e.data) |d| {
                    return std.fmt.format(context, FmtError, output,
                        "{}{},\"error\":{}\"code\":{},\"message\":\"{}\",\"data\":{}{},\"id\":null{}",
                        "{", rpc_version, "{", e.code.toInt(), e.message, d.dump(), "}", "}"
                    );
                } else {
                    return std.fmt.format(context, FmtError, output,
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

test "import test" {
    _ = @import("oids.zig");
}
