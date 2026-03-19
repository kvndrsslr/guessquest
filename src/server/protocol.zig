const std = @import("std");
const bit_io = @import("./bit_io.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Parsed = std.json.Parsed;

const log = std.log.scoped(.message);

pub const RoomType = enum(u1) {
    StoryPoints = 0,
    PersonDays = 1,
};

const ChoiceType = enum(u2) {
    SingleNumber = 0,
    SingleString = 1,
    TwoNumbers = 2,
    None = 3,
};

pub const Choice = union(ChoiceType) {
    SingleNumber: u8,
    SingleString: []const u8,
    TwoNumbers: [2]u8,
    None,

    pub fn clone(self: Choice, alloc: Allocator) !Choice {
        switch (self) {
            .SingleNumber => |num| {
                return .{ .SingleNumber = num };
            },
            .SingleString => |str| {
                const str_clone = try alloc.dupe(u8, str);
                return .{ .SingleString = str_clone };
            },
            .TwoNumbers => |arr| {
                const arr_clone: [2]u8 = [_]u8{ arr[0], arr[1] };
                return .{ .TwoNumbers = arr_clone };
            },
            .None => {
                return .{ .None = {} };
            },
        }
    }

    pub fn deinit(self: *Choice, alloc: Allocator) void {
        switch (self.*) {
            .SingleString => |str| {
                alloc.free(str);
            },
            else => {},
        }
    }
};

const MessageType = enum(u4) {
    Join = 0,
    Reveal = 1,
    ResetRoom = 2,
    UpdateUserChoice = 3,
    UpdateUserName = 4,
    UpdateUserHero = 5,
    UpdateUserSpectator = 6,
    UserConnected = 7,
    UserDisconnected = 8,
    NotImplemented = 9,
    Reserved1 = 10,
    // 11 is the 4-bit prefix of the byte value of "{" (0x7B), which is used to indicate a JSON object.
    // This makes it easier to embed the Sync payload as a JSON object within our binary protocol.
    Sync = 11,
    Reserved2 = 12,
    Poke = 13,
    Ping = 14,
    Pong = 15,
};

pub const UserData = struct {
    name: []const u8,
    user_id: u4,
    hero: u8,
    choice: Choice,
    is_spectator: bool,
    edited: bool = false,
};

pub const Message = union(MessageType) {
    Join: struct {
        hero: u8,
        room_type: RoomType,
        is_spectator: bool,
        choice: Choice,
        room_id: []const u8,
        name: []const u8,
    },
    Reveal,
    ResetRoom: RoomType,
    UpdateUserChoice: Choice,
    UpdateUserName: []const u8,
    UpdateUserHero: u8,
    UpdateUserSpectator: bool,
    UserConnected: UserData,
    UserDisconnected: u4,
    NotImplemented,
    Reserved1,
    Sync: struct {
        room_type: RoomType,
        is_revealed: bool,
        quest: u8,
        users: []UserData,
    },
    Reserved2,
    Poke: struct {
        user_id: u4,
        with: []const u8,
    },
    Ping,
    Pong,

    const Self = @This();

    // Frontend maxlength counts UTF-16 code units; we count them from UTF-8 to match
    const max_name_utf16_len = 18;
    const max_room_id_utf16_len = 18;
    const max_string_utf16_len = 256;

    /// Count UTF-16 code units for a UTF-8 encoded string.
    /// Returns null if the input is not valid UTF-8.
    fn utf16Len(utf8: []const u8) ?usize {
        const view = std.unicode.Utf8View.init(utf8) catch return null;
        var it = view.iterator();
        var len: usize = 0;
        while (it.nextCodepoint()) |cp| {
            len += if (cp > 0xFFFF) @as(usize, 2) else 1;
        }
        return len;
    }

    fn validateStringLen(str: []const u8, max_utf16_len: usize, alloc: Allocator) MessageError!void {
        const len = utf16Len(str) orelse {
            alloc.free(str);
            return MessageError.InvalidData;
        };
        if (len > max_utf16_len) {
            alloc.free(str);
            return MessageError.InvalidData;
        }
    }

    fn parseChoice(
        bit_reader: *bit_io.BitReader(.little),
        bytes_reader: *std.io.Reader,
        alloc: Allocator,
    ) !Choice {
        const choice_type: ChoiceType = @enumFromInt(try bit_reader.readBitsNoEof(u2, 2));
        bit_reader.alignToByte();
        switch (choice_type) {
            .SingleNumber => {
                const choice_value: u8 = try bit_reader.readBitsNoEof(u8, 8);
                return .{ .SingleNumber = choice_value };
            },
            .SingleString => {
                var alloc_writer = std.io.Writer.Allocating.init(alloc);
                defer alloc_writer.deinit();
                _ = try bytes_reader.streamDelimiterEnding(&alloc_writer.writer, 0);
                const choice = try alloc_writer.toOwnedSlice();
                return .{ .SingleString = choice };
            },
            .TwoNumbers => {
                var arr: [2]u8 = undefined;
                arr[0] = try bit_reader.readBitsNoEof(u8, 8);
                arr[1] = try bit_reader.readBitsNoEof(u8, 8);
                return .{ .TwoNumbers = arr };
            },
            .None => {
                return .{ .None = {} };
            },
        }
    }

    const MessageError = error{
        InvalidData,
    };

    pub fn parse(data: []const u8, alloc: Allocator) !Self {
        if (data.len < 1 or data.len > 2048) {
            return MessageError.InvalidData;
        }
        // const mem: [64]u8 = [0] ** 64;
        var bytes_reader = std.Io.Reader.fixed(data);
        var bit_reader = bit_io.bitReader(.little, &bytes_reader);
        // var out_bits: u16 = undefined;
        // _ = out_bits; // autofix
        const message_type: MessageType = @enumFromInt(try bit_reader.readBitsNoEof(u4, 4));
        switch (message_type) {
            // empty
            .Ping => {
                return .{ .Ping = {} };
            },
            .Reveal => {
                return .{ .Reveal = {} };
            },
            // simple
            .ResetRoom => {
                const room_type: RoomType = @enumFromInt(try bit_reader.readBitsNoEof(u1, 1));
                return .{ .ResetRoom = room_type };
            },
            .UpdateUserHero => {
                const hero: u8 = try bit_reader.readBitsNoEof(u8, 8);
                return .{ .UpdateUserHero = hero };
            },
            .UpdateUserName => {
                var alloc_writer = std.io.Writer.Allocating.init(alloc);
                defer alloc_writer.deinit();
                _ = try bytes_reader.streamDelimiterEnding(&alloc_writer.writer, 0);
                const name = try alloc_writer.toOwnedSlice();
                try validateStringLen(name, max_name_utf16_len, alloc);

                return .{ .UpdateUserName = name };
            },
            .UpdateUserChoice => {
                return .{ .UpdateUserChoice = try parseChoice(&bit_reader, &bytes_reader, alloc) };
            },
            .UpdateUserSpectator => {
                const is_spectator: bool = @as(bool, @bitCast(try bit_reader.readBitsNoEof(u1, 1)));
                return .{ .UpdateUserSpectator = is_spectator };
            },
            .Poke => {
                const user_id: u4 = try bit_reader.readBitsNoEof(u4, 4);
                var alloc_writer = std.io.Writer.Allocating.init(alloc);
                defer alloc_writer.deinit();
                _ = try bytes_reader.streamDelimiterEnding(&alloc_writer.writer, 0);
                const with = try alloc_writer.toOwnedSlice();
                try validateStringLen(with, max_string_utf16_len, alloc);

                return .{ .Poke = .{ .user_id = user_id, .with = with } };
            },
            // complex
            .Join => {
                const hero: u8 = try bit_reader.readBitsNoEof(u8, 8);
                const room_type: RoomType = @enumFromInt(try bit_reader.readBitsNoEof(u1, 1));
                const is_spectator: bool = @as(bool, @bitCast(try bit_reader.readBitsNoEof(u1, 1)));
                const choice = try parseChoice(&bit_reader, &bytes_reader, alloc);

                var alloc_writer = std.io.Writer.Allocating.init(alloc);
                defer alloc_writer.deinit();

                _ = try bytes_reader.streamDelimiterEnding(&alloc_writer.writer, 0);
                const room_id = try alloc_writer.toOwnedSlice();
                try validateStringLen(room_id, max_room_id_utf16_len, alloc);

                bytes_reader.toss(1);

                _ = try bytes_reader.streamDelimiterEnding(&alloc_writer.writer, 0);
                const name = try alloc_writer.toOwnedSlice();
                validateStringLen(name, max_name_utf16_len, alloc) catch |err| {
                    alloc.free(room_id);
                    return err;
                };

                return .{
                    .Join = .{
                        .hero = hero,
                        .room_type = room_type,
                        .is_spectator = is_spectator,
                        .choice = choice,
                        .room_id = room_id,
                        .name = name,
                    },
                };
            },
            // client only or reserved
            else => {
                log.warn("Received unsupported message type: {any}", .{message_type});
                return .{ .NotImplemented = {} };
            },
        }
    }

    pub fn serialize(self: *Message, byte_writer: *std.Io.Writer, user_id: u4) !void {
        var bit_writer = bit_io.bitWriter(.little, byte_writer);

        try bit_writer.writeBits(@intFromEnum(self.*), 4);

        switch (self.*) {
            .ResetRoom => |room_type| {
                try bit_writer.writeBits(@intFromEnum(room_type), 1);
            },
            .UpdateUserHero => |hero| {
                try bit_writer.writeBits(user_id, 4);
                try bit_writer.writeBits(hero, 8);
            },
            .UpdateUserName => |name| {
                try bit_writer.writeBits(user_id, 4);
                try bit_writer.flushBits();
                try byte_writer.writeAll(name);
                try byte_writer.writeByte(0);
            },
            .UpdateUserChoice => |choice| {
                try bit_writer.writeBits(user_id, 4);
                try bit_writer.writeBits(@intFromEnum(choice), 2);
                try bit_writer.flushBits();
                switch (choice) {
                    .SingleNumber => |num| {
                        try byte_writer.writeByte(num);
                    },
                    .SingleString => |str| {
                        try byte_writer.writeAll(str);
                        try byte_writer.writeByte(0);
                    },
                    .TwoNumbers => |arr| {
                        try byte_writer.writeAll(&arr);
                    },
                    .None => {},
                }
            },
            .UpdateUserSpectator => |is_spectator| {
                try bit_writer.writeBits(user_id, 4);
                try bit_writer.writeBits(@intFromBool(is_spectator), 1);
            },
            .Poke => |poke| {
                try bit_writer.writeBits(user_id, 4);
                try bit_writer.writeBits(poke.user_id, 4);
                try bit_writer.flushBits();
                try byte_writer.writeAll(poke.with);
                try byte_writer.writeByte(0); // null-terminate the string
            },
            .UserDisconnected => |dc_id| {
                try bit_writer.writeBits(dc_id, 4);
            },
            .UserConnected => |user| {
                try bit_writer.writeBits(user.user_id, 4);
                try bit_writer.writeBits(user.hero, 8);
                try bit_writer.writeBits(@intFromBool(user.is_spectator), 1);
                try bit_writer.writeBits(@intFromEnum(user.choice), 2);
                try bit_writer.flushBits();
                switch (user.choice) {
                    .SingleNumber => |num| {
                        try byte_writer.writeByte(num);
                    },
                    .SingleString => |str| {
                        try byte_writer.writeAll(str);
                        try byte_writer.writeByte(0);
                    },
                    .TwoNumbers => |arr| {
                        try byte_writer.writeAll(&arr);
                    },
                    .None => {},
                }
                try byte_writer.writeAll(user.name);
                try byte_writer.writeByte(0); // null-terminate the name
            },
            .Sync => |data| {
                try bit_writer.writeBits(user_id, 4);
                try bit_writer.writeBits(@intFromEnum(data.room_type), 1);
                try bit_writer.writeBits(@intFromBool(data.is_revealed), 1);
                try bit_writer.writeBits(data.users.len, 6);
                try bit_writer.writeBits(data.quest, 8);
                for (data.users) |user| {
                    try bit_writer.writeBits(user.user_id, 4);
                }
                for (data.users) |user| {
                    try bit_writer.writeBits(user.hero, 8);
                }
                for (data.users) |user| {
                    try bit_writer.writeBits(@intFromBool(user.is_spectator), 1);
                }
                for (data.users) |user| {
                    try bit_writer.writeBits(@intFromBool(user.edited), 1);
                }
                for (data.users) |user| {
                    try bit_writer.writeBits(@intFromEnum(user.choice), 2);
                }
                try bit_writer.flushBits();
                for (data.users) |user| {
                    switch (user.choice) {
                        .SingleNumber => |num| {
                            try byte_writer.writeByte(num);
                        },
                        .SingleString => |str| {
                            try byte_writer.writeAll(str);
                            try byte_writer.writeByte(0);
                        },
                        .TwoNumbers => |arr| {
                            try byte_writer.writeAll(&arr);
                        },
                        .None => {},
                    }
                }
                for (data.users) |user| {
                    try byte_writer.writeAll(user.name);
                    try byte_writer.writeByte(0); // null-terminate the name
                }
            },
            else => {},
        }

        try bit_writer.flushBits();
        try byte_writer.flush();
    }
};

const expect = std.testing.expect;
var test_alloc = std.testing.allocator;

test "parse ping" {
    const data = [_]u8{0b00001110};

    const msg = try Message.parse(&data, test_alloc);
    try switch (msg) {
        .Ping => expect(true),
        else => expect(false),
    };
}

test "parse reveal" {
    const data = [_]u8{0b00010001};

    const msg = try Message.parse(&data, test_alloc);
    try switch (msg) {
        .Reveal => expect(true),
        else => expect(false),
    };
}

test "parse reset room" {
    var data = [_]u8{0b00000010};

    const msg = try Message.parse(&data, test_alloc);
    try switch (msg) {
        .ResetRoom => |rt| expect(rt == .StoryPoints),
        else => expect(false),
    };
    data[0] = 0b00010010;
    const msg2 = try Message.parse(&data, test_alloc);
    try switch (msg2) {
        .ResetRoom => |rt| expect(rt == .PersonDays),
        else => expect(false),
    };
}

test "parse update user hero" {
    const data = [_]u8{ 0b10110101, 0b0000000 };

    const msg = try Message.parse(&data, test_alloc);
    try switch (msg) {
        .UpdateUserHero => |hero| expect(hero == 11),
        else => expect(false),
    };
}

test "parse update user name" {
    const data = [_]u8{ 0b10100100, 70, 111, 111, 66, 97, 114, 32, 66, 97, 122 };
    const msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserName => |name| {
            try expect(std.mem.eql(u8, name, "FooBar Baz"));
            test_alloc.free(msg.UpdateUserName);
        },
        else => try expect(false),
    }
}

