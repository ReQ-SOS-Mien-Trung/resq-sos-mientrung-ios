// MeasurementQualityEstimator.swift
import Foundation
import NearbyInteraction

final class MeasurementQualityEstimator {
    // Define criteria
    let freshnessWindow = TimeInterval(2.0)
    let minSamples: Int = 8
    let maxDistance: Float = 50
    let closeDistance: Float = 10

    private var measurements: [TimedNIObject] = []

    enum MeasurementQuality {
        case unknown
        case good
        case close
    }

    struct TimedNIObject {
        let time: TimeInterval
        let distance: Float
    }

    func estimateQuality(update: NINearbyObject?) -> MeasurementQuality {
        let timeNow = Date.timeIntervalSinceReferenceDate
        if let distance = update?.distance {
            if let last = measurements.last {
                if last.distance != distance {
                    measurements.append(TimedNIObject(time: timeNow, distance: distance))
                }
            } else {
                measurements.append(TimedNIObject(time: timeNow, distance: distance))
            }
        }

        let validTimestamp = timeNow - freshnessWindow
        measurements.removeAll { $0.time < validTimestamp }

        if measurements.count > minSamples, let lastDistance = measurements.last?.distance {
            if lastDistance <= closeDistance { return .close }
            return lastDistance < maxDistance ? .good : .unknown
        }
        return .unknown
    }
}
