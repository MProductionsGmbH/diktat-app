// Checks an Ed25519 signature: verify-ed25519.swift <public key, base64> <signature, base64> <file>
// Used by release.sh to make sure an update key file belongs to the public key in project.yml.
import CryptoKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4,
      let keyData = Data(base64Encoded: arguments[1]),
      let signature = Data(base64Encoded: arguments[2]),
      let message = FileManager.default.contents(atPath: arguments[3]),
      let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData) else {
    exit(2)
}
exit(key.isValidSignature(signature, for: message) ? 0 : 1)
