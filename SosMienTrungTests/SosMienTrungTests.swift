//
//  SosMienTrungTests.swift
//  SosMienTrungTests
//
//  Created by Huỳnh Kim Cương on 6/12/25.
//

import XCTest
import Combine
@testable import SosMienTrung

@MainActor
final class SosMienTrungTests: XCTestCase {

    private func makeFormData(
        adults: Int = 1,
        children: Int = 0,
        elderly: Int = 0
    ) -> SOSFormData {
        let formData = SOSFormData()
        formData.sharedPeopleCount = PeopleCount(adults: adults, children: children, elderly: elderly)
        return formData
    }

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

    func testActivityDescriptionHasRouteInstructionWhenDescriptionContainsMovementDirective() {
        let activity = Activity(
            id: 1,
            step: 6,
            activityCode: "RESCUE",
            activityType: "RESCUE",
            description: "Di chuyển đến 18.351, 105.902. Thực hiện cứu hộ 5 người bị ảnh hưởng bởi sạt lở đất.",
            imageUrl: nil,
            priority: "High",
            estimatedTime: 2,
            sosRequestId: 3,
            depotId: nil,
            depotName: nil,
            depotAddress: nil,
            suppliesToCollect: nil,
            targetLatitude: 18.351,
            targetLongitude: 105.902,
            status: ActivityStatus.onGoing.rawValue,
            missionTeamId: 3,
            assignedAt: nil,
            completedAt: nil,
            completedBy: nil
        )

        XCTAssertTrue(activityDescriptionHasRouteInstruction(activity))
    }

    func testActivityDescriptionHasRouteInstructionWhenDescriptionIsOnlyExecutionDirective() {
        let activity = Activity(
            id: 2,
            step: 6,
            activityCode: "FIRST_AID",
            activityType: "MEDICAL",
            description: "Thực hiện sơ cứu tại 18.351, 105.902 cho 2 người bị thương.",
            imageUrl: nil,
            priority: "High",
            estimatedTime: 2,
            sosRequestId: 3,
            depotId: nil,
            depotName: nil,
            depotAddress: nil,
            suppliesToCollect: nil,
            targetLatitude: 18.351,
            targetLongitude: 105.902,
            status: ActivityStatus.onGoing.rawValue,
            missionTeamId: 3,
            assignedAt: nil,
            completedAt: nil,
            completedBy: nil
        )

        XCTAssertFalse(activityDescriptionHasRouteInstruction(activity))
    }

    func testLocalizedActivityTypeDisplayForReturnAssemblyPoint() {
        XCTAssertEqual(
            localizedActivityTypeDisplay("RETURN_ASSEMBLY_POINT"),
            L10n.Domain.activityTypeReturnAssemblyPoint
        )
    }

