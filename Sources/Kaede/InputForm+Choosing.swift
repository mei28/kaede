import AppKit
import KaedeCore

/// Choosing conversions in the form with Tab, with the keys of an input method: ← → move between
/// phrases and English, Shift+← → move a phrase's border, ↑ ↓ and Space step through candidates,
/// 1–9 pick one and go on, Return or Tab keep what was chosen, Escape or Backspace cancel it.
extension InputForm {
    /// Tab: selects the first unit of the caret's line, once the preview has caught up.
    func beginChoosing() {
        isBeginningToChoose = true
        step {
            let converted = await self.currentConversion()
            // A key that ended choosing before it began leaves the form writing
            guard self.isBeginningToChoose, let converted else {
                self.isBeginningToChoose = false
                return
            }
            self.isBeginningToChoose = false
            guard let selection = ConversionSelection(units: converted.units, line: self.caretLine(), choices: self.choices) else {
                // Nothing on the form converts
                NSSound.beep()
                return
            }
            self.selection = selection
            await self.showCandidates()
        }
    }

    /// The keys of choosing; any other key ends it, keeping the choices, and goes to the text.
    func takeChoosingKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.subtracting(.shift).isEmpty else {
            endChoosing()
            return false
        }
        let shift = modifiers.contains(.shift)
        switch event.keyCode {
        case 123: step { shift ? await self.resize(by: -1) : await self.move(by: -1) }
        case 124: step { shift ? await self.resize(by: 1) : await self.move(by: 1) }
        case 125: step { await self.stepCandidate(by: 1) }
        case 126: step { await self.stepCandidate(by: -1) }
        case 49: step { await self.stepCandidate(by: shift ? -1 : 1) }
        // Return, Enter, Tab
        case 36, 76, 48: step { self.endChoosing() }
        // Escape, Backspace: a key that would delete text cancels instead
        case 53, 51: step { self.cancelChoosing() }
        default:
            guard let number = event.charactersIgnoringModifiers.flatMap(Int.init), (1...9).contains(number), !shift else {
                endChoosing()
                return false
            }
            step { await self.pickCandidate(number: number) }
        }
        return true
    }

    /// Keeps the choices and goes back to writing.
    func endChoosing() {
        isBeginningToChoose = false
        selection = nil
        publishSelection()
    }

    /// Takes the selection to the units of a new conversion; ends choosing when its unit is gone.
    func followSelection(to units: [ConversionUnit]) {
        guard selection != nil else { return }
        if selection?.update(units: units) == false {
            endChoosing()
        }
        publishSelection()
    }

    /// Runs after the steps before it, so keys typed quickly act in their order.
    private func step(_ work: @escaping @MainActor () async -> Void) {
        let previous = choosingStep
        choosingStep = Task {
            await previous?.value
            await work()
        }
    }

    private func cancelChoosing() {
        guard let selection else { return }
        choices = selection.choicesAtStart
        endChoosing()
        convertForPreview()
    }

    private func move(by delta: Int) async {
        guard selection?.move(by: delta) == true else { return }
        await showCandidates()
    }

    private func stepCandidate(by delta: Int) async {
        guard let text = selection?.stepCandidate(by: delta) else { return }
        await choose(text)
    }

    /// Chooses the numbered candidate and goes on to the next unit, or ends after the last.
    private func pickCandidate(number: Int) async {
        guard let text = selection?.pickCandidate(number: number) else {
            NSSound.beep()
            return
        }
        await choose(text)
        if selection?.move(by: 1) == true {
            await showCandidates()
        } else {
            endChoosing()
        }
    }

    private func choose(_ text: String) async {
        guard let selection else { return }
        choices = selection.choices(choices, choosing: text)
        publishSelection()
        _ = await currentConversion()
    }

    /// Moves the border after the selected phrase and converts the two phrases it changes.
    private func resize(by delta: Int) async {
        guard let selection, let phrases = selection.clausePhrases,
              case let .bunsetsu(clause, index) = selection.selectedUnit.kind
        else { return }
        let resized: [Bunsetsu]
        do {
            resized = try await worker.resized(phrases, at: index, by: delta)
        } catch {
            fail("Resizing a phrase failed: \(error)")
            return
        }
        guard resized != phrases else { return }
        choices.clauses[clause] = resized
        _ = await currentConversion()
        await showCandidates()
    }

    private func showCandidates() async {
        guard let unit = selection?.selectedUnit else { return }
        do {
            let candidates = try await worker.candidates(for: unit)
            // Still the same unit: steps run one at a time
            selection?.show(candidates: candidates)
        } catch {
            fail("Listing candidates failed: \(error)")
        }
        publishSelection()
    }

    private func publishSelection() {
        model.isChoosing = selection != nil
        model.unitRanges = selection?.units.map(\.range) ?? []
        model.selectedRange = selection?.selectedUnit.range
        model.candidates = selection?.candidates ?? []
        model.candidateIndex = selection?.candidateIndex
    }

    /// The line of the text the caret is on, from 0, counting line breaks as the converter does.
    private func caretLine() -> Int {
        let caret = textView.selectedRange().location
        let before = (textView.string as NSString).substring(to: caret)
        return before.count(where: \.isNewline)
    }
}
