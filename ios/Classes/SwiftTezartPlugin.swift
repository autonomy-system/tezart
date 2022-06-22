import Flutter
import UIKit
import JavaScriptCore

public class SwiftTezartPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tezart", binaryMessenger: registrar.messenger())
        let instance = SwiftTezartPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "localForge":
            let args: NSDictionary = call.arguments as! NSDictionary
            let data: String = args["data"] as! String
            
            TaquitoService.shared.forge(operationPayload: data) { forgeResult in
                switch forgeResult {
                case .success(let forgedString):
                    result(forgedString)
                    
                case .failure(let forgeError):
                    result(FlutterError(code: "0", message: forgeError.localizedDescription, details: nil))
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
