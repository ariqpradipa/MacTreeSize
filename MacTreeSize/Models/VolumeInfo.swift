import Foundation

struct VolumeInfo: Identifiable, Hashable {
    let id: UUID = UUID()
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let isRemovable: Bool
    let isEjectable: Bool
    let volumeType: VolumeType
    
    var usedCapacity: Int64 {
        totalCapacity - availableCapacity
    }
    
    var usedPercentage: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalCapacity, countStyle: .file)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedCapacity, countStyle: .file)
    }
    
    var formattedAvailable: String {
        ByteCountFormatter.string(fromByteCount: availableCapacity, countStyle: .file)
    }
    
    var icon: String {
        switch volumeType {
        case .internalDrive:
            return "internaldrive.fill"
        case .external:
            return "externaldrive.fill"
        case .network:
            return "network"
        case .disk:
            return "opticaldiscdrive.fill"
        }
    }
}

enum VolumeType {
    case internalDrive
    case external
    case network
    case disk
}
