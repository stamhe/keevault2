import Foundation

public class DatabaseFileManager {
    public enum Error {
        case databaseUnreachable(_ reason: DatabaseUnreachableReason)
        case lowMemory
        case databaseError(reason: DatabaseError)
        case otherError(message: String)
    }
    
    public enum DatabaseUnreachableReason {
        case cannotFindDatabaseFile
        case cannotOpenDatabaseFile
    }
    
    private let kdbxAutofillURL: URL
    private let kdbxCurrentURL: URL
    private let preTransformedKeyMaterial: ByteArray
    public let status: DatabaseFile.Status
    public private(set) var database: Database?
    
    private var isReadOnly: Bool {
        status.contains(.readOnly)
    }
    
    private var startTime: Date?
    
    public init(
        status: DatabaseFile.Status,
        preTransformedKeyMaterial: ByteArray,
        userId: String,
        sharedGroupName: String,
        sharedDefaults: UserDefaults
    ) {
        self.preTransformedKeyMaterial = preTransformedKeyMaterial.clone()
        self.status = status
        
        let documentsDirectory = FileManager().containerURL(forSecurityApplicationGroupIdentifier: sharedGroupName)
        let userFolderName = userId == "localUserMagicString@v1" ? "local_user" : userId.base64ToBase64url()
        kdbxAutofillURL = documentsDirectory!.appendingPathComponent(userFolderName + "/autofill.kdbx")
        kdbxCurrentURL = documentsDirectory!.appendingPathComponent(userFolderName + "/current.kdbx")
    }
    
    private func initDatabase(signature data: ByteArray) -> Database? {
        if Database2.isSignatureMatches(data: data) {
            Diag.info("DB signature: KDBX")
            return Database2()
        } else {
            Diag.info("DB signature: no match")
            return nil
        }
    }
    
    public func loadFromFile(
        // fileName: String
    ) -> DatabaseFile {
        var fileData: ByteArray
        do {
            let autofillFileData = try ByteArray(contentsOf: kdbxAutofillURL, options: [.uncached, .mappedIfSafe])
            fileData = autofillFileData
        } catch {
            Diag.info("Autofill file not found. Expected unless recent changes have been made via autofill and main app not opened yet.")
            do {
                    fileData = try ByteArray(contentsOf: kdbxCurrentURL, options: [.uncached, .mappedIfSafe])
                
            } catch {
                Diag.error("Failed to read current KDBX file [message: \(error.localizedDescription)]")
                fatalError("couldn't read KDBX file")
            }
        }
        
        guard let db = initDatabase(signature: fileData) else {
            fatalError("database init failed")
        }
        
        let dbFile = DatabaseFile(
            database: db,
            data: fileData,
            fileName: "<ignored filename>",
            status: status
        )        
        
        do {
            let db = dbFile.database
            try db.load(
                dbFileName: dbFile.fileName,
                dbFileData: dbFile.data,
                preTransformedKeyMaterial: preTransformedKeyMaterial)
            database = db
            
        } catch {
            fatalError("Unprocessed exception while opening database. Probably hardware failure has corrupted the data on this device.")
        }
        return dbFile
    }
    
    public func saveToFile(db: Database?) {
        do {
            guard let targetDatabase = db ?? database else {
                fatalError("No database to save")
            }
            let fileData = try targetDatabase.save()
            try fileData.write(to: kdbxAutofillURL, options: .atomic)
        } catch {
            Diag.error("Failed to write autofill KDBX file [message: \(error.localizedDescription)]")
        }
    }
}
