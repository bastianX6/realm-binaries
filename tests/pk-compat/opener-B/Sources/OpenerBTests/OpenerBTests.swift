import XCTest
import RealmSwift

final class RealmDeletionTombstone: Object {
    @Persisted(primaryKey: true) var recordID: String
    @Persisted var recordType: String
    @Persisted var deletedAt: Date
}

final class RealmDeletionTombstoneOverride: Object {
    @Persisted var recordID: String
    @Persisted var recordType: String
    @Persisted var deletedAt: Date
    override class func primaryKey() -> String? { "recordID" }
}

final class OpenerBTests: XCTestCase {
    private func fixture() -> URL {
        Bundle.module.url(forResource: "fixture-A", withExtension: "realm", subdirectory: "Fixtures")!
    }

    func testWrapper() throws {
        var configuration = Realm.Configuration(fileURL: fixture(), schemaVersion: 5, deleteRealmIfMigrationNeeded: false)
        configuration.objectTypes = [RealmDeletionTombstone.self]
        do {
            _ = try Realm(configuration: configuration)
            XCTFail("expected primary key error")
        } catch {
            let message = String(describing: error)
            XCTAssertTrue(message.contains("Primary Key"), message)
            print("[abopen] wrapper open=throw msg=\(message)")
        }
    }

    func testOverride() throws {
        var configuration = Realm.Configuration(fileURL: fixture(), schemaVersion: 5, deleteRealmIfMigrationNeeded: false)
        configuration.objectTypes = [RealmDeletionTombstoneOverride.self]
        let realm = try Realm(configuration: configuration)
        XCTAssertEqual(realm.schema["RealmDeletionTombstoneOverride"]?.primaryKeyProperty?.name, "recordID")
        XCTAssertEqual(realm.objects(RealmDeletionTombstoneOverride.self).count, 3)
        print("[abopen] override open=ok pk=recordID count=3")
    }
}
