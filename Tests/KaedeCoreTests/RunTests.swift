import Testing
@testable import KaedeCore

@Suite struct RunTests {
    @Test func ebiReadsTatoebaStrokes() {
        var run = Run()
        for position: KeyPosition in [.j, .a, .j, .s, .d, .slash, .a] {
            run.append(.stroke(position, shift: false))
        }
        #expect(run.reading(in: .ebi) == "tatoeba")
    }

    @Test func literalsReadAsThemselvesInEveryLayout() {
        var run = Run()
        run.append(.stroke(.a, shift: false))
        run.append(.literal(" "))
        run.append(.literal("7"))
        run.append(.literal("-"))
        run.append(.stroke(.s, shift: false))
        #expect(run.reading(in: .qwerty) == "a 7-s")
        #expect(run.reading(in: .ebi) == "a 7-o")
    }

    @Test func backspaceRemovesTheLastElement() {
        var run = Run()
        run.append(.stroke(.a, shift: false))
        run.append(.literal(" "))
        run.removeLast()
        #expect(run.elements == [.stroke(.a, shift: false)])
    }

    @Test func backspaceOnAnEmptyRunKeepsItEmpty() {
        var run = Run()
        run.removeLast()
        #expect(run.elements.isEmpty)
    }

    @Test func screenTextIsTheQwertyReading() {
        var run = Run()
        run.append(.stroke(.j, shift: true))
        run.append(.stroke(.a, shift: false))
        run.append(.literal(" "))
        run.append(.stroke(.slash, shift: false))
        #expect(run.screenText == "Ja /")
    }

    @Test func strokeCountExcludesLiterals() {
        var run = Run()
        run.append(.stroke(.a, shift: false))
        run.append(.literal(" "))
        run.append(.stroke(.s, shift: true))
        run.append(.literal("1"))
        #expect(run.strokeCount == 2)
    }

    @Test(arguments: [
        ("iflsgjdhfkf;a", "risoutekiniha"),
        ("hskkkahakk.fmd", "konnnakannjide"),
        (";afidjgjs", "hairetuto"),
        ("kf;skknsna,azajjd,shfjfkkjs;dkkhakk", "nihonngogamazattemokitinntohennkann"),
    ])
    func ebiReadsTheExampleSentenceChunks(typed: String, reading: String) {
        #expect(Run(typing: typed).reading(in: .ebi) == reading)
        #expect(RomajiParser.isRomaji(reading))
    }
}
