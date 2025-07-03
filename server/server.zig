const std = @import("std");
const ws = @import("websocket");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Parsed = std.json.Parsed;

pub const std_options = std.Options{ .log_scope_levels = &[_]std.log.ScopeLevel{
    .{ .scope = .websocket, .level = .err },
} };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        // .verbose_log = true,
    }){};

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

        const parsed_msg = std.json.parseFromSlice(std.json.Value, msg_allocator, data, .{ .parse_numbers = false }) catch return;
        const msg_type_wrapped = parsed_msg.value.object.get("type") orelse return;
        const msg_type = std.meta.stringToEnum(MessageType, msg_type_wrapped.string) orelse .unknown;

        if (msg_type != .join and self.room == null) {
            std.log.warn("Received message of type {any} but no room is set.\n", .{msg_type});
            return;
        }
        if (msg_type == .join and self.room != null) {
            std.log.warn("Received join message but already in a room: {any}\n", .{msg_type});
            return;
        }
        switch (msg_type) {
            .unknown => {
                std.log.warn("Received message with unknown type: {any}\n", .{msg_type});
                return;
            },
            .ping => {
                self.conn.write("{\"type\":\"pong\"}") catch |err| {
                    std.log.err("Error writing pong message: {any}\n", .{err});
                };
                return;
            },
            .poke => {
                self.conn.write(data) catch |err| {
                    std.log.err("Error writing poke message: {any}\n", .{err});
                };
                return;
            },
            .reveal => {
                self.room.?.revealed = true;
            },
            .newQuest => {
                const r = self.room.?;
                const new_quest_msg = std.json.parseFromValue(NewQuestMessage, msg_allocator, parsed_msg.value, .{ .ignore_unknown_fields = true }) catch |err| {
                    std.log.warn("Error parsing new quest message: {any}\n", .{err});
                    return;
                };
                defer new_quest_msg.deinit();

                r.revealed = false;
                r.quest += 1;
                if (new_quest_msg.value.questType) |quest_type| {
                    r.questType = quest_type;
                }
                for (r.handlers.items) |handler| {
                    if (handler.room == null) continue;
                    handler.user_data.?.edited = false;
                }
            },
            .userUpdate => {
                const update_msg = std.json.parseFromValue(UpdateUserMessage, msg_allocator, parsed_msg.value, .{ .ignore_unknown_fields = true }) catch |err| {
                    std.log.warn("Error parsing user update message: {any}\n", .{err});
                    return;
                };
                defer update_msg.deinit();
                const room_arena = self.room.?.arena.allocator();
                if (update_msg.value.name) |name| {
                    self.user_data.?.name = try room_arena.dupe(u8, name);
                }
                if (update_msg.value.hero) |hero| {
                    self.user_data.?.hero = hero;
                }
                if (update_msg.value.choice) |choice| {
                    self.user_data.?.choice = try room_arena.dupe(u8, choice);
                    self.user_data.?.edited = self.room.?.revealed;
                }
                if (update_msg.value.spectator) |spectator| {
                    self.user_data.?.spectator = spectator;
                }
            },
            .join => {
                const join_msg = std.json.parseFromValue(JoinMessage, msg_allocator, parsed_msg.value, .{ .ignore_unknown_fields = true }) catch |err| {
                    std.log.warn("Error parsing join message: {any}\n", .{err});
                    return;
                };
                defer join_msg.deinit();
                var map = &self.app.rooms;
                const key = try app_allocator.dupe(u8, join_msg.value.roomId);
                const gop = try map.getOrPut(key);
                if (!gop.found_existing) {
                    std.log.debug("Room {s} does not exist yet, creating a new one...", .{key});
                    const room = try app_allocator.create(Room);
                    gop.value_ptr.* = room;
                    room.* = try Room.init(app_allocator, key, join_msg.value.questType);
                }

                self.room = gop.value_ptr.*;
                const room_arena = self.room.?.arena.allocator();

                self.user_data = .{
                    .name = try room_arena.dupe(u8, join_msg.value.name),
                    .hero = join_msg.value.hero,
                    .choice = try room_arena.dupe(u8, join_msg.value.choice),
                    .spectator = join_msg.value.spectator,
                    .edited = false,
                };
                try self.room.?.handlers.append(self);
            },
        }

        try self.room.?.broadcastRoomUpdate(self, msg_type);
    }
};

