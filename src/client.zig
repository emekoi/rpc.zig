//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

const std = @import("std");
const rpc = @import("index.zig");

const AwaitMap = ;
const Allocator = std.mem.Allocator;
const socket = std.socket;
const net = std.net;

fn AwaitMap(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: *Allocator,
        map: AutoHashMap,

        fn init(allocator: *Allocator) {
            return Self {
                .map = std.AutoHashMap(rpc.Oid, promise->T).init(allocator),
                .allocator = allocator,
            };
        }

        async fn get(self: *Self, socket: Socket, id: rp.Oid) T {
            
        }

        fn deinit(self: *Self) void {
            defer self.map.deinit();
            var it = self.map.iter();
            while (it.next()) |request| {
                cancel request;
            }
        }
    };
}

pub const Client = struct {
    allocator: *std.mem.Allocator,
    fd: socket.Socket,
    address: net.Address,
    await_ids: ,

    pub fn new(allocator: *std.mem.Allocator) !Client {
        return Client {
            .fd = try Socket.tcp(Domain.Inet6),
            .await_ids = AwaitMap.init(),
            .allocator = allocator,
            .address = undefined,
        };
    }

    pub fn close(self: Client) void {
        self.await_ids.deinit();
        self.fd.close();
    }

    pub fn call(self: *Client, method: []const u8, params: ?rpc.Value) rpc.Response {
        const request = rpc.Request.new(methods, params);
        self.fd.send(request.toString() ++ "\r\n");
        self.await_ids.get(request.id);
    }

    pub fn notify(self: *Client, method: []const u8, params: ?rpc.Value) {
        _ = self.call(method, params);
    }
};
