// SQLiteDatabase.swift
// Thin Swift wrapper over the system sqlite3 C-API.
// Internal-only — callers go through higher-level stores
// (ConversationStore, RatchetSessionStore) shipped in later
// Sprint 8 commits.
//
// Why raw SQLite (Sprint 8 settled choice): audit-friendly
// (any developer can `.dump` the DB), zero third-party
// dependencies, and the wrapper here is small and one we own.
// CoreData / SwiftData would add a runtime we'd inherit from
// Apple's SDK without being able to reason about its on-disk
// shape; GRDB would require a third-party-deviation note we
// don't need at this stage.
//
// Threading: the wrapper is NOT Sendable. macOS / iOS ship
// sqlite3 in serialized mode, but the expected use is one
// connection per actor / MainActor. Concurrent use from
// multiple actors is undefined here; the higher-level stores
// will enforce serialization.

import Foundation
import SQLite3

/// Errors raised by the SQLite layer.
public enum SQLiteError: Error, Equatable {
    /// `sqlite3_open_v2` failed.
    case openFailed(code: Int32, message: String)
    /// `sqlite3_prepare_v2` / `sqlite3_step` / `sqlite3_exec`
    /// returned an unexpected code. `sql` carries the offending
    /// statement when available.
    case operationFailed(code: Int32, message: String, sql: String?)
    /// A bind index was out of range or an unsupported type was
    /// passed.
    case invalidBind(index: Int32, message: String)
}

/// SQLITE_TRANSIENT — tells SQLite to copy the bound value
/// before returning. Using SQLITE_STATIC with Swift Strings or
/// Data buffers is unsafe because their backing storage is not
/// guaranteed to outlive the bind call.
private let SQLITE_TRANSIENT = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

/// Wrapper around an open sqlite3 connection.
public final class SQLiteDatabase {

    fileprivate var handle: OpaquePointer?

    /// Opens (or creates, if missing) a database at `url`.
    ///
    /// Foreign keys are enabled at open time; SQLite's default
    /// is OFF, which would silently ignore our `REFERENCES`
    /// clauses. WAL journaling is on for better concurrency
    /// under the iOS lifecycle.
    public init(url: URL) throws {
        var raw: OpaquePointer?
        let flags: Int32 =
            SQLITE_OPEN_READWRITE |
            SQLITE_OPEN_CREATE |
            SQLITE_OPEN_FULLMUTEX
        let openCode = sqlite3_open_v2(url.path, &raw, flags, nil)
        guard openCode == SQLITE_OK, let raw else {
            let msg = raw.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            if let raw { sqlite3_close_v2(raw) }
            throw SQLiteError.openFailed(code: openCode, message: msg)
        }
        self.handle = raw

        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA journal_mode = WAL;")
    }

    deinit {
        if let handle { sqlite3_close_v2(handle) }
    }

    /// Execute one or more statements with no parameters and no
    /// rows returned (e.g. DDL).
    public func execute(_ sql: String) throws {
        guard let handle else { return }
        var error: UnsafeMutablePointer<CChar>?
        let code = sqlite3_exec(handle, sql, nil, nil, &error)
        if code != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "exec failed"
            sqlite3_free(error)
            throw SQLiteError.operationFailed(code: code, message: message, sql: sql)
        }
    }

    /// Prepare a parameterised statement.
    public func prepare(_ sql: String) throws -> SQLiteStatement {
        guard let handle else {
            throw SQLiteError.operationFailed(
                code: -1, message: "database handle is nil", sql: sql
            )
        }
        var raw: OpaquePointer?
        let code = sqlite3_prepare_v2(handle, sql, -1, &raw, nil)
        guard code == SQLITE_OK, let raw else {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw SQLiteError.operationFailed(code: code, message: msg, sql: sql)
        }
        return SQLiteStatement(handle: raw, sql: sql)
    }

    /// Run `body` inside a SQLite transaction. On throw the
    /// transaction is rolled back; on success it commits.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            let result = try body()
            try execute("COMMIT;")
            return result
        } catch {
            // Best-effort rollback. Surface the original error
            // even if rollback fails; caller can re-open if the
            // connection is now wedged.
            _ = try? execute("ROLLBACK;")
            throw error
        }
    }

    /// Read the `PRAGMA user_version` value. Used by Migrations.
    public func userVersion() throws -> Int64 {
        let stmt = try prepare("PRAGMA user_version;")
        defer { stmt.finalize() }
        guard try stmt.step() else { return 0 }
        return stmt.int64(at: 0)
    }

    /// Set `PRAGMA user_version` to `value`. SQLite's PRAGMA
    /// statements don't accept bound parameters, so we inline
    /// the integer; `Int64` cannot carry SQL injection.
    public func setUserVersion(_ value: Int64) throws {
        try execute("PRAGMA user_version = \(value);")
    }
}