test "parse update user spectator" {
    const data = [_]u8{0b00010110};
    const msg = try Message.parse(&data, test_alloc);
    try switch (msg) {
        .UpdateUserSpectator => |is_spectator| expect(is_spectator == true),
        else => expect(false),
    };
}

test "parse update user choice" {
    var data = [_]u8{ 0b00000011, 'A', 'B', 'C', 0, 'D' };
    var msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserChoice => |choice| switch (choice) {
            .SingleNumber => try expect(choice.SingleNumber == 65),
            else => try expect(false),
        },
        else => try expect(false),
    }
    data[0] = 0b00010011;
    msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserChoice => |choice| switch (choice) {
            .SingleString => |str| {
                try expect(std.mem.eql(u8, choice.SingleString, "ABC"));
                test_alloc.free(str);
            },
            else => try expect(false),
        },
        else => try expect(false),
    }
    data[0] = 0b00100011;
    msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserChoice => |choice| switch (choice) {
            .TwoNumbers => |arr| {
                try expect(arr[0] == 65);
                try expect(arr[1] == 66);
            },
            else => try expect(false),
        },
        else => try expect(false),
    }
    data[0] = 0b00110011;
    msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserChoice => |choice| switch (choice) {
            .None => try expect(true),
            else => try expect(false),
        },
        else => try expect(false),
    }
}

