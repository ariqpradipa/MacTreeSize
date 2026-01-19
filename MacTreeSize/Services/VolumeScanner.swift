import Foundation
import Combine

@MainActor
class VolumeScanner: ObservableObject {
    @Published var volumes: [VolumeInfo] = []
    
    func scanVolumes() {
        let fileManager = FileManager.default
        
        guard let urls = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsInternalKey,
            .volumeIsLocalKey
        ], options: [.skipHiddenVolumes]) else {
            return
        }
        
        var volumeInfos: [VolumeInfo] = []
        
        for url in urls {
            guard let resourceValues = try? url.resourceValues(forKeys: [
                .volumeNameKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeIsRemovableKey,
                .volumeIsEjectableKey,
                .volumeIsInternalKey,
                .volumeIsLocalKey
            ]) else {
                continue
            }
            
            let name = resourceValues.volumeName ?? url.lastPathComponent
            let total = Int64(resourceValues.volumeTotalCapacity ?? 0)
            let available = Int64(resourceValues.volumeAvailableCapacity ?? 0)
            let isRemovable = resourceValues.volumeIsRemovable ?? false
            let isEjectable = resourceValues.volumeIsEjectable ?? false
            let isInternal = resourceValues.volumeIsInternal ?? false
            let isLocal = resourceValues.volumeIsLocal ?? true
            
            let volumeType: VolumeType
            if !isLocal {
                volumeType = .network
            } else if isRemovable {
                volumeType = .disk
            } else if !isInternal || isEjectable {
                volumeType = .external
            } else {
                volumeType = .internalDrive
            }
            
            let volumeInfo = VolumeInfo(
                url: url,
                name: name,
                totalCapacity: total,
                availableCapacity: available,
                isRemovable: isRemovable,
                isEjectable: isEjectable,
                volumeType: volumeType
            )
            
            volumeInfos.append(volumeInfo)
        }
        
        // Sort: internal first, then external, then network
        self.volumes = volumeInfos.sorted { vol1, vol2 in
            if vol1.volumeType != vol2.volumeType {
                return volumeTypePriority(vol1.volumeType) < volumeTypePriority(vol2.volumeType)
            }
            return vol1.name.localizedStandardCompare(vol2.name) == .orderedAscending
        }
        
        // Remove duplicates if any (based on URL)
        // Although mounting logic should prevent it, sometimes multiple mounts appear
        // self.volumes = Array(Set(self.volumes)) // VolumeInfo needs to be Hashable
    }
    
    private func volumeTypePriority(_ type: VolumeType) -> Int {
        switch type {
        case .internalDrive: return 0
        case .external: return 1
        case .disk: return 2
        case .network: return 3
        }
    }
}
