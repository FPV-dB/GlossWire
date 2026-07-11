import Testing
@testable import LiveConnectionsMonitorCore

@Test func internetWeatherParsesMacOSProbeOutput() {
    let ping = """
    3 packets transmitted, 3 packets received, 0.0% packet loss
    round-trip min/avg/max/stddev = 8.100/12.500/18.000/4.000 ms
    """
    let dig = ";; Query time: 17 msec\n"
    let route = "   route to: default\n    gateway: 192.168.1.1\n"
    #expect(InternetWeatherService.averageLatency(ping) == 12.5)
    #expect(InternetWeatherService.packetLoss(ping) == 0)
    #expect(InternetWeatherService.dnsTime(dig) == 17)
    #expect(InternetWeatherService.gateway(route) == "192.168.1.1")
}