    func testActivityDecodesImageURLFromAPIResponse() throws {
        let json = """
        {
          "id": 20,
          "step": 9,
          "activityType": "RETURN_ASSEMBLY_POINT",
          "status": "Planned",
          "imageUrl": "https://res.cloudinary.com/demo/image/upload/v1/activity-proof.jpg"
        }
        """

        let activity = try JSONDecoder().decode(
            Activity.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(activity.imageUrl, "https://res.cloudinary.com/demo/image/upload/v1/activity-proof.jpg")
        XCTAssertEqual(activity.localizedActivityType, L10n.Domain.activityTypeReturnAssemblyPoint)
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

    func testMissionNotificationDecodesMissionIdentifiers() throws {
        let json = """
        {
          "notificationId": 121,
          "missionId": "789",
          "activityId": 33,
          "incidentId": "11",
          "type": "supply_request",
          "title": "Yeu cau tiep te moi",
          "body": "Team vua tao yeu cau moi",
          "createdAt": "2026-03-20T04:00:32.373Z"
        }
        """

        let notification = try RealtimeNotification.decoder().decode(
            RealtimeNotification.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(notification.missionId, 789)
        XCTAssertEqual(notification.activityId, 33)
        XCTAssertEqual(notification.incidentId, 11)
        XCTAssertEqual(notification.normalizedType, "supply_request")
    }

    func testSharedPeopleRegenerationPreservesNamesAndFiltersReliefSelections() throws {
        let formData = makeFormData(adults: 1, children: 1)

        var count = formData.sharedPeopleCount

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
        let formData = makeFormData()

        formData.updatePersonName("Bé Na", for: "adult_1")
        formData.rescueData.injuredPersonIds = ["adult_1"]
        formData.rescueData.medicalInfoByPerson["adult_1"] = PersonMedicalInfo(
            personId: "adult_1",
            medicalIssues: [MedicalIssue.highFever.rawValue]
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

    func testReportingModeRequiresExplicitSelectionBeforeContinuing() {
        let formData = SOSFormData()

        XCTAssertEqual(formData.currentStep, .reportingMode)
        XCTAssertFalse(formData.canProceedToNextStep)

        formData.reportingTarget = .other

        XCTAssertTrue(formData.canProceedToNextStep)

        formData.goToNextStep()

        XCTAssertEqual(formData.currentStep, .autoInfo)
    }

    func testEnhancedPacketEncodesAndDecodesNewReliefFields() throws {
        let formData = makeFormData()
        formData.selectedTypes = [.relief]
        formData.addressQuery = "12 Le Loi, Hue"
        formData.resolvedAddress = "12 Le Loi, Hue, Viet Nam"
        formData.manualLocation = SOSManualLocation(latitude: 16.4637, longitude: 107.5909, accuracy: nil)
        formData.autoInfo = AutoCollectedInfo(
            deviceId: "device-1",
            userId: "user-1",
            userName: "Nguyen Van A",
            userPhone: "0901234567",
            latitude: 16.0,
            longitude: 108.0,
            accuracy: 5,
            isOnline: true,
            batteryLevel: 72
        )
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
        let groupNeeds = try XCTUnwrap(decoded.structuredData?.groupNeeds)
        let victims = try XCTUnwrap(decoded.structuredData?.victims)
        let primaryVictim = try XCTUnwrap(victims.first(where: { $0.personId == "adult_1" }))

        XCTAssertEqual(primaryVictim.customName, "Bé Tí")
        XCTAssertEqual(primaryVictim.personalNeeds.diet.hasSpecialDiet, true)
        XCTAssertEqual(primaryVictim.personalNeeds.diet.description, "Cần thức ăn mềm")
        XCTAssertEqual(Set(groupNeeds.medicine?.medicalNeeds ?? []), Set([MedicalSupportNeed.commonMedicine.rawValue, MedicalSupportNeed.minorInjury.rawValue]))
        XCTAssertEqual(groupNeeds.blanket?.requestCount, 1)
        XCTAssertEqual(primaryVictim.personalNeeds.clothing.needed, true)
        XCTAssertEqual(primaryVictim.personalNeeds.clothing.gender, ClothingGender.male.rawValue)
        XCTAssertEqual(decoded.structuredData?.address, "12 Le Loi, Hue, Viet Nam")
        XCTAssertNil(decoded.victimInfo)
        XCTAssertEqual(decoded.reporterInfo?.userId, "user-1")
        XCTAssertEqual(decoded.isSentOnBehalf, false)
    }

    func testFormDataOtherModeSerializesVictimReporterAndLegacySender() throws {
        let formData = SOSFormData()
        formData.autoInfo = AutoCollectedInfo(
            deviceId: "device-2",
            userId: "reporter-1",
            userName: "Nguoi gui",
            userPhone: "0911222333",
            latitude: 15.0,
            longitude: 108.0,
            accuracy: 8,
            isOnline: false,
            batteryLevel: 40
        )
        formData.reportingTarget = .other
        formData.victimName = "Tran Thi B"
        formData.victimPhone = ""
        formData.addressQuery = "Cho Dong Ba, Hue"
        formData.resolvedAddress = "Cho Dong Ba, Hue, Viet Nam"
        formData.manualLocation = SOSManualLocation(latitude: 16.467, longitude: 107.584, accuracy: nil)

        XCTAssertTrue(formData.canProceedToNextStep)

        let packet = formData.toSOSPacket()

        XCTAssertEqual(packet.location.lat, 16.467)
        XCTAssertEqual(packet.location.lng, 107.584)
        XCTAssertNil(packet.victimInfo)
        XCTAssertNil(packet.structuredData?.victims)
        XCTAssertEqual(packet.reporterInfo?.userId, "reporter-1")
        XCTAssertEqual(packet.reporterInfo?.userName, "Nguoi gui")
        XCTAssertEqual(packet.reporterInfo?.batteryLevel, nil)
        XCTAssertEqual(packet.reporterInfo?.isOnline, false)
        XCTAssertEqual(packet.isSentOnBehalf, true)
        XCTAssertEqual(packet.senderInfo?.userId, "reporter-1")
        XCTAssertEqual(packet.senderInfo?.userName, "Nguoi gui")
        XCTAssertEqual(packet.senderInfo?.userPhone, "0911222333")
        XCTAssertNil(packet.senderInfo?.batteryLevel)
        XCTAssertEqual(packet.senderInfo?.isOnline, false)
        XCTAssertEqual(packet.structuredData?.address, "Cho Dong Ba, Hue, Viet Nam")
    }

    func testSavedSOSRoundTripPreservesOnBehalfAddressAndManualLocation() throws {
        let formData = SOSFormData()
        formData.autoInfo = AutoCollectedInfo(
            deviceId: "device-3",
            userId: "reporter-2",
            userName: "Le Van C",
            userPhone: "0909000111",
            latitude: 16.0,
            longitude: 108.0,
            accuracy: 10,
            isOnline: true,
            batteryLevel: 60
        )
        formData.reportingTarget = .other
        formData.victimName = "Pham Thi D"
        formData.victimPhone = "0977777777"
        formData.addressQuery = "Dai Noi Hue"
        formData.resolvedAddress = "Dai Noi Hue, Viet Nam"
        formData.manualLocation = SOSManualLocation(latitude: 16.471, longitude: 107.578, accuracy: nil)
        formData.selectedTypes = [.rescue]
        formData.rescueData.situation = RescueSituation.trapped.rawValue

        let saved = SavedSOS(from: formData, packetId: "packet-1", latitude: 16.471, longitude: 107.578)
        let restored = saved.toFormData()

        XCTAssertEqual(restored.reportingTarget, .other)
        XCTAssertEqual(restored.victimName, "Pham Thi D")
        XCTAssertEqual(restored.victimPhone, "0977777777")
        XCTAssertEqual(restored.addressQuery, "Dai Noi Hue")
        XCTAssertEqual(restored.resolvedAddress, "Dai Noi Hue, Viet Nam")
        XCTAssertEqual(restored.manualLocation, SOSManualLocation(latitude: 16.471, longitude: 107.578, accuracy: nil))
        XCTAssertEqual(restored.effectiveLocation?.latitude, 16.471)
        XCTAssertEqual(restored.effectiveVictimName, "Pham Thi D")
    }

    func testFormDataOtherModeForcesOfflineAndOmitsBattery() throws {
        let formData = SOSFormData()
        formData.autoInfo = AutoCollectedInfo(
            deviceId: "device-4",
            userId: "reporter-3",
            userName: "Nguoi bao tin",
            userPhone: "0909000222",
            latitude: 16.0,
            longitude: 107.0,
            accuracy: 6,
            isOnline: true,
            batteryLevel: 88
        )
        formData.reportingTarget = .other
        formData.victimName = "Hoang Van E"
        formData.manualLocation = SOSManualLocation(latitude: 16.5, longitude: 107.6, accuracy: nil)

        let packet = formData.toSOSPacket()

        XCTAssertNil(packet.reporterInfo?.batteryLevel)
        XCTAssertEqual(packet.reporterInfo?.isOnline, false)
        XCTAssertNil(packet.senderInfo?.batteryLevel)
        XCTAssertEqual(packet.senderInfo?.isOnline, false)
    }

    func testPeopleCountMetricsAlwaysIncludeFourCards() {
        let metrics = peopleCountMetrics(from: PeopleCount(adults: 2, children: 0, elderly: 1))

        XCTAssertEqual(metrics.map(\.title), ["Tổng người", "Người lớn", "Trẻ em", "Người già"])
        XCTAssertEqual(metrics.map(\.value), ["3", "2", "0", "1"])
    }

    func testPersonRequirementSummaryModelsMergeNeedsForSamePerson() {
        let formData = makeFormData()
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
        relief.waterDuration = WaterDuration.from12to24h.rawValue
        relief.foodDuration = FoodDuration.from1to2days.rawValue
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

    func testRelativeProfileStoreScopesProfilesPerUserAndFilters() throws {
        let suiteName = "RelativeProfileStoreTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        var activeUserId: String? = "user-a"
        let store = RelativeProfileStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { activeUserId },
            sessionPublisher: nil
        )

        store.save(profile: EmergencyRelativeProfile(
            displayName: "Bà Lan",
            phoneNumber: "0901000200",
            personType: .elderly,
            gender: .female,
            relationGroup: .nhaNgoai,
            medicalProfile: RelativeMedicalProfile(
                chronicConditions: [.hypertension, .diabetes],
                mobilityStatus: .wheelchair,
                bloodType: .oPositive
            ),
            medicalBaselineNote: "Cần thuốc huyết áp"
        ))
        store.save(profile: EmergencyRelativeProfile(
            displayName: "Bé Na",
            personType: .child,
            relationGroup: .hangXom,
            specialNeedsNote: "Trẻ nhỏ",
            specialDietNote: "Cần sữa"
        ))

        XCTAssertEqual(store.profiles.count, 2)
        XCTAssertEqual(store.filteredProfiles(searchText: "Lan").count, 1)
        XCTAssertEqual(store.filteredProfiles(searchText: "Nữ").count, 1)
        XCTAssertEqual(store.filteredProfiles(searchText: "tiểu đường").count, 1)
        XCTAssertEqual(store.filteredProfiles(relationGroup: .hangXom).count, 1)
        XCTAssertEqual(store.filteredProfiles(searchText: "xe lăn").count, 1)

        activeUserId = "user-b"
        store.reloadCurrentUser()
        XCTAssertTrue(store.profiles.isEmpty)

        store.save(profile: EmergencyRelativeProfile(
            displayName: "Chú Tư",
            personType: .adult,
            relationGroup: .giaDinh
        ))
        XCTAssertEqual(store.profiles.count, 1)

        activeUserId = "user-a"
        store.reloadCurrentUser()
        XCTAssertEqual(store.profiles.count, 2)
        XCTAssertEqual(store.filteredProfiles(searchText: "huyết áp").count, 1)
        XCTAssertEqual(store.filteredProfiles(searchText: "trẻ nhỏ").count, 1)
    }

    func testApplyingSavedRelativeProfilesSupportsZeroAdultsAndPrefillsDiet() {
        let formData = SOSFormData()
        formData.reportingTarget = .other

        let childProfile = EmergencyRelativeProfile(
            displayName: "Bé Tí",
            personType: .child,
            gender: .female,
            relationGroup: .giaDinh,
            specialDietNote: "Cần sữa"
        )
        let elderlyProfile = EmergencyRelativeProfile(
            displayName: "Bà Ngoại",
            personType: .elderly,
            relationGroup: .nhaNgoai,
            medicalProfile: RelativeMedicalProfile(
                chronicConditions: [.hypertension],
                mobilityStatus: .immobile,
                medicalDevices: [.oxygen]
            ),
            medicalBaselineNote: "Cần thuốc huyết áp",
            specialNeedsNote: "Khó di chuyển"
        )

        formData.applySelectedRelativeProfiles([childProfile, elderlyProfile])

        XCTAssertEqual(formData.personSourceMode, .savedProfiles)
        XCTAssertEqual(formData.sharedPeopleCount, PeopleCount(adults: 0, children: 1, elderly: 1))
        XCTAssertEqual(formData.victimName, "Nhóm 2 người")
        XCTAssertEqual(formData.victimPhone, "")
        XCTAssertTrue(formData.reliefData.specialDietPersonIds.contains(childProfile.personId))
        XCTAssertEqual(
            formData.reliefData.specialDietInfoByPerson[childProfile.personId]?.dietDescription,
            "Cần sữa"
        )
        XCTAssertEqual(
            formData.reliefData.clothingInfoByPerson[childProfile.personId]?.gender,
            .female
        )
        XCTAssertFalse(formData.reliefData.clothingPersonIds.contains(childProfile.personId))
        XCTAssertTrue(formData.savedProfileContextMessage?.contains("Bà Ngoại") == true)
        XCTAssertTrue(formData.savedProfileContextMessage?.contains("Khả năng vận động: Không thể tự di chuyển") == true)
        XCTAssertTrue(formData.savedProfileContextMessage?.contains("Khó di chuyển") == true)
    }

    func testSavedRelativeProfilesAlsoDriveVictimInfoInSelfMode() {
        let formData = SOSFormData()
        formData.reportingTarget = .self
        formData.autoInfo = AutoCollectedInfo(
            deviceId: "device-self",
            userId: "user-self",
            userName: "Người gửi",
            userPhone: "0909990000",
            latitude: 16.46,
            longitude: 107.59,
            accuracy: 5,
            isOnline: true,
            batteryLevel: 70
        )

        let profile = EmergencyRelativeProfile(
            displayName: "Bà Lan",
            phoneNumber: "0901000200",
            personType: .elderly,
            relationGroup: .giaDinh
        )

        formData.applySelectedRelativeProfiles([profile])

        XCTAssertTrue(formData.usesSavedRelativeProfiles)
        XCTAssertEqual(formData.effectiveVictimName, "Bà Lan")
        XCTAssertEqual(formData.effectiveVictimPhone, "0901000200")
        XCTAssertNil(formData.effectiveVictimInfo?.userId)
        XCTAssertEqual(formData.effectiveVictimInfo?.userName, "Bà Lan")
        XCTAssertEqual(formData.sharedPeople.first?.id, profile.personId)
    }

    func testSavedRelativeProfilesCanBeCombinedWithManualAdditionalPeople() throws {
        let formData = SOSFormData()
        let firstProfile = EmergencyRelativeProfile(
            displayName: "Anh Hai",
            personType: .adult,
            relationGroup: .giaDinh
        )
        let secondProfile = EmergencyRelativeProfile(
            displayName: "Chị Ba",
            personType: .adult,
            relationGroup: .giaDinh
        )

        formData.applySelectedRelativeProfiles([firstProfile, secondProfile])
        formData.sharedPeopleCount = PeopleCount(adults: 3, children: 0, elderly: 0)

        XCTAssertTrue(formData.usesSavedRelativeProfiles)
        XCTAssertTrue(formData.hasManualAdditionalPeople)
        XCTAssertEqual(formData.personSourceMode, .mixed)
        XCTAssertEqual(formData.sharedPeopleCount, PeopleCount(adults: 3, children: 0, elderly: 0))
        XCTAssertEqual(formData.sharedPeople.count, 3)
        XCTAssertEqual(formData.selectedRelativeSnapshots.count, 2)
        XCTAssertNotNil(formData.person(for: firstProfile.personId))
        XCTAssertNotNil(formData.person(for: secondProfile.personId))

        let manualAdult = try XCTUnwrap(
            formData.sharedPeople.first(where: { $0.id.hasPrefix("manual_adult_") })
        )
        XCTAssertEqual(manualAdult.type, .adult)
        XCTAssertNil(formData.selectedRelativeSnapshot(for: manualAdult.id))
        XCTAssertEqual(formData.victimName, "Nhóm 3 người")

        formData.sharedPeopleCount = PeopleCount(adults: 1, children: 0, elderly: 0)

        XCTAssertEqual(formData.sharedPeopleCount, PeopleCount(adults: 2, children: 0, elderly: 0))
        XCTAssertEqual(formData.personSourceMode, .savedProfiles)
        XCTAssertFalse(formData.hasManualAdditionalPeople)
    }

    func testDraftEditsDoNotMutateSelectedRelativeSnapshot() {
        let formData = SOSFormData()
        let profile = EmergencyRelativeProfile(
            displayName: "Bà Lan",
            personType: .elderly,
            relationGroup: .giaDinh,
            medicalBaselineNote: "Cần thuốc huyết áp"
        )

        formData.applySelectedRelativeProfiles([profile])
        formData.updatePersonName("Bà Lan (SOS)", for: profile.personId)

        XCTAssertEqual(formData.person(for: profile.personId)?.displayName, "Bà Lan (SOS)")
        XCTAssertEqual(formData.selectedRelativeSnapshots.first?.displayName, "Bà Lan")
        XCTAssertEqual(formData.selectedRelativeSnapshots.first?.medicalBaselineNote, "Cần thuốc huyết áp")
    }

    func testSavedSOSRoundTripPreservesSavedRelativeSnapshotsAndMode() throws {
        let formData = SOSFormData()
        formData.reportingTarget = .other
        formData.selectedTypes = [.relief]
        formData.additionalDescription = "Cần hỗ trợ sớm"
        formData.manualLocation = SOSManualLocation(latitude: 16.47, longitude: 107.58, accuracy: nil)
        formData.autoInfo = AutoCollectedInfo(
            deviceId: "device-relative",
            userId: "reporter-relative",
            userName: "Người báo tin",
            userPhone: "0909000999",
            latitude: 16.0,
            longitude: 108.0,
            accuracy: 4,
            isOnline: true,
            batteryLevel: 55
        )

        let profile = EmergencyRelativeProfile(
            displayName: "Ông Nội",
            phoneNumber: "0911222333",
            personType: .elderly,
            gender: .male,
            relationGroup: .nhaNoi,
            medicalProfile: RelativeMedicalProfile(
                chronicConditions: [.diabetes],
                allergyOptions: [.medication],
                allergyDetails: "dị ứng penicillin",
                bloodType: .abPositive
            ),
            medicalBaselineNote: "Cần thuốc tiểu đường"
        )

        formData.applySelectedRelativeProfiles([profile])

        let saved = SavedSOS(from: formData, packetId: "relative-packet", latitude: 16.47, longitude: 107.58)
        let restored = saved.toFormData()

        XCTAssertEqual(saved.personSourceMode, .savedProfiles)
        XCTAssertEqual(saved.selectedRelativeSnapshots.count, 1)
        XCTAssertEqual(restored.personSourceMode, .savedProfiles)
        XCTAssertEqual(restored.selectedRelativeSnapshots.first?.profileId, profile.id)
        XCTAssertEqual(restored.selectedRelativeSnapshots.first?.gender, .male)
        XCTAssertEqual(restored.selectedRelativeSnapshots.first?.medicalProfile.bloodType, .abPositive)
        XCTAssertEqual(restored.selectedRelativeSnapshots.first?.medicalProfile.allergyDetails, "dị ứng penicillin")
        XCTAssertEqual(restored.sharedPeople.first?.id, profile.personId)
        XCTAssertEqual(restored.effectiveVictimName, "Ông Nội")
        XCTAssertTrue(restored.mergedAdditionalDescription?.contains("Cần thuốc tiểu đường") == true)
    }

    func testRelativeMedicalProfileSummaryLinesIncludeStructuredMedicalDetails() {
        let profile = RelativeMedicalProfile(
            chronicConditions: [.diabetes, .asthma],
            otherChronicCondition: "viêm khớp",
            allergyOptions: [.food],
            allergyDetails: "dị ứng hải sản",
            hasLongTermMedication: true,
            longTermMedications: [
                LongTermMedicationEntry(name: "Metformin", frequency: "2 lần/ngày", note: "sau ăn")
            ],
            mobilityStatus: .needsSupport,
            medicalDevices: [.glucoseMonitor],
            otherMedicalDevice: "máy hút đàm",
            specialSituation: SpecialMedicalSituation(isPregnant: false, isSenior: true, isYoungChild: false, hasDisability: true),
            medicalHistory: [.majorSurgery],
            medicalHistoryDetails: "mổ tim năm 2022",
            bloodType: .oNegative
        )

        let summary = profile.summaryLines.joined(separator: " | ")

        XCTAssertTrue(summary.contains("Tiểu đường"))
        XCTAssertTrue(summary.contains("dị ứng hải sản"))
        XCTAssertTrue(summary.contains("Metformin"))
        XCTAssertTrue(summary.contains("Cần hỗ trợ"))
        XCTAssertTrue(summary.contains("máy hút đàm"))
        XCTAssertTrue(summary.contains("Nhóm máu: O-"))
    }

    func testMissionIncidentsResponseDecodesWrappedPayload() throws {
        let json = """
        {
          "missionId": 91,
          "incidents": [
            {
              "incidentId": 22,
              "missionTeamId": 7,
              "missionActivityId": 18,
              "incidentScope": "Activity",
              "description": "Lở đất chặn đường",
              "latitude": 16.4637,
              "longitude": 107.5909,
              "status": "Reported",
              "reportedBy": {
                "id": "b3f8b7e0-2cbf-4d26-8b9d-95f1fcefa222",
                "firstName": "An",
                "lastName": "Nguyen"
              },
              "reportedAt": "2026-04-08T10:00:00Z"
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(
            MissionIncidentsResponse.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(decoded.missionId, 91)
        XCTAssertEqual(decoded.incidents.count, 1)
        XCTAssertEqual(decoded.incidents.first?.id, 22)
        XCTAssertEqual(decoded.incidents.first?.missionActivityId, 18)
        XCTAssertEqual(decoded.incidents.first?.incidentScope, "Activity")
        XCTAssertEqual(decoded.incidents.first?.reportedBy?.displayName, "Nguyen An")
    }

    func testIncidentReportResponseDecodesAssistanceFields() throws {
        let json = """
        {
          "incidentId": 33,
          "missionId": 11,
          "missionTeamId": 5,
          "missionActivityId": null,
          "incidentScope": "Mission",
          "status": "Reported",
          "incidentSosRequestIds": [101, 102],
          "assistanceSosRequestId": 401,
          "assistanceSosStatus": "Pending",
          "assistanceSosPriorityLevel": "P2",
          "reportedAt": "2026-04-08T11:45:00Z"
        }
        """

        let decoded = try JSONDecoder().decode(
            IncidentResponse.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(decoded.incidentId, 33)
        XCTAssertEqual(decoded.missionId, 11)
        XCTAssertEqual(decoded.incidentSosRequestIds, [101, 102])
        XCTAssertEqual(decoded.assistanceSosRequestId, 401)
        XCTAssertEqual(decoded.assistanceSosPriorityLevel, "P2")
    }

    func testFetchMySOSDecodesIncidentSummaryFields() throws {
        let json = """
        {
          "sosRequests": [
            {
              "id": 55,
              "packetId": "packet-55",
              "userId": "2c79ce03-9bdb-4cef-bdd0-eab3f0d6de87",
              "sosType": "RESCUE",
              "msg": "Cần hỗ trợ khẩn cấp",
              "status": "InProgress",
              "latitude": 16.47,
              "longitude": 107.58,
              "timestamp": 1712570400,
              "latestIncidentNote": "Đội cứu hộ đang tiếp cận",
              "latestIncidentAt": "2026-04-08T12:15:00Z",
              "isCompanion": true
            }
          ]
        }
        """

        let decoded = try JSONDecoder().decode(
            SOSServerResponse.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        let record = try XCTUnwrap(decoded.sosRequests.first)
        XCTAssertEqual(record.id, 55)
        XCTAssertEqual(record.latestIncidentNote, "Đội cứu hộ đang tiếp cận")
        XCTAssertEqual(record.latestIncidentAt, "2026-04-08T12:15:00Z")
        XCTAssertEqual(record.isCompanion, true)
    }

    func testSosRequestDetailDecodesIncidentHistoryAndCompanions() throws {
        let json = """
        {
          "sosRequest": {
            "id": 70,
            "packetId": "packet-70",
            "userId": "3f20f9c8-13dc-4861-9457-b31b4b6dbab3",
            "sosType": "RELIEF",
            "msg": "Cần nước và thuốc",
            "status": "Pending",
            "latitude": 16.1,
            "longitude": 108.2,
            "timestamp": 1712574000,
            "latestIncidentNote": "Đã ghi nhận yêu cầu",
            "latestIncidentAt": "2026-04-08T13:00:00Z",
            "incidentHistory": [
              {
                "id": 1,
                "teamIncidentId": 99,
                "missionId": 8,
                "missionTeamId": 6,
                "missionActivityId": null,
                "incidentScope": "Mission",
                "note": "Đội A đã tiếp cận khu vực",
                "reportedById": "90d9c5d4-8a1d-4b97-99d5-3303b64f65e2",
                "createdAt": "2026-04-08T13:10:00Z",
                "teamName": "Đội A",
                "activityType": null
              }
            ],
            "companions": [
              {
                "userId": "7474c6f2-cc94-4db9-bf80-72ceeceea1cc",
                "fullName": "Tran Thi Lan",
                "phone": "0905000111",
                "addedAt": "2026-04-08T13:12:00Z"
              }
            ]
          }
        }
        """

        let decoded = try JSONDecoder().decode(
            SosRequestDetailResponse.self,
            from: XCTUnwrap(json.data(using: .utf8))
        )

        XCTAssertEqual(decoded.sosRequest.id, 70)
        XCTAssertEqual(decoded.sosRequest.incidentHistory?.first?.note, "Đội A đã tiếp cận khu vực")
        XCTAssertEqual(decoded.sosRequest.companions?.first?.fullName, "Tran Thi Lan")
    }

    func testServerRequestEnvelopeAndAckEncodeDecodeVictimUpdate() throws {
        let packet = SOSPacket(
            packetId: "packet-update",
            originId: "device-1",
            timestamp: Date(timeIntervalSince1970: 1712577600),
            latitude: 16.46,
            longitude: 107.59,
            sosType: "RESCUE",
            message: "Cập nhật vị trí",
            structuredData: nil,
            victimInfo: nil,
            reporterInfo: nil,
            isSentOnBehalf: false,
            senderInfo: nil,
            hopCount: 0,
            path: ["device-1"]
        )

        let envelope = ServerRequestEnvelope.victimSosUpdate(
            requestId: "update-req-1",
            targetLocalSosId: "packet-update",
            serverSosRequestId: 88,
            packet: packet,
            requesterUserId: "user-1",
            victimPhone: "0901234567",
            reporterPhone: "0907654321"
        )
        let ack = ServerRequestAck(
            requestId: "update-req-1",
            originDeviceId: "device-1",
            success: true,
            timestamp: 1712577601,
            requestType: .victimSosUpdate,
            targetLocalSosId: "packet-update"
        )

        let encodedEnvelope = try JSONEncoder().encode(envelope)
        let decodedEnvelope = try JSONDecoder().decode(ServerRequestEnvelope.self, from: encodedEnvelope)
        XCTAssertEqual(decodedEnvelope.type, .victimSosUpdate)
        XCTAssertEqual(decodedEnvelope.targetLocalSosId, "packet-update")
        XCTAssertEqual(decodedEnvelope.serverSosRequestId, 88)
        XCTAssertEqual(decodedEnvelope.victimSosUpdate?.packet.packetId, "packet-update")

        let encodedAck = try JSONEncoder().encode(ack)
        let decodedAck = try JSONDecoder().decode(ServerRequestAck.self, from: encodedAck)
        XCTAssertEqual(decodedAck.requestType, .victimSosUpdate)
        XCTAssertEqual(decodedAck.targetLocalSosId, "packet-update")
    }

    func testMissionActivitySyncStoreScopesUpdatesPerUserAndDedupes() throws {
        let suiteName = "MissionActivitySyncStoreTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        var activeUserId: String? = "user-a"
        let store = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { activeUserId }
        )

        XCTAssertNotNil(store.enqueue(
            missionId: 1,
            activityId: 101,
            targetStatus: "Succeed",
            baseServerStatus: "Planned"
        ))
        XCTAssertNil(store.enqueue(
            missionId: 1,
            activityId: 101,
            targetStatus: "Failed",
            baseServerStatus: "Planned"
        ))
        XCTAssertEqual(store.updates.count, 1)

        activeUserId = "user-b"
        store.reloadCurrentUser()
        XCTAssertTrue(store.updates.isEmpty)

        XCTAssertNotNil(store.enqueue(
            missionId: 2,
            activityId: 202,
            targetStatus: "Failed",
            baseServerStatus: "OnGoing"
        ))
        XCTAssertEqual(store.updates.count, 1)

        activeUserId = "user-a"
        store.reloadCurrentUser()
        XCTAssertEqual(store.updates.count, 1)
        XCTAssertEqual(store.updates.first?.missionId, 1)
        XCTAssertEqual(store.updates.first?.activityId, 101)
        XCTAssertEqual(store.updates.first?.syncState, .queued)
    }

    func testMissionActivitySyncStoreAppliesLocalOverlayAndUnlocksNextStep() throws {
        let suiteName = "MissionActivitySyncOverlayTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { "rescuer-a" }
        )

        let baseActivities = [
            makeActivity(id: 11, step: 1, status: "Planned"),
            makeActivity(id: 12, step: 2, status: "Planned")
        ]

        XCTAssertNotNil(store.enqueue(
            missionId: 9,
            activityId: 11,
            targetStatus: "Succeed",
            baseServerStatus: "Planned"
        ))

        let effective = store.effectiveActivities(base: baseActivities, missionId: 9)
        XCTAssertEqual(effective.first?.activityStatus, .succeed)
        XCTAssertTrue(missionActivityActionIsUnlocked(effective[1], within: effective))
        XCTAssertEqual(store.syncState(for: 9, activityId: 11), .queued)
    }

    func testMissionActivitySyncStoreReloadsPersistedUpdatesAfterRestart() throws {
        let suiteName = "MissionActivitySyncRestartTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { "rescuer-restart" }
        )

        XCTAssertNotNil(firstStore.enqueue(
            missionId: 4,
            activityId: 44,
            targetStatus: "Failed",
            baseServerStatus: "OnGoing"
        ))
        XCTAssertEqual(firstStore.updates.count, 1)

        let reloadedStore = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { "rescuer-restart" }
        )

        XCTAssertEqual(reloadedStore.updates.count, 1)
        XCTAssertEqual(reloadedStore.updates.first?.activityId, 44)
        XCTAssertEqual(reloadedStore.updates.first?.targetStatus, "Failed")

        let effective = reloadedStore.effectiveActivities(
            base: [makeActivity(id: 44, step: 3, status: "OnGoing")],
            missionId: 4
        )
        XCTAssertEqual(effective.first?.activityStatus, .failed)
    }

    func testRescuerMissionViewModelOfflineUpdateQueuesWithoutCallingRemoteService() throws {
        let suiteName = "RescuerMissionViewModelOfflineTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { "rescuer-offline" }
        )
        let service = MockMissionActivityRemoteService()
        let network = FixedNetworkStatusProvider(isConnected: false)
        let vm = RescuerMissionViewModel(
            missionService: service,
            networkStatusProvider: network,
            missionActivitySyncStore: store
        )

        let knownActivities = [makeActivity(id: 70, step: 1, status: "Planned")]
        vm.updateActivity(
            missionId: 5,
            activityId: 70,
            status: "Succeed",
            knownActivities: knownActivities
        )

        XCTAssertTrue(service.updatedActivityCalls.isEmpty)
        XCTAssertEqual(store.pendingCount(for: 5), 1)
        XCTAssertEqual(vm.pendingSyncState(missionId: 5, activityId: 70), .queued)
        XCTAssertEqual(vm.effectiveActivities(missionId: 5, fallback: knownActivities).first?.activityStatus, .succeed)
        XCTAssertEqual(vm.successMessage, "Đã lưu cục bộ. Hoạt động đang chờ đồng bộ máy chủ.")
    }

    func testRescuerMissionViewModelOnlineUpdateCallsRemoteService() async throws {
        let suiteName = "RescuerMissionViewModelOnlineTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { "rescuer-online" }
        )
        let service = MockMissionActivityRemoteService()
        let network = FixedNetworkStatusProvider(isConnected: true)
        let vm = RescuerMissionViewModel(
            missionService: service,
            networkStatusProvider: network,
            missionActivitySyncStore: store
        )

        let knownActivities = [makeActivity(id: 80, step: 1, status: "Planned")]
        service.activitiesByMission[7] = [makeActivity(id: 80, step: 1, status: "Succeed")]

        vm.updateActivity(
            missionId: 7,
            activityId: 80,
            status: "Succeed",
            knownActivities: knownActivities
        )

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(service.updatedActivityCalls.count, 1)
        XCTAssertEqual(service.updatedActivityCalls.first?.missionId, 7)
        XCTAssertEqual(service.updatedActivityCalls.first?.activityId, 80)
        XCTAssertEqual(service.updatedActivityCalls.first?.status, "Succeed")
        XCTAssertNil(service.updatedActivityCalls.first?.imageUrl)
        XCTAssertTrue(store.updates.isEmpty)
        XCTAssertEqual(vm.activities.first?.activityStatus, .succeed)
        XCTAssertEqual(vm.successMessage, L10n.RescuerMission.activityStatusUpdated)
    }

    func testRescuerMissionViewModelSafetyCheckInCallsRemoteService() async throws {
        let suiteName = "RescuerMissionViewModelSafetyCheckInTests-\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let store = makeMissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: { "rescuer-safe" }
        )
        let service = MockMissionActivityRemoteService()
        let network = FixedNetworkStatusProvider(isConnected: true)
        let vm = RescuerMissionViewModel(
            missionService: service,
            networkStatusProvider: network,
            missionActivitySyncStore: store
        )

        let didCheckIn = await vm.safetyCheckIn(missionId: 12, missionTeamId: 34)

        XCTAssertTrue(didCheckIn)
        XCTAssertEqual(service.safetyCheckInCalls.count, 1)
        XCTAssertEqual(service.safetyCheckInCalls.first?.missionId, 12)
        XCTAssertEqual(service.safetyCheckInCalls.first?.missionTeamId, 34)
        XCTAssertEqual(vm.successMessage, L10n.RescuerMission.safetyCheckInSucceeded)
    }

    func testVoiceSOSDraftMapsFreeSpeechExampleToStructuredPacket() async throws {
        let transcript = "Có 3 người đang gặp nạn Huỳnh Kim Cương, Nguyễn Trọng Phương An và Nguyễn Ngọc Thảo. Cho tôi 1 cái hamburger. Tụi nó vẫn ổn chỉ bị mắc kẹt."
        let expectedDraft = VoiceSOSDraft(
            selectedTypes: ["BOTH"],
            peopleCount: VoiceSOSPeopleCountDraft(adults: 0, children: 0, elderly: 0, total: 3),
            victims: [
                VoiceSOSVictimDraft(personId: nil, name: "Huỳnh Kim Cương", personType: nil, index: nil, phone: nil, isInjured: false, medicalIssues: []),
                VoiceSOSVictimDraft(personId: nil, name: "Nguyễn Trọng Phương An", personType: nil, index: nil, phone: nil, isInjured: false, medicalIssues: []),
                VoiceSOSVictimDraft(personId: nil, name: "Nguyễn Ngọc Thảo", personType: nil, index: nil, phone: nil, isInjured: false, medicalIssues: [])
            ],
            situation: RescueSituation.trapped.rawValue,
            situationDescription: "Tụi nó vẫn ổn chỉ bị mắc kẹt",
            hasInjured: false,
            medicalIssues: [],
            medicalDescription: nil,
            othersAreStable: true,
            canMove: true,
            groupNeeds: VoiceSOSGroupNeedsDraft(
                supplies: [SupplyNeed.food.rawValue],
                otherSupplyDescription: "1 cái hamburger"
            ),
            missingFields: [],
            nextQuestion: nil,
            readyToSend: true
        )
        let provider = FakeVoiceSOSUnderstandingProvider(draft: expectedDraft)

        let draft = try await provider.updateDraft(
            conversationHistory: [VoiceConversationTurn(role: "user", text: transcript)],
            currentDraft: .empty
        )
        let formData = draft.makeSOSFormData(
            autoInfo: makeVoiceAutoInfo(),
            conversationUserTexts: [transcript],
            applyDefaults: true
        )
        let packet = formData.toSOSPacket(
            originIdOverride: "voice-test-device",
            timestampOverride: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(packet.sosType, "BOTH")
        XCTAssertEqual(packet.structuredData?.incident?.peopleCount.adult, 3)
        XCTAssertEqual(packet.structuredData?.incident?.situation, RescueSituation.trapped.rawValue)
        XCTAssertEqual(packet.structuredData?.incident?.hasInjured, false)
        XCTAssertNil(packet.structuredData?.incident?.othersAreStable)
        XCTAssertNil(packet.structuredData?.incident?.canMove)
        XCTAssertEqual(packet.structuredData?.groupNeeds?.supplies, [SupplyNeed.food.rawValue])
        XCTAssertEqual(packet.structuredData?.groupNeeds?.otherSupplyDescription, "1 cái hamburger")
        XCTAssertEqual(packet.structuredData?.victims?.map(\.customName), [
            "Huỳnh Kim Cương",
            "Nguyễn Trọng Phương An",
            "Nguyễn Ngọc Thảo"
        ])
        XCTAssertTrue(packet.structuredData?.additionalDescription?.contains("[Voice SOS]") == true)
    }

    func testGeminiVoiceSOSUsesGenerateContentCompatibleModelFirst() {
        XCTAssertEqual(GeminiVoiceSOSUnderstandingProvider.defaultModelCandidates.first, "gemini-2.5-flash")
        XCTAssertFalse(
            GeminiVoiceSOSUnderstandingProvider.defaultModelCandidates.contains("gemini-3.1-flash-live-preview")
        )
    }

    func testVoiceSOSDraftDefaultsPeopleCountWhenUserSkipsMissingAnswer() {
        let transcript = "Mọi người đang bị mắc kẹt."
        let draft = VoiceSOSDraft(
            selectedTypes: [SOSType.rescue.rawValue],
            situation: RescueSituation.trapped.rawValue,
            missingFields: ["PEOPLE_COUNT"],
            nextQuestion: "Có bao nhiêu người đang cần hỗ trợ?",
            readyToSend: false
        )

        XCTAssertEqual(draft.followUpQuestion, "Có bao nhiêu người đang cần hỗ trợ?")

        let formData = draft.makeSOSFormData(
            autoInfo: makeVoiceAutoInfo(),
            conversationUserTexts: [transcript],
            applyDefaults: true
        )
        let packet = formData.toSOSPacket(originIdOverride: "voice-test-device")

        XCTAssertEqual(packet.sosType, "RESCUE")
        XCTAssertEqual(packet.structuredData?.incident?.peopleCount.adult, 1)
        XCTAssertEqual(packet.structuredData?.incident?.situation, RescueSituation.trapped.rawValue)
    }

    func testVoiceSOSDraftUsesMissingNeedsAsDynamicFollowUp() {
        let draft = VoiceSOSDraft(
            selectedTypes: [],
            peopleCount: VoiceSOSPeopleCountDraft(adults: 2, children: 0, elderly: 0, total: 2),
            missingFields: ["GROUP_NEEDS"],
            nextQuestion: "Bạn cần cứu hộ, cứu trợ gì ngay bây giờ?",
            readyToSend: false
        )

        XCTAssertEqual(draft.followUpQuestion, "Bạn cần cứu hộ, cứu trợ gì ngay bây giờ?")
        XCTAssertEqual(draft.missingFieldLabels, ["Nhu cầu cứu trợ"])
    }

    func testVoiceSOSGroundingBlocksHallucinatedSituationAddressAndAutoSend() {
        let transcript = "Trần Phương An đang bị thương ở tay"
        let hallucinatedDraft = VoiceSOSDraft(
            selectedTypes: ["medical"],
            peopleCount: VoiceSOSPeopleCountDraft(adults: 1, children: 0, elderly: 0, total: 1),
            victims: [
                VoiceSOSVictimDraft(
                    personId: nil,
                    name: "Trần Phương An",
                    personType: nil,
                    index: nil,
                    phone: nil,
                    isInjured: true,
                    medicalIssues: ["gãy tay", "chảy máu"]
                )
            ],
            situation: RescueSituation.collapsed.rawValue,
            situationDescription: "Nhà Trần Phương An bị sập.",
            hasInjured: true,
            medicalIssues: ["gãy tay", "chảy máu"],
            medicalDescription: nil,
            othersAreStable: false,
            canMove: true,
            groupNeeds: VoiceSOSGroupNeedsDraft(
                supplies: ["nếu cần"],
                medicineConditions: ["nếu cần"],
                medicalNeeds: ["nếu cần"]
            ),
            missingFields: [],
            nextQuestion: "Bạn cần hỗ trợ gì thêm? Các nhu cầu của bạn là gì?",
            address: "Trần Phương An",
            readyToSend: true
        )

        let groundedDraft = hallucinatedDraft.grounded(in: [transcript])

        XCTAssertFalse(groundedDraft.readyToSend)
        XCTAssertNil(groundedDraft.address)
        XCTAssertNil(groundedDraft.normalizedSituation)
        XCTAssertTrue(groundedDraft.groupNeeds.hasContent == false)
        XCTAssertTrue(groundedDraft.medicalIssues.first?.contains("bị thương ở tay") == true)
        XCTAssertTrue(groundedDraft.missingFields.contains("LOCATION"))
        XCTAssertEqual(Set(groundedDraft.selectedTypes), [SOSType.rescue.rawValue])

        let formData = groundedDraft.makeSOSFormData(
            autoInfo: makeVoiceAutoInfo(),
            conversationUserTexts: [transcript],
            applyDefaults: true
        )
        let packet = formData.toSOSPacket(originIdOverride: "voice-test-device")

        XCTAssertEqual(packet.sosType, SOSType.rescue.rawValue)
        XCTAssertNil(packet.structuredData?.incident?.situation)
        XCTAssertNil(packet.structuredData?.incident?.othersAreStable)
        XCTAssertNil(packet.structuredData?.incident?.canMove)
        XCTAssertTrue(packet.structuredData?.incident?.otherMedicalDescription?.contains("bị thương ở tay") == true)
        XCTAssertNil(packet.structuredData?.groupNeeds)
        XCTAssertEqual(packet.structuredData?.victims?.first?.incidentStatus.medicalIssues, [MedicalIssue.other.rawValue])
        XCTAssertNil(packet.structuredData?.victims?.first?.incidentStatus.severity)
        XCTAssertFalse(packet.msg.contains("Sập công trình"))
        XCTAssertFalse(packet.msg.contains("Địa chỉ/Vị trí: Trần Phương An"))
        XCTAssertTrue(packet.msg.contains("bị thương ở tay"))
    }

    func testVoiceSOSGroundingDropsHallucinatedSuppliesAgeTypesAndKeepsNames() {
        let transcript = "Thôi thần cố cứu 3 người Huỳnh kim cương Nguyễn Ngọc Thảo và lê bảo châu"
        let hallucinatedDraft = VoiceSOSDraft(
            selectedTypes: ["BOTH"],
            peopleCount: VoiceSOSPeopleCountDraft(
                adults: 1,
                children: 2,
                elderly: 0,
                total: 3
            ),
            victims: [
                VoiceSOSVictimDraft(personId: "adult_1", name: "Huỳnh kim cương", personType: "ADULT", index: 1, phone: nil, isInjured: false, medicalIssues: []),
                VoiceSOSVictimDraft(personId: "child_1", name: "Nguyễn Ngọc Thảo", personType: "CHILD", index: 1, phone: nil, isInjured: false, medicalIssues: []),
                VoiceSOSVictimDraft(personId: "child_2", name: "lê bảo châu", personType: "CHILD", index: 2, phone: nil, isInjured: false, medicalIssues: [])
            ],
            situation: RescueSituation.trapped.rawValue,
            situationDescription: "Ba người đã bị mắc kẹt trong một khu vực nguy hiểm.",
            hasInjured: false,
            medicalIssues: [],
            medicalDescription: nil,
            othersAreStable: false,
            canMove: true,
            groupNeeds: VoiceSOSGroupNeedsDraft(
                supplies: [SupplyNeed.food.rawValue, SupplyNeed.clothes.rawValue],
                otherSupplyDescription: "Cần quần áo và thực phẩm.",
                waterDescription: "Nước uống cần thiết.",
                foodDescription: "Thực phẩm để cung cấp năng lượng.",
                clothingDescription: "Quần áo ấm áp và an toàn."
            ),
            missingFields: [],
            nextQuestion: nil,
            readyToSend: true
        )

        let groundedDraft = hallucinatedDraft.grounded(in: [transcript])
        XCTAssertFalse(groundedDraft.readyToSend)
        XCTAssertTrue(groundedDraft.missingFields.contains("GROUP_NEEDS"))
        XCTAssertTrue(groundedDraft.missingFields.contains("LOCATION"))

        let formData = groundedDraft.makeSOSFormData(
            autoInfo: makeVoiceAutoInfo(),
            conversationUserTexts: [transcript],
            applyDefaults: true
        )
        let packet = formData.toSOSPacket(originIdOverride: "voice-test-device")

        XCTAssertEqual(packet.sosType, SOSType.rescue.rawValue)
        XCTAssertEqual(packet.structuredData?.incident?.peopleCount.adult, 3)
        XCTAssertEqual(packet.structuredData?.incident?.peopleCount.child, 0)
        XCTAssertNil(packet.structuredData?.incident?.situation)
        XCTAssertNil(packet.structuredData?.groupNeeds?.supplies)
        XCTAssertNil(packet.structuredData?.groupNeeds?.otherSupplyDescription)
        XCTAssertEqual(packet.structuredData?.victims?.map(\.customName), [
            "Huỳnh kim cương",
            "Nguyễn Ngọc Thảo",
            "lê bảo châu"
        ])
    }

    func testVoiceSOSUnavailableStatusHidesButtonAndBlocksConversationStart() {
        let unavailable = VoiceSOSAIAvailability.unavailable("AI on-device unavailable")

        XCTAssertFalse(VoiceSOSAvailability.shouldShowVoiceSOSButton(status: unavailable))

        let viewModel = VoiceSOSAgentViewModel(
            bridgefyManager: BridgefyNetworkManager.shared,
            understandingProvider: FakeVoiceSOSUnderstandingProvider(draft: .empty),
            aiAvailability: unavailable,
            availabilityProvider: { unavailable }
        )
        viewModel.isAuthorized = true
        viewModel.startConversation()

        if case .error(let message) = viewModel.conversationState {
            XCTAssertEqual(message, "AI on-device unavailable")
        } else {
            XCTFail("Voice SOS should not start when on-device AI is unavailable.")
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    private func makeMissionActivitySyncStore(
        userDefaults: UserDefaults,
        activeUserIdProvider: @escaping () -> String?
    ) -> MissionActivitySyncStore {
        MissionActivitySyncStore(
            userDefaults: userDefaults,
            activeUserIdProvider: activeUserIdProvider,
            sessionPublisher: Empty<AuthSession?, Never>(completeImmediately: false).eraseToAnyPublisher(),
            networkPublisher: Empty<Bool, Never>(completeImmediately: false).eraseToAnyPublisher(),
            transport: NoopMissionActivitySyncTransport()
        )
    }

    private func makeActivity(
        id: Int,
        step: Int?,
        status: String,
        missionTeamId: Int? = 3
    ) -> Activity {
        Activity(
            id: id,
            step: step,
            activityCode: "ACT-\(id)",
            activityType: "EVACUATE",
            description: "Sample activity \(id)",
            imageUrl: nil,
            priority: "High",
            estimatedTime: 15,
            sosRequestId: nil,
            depotId: nil,
            depotName: nil,
            depotAddress: nil,
            suppliesToCollect: nil,
            targetLatitude: 16.4637,
            targetLongitude: 107.5909,
            status: status,
            missionTeamId: missionTeamId,
            assignedAt: nil,
            completedAt: nil,
            completedBy: nil
        )
    }

    private final class MockMissionActivityRemoteService: MissionActivityRemoteService {
        var missionsToReturn: [Mission] = []
        var activitiesByMission: [Int: [Activity]] = [:]
        var updatedActivityCalls: [(missionId: Int, activityId: Int, status: String, imageUrl: String?)] = []
        var updatedMissionCalls: [(missionId: Int, status: String)] = []
        var safetyCheckInCalls: [(missionId: Int, missionTeamId: Int)] = []

        func getMyTeamMissions() async throws -> [Mission] {
            missionsToReturn
        }

        func getMyTeamActivities(missionId: Int) async throws -> [Activity] {
            activitiesByMission[missionId] ?? []
        }

        func getActivities(missionId: Int) async throws -> [Activity] {
            activitiesByMission[missionId] ?? []
        }

        func updateActivityStatus(missionId: Int, activityId: Int, status: String, imageUrl: String?) async throws {
            updatedActivityCalls.append((missionId, activityId, status, imageUrl))
        }

        func updateMissionStatus(missionId: Int, status: String) async throws {
            updatedMissionCalls.append((missionId, status))
        }

        func safetyCheckIn(missionId: Int, missionTeamId: Int) async throws -> Bool {
            safetyCheckInCalls.append((missionId, missionTeamId))
            return true
        }
    }

    private final class FixedNetworkStatusProvider: NetworkStatusProviding {
        let isConnected: Bool

        init(isConnected: Bool) {
            self.isConnected = isConnected
        }
    }

    private struct FakeVoiceSOSUnderstandingProvider: VoiceSOSUnderstandingProvider {
        let draft: VoiceSOSDraft

        func updateDraft(
            conversationHistory: [VoiceConversationTurn],
            currentDraft: VoiceSOSDraft
        ) async throws -> VoiceSOSDraft {
            draft
        }
    }

    private func makeVoiceAutoInfo() -> AutoCollectedInfo {
        AutoCollectedInfo(
            deviceId: "voice-test-device",
            userId: "voice-user-id",
            userName: "Lê Minh Anh",
            userPhone: "+84374745872",
            timestamp: Date(timeIntervalSince1970: 0),
            latitude: 10.790899552066476,
            longitude: 106.70475657351173,
            accuracy: 9.7,
            isOnline: true,
            batteryLevel: 85
        )
    }

}
