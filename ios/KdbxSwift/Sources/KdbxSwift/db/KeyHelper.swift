import Foundation

public class KeyHelper {
    public static let compositeKeyLength = 32
    internal let keyFileKeyLength = 32
    
    public func combineComponents(
        passwordData: ByteArray,
        keyFileData: ByteArray
    ) throws -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func getKey(fromCombinedComponents combinedComponents: ByteArray) -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func getPasswordData(password: String) -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func processKeyFile(keyFileData: ByteArray) throws -> ByteArray {
        assert(!keyFileData.isEmpty, "keyFileData cannot be empty here")
        
        let keyFileDataSize = keyFileData.count
        if keyFileDataSize == keyFileKeyLength {
            Diag.debug("Key file format is: binary")
            return keyFileData
        }
        
        if let key = try processXmlKeyFile(keyFileData: keyFileData) {
            Diag.debug("Key file format is: XML")
            return key
        }
        
        Diag.debug("Key file format is: other")
        return keyFileData.sha256
    }
    
    public func processXmlKeyFile(keyFileData: ByteArray) throws -> ByteArray? {
        return nil
    }
}
