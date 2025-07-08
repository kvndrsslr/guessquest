const std = @import("std");
const ws = @import("websocket");
const msg = @import("message.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Parsed = std.json.Parsed;
const Mutex = std.Thread.Mutex;

const Message = msg.Message;
const RoomType = msg.RoomType;
const Choice = msg.Choice;
const UserData = msg.UserData;

pub const std_options = std.Options{ .log_scope_levels = &[_]std.log.ScopeLevel{
    .{ .scope = .websocket, .level = .err },
} };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = gpa.allocator();

    var server = try ws.Server(Handler).init(allocator, .{
        .port = 60355,
        .address = "127.0.0.1",
        .handshake = .{
            .timeout = 10,
            .max_size = 1024 * 16,
            // since we aren't using hanshake.headers
            // we can set this to 0 to save a few bytes.
            .max_headers = 0,
        },
    });

    var app = App{
        .allocator = &allocator,
        .rooms = std.StringHashMap(*Room).init(allocator),
    };

    // this blocks
    try server.listen(&app);
}

const App = struct {
    allocator: *const Allocator,
    rooms: std.StringHashMap(*Room),
};

// This is your application-specific wrapper around a websocket connection
const Handler = struct {
    app: *App,
    conn: *ws.Conn,
    room: ?*Room = null,
    user_data: ?UserData = null,

    // You must define a public init function which takes
    pub fn init(h: *const ws.Handshake, conn: *ws.Conn, app: *App) !Handler {
        _ = h; // we're not using handshake headers

        return .{
            .app = app,
            .conn = conn,
        };
    }

    pub fn close(self: *Handler) void {
        if (self.room) |room| {
            room.removeHandler(self);
        }
    }

    pub fn clientMessage(self: *Handler, allocator: Allocator, data: []const u8) !void {
        const app_allocator = self.app.allocator;
        const msg_allocator = allocator;

        // const parsed_msg = std.json.parseFromSlice(std.json.Value, msg_allocator, data, .{ .parse_numbers = false }) catch return;
        // const msg_type_wrapped = parsed_msg.value.object.get("type") orelse return;
        // const msg_type = std.meta.stringToEnum(MessageType, msg_type_wrapped.string) orelse .unknown;

        const m = try Message.parse(data, msg_allocator);

        if (m == .Ping) {
            const writer = self.conn.writeBuffer(msg_allocator, .binary);
            var pong = @as(Message, .Pong);
            try pong.serialize(writer, 0);
            return;
        }

        if (m != .Join and self.room == null) {
            std.log.warn("Received message of type {s} but no room is set.\n", .{@tagName(m)});
            return;
        }

        if (m == .Join and self.room != null) {
            std.log.warn("Received join message but already in a room: {s}\n", .{@tagName(m)});
            return;
        }

        if (m == .Join) {
            const join_data = m.Join;
            const writer = self.conn.writeBuffer(msg_allocator, .binary);

            var rooms = &self.app.rooms;
            const key = try app_allocator.dupe(u8, join_data.room_id);
            const gop = try rooms.getOrPut(key);
            if (!gop.found_existing) {
                std.log.debug("Room {s} does not exist yet, creating a new one...", .{key});
                const room = try app_allocator.create(Room);
                gop.value_ptr.* = room;
                room.* = try Room.init(app_allocator, key, join_data.room_type);
            }

            const room = gop.value_ptr.*;
            self.room = room;
            const user_id = room.addHandler(self) catch |err| {
                if (err == Room.RoomError.RoomFull) {
                    try self.conn.close(.{ .reason = "Room is full!" });
                    return;
                }
                return err;
            };

            const room_arena = self.room.?.arena.allocator();

            self.user_data = .{
                .user_id = user_id,
                .name = try room_arena.dupe(u8, join_data.name),
                .hero = join_data.hero,
                .choice = try join_data.choice.clone(room_arena),
                .is_spectator = join_data.is_spectator,
            };

            std.log.debug("Assigned user id {d} to {s} in {s}", .{ user_id, self.user_data.?.name, self.room.?.room_id });

            const users = try room.collectUsers(user_id);

            var sync = Message{
                .Sync = .{
                    .is_revealed = room.revealed,
                    .quest = room.quest,
                    .room_type = room.room_type,
                    .users = users,
                },
            };

            std.log.debug("Sync msg: {any}\n Users: {any}", .{ sync, users });

            try sync.serialize(writer, user_id);

            const user_connected = Message{
                .UserConnected = self.user_data.?,
            };
            try room.broadcastMessage(user_connected, self);

            return;
        }

        const room = self.room.?;
        const room_arena = room.arena.allocator();

        switch (m) {
            .Poke => {
                // nothing to do, will just broadcast below
            },
            .Reveal => {
                room.revealed = true;
            },
            .ResetRoom => |room_type| {
                room.revealed = false;
                room.quest += 1;
                room.room_type = room_type;
                for (room.handlers) |handler| {
                    if (handler == null or handler.?.room == null) continue;
                    var x = handler;
                    x.?.user_data.?.choice = @as(Choice, .None);
                    x.?.user_data.?.edited = false;
                }
            },
            .UpdateUserChoice => |choice| {
                self.user_data.?.choice = try choice.clone(room_arena);
                self.user_data.?.edited = true;
            },
            .UpdateUserName => |name| {
                self.user_data.?.name = try room_arena.dupe(u8, name);
            },
            .UpdateUserHero => |hero| {
                self.user_data.?.hero = hero;
            },
            .UpdateUserSpectator => |spectator| {
                self.user_data.?.is_spectator = spectator;
            },
            else => {
                return;
            },
        }

        try room.broadcastMessage(m, self);
    }
};

