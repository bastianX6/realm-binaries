import XCTest
import RealmSwift

final class RealmDeletionTombstone: Object {
    @Persisted(primaryKey: true) var recordID: String
    @Persisted var recordType: String
    @Persisted var deletedAt: Date
}

final class CreatorATests: XCTestCase {
    func testCreateFixtureA() throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documents.appendingPathComponent("fixture-A-source.realm")
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
        try realm.writeCopy(toFile: documents.appendingPathComponent("fixture-A.realm"))
        print("[abfix] creator.pk=recordID count=3")
    }
}
