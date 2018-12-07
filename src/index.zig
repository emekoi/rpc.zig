//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

const std = @import("std");

pub const Oid = @import("oid.zig").Oid;
pub const Value = std.json.Value;

pub const Request = struct {
    jsonrpc: []const u8,
    method: []const u8,
    params: ?Value,
    id: Oid,

    pub fn new(method: []const u8, params: ?Value) Request {
        return Request {
            .jsonrpc = "2.0",
            .method = method,
            .params = params,
            .id = Oid.new(),
        };
    }
};

pub const Notification = struct {
    method: []const u8,
    params: ?Value,

    pub fn new(method: []const u8, params: ?Value) Notification {
        return Notification {
            .method = method,
            .params = params,
        };
    }
};

pub const Response = struct {
    result: ?Value,
    err: ?Error,
    id: ?Oid,

    pub fn new(result: Value, id: Oid) Response {
        return Response {
            .result = result,
            .err = null,
            .id = id,
        };
    }

    pub fn err(err: Error) Response {
        return Response {
            .result = null,
            .err = err,
            .id = null,
        };
    }
};

pub const Error = struct {
    code: ErrorCode,
    message: []const u8,
    data: ?Value,

    pub fn new(code: ErrorCode, data: ?Value) Error {
        return Error {
            .code = code,
            .message = code.getMsg(),
            .data = data,
        };
    }

    pub fn parse(data: []const u8) Error {

    }
};

pub const ErrorCode = union(enum) {
    ParserError: void,
    InvalidRequest: void,
    MethodNotFound: void,
    InvalidParams: void,
    InternalError: void,
    ServerError: isize,
    Custom: Custom,

    pub const Custom = struct {
        err: anyerror,
        msg: []const u8,
    };

    fn toCode(self: ErrorCode) isize {
        return switch (self) {
            ErrorCode.ParserError => -32700,
            ErrorCode.InvalidRequest => -32600,
            ErrorCode.MethodNotFound => -32601,
            ErrorCode.InvalidParams => -32602,
            ErrorCode.InternalError => -32603,
            ErrorCode.ServerError => |c| c,
            ErrorCode.Custom => |c| @errorToInt(c.err),
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
            ErrorCode.Custom => |c| c.msg,
        };
    }
};


test "import test" {
    _ = @import("oids.zig");
}
