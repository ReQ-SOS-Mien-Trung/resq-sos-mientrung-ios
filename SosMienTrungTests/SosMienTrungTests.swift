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

    func testChatNotificationDecodesConversationId() throws {
        let json = """
        {
          "notificationId": 120,
          "conversationId": "456",
          "type": "chat_message",
          "title": "Tin nhắn mới",
          "body": "Coordinator vừa nhắn bạn",
          "createdAt": "2026-03-20T04:00:32.373Z"
        }
        """

        let notification = try RealtimeNotification.decoder().decode(
            RealtimeNotification.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(notification.conversationId, 456)
        XCTAssertTrue(notification.isChatMessage)
    }

    func testSharedPeopleRegenerationPreservesNamesAndFiltersReliefSelections() throws {
        let formData = SOSFormData()

        var count = formData.sharedPeopleCount
        count.children = 1
        formData.sharedPeopleCount = count

        formData.updatePersonName("Anh Hai", for: "adult_1")
        formData.reliefData.specialDietPersonIds = ["adult_1", "child_1"]
        formData.reliefData.specialDietInfoByPerson["adult_1"] = PersonSpecialDietInfo(personId: "adult_1", dietDescription: "Ăn mềm")
        formData.reliefData.specialDietInfoByPerson["child_1"] = PersonSpecialDietInfo(personId: "child_1", dietDescription: "Cần sữa")

        count.children = 0
        formData.sharedPeopleCount = count

        XCTAssertEqual(formData.person(for: "adult_1")?.displayName, "Anh Hai")
        XCTAssertEqual(formData.sharedPeople.count, 1)
        XCTAssertEqual(formData.reliefData.specialDietPersonIds, ["adult_1"])
        XCTAssertNil(formData.reliefData.specialDietInfoByPerson["child_1"])
    }

    func testUpdatePersonNameSyncsAcrossSharedAndRescueData() throws {
        let formData = SOSFormData()

        formData.updatePersonName("Bé Na", for: "adult_1")
        formData.rescueData.injuredPersonIds = ["adult_1"]
        formData.rescueData.medicalInfoByPerson["adult_1"] = PersonMedicalInfo(
            personId: "adult_1",
            medicalIssues: [.highFever]
        )

        XCTAssertEqual(formData.person(for: "adult_1")?.displayName, "Bé Na")
        XCTAssertEqual(formData.rescueData.people.first?.displayName, "Bé Na")
    }

    func testBlanketRequestCountIsClampedToPeopleCountAndClearedWhenNoPeople() throws {
        var relief = ReliefData()
        relief.blanketRequestCount = 10
        relief.syncToValidPeople(validIds: ["adult_1"], maxPeopleCount: 3)
        XCTAssertEqual(relief.blanketRequestCount, 3)

        relief.blanketRequestCount = 2
        relief.syncToValidPeople(validIds: [], maxPeopleCount: 0)
        XCTAssertNil(relief.blanketRequestCount)
    }

    func testEnhancedPacketEncodesAndDecodesNewReliefFields() throws {
        let formData = SOSFormData()
        formData.selectedTypes = [.relief]
        formData.reliefData.supplies = [.food, .medicine, .blanket, .clothes]
        formData.updatePersonName("Bé Tí", for: "adult_1")
        formData.reliefData.specialDietPersonIds = ["adult_1"]
        formData.reliefData.specialDietInfoByPerson["adult_1"] = PersonSpecialDietInfo(
            personId: "adult_1",
            dietDescription: "Cần thức ăn mềm"
        )
        formData.reliefData.medicalNeeds = [.commonMedicine, .minorInjury]
        formData.reliefData.medicalDescription = "Đau đầu và trầy xước nhẹ"
        formData.reliefData.areBlanketsEnough = false
        formData.reliefData.blanketRequestCount = 1
        formData.reliefData.clothingPersonIds = ["adult_1"]
        formData.reliefData.clothingInfoByPerson["adult_1"] = ClothingPersonInfo(
            personId: "adult_1",
            gender: .male
        )

        let packet = SOSPacketEnhanced(from: formData, originId: "origin", latitude: 16.0, longitude: 108.0)
        let data = try JSONEncoder().encode(packet)
        let decoded = try JSONDecoder().decode(SOSPacketEnhanced.self, from: data)
        let supplyDetails = try XCTUnwrap(decoded.structuredData?.supplyDetails)

        XCTAssertEqual(supplyDetails.specialDietPersons?.first?.name, "Bé Tí")
        XCTAssertEqual(Set(supplyDetails.medicalNeeds ?? []), Set([MedicalSupportNeed.commonMedicine.rawValue, MedicalSupportNeed.minorInjury.rawValue]))
        XCTAssertEqual(supplyDetails.areBlanketsEnough, false)
        XCTAssertEqual(supplyDetails.blanketRequestCount, 1)
        XCTAssertEqual(supplyDetails.clothingPersons?.first?.gender, ClothingGender.male.rawValue)
    }

    func testPeopleCountMetricsAlwaysIncludeFourCards() {
        let metrics = peopleCountMetrics(from: PeopleCount(adults: 2, children: 0, elderly: 1))

        XCTAssertEqual(metrics.map(\.title), ["Tổng người", "Người lớn", "Trẻ em", "Người già"])
        XCTAssertEqual(metrics.map(\.value), ["3", "2", "0", "1"])
    }

    func testPersonRequirementSummaryModelsMergeNeedsForSamePerson() {
        let formData = SOSFormData()
        formData.updatePersonName("Thảo", for: "adult_1")
        formData.reliefData.specialDietPersonIds = ["adult_1"]
        formData.reliefData.specialDietInfoByPerson["adult_1"] = PersonSpecialDietInfo(
            personId: "adult_1",
            dietDescription: "Không lactose"
        )
        formData.reliefData.clothingPersonIds = ["adult_1"]
        formData.reliefData.clothingInfoByPerson["adult_1"] = ClothingPersonInfo(
            personId: "adult_1",
            gender: .female
        )

        let summaries = personRequirementSummaryModels(from: formData.reliefData, people: formData.sharedPeople)

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.name, "Thảo")
        XCTAssertEqual(summaries.first?.needsClothing, true)
        XCTAssertEqual(summaries.first?.hasSpecialDiet, true)
        XCTAssertEqual(summaries.first?.dietDescription, "Không lactose")
        XCTAssertEqual(summaries.first?.genderTag, "Nữ")
    }

    func testReliefSupplyCardModelsCreateCompactCardsForSelectedNeeds() {
        var relief = ReliefData()
        relief.supplies = [.water, .food, .medicine, .blanket, .clothes]
        relief.waterDuration = .from12to24h
        relief.foodDuration = .from1to2days
        relief.medicalNeeds = [.commonMedicine]
        relief.areBlanketsEnough = false
        relief.blanketRequestCount = 2
        relief.specialDietPersonIds = ["adult_1"]
        relief.clothingPersonIds = ["adult_1"]

        let cards = reliefSupplyCardModels(from: relief)

        XCTAssertEqual(cards.map(\.title), ["Nước uống", "Thực phẩm", "Y tế", "Chăn mền", "Quần áo"])
        XCTAssertNil(cards.first(where: { $0.title == "Chế độ ăn đặc biệt" }))
        XCTAssertEqual(cards.first(where: { $0.title == "Quần áo" })?.lines.first?.value, "1 người")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
