const std = @import("std");
const httpz = @import("httpz");
const ws = httpz.websocket;
const options = @import("options");
const zul = @import("zul");
const prot = @import("protocol.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Parsed = std.json.Parsed;
const Mutex = std.Thread.Mutex;

const Message = prot.Message;
const RoomType = prot.RoomType;
const Choice = prot.Choice;
const UserData = prot.UserData;

// Compile-time static file map for O(1) lookup
const StaticFileMap = blk: {
    @setEvalBranchQuota(10000);
    var entries: [options.static_files.len]struct { []const u8, []const u8 } = undefined;
    for (options.static_files, 0..) |file_path, i| {
        entries[i] = .{ file_path, @embedFile("_static/" ++ file_path) };
    }
    break :blk std.StaticStringMap([]const u8).initComptime(entries);
};

pub const std_options = std.Options{
    .logFn = logWithTimestamp,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        // Don't log websocket debug messages to reduce log size
        .{ .scope = .httpz, .level = .err },
        // Application specific logs
        .{ .scope = .app, .level = .info },
    },
};

fn addCachingHeaders(res: *httpz.Response, content_type: ?httpz.ContentType) void {
    const ct = content_type orelse return;

    switch (ct) {
        // Code assets - cache for 10 minutes
        .CSS, .HTML, .JS, .JSON => {
            res.headers.add("Cache-Control", "public, max-age=600");
            res.headers.add("Expires", "10m");
        },
        else => {
            // Everything else - cache for 30 days
            res.headers.add("Cache-Control", "public, max-age=2592000");
            res.headers.add("Expires", "30d");
        },
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = httpz.Config{
        .port = 48377,
        .thread_pool = .{
            .count = @intCast(std.Thread.getCpuCount() catch 2),
        },
        .address = "0.0.0.0",
        .request = .{
            .max_body_size = 1,
            .max_form_count = 1,
            .max_multiform_count = 1,
            .max_param_count = 1,
            .max_query_count = 1,
            .lazy_read_size = 1,
        },
    };
    var server = try httpz.Server(App).init(allocator, config, .{
        .allocator = &allocator,
        .rooms = std.StringHashMap(*App.Room).init(allocator),
    });

    std.log.info("Starting server on http://127.0.0.1:48377", .{});
    // start the server in the current thread, blocking.
    try server.listen();
}

const App = struct {
    allocator: *const Allocator,
    rooms: std.StringHashMap(*Room),
    max_observed_rooms: u32 = 0,

    const Self = @This();

    pub fn handle(app: *Self, req: *httpz.Request, res: *httpz.Response) void {
        if (req.method != .GET) {
            res.status = 405;
            res.body = "Method Not Allowed";
            return;
        }
        if (std.mem.eql(u8, req.url.path, "/ws")) {
            const upgraded = httpz.upgradeWebsocket(WebsocketHandler, req, res, app) catch unreachable;
            if (upgraded == false) {
                std.log.err("Invalid websocket handshake on path: {s}", .{req.url.path});
                res.status = 400;
                res.body = "invalid websocket handshake";
            }
            return;
        }

        // Fast O(1) static file lookup using compile-time hash map
        if (StaticFileMap.get(req.url.path[1..])) |embeddedFile| {
            res.status = 200;
            res.body = embeddedFile;
            const content_type = httpz.ContentType.forFile(req.url.path[1..]);
            res.content_type = content_type;
            addCachingHeaders(res, content_type);
            return;
        }

        // Fallback to index.html for SPA routing
        const embeddedIndex = @embedFile("_static" ++ "/index.html");
        res.status = 200;
        res.body = embeddedIndex;
        res.content_type = .HTML;
        addCachingHeaders(res, .HTML);
    }

    // This is your application-specific wrapper around a websocket connection
    pub const WebsocketHandler = struct {
        app: *App,
        conn: *ws.Conn,
        room: ?*Room = null,
        user_data: ?UserData = null,

        // You must define a public init function which takes
        pub fn init(conn: *ws.Conn, app: *App) !WebsocketHandler {
            std.log.debug("init websocket", .{});
            return .{
                .app = app,
                .conn = conn,
            };
        }

        pub fn close(self: *WebsocketHandler) void {
            if (self.room) |room| {
                room.removeHandler(self);
            }
        }

        pub fn clientMessage(self: *WebsocketHandler, allocator: Allocator, data: []const u8) !void {
            const app_allocator = self.app.allocator;
            const msg_allocator = allocator;

            // const parsed_msg = std.json.parseFromSlice(std.json.Value, msg_allocator, data, .{ .parse_numbers = false }) catch return;
            // const msg_type_wrapped = parsed_msg.value.object.get("type") orelse return;
            // const msg_type = std.meta.stringToEnum(MessageType, msg_type_wrapped.string) orelse .unknown;

            const m = try Message.parse(data, msg_allocator);

            if (m == .Ping) {
                var writer = self.conn.writeBuffer(msg_allocator, .binary);
                defer writer.deinit();
                var pong = @as(Message, .Pong);
                try pong.serialize(&writer.interface, 0);
                try writer.send();
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
                var writer = self.conn.writeBuffer(msg_allocator, .binary);
                defer writer.deinit();

                var rooms = &self.app.rooms;
                const key = try app_allocator.dupe(u8, join_data.room_id);
                const gop = try rooms.getOrPut(key);
                if (!gop.found_existing) {
                    std.log.debug("Room {s} does not exist yet, creating a new one...", .{key});
                    const room = try app_allocator.create(Room);
                    gop.value_ptr.* = room;
                    room.* = try Room.init(app_allocator, key, join_data.room_type);
                    std.log.info("Created room: {s}", .{key});
                    const room_count = rooms.count();
                    if (room_count > self.app.max_observed_rooms) {
                        self.app.max_observed_rooms = room_count;
                    }
                    std.log.info("Total rooms: {d} (max observed: {d})", .{ room_count, self.app.max_observed_rooms });
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

                try sync.serialize(&writer.interface, user_id);
                try writer.send();

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

    pub const Room = struct {
        mutex: Mutex = Mutex{},
        room_id: []const u8,
        room_type: RoomType,
        quest: u8 = 0,
        revealed: bool = false,
        handlers: [16]?*WebsocketHandler = [_]?*WebsocketHandler{null} ** 16, // max 16 users per room
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

        pub fn broadcastMessage(self: *Room, m: Message, current_handler: *const WebsocketHandler) !void {
            const alloc = self.arena.child_allocator;
            for (self.handlers) |maybe_handler| {
                if (maybe_handler) |handler| {
                    if (handler != current_handler and handler.room == self) {
                        var writer = handler.conn.writeBuffer(alloc, .binary);
                        defer writer.deinit();
                        var mm = m;
                        mm.serialize(&writer.interface, current_handler.user_data.?.user_id) catch |err| {
                            std.log.err("Error serializing message {s} for handler: {any}", .{ @tagName(m), err });
                            return err;
                        };
                        try writer.send();
                    }
                }
            }
        }

        const RoomError = error{
            RoomFull,
        };

        pub fn addHandler(self: *Room, handler: *WebsocketHandler) RoomError!u4 {
            self.mutex.lock();
            defer self.mutex.unlock();
            for (self.handlers, 0..) |h, i| {
                if (h == null) {
                    self.handlers[i] = handler;
                    return @as(u4, @intCast(i));
                }
            }
            return RoomError.RoomFull;
        }

        pub fn removeHandler(self: *Room, handler: *WebsocketHandler) void {
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
                std.log.info("Destroyed room: {s}", .{self.room_id});
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
            var users = std.ArrayList(UserData){};
            for (self.handlers) |maybe_handler| {
                if (maybe_handler) |handler| {
                    if (handler.room == self and handler.user_data.?.user_id != user_id) {
                        try users.append(self.arena.child_allocator, handler.user_data.?);
                    }
                }
            }
            return try users.toOwnedSlice(self.arena.child_allocator);
        }
    };
};

fn logWithTimestamp(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = scope; // not used
    const ts = zul.DateTime.fromUnix(std.time.milliTimestamp(), .milliseconds) catch unreachable;
    var buf = [_]u8{0} ** 64;
    var writer = std.fs.File.stdout().writerStreaming(&buf);
    const date = ts.date();
    const time = ts.time();
    writer.interface.print("{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} [", .{ date.year, date.month, date.day, time.hour, time.min, time.sec }) catch unreachable;
    for (message_level.asText()) |c| {
        writer.interface.writeByte(std.ascii.toUpper(c)) catch unreachable;
    }
    writer.interface.print("] " ++ format ++ "\n", args) catch unreachable;
    writer.interface.flush() catch unreachable;
}

const this = @This();

test {
    _ = prot; // reference msg module to add to tests
}
