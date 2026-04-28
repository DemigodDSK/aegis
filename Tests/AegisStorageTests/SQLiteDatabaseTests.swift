// SQLiteDatabaseTests.swift
// Round-trip tests for the SQLite wrapper.
//
// Each test opens a fresh per-test temp file and removes it
// in tearDown, so concurrent runs don't collide and a crashed
// run doesn't leave artefacts in NSTemporaryDirectory.

@testable import AegisStorage
import Foundation
import XCTest

final class SQLiteDatabaseTests: XCTestCase {

    private var dbURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("aegis-sqlite-\(UUID().uuidString).sqlite")
    }

    override func tearDownWithError() throws {
        if let dbURL {
            try? FileManager.default.removeItem(at: dbURL)
            // SQLite WAL leaves -wal and -shm sidecars next to the file.
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-wal"))
            try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("-shm"))
        }
        dbURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Open

    func testOpenCreatesDatabaseFile() throws {
        XCTAssertFalse(FileManager.default.fileExists(atPath: dbURL.path))
        _ = try SQLiteDatabase(url: dbURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dbURL.path))
    }

    func testForeignKeysEnforcementIsOn() throws {
        let db = try SQLiteDatabase(url: dbURL)
        let stmt = try db.prepare("PRAGMA foreign_keys;")
        defer { stmt.finalize() }
        XCTAssertTrue(try stmt.step())
        XCTAssertEqual(stmt.int64(at: 0), 1,
                       "PRAGMA foreign_keys must be ON; we rely on REFERENCES clauses")
    }

    // MARK: - Bind round-trips

    func testRoundTripIntStringBlob() throws {
        let db = try SQLiteDatabase(url: dbURL)
        try db.execute("CREATE TABLE t (i INTEGER, s TEXT, b BLOB);")

        let insert = try db.prepare("INSERT INTO t (i, s, b) VALUES (?, ?, ?);")
        defer { insert.finalize() }
        try insert.bind(Int64(42), at: 1)
        try insert.bind("hello", at: 2)
        try insert.bind(Data([0xDE, 0xAD, 0xBE, 0xEF]), at: 3)
        XCTAssertFalse(try insert.step())  // INSERT yields DONE, not ROW

        let read = try db.prepare("SELECT i, s, b FROM t;")
        defer { read.finalize() }
        XCTAssertTrue(try read.step())
        XCTAssertEqual(read.int64(at: 0), 42)
        XCTAssertEqual(read.text(at: 1), "hello")
        XCTAssertEqual(read.data(at: 2), Data([0xDE, 0xAD, 0xBE, 0xEF]))
        XCTAssertFalse(try read.step())
    }

    func testNullColumnReadsBackAsNil() throws {
        let db = try SQLiteDatabase(url: dbURL)
        try db.execute("CREATE TABLE t (s TEXT, b BLOB);")
        let insert = try db.prepare("INSERT INTO t (s, b) VALUES (?, ?);")
        defer { insert.finalize() }
        try insert.bindNull(at: 1)
        try insert.bindNull(at: 2)
        XCTAssertFalse(try insert.step())

        let read = try db.prepare("SELECT s, b FROM t;")
        defer { read.finalize() }
        XCTAssertTrue(try read.step())
        XCTAssertTrue(read.isNull(at: 0))
        XCTAssertTrue(read.isNull(at: 1))
        XCTAssertNil(read.text(at: 0))
        XCTAssertNil(read.data(at: 1))
    }

    func testStatementCanBeResetAndRebound() throws {
        let db = try SQLiteDatabase(url: dbURL)
        try db.execute("CREATE TABLE t (i INTEGER);")
        let insert = try db.prepare("INSERT INTO t (i) VALUES (?);")
        defer { insert.finalize() }

        for value in Int64(1)...Int64(5) {
            try insert.reset()
            try insert.bind(value, at: 1)
            XCTAssertFalse(try insert.step())
        }

        let count = try db.prepare("SELECT COUNT(*) FROM t;")
        defer { count.finalize() }
        XCTAssertTrue(try count.step())
        XCTAssertEqual(count.int64(at: 0), 5)
    }

    // MARK: - Transactions

    func testTransactionCommitsOnSuccess() throws {
        let db = try SQLiteDatabase(url: dbURL)
        try db.execute("CREATE TABLE t (i INTEGER);")

        try db.transaction {
            try db.execute("INSERT INTO t VALUES (1);")
            try db.execute("INSERT INTO t VALUES (2);")
        }

        let count = try db.prepare("SELECT COUNT(*) FROM t;")
        defer { count.finalize() }
        XCTAssertTrue(try count.step())
        XCTAssertEqual(count.int64(at: 0), 2)
    }

    func testTransactionRollsBackOnThrow() throws {
        let db = try SQLiteDatabase(url: dbURL)
        try db.execute("CREATE TABLE t (i INTEGER);")
        struct Sentinel: Error {}

        XCTAssertThrowsError(try db.transaction {
            try db.execute("INSERT INTO t VALUES (1);")
            throw Sentinel()
        })

        let count = try db.prepare("SELECT COUNT(*) FROM t;")
        defer { count.finalize() }
        XCTAssertTrue(try count.step())
        XCTAssertEqual(count.int64(at: 0), 0,
                       "rollback must remove the partially-inserted row")
    }

    // MARK: - User version

    func testUserVersionStartsAtZero() throws {
        let db = try SQLiteDatabase(url: dbURL)
        XCTAssertEqual(try db.userVersion(), 0)
    }

    func testUserVersionRoundTrips() throws {
        let db = try SQLiteDatabase(url: dbURL)
        try db.setUserVersion(7)
        XCTAssertEqual(try db.userVersion(), 7)
    }

    // MARK: - Errors

    func testPrepareThrowsOnInvalidSql() throws {
        let db = try SQLiteDatabase(url: dbURL)
        XCTAssertThrowsError(try db.prepare("THIS IS NOT VALID SQL;")) { error in
            guard case SQLiteError.operationFailed = error else {
                XCTFail("expected operationFailed, got \(error)")
                return
            }
        }
    }
}
