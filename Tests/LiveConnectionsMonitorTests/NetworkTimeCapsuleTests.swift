import Testing
@testable import LiveConnectionsMonitorCore

@Test func timeCapsuleParsesWiFiWithoutInventingDisconnectedNetwork() {
    let service = NetworkTimeCapsuleService()
    #expect(service.parseWiFi("Current Wi-Fi Network: StudioLAN\n") == "StudioLAN")
    #expect(service.parseWiFi("You are not associated with an AirPort network.\n") == nil)
}
