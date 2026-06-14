//
// github.com/screensailor 2022
//

public struct Weak<Reference: AnyObject> {
    
    public private(set) weak var reference: Reference?
    
    public init(_ reference: Reference? = nil) {
        self.reference = reference
    }
}

extension Weak: Equatable where Reference: Equatable {}
extension Weak: Hashable where Reference: Hashable {}
