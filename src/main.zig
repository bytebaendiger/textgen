const std = @import("std");
const File = std.fs.File;
const Arena = std.heap.ArenaAllocator;

pub fn main() anyerror!void {
    const annot: Annotation = Annotation{ .floskel = Floskel() };
}
/// Longest Lifetime: Responsible for (de-)allocating file + resources,
/// all other actions happen on slices into `resource`
// TODO: implement iterator
const Reader = struct {
    resource: []const u8,
    jmp_pts: []usize, // stored indexes into `resource`. should be a hashmap
    cursor: usize,
    last_newline: ?usize, // for `line`: even if the cursor is in the middle of the line, it should be able to return an entire line (last newline to next)
    allocator: Arena,

    // TODO: initializing from file, stdin, a buffer, ...
    pub fn initBuffer(buff: []const u8) error{ OutOfMemory, EmptyBuffer }!Reader {
        if (buff.len == 0) return error.EmptyBuffer;
        var self: Reader = init();
        errdefer self.deinit();
        self.resource = buff;
        self.jmp_pts = try self.allocator.create([10]usize);
        return Self;
    }

    fn init() Reader {
        return .{
            .resource = undefined,
            .jmp_pts = undefined,
            .cursor = 0,
            .last_newline = null,
            .allocator = Arena.init(std.heap.GeneralPurposeAllocator(.{})),
        };
    }

    pub fn deinit(self: *Reader) void {
        self.allocator.deinit();
    }

    pub fn initFile(file: File) !Reader {
        var self = init();
        errdefer self.deinit();
        const filesize = try file.stat();
        self.jmp_pts = try self.allocator.create([10]usize);
        self.resource = try file.readToEndAlloc(&self.allocator, filesize);
    }

    pub fn saveCursorPos(self: *Reader) void {
        self.jmp_pts.add(self.cursor);
    }

    pub fn line(self: *Reader) ?[]const u8 {
        const lnl = self.last_newline orelse 0;
        if (lnl == self.resource.len) return null;
        var i: usize = self.cursor;
        while (i < self.resource.len and self.resource[i] != '\n') : (i += 1) {}
        self.last_newline = i; // update index of last newline found
        return self.resource[lnl..i];
    }
};

test "Reader: read lines" {
    const txt =
        \\ Some text
        \\ hopefully with
        \\ newlines!
    ;
    const eql = std.mem.eql;
    const expect = std.testing.expect;
    var reader = Reader.initBuffer(txt) catch unreachable;

    expect(eql([]const u8, reader.line().?, "Some text"));
    expect(eql(reader.line().?, "hopefully with"));
    expect(eql(reader.line().?, "newlines!"));
    expect(eql(reader.line(), null));
}

const Annotation = union(enum) {
    pronomen: Pronomen,
    floskel: comptime type,
    artikel: Artikel,
    anrede: comptime type,
};

pub fn Anrede() type {
    return struct {
        formal: bool = undefined,
        gender: Gender = undefined,
        titel: ?[]const u8 = undefined,
        custom: ?[]const u8 = undefined,
    };
}

const Gender = enum {
    Female,
    Male,
    Diverse,
};

const Artikel = enum {
    der,
    die,
    das,
};

const PSingular = enum(u8) {
    du = 2,
    ich = 3,
    ersiees,

    pub fn getStringSize(self: PSingular) usize {
        return switch (self) {
            .ich => @enumToInt(.ich),
            .du => @enumToInt(.du),
            .ersiees => 7,
        };
    }
};

const PPlural = enum {
    wir,
    ihr,
    sie,

    pub fn getStringSize(self: PPlural) usize {
        return 3;
    }
};

const Pronomen = union(enum) {
    singular: PSingular,
    plural: PPlural,
};

//pub fn Floskel(comptime tags: type) type {
pub fn Floskel() type {
    // TODO: check that `tags` is an arraylist of tags
    return struct {
        tags: std.ArrayList([]const u8) = undefined,
        string: []const u8 = undefined,
    };
}

const Expandable = struct {
    annot: Annotation,
    index: usize,

    pub fn updateIndex(self: *Expandable, new_index: usize) void {
        self.index = new_index;
    }
};
