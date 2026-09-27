import Testing
@testable import KaedeCore

@Suite struct QueryHealthTests {
    @Test func beepsWhenFailuresStartOnly() {
        var health = QueryHealth()
        var beeps: [Bool] = []
        beeps.append(health.failed())
        beeps.append(health.failed())
        health.succeeded()
        beeps.append(health.failed())
        beeps.append(health.failed())
        #expect(beeps == [true, false, true, false])
    }
}