/// A prepared statement. Always finalised on `deinit` (or
/// explicit `finalize()` for early release).
public final class SQLiteStatement {

    fileprivate var handle: OpaquePointer?
    let sql: String

    fileprivate init(handle: OpaquePointer, sql: String) {
        self.handle = handle
        self.sql = sql
    }

    deinit {
        if let handle { sqlite3_finalize(handle) }
    }

    /// Release the statement. After this, no further methods
    /// may be called.
    public func finalize() {
        if let handle {
            sqlite3_finalize(handle)
            self.handle = nil
        }
    }

    // MARK: - Bind

    public func bind(_ value: Int64, at index: Int32) throws {
        guard let handle else {
            throw SQLiteError.invalidBind(index: index, message: "statement is finalized")
        }
        try check(sqlite3_bind_int64(handle, index, value), at: index)
    }

    public func bind(_ value: String, at index: Int32) throws {
        guard let handle else {
            throw SQLiteError.invalidBind(index: index, message: "statement is finalized")
        }
        try check(
            sqlite3_bind_text(handle, index, value, -1, SQLITE_TRANSIENT),
            at: index
        )
    }

    public func bind(_ value: Data, at index: Int32) throws {
        guard let handle else {
            throw SQLiteError.invalidBind(index: index, message: "statement is finalized")
        }
        let code: Int32 = value.withUnsafeBytes { raw in
            sqlite3_bind_blob(handle, index, raw.baseAddress, Int32(raw.count), SQLITE_TRANSIENT)
        }
        try check(code, at: index)
    }

    public func bindNull(at index: Int32) throws {
        guard let handle else {
            throw SQLiteError.invalidBind(index: index, message: "statement is finalized")
        }
        try check(sqlite3_bind_null(handle, index), at: index)
    }

    private func check(_ code: Int32, at index: Int32) throws {
        if code != SQLITE_OK {
            throw SQLiteError.operationFailed(code: code, message: "bind failed", sql: sql)
        }
    }

    // MARK: - Execute

    /// Step the statement once. Returns true if a row is
    /// available (SQLITE_ROW), false if done (SQLITE_DONE).
    /// Other codes throw.
    public func step() throws -> Bool {
        guard let handle else { return false }
        let code = sqlite3_step(handle)
        switch code {
        case SQLITE_ROW:
            return true
        case SQLITE_DONE:
            return false
        default:
            throw SQLiteError.operationFailed(code: code, message: "step failed", sql: sql)
        }
    }

    /// Reset to the beginning so the statement can be re-bound
    /// and re-executed. Bindings persist across reset.
    public func reset() throws {
        guard let handle else { return }
        let code = sqlite3_reset(handle)
        if code != SQLITE_OK {
            throw SQLiteError.operationFailed(code: code, message: "reset failed", sql: sql)
        }
    }

    // MARK: - Read

    public func int64(at column: Int32) -> Int64 {
        guard let handle else { return 0 }
        return sqlite3_column_int64(handle, column)
    }

    public func text(at column: Int32) -> String? {
        guard let handle else { return nil }
        guard let cstr = sqlite3_column_text(handle, column) else { return nil }
        return String(cString: cstr)
    }

    public func data(at column: Int32) -> Data? {
        guard let handle else { return nil }
        guard let bytes = sqlite3_column_blob(handle, column) else { return nil }
        let length = Int(sqlite3_column_bytes(handle, column))
        return Data(bytes: bytes, count: length)
    }

    /// True if the named column is NULL in the current row.
    public func isNull(at column: Int32) -> Bool {
        guard let handle else { return true }
        return sqlite3_column_type(handle, column) == SQLITE_NULL
    }
}