test "parse poke" {
    const data = [_]u8{ 0b01111101, 'F', 'o', 'o', ' ', 'B', 'a', 'r' };
    const msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .Poke => |poke| {
            try expect(poke.user_id == 7);
            try expect(std.mem.eql(u8, poke.with, "Foo Bar"));
            test_alloc.free(poke.with);
        },
        else => try expect(false),
    }
}

test "parse join" {
    const data = [_]u8{
        0b10000000,
        0b00100000,
        0b10000010,
        'R', 'o', 'o', 'm', '1', 0, // Room ID
        'U', 's', 'e', 'r', 0, // User name
    };
    std.debug.print("Data: \n{any}\n", .{data});
    const msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .Join => |join| {
            std.debug.print("Parsed Join: \n{any}\n", .{join});
            try expect(join.hero == 8);
            try expect(join.room_type == .StoryPoints);
            try expect(join.is_spectator == true);
            try expect(join.choice.SingleNumber == 130);
            try expect(std.mem.eql(u8, join.room_id, "Room1"));
            try expect(std.mem.eql(u8, join.name, "User"));
            test_alloc.free(join.room_id);
            test_alloc.free(join.name);
        },
        else => try expect(false),
    }
}

test "utf16Len counts correctly" {
    // ASCII: 1 byte = 1 UTF-16 code unit each
    try expect(Message.utf16Len("hello").? == 5);
    // CJK U+4E16 (世): 3 UTF-8 bytes, 1 UTF-16 code unit each
    try expect(Message.utf16Len("世界").? == 2);
    // Emoji U+1F389 (🎉): 4 UTF-8 bytes, 2 UTF-16 code units (surrogate pair)
    try expect(Message.utf16Len("🎉").? == 2);
    // Mixed: "hi🎉" = 2 + 2 = 4 UTF-16 code units
    try expect(Message.utf16Len("hi🎉").? == 4);
    // Empty string
    try expect(Message.utf16Len("").? == 0);
    // Invalid UTF-8
    try expect(Message.utf16Len(&[_]u8{ 0xFF, 0xFE }) == null);
}

