import Flutter
import UIKit
import CoreMotion

public class SwiftSimplePedometerPlugin: NSObject, FlutterPlugin {
    
    let pedometer = CMPedometer()
    var channelResult: FlutterResult?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "simple_pedometer", binaryMessenger: registrar.messenger())
        let instance = SwiftSimplePedometerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.channelResult = result
        if call.method.elementsEqual("getSteps") {
            getSteps(call: call)
        } else if call.method.elementsEqual("getWalkingDuration") {
            getWalkingDuration(call: call)
        }
    }
    
    func getSteps(call: FlutterMethodCall) {
        guard let arguments = call.arguments as? NSDictionary,
              let startTime = arguments["startTime"] as? NSNumber,
              let endTime = arguments["endTime"] as? NSNumber
        else {
            self.channelResult?(0)
            return
        }
        
        let dateFrom = Date(timeIntervalSince1970: startTime.doubleValue / 1000)
        let dateTo = Date(timeIntervalSince1970: endTime.doubleValue / 1000)
        
        pedometer.queryPedometerData(from: dateFrom, to: dateTo, withHandler: { (data, error) in
            if let data = data, error == nil {
                let steps = data.numberOfSteps
                self.channelResult?(steps.intValue)
            } else {
                self.channelResult?(0)
            }
        })
    }

    func calculateTotalActiveTime(startDate: Date, endDate: Date) {

    var previousStepCount: Int = 0
    var totalActiveTimeInSeconds: TimeInterval = 0

    // Define the time interval for querying step count data
    let queryInterval: TimeInterval = 5 // 5 seconds interval

    let dispatchGroup = DispatchGroup()

    // Iterate over smaller intervals and query step count data
    for intervalStart in stride(from: startDate.timeIntervalSinceReferenceDate, to: endDate.timeIntervalSinceReferenceDate, by: queryInterval) {
        let intervalEnd = min(intervalStart + queryInterval, endDate.timeIntervalSinceReferenceDate)
        let intervalStartDate = Date(timeIntervalSinceReferenceDate: intervalStart)
        let intervalEndDate = Date(timeIntervalSinceReferenceDate: intervalEnd)

        dispatchGroup.enter()

        pedometer.queryPedometerData(from: intervalStartDate, to: intervalEndDate) { pedometerData, error in
            defer {
                dispatchGroup.leave()
            }

            if let pedometerData = pedometerData {
                let currentStepCount = pedometerData.numberOfSteps.intValue
                let stepCountDifference = currentStepCount - previousStepCount

                if stepCountDifference > 0 {
                    // If steps were taken in this interval, add the interval duration to totalActiveTimeInSeconds
                    totalActiveTimeInSeconds += intervalEndDate.timeIntervalSince(intervalStartDate)
                }

                previousStepCount = currentStepCount
            } else if let error = error {
                print("Error: \(error.localizedDescription)")
                self.channelResult?(0) // Use self.channelResult directly
                return
            }
        }
    }

    dispatchGroup.notify(queue: .main) {
        print("Swift:::: I am done here.");
        // At the end of the iteration, totalActiveTimeInSeconds will contain the total active time duration
        self.channelResult?(totalActiveTimeInSeconds) // Use self.channelResult directly
    }
}

func getWalkingDuration(call: FlutterMethodCall) {
    guard let arguments = call.arguments as? [String: Any],
          let startTime = arguments["startTime"] as? NSNumber,
          let endTime = arguments["endTime"] as? NSNumber
    else {
        self.channelResult?(0)
        return
    }

    let dateFrom = Date(timeIntervalSince1970: startTime.doubleValue / 1000)
    let dateTo = Date(timeIntervalSince1970: endTime.doubleValue / 1000)

    calculateTotalActiveTime(startDate: dateFrom, endDate: dateTo)
}

}
