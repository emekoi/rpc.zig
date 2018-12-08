//  Copyright (c) 2018 emekoi
//
//  This library is free software; you can redistribute it and/or modify it
//  under the terms of the MIT license. See LICENSE for details.
//

const std = @import("std");
const time = std.os.time;
const mem = std.mem;

const AtomicInt = std.atomic.Int;
const Xoroshiro128 = std.rand.Xoroshiro128;

pub const OidError = error {
    InvalidOid,
};

pub const Oid = packed struct {
    const Size = @sizeOf(u32) * 3;

    // data race!
    var prng: ?Xoroshiro128 = null;
    var incr = AtomicInt(usize).init(0);

    time: u32,
    fuzz: u32,
    count: u32,

    pub fn new() Oid {
        const t = time.timestamp();
        _ = incr.incr();

        // data race!
        if (prng == null) {
            prng = Xoroshiro128.init(t);
        }

        return Oid {
            .count = mem.endianSwapIfLe(u32, @truncate(u32, incr.incr())),
            .time = mem.endianSwapIfLe(u32, @truncate(u32, t)),
            .fuzz = @truncate(u32, prng.?.next()),
        };
    }

    pub fn parse(str: []const u8) !Oid {
        var result: Oid = undefined;
        var bytes = std.mem.asBytes(&result);
        try std.fmt.hexToBytes(bytes[0..], str);
        return result;
    }

    // TODO make this simpler
    pub fn toString(self: Oid) [Size * 2]u8 {
        const hex = "0123456789abcdef";
        var result = []u8{0} ** (Size * 2);
        const bytes = std.mem.toBytes(self);
        for (bytes) |b, i| {
            result[2 * i] = hex[(b & 0xF0) >> 4];
            result[2 * i + 1] = hex[b & 0x0F];
        }
        return result;
    }

    pub fn format(
        self: Oid,
        comptime fmt: []const u8,
        context: var,
        comptime FmtError: type,
        output: fn (@typeOf(context), []const u8) FmtError!void,
    ) FmtError!void {
        return std.fmt.format(context, FmtError, output, "{}", self.toString());
    }

    pub fn equal(self: Oid, other: Oid) bool {
        return std.mem.eql(u8,
            std.mem.asBytes(&self),
            std.mem.asBytes(&other)
        );
    }
};


test "Oids" {
    const assert = std.debug.assert;
    const oid = Oid.new();
    assert(oid.equal(try Oid.parse(oid.toString())));
}
