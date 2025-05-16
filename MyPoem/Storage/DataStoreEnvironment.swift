//
//  DataStoreEnvironment.swift
//  MyPoem
//
//  Created by Steven Richter on 5/14/25.
//

import SwiftUI

private struct RequestStoreKey: EnvironmentKey {
    static let defaultValue: SwiftDataRequestStore = {
        fatalError("SwiftDataRequestStore not injected into environment")
    }()
}

private struct ResponseStoreKey: EnvironmentKey {
    static let defaultValue: SwiftDataResponseStore = {
        fatalError("SwiftDataResponseStore not injected into environment")
    }()
}

extension EnvironmentValues {
    var requestStore: SwiftDataRequestStore {
        get { self[RequestStoreKey.self] }
        set { self[RequestStoreKey.self] = newValue }
    }

    var responseStore: SwiftDataResponseStore {
        get { self[ResponseStoreKey.self] }
        set { self[ResponseStoreKey.self] = newValue }
    }
}
