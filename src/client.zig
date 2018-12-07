//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

const std = @import("std");
const rpc = @import("index.zig");

const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const socket = std.socket;
const json = std.json;
const net = std.net;

const assert = std.debug.assert;

fn Future(comptime T: type) type {
    return struct {
        handle: promise,
        data: ?T,
    };
}

pub const Client = struct {
    const ResponseFuture = Future(rpc.Response);
    const AwaitMap = std.AutoHashMap(rpc.Oid, ResponseFuture);

    allocator: *std.mem.Allocator,
    parser: json.Parser,
    fd: socket.Socket,
    address: net.Address,
    await_ids: AwaitMap,

    pub fn new(allocator: *std.mem.Allocator) !Client {
        return Client {
            .fd = try Socket.tcp(Domain.Inet6),
            .await_ids = AwaitMap.init(allocator),
            .parser = json.Parser.init(allocator, true),
            .allocator = allocator,
            .address = undefined,
        };
    }

    pub fn close(self: Client) void {
        defer self.parser.deinit();
        defer self.map.deinit();
        defer self.fd.close();

        var it = self.map.iter();
        while (it.next()) |request| {
            cancel request;
        }
    }

    pub fn connect(self: *Client, address: Address) !void {
        try self.fd.connect(&address);
        errdefer self.fd.close();
        self.address = address;
        cancel try self.processData();
    }

    async fn processData(self: *Client) !void {
        loop: while (true) {
            const data = await self.fd.recv(self.allocator) catch |err| {
                switch (err) {
                    error.Disconnect => {
                        self.fd.close();
                        self.fd = try Socket.tcp(Domain.Inet6);
                        break :loop;
                    },
                    else => return err,
                }
            };

            try self.processMessage(data);
        }

        try self.fd.connect(&address);
    }

    fn processMessage(self: *Client, data: []const u8) !void {
        const root = try self.parser.parse(data).root;
        debug.assert(mem.eql(u8, root.Object.get("jsonrpc").?.value.String, "2.0"));
        
        if (root.Object.get("error")) |err| {
            fut.data = rpc.Response {
                .err = Error.parse(err.String),
                .result = null,
                .id = null,
            };
        } else {
            const id = Oid.parse(root.Object.get("id").?.value.String);
            var fut = self.await_ids.get(id).?;

            fut.data = rpc.Response {
                .result = root.Object.get("result").?,
                .err = null,
                .id = id,
            };

            resume fut.handle;

        }
    }

    pub fn async call(self: *Client, method: []const u8, params: ?rpc.Value) !rpc.Response {
        const request = rpc.Request.new(methods, params);
        self.fd.send(request.toString() ++ "\r\n");
        // const fut = try self.getResponse();
        _ = self.await_ids.set(request.id, ResponseFuture {
            .handle = @handle(),
            .data = null
        });
        return await fut;
    }

    pub async fn notify(self: *Client, method: []const u8, params: ?rpc.Value) !void {
        const request = rpc.Request.new(methods, params);
        try await self.fd.send(request.toString() ++ "\r\n");
    }
};