test "reject name exceeding max length" {
    // 19 ASCII chars = 19 UTF-16 code units, exceeds max_name_utf16_len (18)
    const data = [_]u8{0b10100100} ++ "1234567890123456789".*;
    try std.testing.expectError(error.InvalidData, Message.parse(&data, test_alloc));
}

test "accept name at max length" {
    // 18 ASCII chars = 18 UTF-16 code units, exactly at limit
    const data = [_]u8{0b10100100} ++ "123456789012345678".*;
    const msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserName => |name| {
            try expect(name.len == 18);
            test_alloc.free(name);
        },
        else => try expect(false),
    }
}

test "reject name with emoji exceeding max UTF-16 length" {
    // 🎉 = 2 UTF-16 code units. 17 ASCII + 🎉 = 17 + 2 = 19 > 18
    const data = [_]u8{0b10100100} ++ "12345678901234567\xF0\x9F\x8E\x89".*;
    try std.testing.expectError(error.InvalidData, Message.parse(&data, test_alloc));
}

test "accept name with emoji at max UTF-16 length" {
    // 🎉 = 2 UTF-16 code units. 16 ASCII + 🎉 = 16 + 2 = 18
    const data = [_]u8{0b10100100} ++ "1234567890123456\xF0\x9F\x8E\x89".*;
    const msg = try Message.parse(&data, test_alloc);
    switch (msg) {
        .UpdateUserName => |name| {
            try expect(std.mem.eql(u8, name, "1234567890123456🎉"));
            test_alloc.free(name);
        },
        else => try expect(false),
    }
}

