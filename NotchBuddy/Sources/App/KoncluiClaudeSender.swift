import Foundation

// Koncluí: sends one Claude call and says what came back (unit U3a). It knows no Keychain, no setting and no screen: the
// route (with its credential) comes in, a text or the reason it failed goes out, and the credential never leaves this
// function (not in the failure, not in a log). KoncluiClaudeAccess.swift builds the request; the live side picks the route.
enum KoncluiClaudeSender {
    enum Outcome: Equatable, Sendable {
        case text(String)
        case failed(KoncluiClaudeAccess.Failure)
        /// The task was cancelled: nobody is waiting, nobody needs telling.
        case cancelled
    }

    /// Calls each model in turn until one answers. A refused key, the plan's limit, a lost connection or a timeout stop
    /// the loop: another model would fail the same way and dictation would wait twice as long.
    static func send(_ call: KoncluiClaudeAccess.Call, models: [String], route: KoncluiClaudeAccess.Route,
                     session: URLSession = .shared) async -> Outcome {
        var last = Outcome.failed(.noSource)
        for model in models {
            var attempt = call
            attempt.model = model
            let outcome = await send(attempt, route: route, session: session)
            guard case .failed(let failure) = outcome, tryNextModel(after: failure) else { return outcome }
            last = outcome
        }
        return last
    }

    static func send(_ call: KoncluiClaudeAccess.Call, route: KoncluiClaudeAccess.Route,
                     session: URLSession = .shared) async -> Outcome {
        guard let request = KoncluiClaudeAccess.request(call, route: route) else { return .failed(.noSource) }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed(.offline) }
            guard http.statusCode == 200 else { return .failed(KoncluiClaudeAccess.failure(status: http.statusCode)) }
            guard let text = KoncluiClaudeAccess.text(from: data) else { return .failed(.unusable) }
            return .text(text)
        } catch let error as URLError {
            if error.code == .cancelled { return .cancelled }
            return .failed(KoncluiClaudeAccess.failure(urlError: error.code))
        } catch {
            return Task.isCancelled ? .cancelled : .failed(.offline)
        }
    }

    /// Only a failure that may be about the model is tried again with the next one.
    static func tryNextModel(after failure: KoncluiClaudeAccess.Failure) -> Bool {
        switch failure {
        case .rejected, .busy, .unusable: return true
        default: return false
        }
    }
}
