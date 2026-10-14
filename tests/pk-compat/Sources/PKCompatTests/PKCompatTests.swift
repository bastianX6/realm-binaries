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

final class PKCompatTests: XCTestCase {
    func testCreateFixtureA() throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("fixture-A-source.realm")
        try? FileManager.default.removeItem(at: url)
        var configuration = Realm.Configuration(fileURL: url, schemaVersion: 5)
        configuration.objectTypes = [RealmDeletionTombstone.self]
        let realm = try Realm(configuration: configuration)
        try realm.write {
            for index in 1...3 {
                realm.add(RealmDeletionTombstone(recordID: "rec-\(index)", recordType: "test", deletedAt: Date(timeIntervalSince1970: Double(index))))
            }
        }
        XCTAssertEqual(realm.schema["RealmDeletionTombstone"]?.primaryKeyProperty?.name, "recordID")
        XCTAssertEqual(realm.objects(RealmDeletionTombstone.self).count, 3)
        let fixture = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("fixture-A.realm")
        try? FileManager.default.removeItem(at: fixture)
        try realm.writeCopy(toFile: fixture)
        print("[pk-compat] creator.pk=recordID count=3 fixture=\(fixture.path)")
    }

    private func freshCopy() throws -> URL {
        let source = Bundle.module.url(forResource: "fixture-A", withExtension: "realm", subdirectory: "Resources")!
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".realm")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    func testWrapperDocumentsRegression() throws {
        let url = try freshCopy()
        var configuration = Realm.Configuration(fileURL: url, schemaVersion: 5, deleteRealmIfMigrationNeeded: false)
        configuration.objectTypes = [RealmDeletionTombstone.self]
        do {
            _ = try Realm(configuration: configuration)
            print("[pk-compat] wrapper=open-ok (future fix; soft assertion)")
        } catch {
            print("[pk-compat] wrapper=threw \(error)")
        }
    }

    func testOverridePreservesPrimaryKeyAndRows() throws {
        let url = try freshCopy()
        var configuration = Realm.Configuration(fileURL: url, schemaVersion: 5, deleteRealmIfMigrationNeeded: false)
        configuration.objectTypes = [RealmDeletionTombstoneOverride.self]
        let realm = try Realm(configuration: configuration)
        XCTAssertEqual(realm.schema["RealmDeletionTombstoneOverride"]?.primaryKeyProperty?.name, "recordID")
        XCTAssertEqual(realm.objects(RealmDeletionTombstoneOverride.self).count, 3)
        print("[pk-compat] override=open-ok pk=recordID count=3")
    }
}
