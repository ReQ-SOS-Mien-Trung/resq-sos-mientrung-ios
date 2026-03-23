//
//  SosMienTrungTests.swift
//  SosMienTrungTests
//
//  Created by Huỳnh Kim Cương on 6/12/25.
//

import XCTest
@testable import SosMienTrung

final class SosMienTrungTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNotificationDecodesStructuredBodyObject() throws {
        let json = """
        {
          "notificationId": 42,
          "type": "flood_alert",
          "body": {
            "location": {
              "city": "Da Nang",
              "lat": 16.0544,
              "lon": 108.2022
            },
            "activeAlerts": [
              {
                "id": "alert-1",
                "eventType": "flood_alert",
                "title": "Canh bao lu khan cap",
                "severity": "high",
                "areasAffected": ["Hai Chau", "Thanh Khe"],
                "startTime": "2026-03-20T04:00:32.373Z",
                "endTime": "2026-03-20T06:00:32.373Z",
                "description": "Nuoc song dang len nhanh",
                "instructionChecklist": ["Theo doi huong dan", "San sang so tan"],
                "source": "admin"
              }
            ]
          },
          "createdAt": "2026-03-20T04:00:32.373Z"
        }
        """

        let notification = try RealtimeNotification.decoder().decode(
            RealtimeNotification.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(notification.notificationId, 42)
        XCTAssertEqual(notification.body, nil)
        XCTAssertEqual(notification.alertPayload?.location?.city, "Da Nang")
        XCTAssertEqual(notification.alertPayload?.alerts.count, 1)
        XCTAssertEqual(notification.displayTitle, "Canh bao lu khan cap")
        XCTAssertTrue(notification.displayMessage.contains("Da Nang"))
    }

    func testNotificationDecodesStructuredJSONStringBody() throws {
        let body = """
        {
          "location": {
            "city": "Hue",
            "lat": 16.4637,
            "lon": 107.5909
          },
          "activeAlerts": [
            {
              "id": "alert-2",
              "eventType": "storm_alert",
              "title": "Canh bao mua lon",
              "severity": "moderate",
              "areasAffected": ["Phu Vang"]
            }
          ]
        }
        """

        let json = """
        {
          "notificationId": 99,
          "type": "flood_alert",
          "body": \(body.debugDescription),
          "createdAt": "2026-03-20T04:00:32.373Z"
        }
        """

        let notification = try RealtimeNotification.decoder().decode(
            RealtimeNotification.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(notification.body, nil)
        XCTAssertEqual(notification.alertPayload?.location?.city, "Hue")
        XCTAssertEqual(notification.alertPayload?.alerts.first?.title, "Canh bao mua lon")
        XCTAssertTrue(notification.displayMessage.contains("Hue"))
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
