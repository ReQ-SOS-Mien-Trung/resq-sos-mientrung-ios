//
//  SosMienTrungTests.swift
//  SosMienTrungTests
//
//  Created by Huỳnh Kim Cương on 6/12/25.
//

import XCTest
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
        let supplyDetails = try XCTUnwrap(decoded.structuredData?.supplyDetails)

        XCTAssertEqual(supplyDetails.specialDietPersons?.first?.name, "Bé Tí")
        XCTAssertEqual(Set(supplyDetails.medicalNeeds ?? []), Set([MedicalSupportNeed.commonMedicine.rawValue, MedicalSupportNeed.minorInjury.rawValue]))
        XCTAssertEqual(supplyDetails.areBlanketsEnough, false)
        XCTAssertEqual(supplyDetails.blanketRequestCount, 1)
        XCTAssertEqual(supplyDetails.clothingPersons?.first?.gender, ClothingGender.male.rawValue)
        XCTAssertEqual(decoded.structuredData?.address, "12 Le Loi, Hue, Viet Nam")
        XCTAssertEqual(decoded.victimInfo?.userId, "user-1")
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
        XCTAssertEqual(packet.victimInfo?.userId, nil)
        XCTAssertEqual(packet.victimInfo?.userName, "Tran Thi B")
        XCTAssertNil(packet.victimInfo?.userPhone)
        XCTAssertEqual(packet.reporterInfo?.userId, "reporter-1")
        XCTAssertEqual(packet.reporterInfo?.userName, "Nguoi gui")
        XCTAssertEqual(packet.reporterInfo?.batteryLevel, nil)
        XCTAssertEqual(packet.reporterInfo?.isOnline, false)
        XCTAssertEqual(packet.isSentOnBehalf, true)
        XCTAssertEqual(packet.senderInfo?.userId, "reporter-1")
        XCTAssertEqual(packet.senderInfo?.userName, "Tran Thi B")
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
        formData.rescueData.situation = .trapped

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
            tags: ["huyết áp", "xe lăn"],
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
            tags: ["trẻ nhỏ"],
            specialDietNote: "Cần sữa"
        ))

        XCTAssertEqual(store.profiles.count, 2)
        XCTAssertEqual(store.filteredProfiles(searchText: "Lan").count, 1)
        XCTAssertEqual(store.filteredProfiles(searchText: "Nữ").count, 1)
        XCTAssertEqual(store.filteredProfiles(searchText: "tiểu đường").count, 1)
        XCTAssertEqual(store.filteredProfiles(relationGroup: .hangXom).count, 1)
        XCTAssertEqual(store.filteredProfiles(tag: "xe lăn").count, 1)

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
        XCTAssertEqual(store.availableTags, ["huyết áp", "trẻ nhỏ", "xe lăn"])
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

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