const Room = struct {
    mutex: Mutex = Mutex{},
    room_id: []const u8,
    room_type: RoomType,
    quest: u8 = 0,
    revealed: bool = false,
    handlers: [16]?*Handler = [_]?*Handler{null} ** 16, // max 16 users per room
    arena: *ArenaAllocator,

    pub fn init(allocator: *const Allocator, room_id: []const u8, room_type: RoomType) !Room {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = ArenaAllocator.init(allocator.*);
        return .{
            .room_id = room_id,
            .room_type = room_type,
            .arena = arena,
        };
    }

    pub fn broadcastMessage(self: *Room, m: Message, current_handler: *const Handler) !void {
        const alloc = self.arena.child_allocator;
        for (self.handlers) |maybe_handler| {
            if (maybe_handler) |handler| {
                if (handler != current_handler and handler.room == self) {
                    var writer = handler.conn.writeBuffer(alloc, .binary);
                    defer writer.deinit();
                    var mm = m;
                    mm.serialize(writer, current_handler.user_data.?.user_id) catch |err| {
                        std.log.err("Error serializing message {s} for handler: {any}", .{ @tagName(m), err });
                        return err;
                    };
                }
            }
        }
    }

    const RoomError = error{
        RoomFull,
    };

    pub fn addHandler(self: *Room, handler: *Handler) RoomError!u4 {
        // self.mutex.lock();
        // defer self.mutex.unlock();
        for (self.handlers, 0..) |h, i| {
            if (h == null) {
                self.handlers[i] = handler;
                return @as(u4, @intCast(i));
            }
        }
        return RoomError.RoomFull;
    }

    pub fn removeHandler(self: *Room, handler: *Handler) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        std.log.debug("Removing Handler from {s}", .{self.room_id});
        var n: u5 = 0;
        for (self.handlers) |h| {
            if (h != null) n += 1;
        }
        if (n == 1) {
            std.log.debug("Clearing up room {s}", .{self.room_id});
            _ = handler.app.rooms.remove(self.room_id);
            self.arena.deinit();
            handler.app.allocator.destroy(self);
            handler.app.allocator.free(self.room_id);
            return;
        }
        for (self.handlers, 0..) |h, i| {
            if (h != null and h.? == handler) {
                self.handlers[i] = null;
                break;
            }
        }
        self.broadcastMessage(Message{ .UserDisconnected = handler.user_data.?.user_id }, handler) catch |err| {
            std.log.err("Error broadcasting room update: {any}", .{err});
        };
        std.log.debug("Removed Handler, remaining: {d}", .{n - 1});
    }

    pub fn collectUsers(self: *Room, user_id: u4) ![]UserData {
        var users = std.ArrayList(UserData).init(self.arena.child_allocator);
        for (self.handlers) |maybe_handler| {
            if (maybe_handler) |handler| {
                if (handler.room == self and handler.user_data.?.user_id != user_id) {
                    try users.append(handler.user_data.?);
                }
            }
        }
        return try users.toOwnedSlice();
    }
};

const this = @This();

test {
    _ = msg; // reference msg module to add to tests
}
