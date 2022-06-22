//
//  TaquiloService.swift
//  Pods-Runner
//
//  Created by Ho Hien on 20/06/2022.
//

import Foundation
import JavaScriptCore

public class TaquitoService {
    
    /// Pirvate local copy of a javascript context
    private let jsContext: JSContext
    
    /// Private flag to prevent multiple simultaneous forge's
    private var isForging = false
    
    /// Unique TaquitoService errors
    public enum TaquitoServiceError: Error {
        case alreadyForging
        case forgingError
    }
    
    private var lastForgeCompletionHandler: ((Result<String, Error>) -> Void)? = nil
    
    /// Public shared instace to avoid having multiple copies of the underlying `JSContext` created
    public static let shared = TaquitoService()
    
    
    // MARK: - Init
    
    /// Private Init to setup the Javascript Context, find and parse the Taquito file, and setup the `LocalForger` object.
    private init() {
        jsContext = JSContext()
        jsContext.exceptionHandler = { [weak self] context, exception in
            if self?.isForging == true, let lastForge = self?.lastForgeCompletionHandler {
                self?.isForging = false
                lastForge(Result.failure(TaquitoServiceError.forgingError))
                
            }
        }
        
        if let jsSourcePath = Bundle(for: type(of: self)).url(forResource: "taquito_local_forging", withExtension: "js") {
            do {
                let jsSourceContents = try String(contentsOf: jsSourcePath)
                self.jsContext.evaluateScript(jsSourceContents)
                self.jsContext.evaluateScript("var forger = new taquito_local_forging.LocalForger();")
            } catch (_) {
            }
        }
    }
    
    // MARK: - @taquito/local-forging
    public func forge(operationPayload: String, completion: @escaping((Result<String, Error>) -> Void)) {
        if isForging {
            // To avoid setting up a delgate pattern for something that should be synchronous, we only include 1 set of success/errors handlers inside the code at any 1 time
            // Calling it multiple times at the same time could result in strange behaviour
            completion(Result.failure(TaquitoServiceError.alreadyForging))
            return
        }
        
        lastForgeCompletionHandler = completion
        isForging = true
        
        // Assign callback handlers for internal JS promise success and error states
        let forgeSuccessHandler: @convention(block) (String) -> Void = { [weak self] (result) in
            self?.isForging = false
            self?.lastForgeCompletionHandler = nil
            completion(Result.success(result))
            return
        }
        let forgeSuccessBlock = unsafeBitCast(forgeSuccessHandler, to: AnyObject.self)
        jsContext.setObject(forgeSuccessBlock, forKeyedSubscript: "forgeSuccessHandler" as (NSCopying & NSObjectProtocol))
        
        let forgeErrorHandler: @convention(block) (String) -> Void = { [weak self] (result) in
            self?.isForging = false
            self?.lastForgeCompletionHandler = nil
            completion(Result.failure(TaquitoServiceError.forgingError))
            return
        }
        let forgeErrorBlock = unsafeBitCast(forgeErrorHandler, to: AnyObject.self)
        jsContext.setObject(forgeErrorBlock, forKeyedSubscript: "forgeErrorHandler" as (NSCopying & NSObjectProtocol))
        
        // Wrap up the internal call to the forger and pass the promises back to the swift handler blocks
        let _ = jsContext.evaluateScript("""
            forger.forge(\(operationPayload)).then(
                function(value) { forgeSuccessHandler(value) },
                function(error) { forgeErrorHandler( JSON.stringify(error) ) }
            );
            """)
    }
}
