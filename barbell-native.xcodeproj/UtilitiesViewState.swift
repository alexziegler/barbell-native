import Foundation

/// Represents the loading state of a view
enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

/// Represents the state of a data mutation operation
enum MutationState {
    case idle
    case saving
    case success
    case failure(Error)
    
    var isSaving: Bool {
        if case .saving = self {
            return true
        }
        return false
    }
    
    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
