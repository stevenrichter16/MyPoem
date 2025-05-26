// DataManagerKey.swift
// Optional: Create environment key for DataManager if needed for dependency injection
import SwiftUI

private struct DataManagerKey: EnvironmentKey {
    static var defaultValue: DataManager = {
        fatalError("DataManager not injected into environment")
    }()
}

extension EnvironmentValues {
    var dataManager: DataManager {
        get { self[DataManagerKey.self] }
        set { self[DataManagerKey.self] = newValue }
    }
}
