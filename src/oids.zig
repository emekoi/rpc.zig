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

fn hexByte(hex: u8) u8 {
    return switch (hex) {
        '0' ... '9' => hex - '0',
        'a' ... 'f' => hex - 'a' + 10,
        'A' ... 'F' => hex - 'A' + 10,
        else => 0,
    };
}

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

    pub fn parse(str: []const u8) Oid {
        var result: Oid = undefined;

        const bytes = @ptrCast([*]u8, &result);
            
        comptime var i = 0;
        inline while (i < Size) : (i += 1) {
            const hi = hexByte(str[2 * i]);
            const lo = hexByte(str[2 * i + 1]);
            bytes[i] = (hi << 4) | lo;
        }
        return result;
    }

    pub fn toString(self: Oid) [Size * 2]u8 {
        const hex = "0123456789abcdef";
        var result = []u8{0} ** (Size * 2);

        const bytes = @ptrCast([*]const u8, &self);

        comptime var i = 0;
        inline while (i < Size) : (i += 1) {
            result[2 * i] = hex[(bytes[i] & 0xF0) >> 4];
            result[2 * i + 1] = hex[bytes[i] & 0x0F];
        }
        return result;
    }

    pub fn equal(self: Oid, other: Oid) bool {
        return self.time == other.time and self.fuzz == other.fuzz and self.count == other.count;
    }
};


test "Oids" {
    const assert = std.debug.assert;
    const oid = Oid.new();
    assert(oid.equal(Oid.parse(oid.toString())));
}