const QuestType = enum { Storypoints, PersonDay };

const JoinMessage = struct {
    roomId: []const u8,
    questType: QuestType,
    name: []const u8,
    hero: u8,
    choice: []const u8 = "null",
    spectator: bool = false,
};

const UpdateUserMessage = struct {
    name: ?[]const u8 = null,
    hero: ?u8 = null,
    choice: ?[]const u8 = null,
    spectator: ?bool = null,
};

const NewQuestMessage = struct {
    questType: ?QuestType = QuestType.Storypoints,
};

const App = struct {
    allocator: *const Allocator,
    rooms: std.StringHashMap(*Room),
};

const MessageType = enum { unknown, join, reveal, newQuest, userUpdate, poke, ping };

const UserData = struct {
    name: []const u8,
    hero: u8,
    choice: []const u8 = "null",
    edited: bool = false,
    spectator: bool = false,
};

const Room = struct {
    roomId: []const u8,
    questType: QuestType,
    quest: u8 = 0,
    revealed: bool = false,
    handlers: std.ArrayList(*Handler),
    arena: *ArenaAllocator,

    pub fn init(allocator: *const Allocator, room_id: []const u8, quest_type: QuestType) !Room {
        const arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = ArenaAllocator.init(allocator.*);
        return .{
            .roomId = room_id,
            .questType = quest_type,
            .handlers = std.ArrayList(*Handler).init(arena.allocator()),
            .arena = arena,
        };
    }

    pub fn broadcastRoomUpdate(self: *Room, current_handler: *const Handler, msg_type: MessageType) !void {
        var users = try std.ArrayList(UserData).initCapacity(self.arena.child_allocator, self.handlers.items.len);
        defer users.deinit();
        for (self.handlers.items) |user| {
            if (user.room == null) continue;
            const u = user.user_data.?;
            try users.append(.{
                .name = u.name,
                .hero = u.hero,
                .choice = u.choice,
                .edited = u.edited,
                .spectator = u.spectator,
            });
        }

        for (self.handlers.items) |handler| {
            if (handler.room == null) continue;
            if (handler != current_handler or msg_type == .join) {
                const i = for (self.handlers.items, 0..) |other_handler, index| {
                    if (other_handler == handler) break index;
                } else 0;
                var other_users = try users.clone();
                defer other_users.deinit();
                _ = other_users.orderedRemove(i);
                var wb = handler.conn.writeBuffer(self.arena.child_allocator, .text);
                defer wb.deinit();
                try std.json.stringify(.{
                    .type = "roomUpdate",
                    .roomId = self.roomId,
                    .questType = self.questType,
                    .quest = self.quest,
                    .revealed = self.revealed,
                    .otherUsers = other_users.items,
                }, .{}, wb.writer());
                try wb.flush();
            }
        }
    }

    pub fn removeHandler(self: *Room, handler: *const Handler) void {
        std.log.debug("Removing Handler from {s}", .{self.roomId});
        if (self.handlers.items.len == 1) {
            std.log.debug("Clearing up room {s}", .{self.roomId});
            _ = handler.app.rooms.remove(self.roomId);
            self.handlers.deinit();
            self.arena.deinit();
            handler.app.allocator.destroy(self);
            handler.app.allocator.free(self.roomId);
            return;
        }
        var handlers = &self.handlers;
        for (handlers.items, 0..) |h, i| {
            if (h == handler) {
                _ = handlers.orderedRemove(i);
                break;
            }
        }
        self.broadcastRoomUpdate(handler, MessageType.unknown) catch |err| {
            std.log.err("Error broadcasting room update: {any}", .{err});
        };
        std.log.debug("Removed Handler, remaining: {any}", .{handlers.items.len});
    }
};
