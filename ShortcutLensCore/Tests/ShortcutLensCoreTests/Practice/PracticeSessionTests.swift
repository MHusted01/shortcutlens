import ShortcutLensCore
import Testing

struct PracticeSessionTests {
    /// kVK_ANSI_S and kVK_ANSI_C.
    private let sKey = 1
    private let cKey = 8

    private let save = PracticeCard(menuPath: ["File", "Save"], combo: KeyCombo(key: "S", modifiers: []), keys: "⌘S")
    private let copy = PracticeCard(menuPath: ["Edit", "Copy"], combo: KeyCombo(key: "C", modifiers: []), keys: "⌘C")

    private var session: PracticeSession {
        PracticeSession(questions: [save, copy])
    }

    private var pressS: PracticePress {
        PracticePress(keyCode: sKey, character: "s", shiftedCharacter: "S", modifiers: [])
    }

    private var pressC: PracticePress {
        PracticePress(keyCode: cKey, character: "c", shiftedCharacter: "C", modifiers: [])
    }

    @Test func startsAskingTheFirstQuestion() {
        #expect(session.phase == .asking)
        #expect(session.current == save)
        #expect(session.position == 1)
        #expect(session.count == 2)
        #expect(session.correctCount == 0)
        #expect(session.outcome == nil)
    }

    @Test func aRightAnswerScores() {
        let answered = session.answering(pressS)

        #expect(answered.phase == .correct)
        #expect(answered.outcome == true)
        #expect(answered.correctCount == 1)
    }

    @Test func aWrongAnswerShowsWhatWasPressed() {
        let answered = session.answering(pressC)

        #expect(answered.phase == .wrong(pressed: "⌘C"))
        #expect(answered.outcome == false)
        #expect(answered.correctCount == 0)
    }

    @Test func revealingCountsAsWrong() {
        let revealed = session.revealing()

        #expect(revealed.phase == .revealed)
        #expect(revealed.outcome == false)
        #expect(revealed.correctCount == 0)
    }

    @Test func onlyTheFirstAnswerCounts() {
        let wrong = session.answering(pressC)

        #expect(wrong.answering(pressS) == wrong)
        #expect(wrong.revealing() == wrong)
        #expect(session.answering(pressS).revealing().correctCount == 1)
    }

    @Test func advancingMovesToTheNextQuestion() {
        let next = session.answering(pressS).advancing()

        #expect(next.phase == .asking)
        #expect(next.current == copy)
        #expect(next.position == 2)
        #expect(next.correctCount == 1)
    }

    @Test func advancingWaitsForAnAnswer() {
        #expect(session.advancing() == session)
    }

    @Test func finishesAfterTheLastQuestion() {
        let finished = session.answering(pressS).advancing().answering(pressC).advancing()

        #expect(finished.phase == .finished)
        #expect(finished.current == nil)
        #expect(finished.correctCount == 2)
        #expect(finished.position == 2)
        #expect(finished.advancing() == finished)
        #expect(finished.answering(pressS) == finished)
    }

    @Test func anEmptySessionIsFinished() {
        let empty = PracticeSession(questions: [])

        #expect(empty.phase == .finished)
        #expect(empty.current == nil)
        #expect(empty.position == 0)
    }
}