test "reject name with invalid UTF-8" {
    const data = [_]u8{ 0b10100100, 0xFF, 0xFE, 0 };
    try std.testing.expectError(error.InvalidData, Message.parse(&data, test_alloc));
}

test "reject join with room_id exceeding max length" {
    // Build a Join message with a 19-char room_id
    const data = [_]u8{
        0b10000000, // Join + hero high nibble
        0b00100000, // hero low + room_type + spectator
        0b10000010, // choice (SingleNumber = 130)
    } ++ "1234567890123456789".* ++ [_]u8{0} // room_id: 19 chars
    ++ "Ok".* ++ [_]u8{0}; // name: 2 chars
    try std.testing.expectError(error.InvalidData, Message.parse(&data, test_alloc));
}

test "reject poke with string exceeding max length" {
    // Poke message: 4-bit type (0xD) + 4-bit user_id + null-terminated string
    // Build string of 257 ASCII chars (exceeds max_string_utf16_len = 256)
    var data: [2 + 257]u8 = undefined;
    data[0] = 0b01111101; // user_id=7, type=Poke(13)
    @memset(data[1 .. 1 + 257], 'A');
    // No null terminator — streamDelimiterEnding reads to end of fixed reader
    try std.testing.expectError(error.InvalidData, Message.parse(&data, test_alloc));
}
