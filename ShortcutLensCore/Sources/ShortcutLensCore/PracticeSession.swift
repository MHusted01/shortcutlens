/// One practice round: asks each question in turn and counts right answers.
///
/// Each question takes one answer: pressed keys or "Show Answer", which
/// counts as wrong. After that, `advancing()` moves on.
public struct PracticeSession: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case asking
        case correct
        /// `pressed` is the label of the keys pressed, if they have one.
        case wrong(pressed: String?)
        case revealed
        case finished
    }

    public let questions: [PracticeCard]
    public let phase: Phase
    public let correctCount: Int
    private let index: Int

    /// A session without questions is finished from the start.
    public init(questions: [PracticeCard]) {
        self.init(questions: questions, index: 0, phase: questions.isEmpty ? .finished : .asking, correctCount: 0)
    }

    private init(questions: [PracticeCard], index: Int, phase: Phase, correctCount: Int) {
        self.questions = questions
        self.index = index
        self.phase = phase
        self.correctCount = correctCount
    }

    public var count: Int {
        questions.count
    }

    /// The question shown, counting from 1; the last one once finished.
    public var position: Int {
        min(index + 1, count)
    }

    /// The question shown, or nil once finished.
    public var current: PracticeCard? {
        phase == .finished ? nil : questions[index]
    }

    /// Whether the current question was answered right; nil before an answer.
    public var outcome: Bool? {
        switch phase {
        case .correct:
            true
        case .wrong, .revealed:
            false
        case .asking, .finished:
            nil
        }
    }

    public func answering(_ press: PracticePress) -> Self {
        guard phase == .asking, let current else {
            return self
        }
        return press.matches(current.combo)
            ? copy(phase: .correct, correctCount: correctCount + 1)
            : copy(phase: .wrong(pressed: press.label))
    }

    public func revealing() -> Self {
        phase == .asking ? copy(phase: .revealed) : self
    }

    /// The next question, or the finished session after the last one.
    public func advancing() -> Self {
        guard outcome != nil else {
            return self
        }
        return index + 1 < count ? copy(index: index + 1, phase: .asking) : copy(phase: .finished)
    }

    private func copy(index: Int? = nil, phase: Phase, correctCount: Int? = nil) -> Self {
        Self(
            questions: questions, index: index ?? self.index, phase: phase,
            correctCount: correctCount ?? self.correctCount
        )
    }
}
