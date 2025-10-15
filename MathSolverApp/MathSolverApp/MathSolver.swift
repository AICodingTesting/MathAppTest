import Foundation

struct SolutionStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

enum MathProblemType: String {
    case expression
    case equation
    case derivative
    case integral
    case differentialEquation
}

struct SolutionResult {
    let finalAnswer: String
    let steps: [SolutionStep]
    let problemType: MathProblemType
}

enum MathSolverError: LocalizedError {
    case unsupportedProblem
    case parsingFailed(String)
    case solvingFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedProblem:
            return "The provided math expression is not supported yet."
        case .parsingFailed(let message):
            return message
        case .solvingFailed(let message):
            return message
        }
    }
}

final class MathSolver {
    private let parser = MathExpressionParser()

    func solve(input: String) async throws -> SolutionResult {
        let trimmed = input.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        let type = detectProblemType(from: trimmed)
        switch type {
        case .derivative:
            return try solveDerivative(trimmed)
        case .integral:
            return try solveIntegral(trimmed)
        case .differentialEquation:
            return try solveDifferentialEquation(trimmed)
        case .equation:
            return try solveEquation(trimmed)
        case .expression:
            return try solveExpression(trimmed)
        }
    }

    private func detectProblemType(from input: String) -> MathProblemType {
        let lowercase = input.lowercased()
        if lowercase.contains("d/d") {
            return .derivative
        }
        if lowercase.contains("∫") || lowercase.contains("integral") || lowercase.contains("integrate") {
            return .integral
        }
        if lowercase.contains("dy/d") || lowercase.contains("y'") {
            return .differentialEquation
        }
        if input.contains("=") {
            return .equation
        }
        return .expression
    }

    private func solveExpression(_ input: String) throws -> SolutionResult {
        do {
            let node = try parser.parseExpression(from: input)
            let variables = node.collectVariables()
            let simplified = node.simplified()
            if variables.isEmpty {
                let value = try simplified.evaluate(variables: [:])
                let final = format(value: value)
                let steps = [
                    SolutionStep(title: "Simplify", description: "Simplified the expression to \(simplified.toString())."),
                    SolutionStep(title: "Evaluate", description: "Evaluated the simplified expression to get \(final).")
                ]
                return SolutionResult(finalAnswer: final, steps: steps, problemType: .expression)
            } else {
                let steps = [
                    SolutionStep(title: "Simplify", description: "Simplified symbolic form: \(simplified.toString()).")
                ]
                return SolutionResult(finalAnswer: simplified.toString(), steps: steps, problemType: .expression)
            }
        } catch {
            throw MathSolverError.parsingFailed(error.localizedDescription)
        }
    }

    private func solveDerivative(_ input: String) throws -> SolutionResult {
        guard let derivativeRange = input.range(of: "d/d") else {
            throw MathSolverError.parsingFailed("Could not find derivative operator.")
        }
        let after = input[derivativeRange.upperBound...]
        guard let variableChar = after.first(where: { $0.isLetter }) else {
            throw MathSolverError.parsingFailed("Could not determine derivative variable.")
        }
        let variable = String(variableChar)
        guard let variableIndex = after.firstIndex(of: Character(variable)) else {
            throw MathSolverError.parsingFailed("Invalid derivative format.")
        }
        let expressionStart = after[after.index(after: variableIndex)...]
        var expressionString = String(expressionStart).trimmingCharacters(in: .whitespaces)
        if let equalsIndex = expressionString.firstIndex(of: "=") {
            expressionString = String(expressionString[..<equalsIndex])
        }
        if expressionString.hasPrefix("(") && expressionString.hasSuffix(")") {
            expressionString.removeFirst()
            expressionString.removeLast()
        }
        do {
            let expression = try parser.parseExpression(from: expressionString)
            let derivative = expression.derivative(variable: variable).simplified()
            let steps = [
                SolutionStep(title: "Differentiate", description: "Computed derivative of \(expression.toString()) with respect to \(variable)."),
                SolutionStep(title: "Simplify", description: "Simplified derivative: \(derivative.toString()).")
            ]
            return SolutionResult(finalAnswer: derivative.toString(), steps: steps, problemType: .derivative)
        } catch {
            throw MathSolverError.solvingFailed(error.localizedDescription)
        }
    }

    private func solveIntegral(_ input: String) throws -> SolutionResult {
        let sanitized = input.replacingOccurrences(of: "∫", with: "")
            .replacingOccurrences(of: "Integral", with: "", options: .caseInsensitive)
        guard let dIndex = sanitized.lowercased().lastIndex(of: "d") else {
            throw MathSolverError.parsingFailed("Integral must include differential like dx.")
        }
        let variableStart = sanitized.index(after: dIndex)
        let variableSegment = String(sanitized[variableStart...])
        let variable = variableSegment.trimmingCharacters(in: CharacterSet.letters.inverted)
        guard !variable.isEmpty else {
            throw MathSolverError.parsingFailed("Could not determine integral variable.")
        }
        let integrandSegment = String(sanitized[..<dIndex])
        let integrandString = integrandSegment.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let integrand = try parser.parseExpression(from: integrandString)
            if let antiderivative = integrand.integrates(variable: variable).map({ $0.simplified() }) {
                let finalExpression = antiderivative.toString() + " + C"
                let steps = [
                    SolutionStep(title: "Integrand", description: "Integrand: \(integrand.toString())."),
                    SolutionStep(title: "Antiderivative", description: "Computed antiderivative with respect to \(variable)."),
                    SolutionStep(title: "General Solution", description: "Result: \(finalExpression)")
                ]
                return SolutionResult(finalAnswer: finalExpression, steps: steps, problemType: .integral)
            } else {
                let final = "∫ \(integrand.toString()) d\(variable) + C"
                let steps = [
                    SolutionStep(title: "Integrand", description: "Integrand: \(integrand.toString())."),
                    SolutionStep(title: "Method", description: "No closed form available with current rules; expressing result as symbolic integral."),
                    SolutionStep(title: "General Solution", description: final)
                ]
                return SolutionResult(finalAnswer: final, steps: steps, problemType: .integral)
            }
        } catch {
            throw MathSolverError.solvingFailed(error.localizedDescription)
        }
    }

    private func solveDifferentialEquation(_ input: String) throws -> SolutionResult {
        let normalized = input.replacingOccurrences(of: " ", with: "")
        guard let equalIndex = normalized.firstIndex(of: "=") else {
            throw MathSolverError.parsingFailed("Differential equation must contain '='.")
        }
        let left = normalized[..<equalIndex]
        let right = normalized[normalized.index(after: equalIndex)...]
        let variable: String
        if left.contains("dy/d") {
            variable = String(left.suffix(1))
        } else if left.contains("y'") {
            variable = "x"
        } else {
            variable = "x"
        }
        let rhsString = String(right)
        do {
            let rhsExpression = try parser.parseExpression(from: rhsString)
            if let integral = rhsExpression.integrates(variable: variable)?.simplified() {
                let final = "y = \(integral.toString()) + C"
                let steps = [
                    SolutionStep(title: "Separate variables", description: "dy = \(rhsExpression.toString()) d\(variable)"),
                    SolutionStep(title: "Integrate", description: "∫ dy = ∫ \(rhsExpression.toString()) d\(variable)"),
                    SolutionStep(title: "General solution", description: final)
                ]
                return SolutionResult(finalAnswer: final, steps: steps, problemType: .differentialEquation)
            } else {
                let final = "y = ∫ \(rhsExpression.toString()) d\(variable) + C"
                let steps = [
                    SolutionStep(title: "Separate variables", description: "dy = \(rhsExpression.toString()) d\(variable)"),
                    SolutionStep(title: "Integrate", description: "Result expressed as symbolic integral."),
                    SolutionStep(title: "General solution", description: final)
                ]
                return SolutionResult(finalAnswer: final, steps: steps, problemType: .differentialEquation)
            }
        } catch {
            throw MathSolverError.solvingFailed("Failed to parse differential equation right-hand side.")
        }
    }

    private func solveEquation(_ input: String) throws -> SolutionResult {
        do {
            let (lhs, rhs) = try parser.parseEquation(from: input)
            let allVariables = lhs.collectVariables().union(rhs.collectVariables())
            let variable = allVariables.first ?? "x"
            if let linear = solveLinear(lhs: lhs, rhs: rhs, variable: variable) {
                return linear
            }
            return try solveNonLinear(lhs: lhs, rhs: rhs, variable: variable)
        } catch {
            throw MathSolverError.parsingFailed(error.localizedDescription)
        }
    }

    private func solveLinear(lhs: ExpressionNode, rhs: ExpressionNode, variable: String) -> SolutionResult? {
        guard let leftCoefficients = lhs.linearDecomposition(variable: variable),
              let rightCoefficients = rhs.linearDecomposition(variable: variable) else {
            return nil
        }
        let a = leftCoefficients.coefficient - rightCoefficients.coefficient
        let b = rightCoefficients.constant - leftCoefficients.constant
        guard abs(a) > 1e-10 else { return nil }
        let solution = b / a
        let final = "\(variable) = \(format(value: solution))"
        let moveStep = "(\(format(value: leftCoefficients.coefficient)) - \(format(value: rightCoefficients.coefficient)))\(variable) = \(format(value: rightCoefficients.constant)) - \(format(value: leftCoefficients.constant))"
        let simplifiedStep = "\(format(value: a))\(variable) = \(format(value: b))"
        let steps = [
            SolutionStep(title: "Collect like terms", description: moveStep),
            SolutionStep(title: "Simplify", description: simplifiedStep),
            SolutionStep(title: "Solve", description: "Divide both sides by \(format(value: a)) to isolate \(variable)."),
            SolutionStep(title: "Result", description: final)
        ]
        return SolutionResult(finalAnswer: final, steps: steps, problemType: .equation)
    }

    private func solveNonLinear(lhs: ExpressionNode, rhs: ExpressionNode, variable: String) throws -> SolutionResult {
        let difference = ExpressionNode.binary(.subtract, lhs, rhs)
        let derivative = difference.derivative(variable: variable)
        let guesses: [Double] = [-10, -5, 0, 5, 10]
        for guess in guesses {
            if let (root, iterationSteps) = attemptNewton(f: difference, derivative: derivative, variable: variable, initial: guess) {
                let final = "\(variable) ≈ \(format(value: root))"
                var steps = [SolutionStep(title: "Setup", description: "Solve \(lhs.toString()) = \(rhs.toString()) using Newton's method.")]
                steps.append(contentsOf: iterationSteps)
                steps.append(SolutionStep(title: "Result", description: final))
                return SolutionResult(finalAnswer: final, steps: steps, problemType: .equation)
            }
        }
        throw MathSolverError.solvingFailed("Could not find a numeric solution.")
    }

    private func attemptNewton(f: ExpressionNode, derivative: ExpressionNode, variable: String, initial: Double) -> (Double, [SolutionStep])? {
        var x = initial
        var steps: [SolutionStep] = []
        for iteration in 1...12 {
            guard let fx = try? f.evaluate(variables: [variable: x]) else { return nil }
            guard let fPrime = try? derivative.evaluate(variables: [variable: x]) else { return nil }
            if abs(fPrime) < 1e-8 { return nil }
            let next = x - fx / fPrime
            steps.append(SolutionStep(title: "Iteration \(iteration)", description: "x = \(format(value: x)), f(x) = \(format(value: fx)), f'(x) = \(format(value: fPrime))"))
            if abs(next - x) < 1e-8 {
                return (next, steps)
            }
            x = next
        }
        return nil
    }

    private func format(value: Double) -> String {
        if abs(value.rounded() - value) < 1e-8 {
            return String(format: "%.0f", value.rounded())
        }
        return String(format: "%.6f", value)
    }
}

private extension ExpressionNode {
    func collectVariables() -> Set<String> {
        var set: Set<String> = []
        collectVariables(into: &set)
        return set
    }

    func collectVariables(into set: inout Set<String>) {
        switch self {
        case .variable(let name):
            set.insert(name)
        case .binary(_, let lhs, let rhs):
            lhs.collectVariables(into: &set)
            rhs.collectVariables(into: &set)
        case .unary(_, let value):
            value.collectVariables(into: &set)
        case .function(_, let arguments):
            arguments.forEach { $0.collectVariables(into: &set) }
        case .number:
            break
        }
    }

    struct LinearComponents {
        let coefficient: Double
        let constant: Double
    }

    func linearDecomposition(variable: String) -> LinearComponents? {
        switch self {
        case .number(let value):
            return LinearComponents(coefficient: 0, constant: value)
        case .variable(let name):
            return LinearComponents(coefficient: name == variable ? 1 : 0, constant: 0)
        case .unary(let op, let value):
            guard let components = value.linearDecomposition(variable: variable) else { return nil }
            switch op {
            case .plus:
                return components
            case .minus:
                return LinearComponents(coefficient: -components.coefficient, constant: -components.constant)
            }
        case .binary(let op, let lhs, let rhs):
            switch op {
            case .add:
                if let l = lhs.linearDecomposition(variable: variable), let r = rhs.linearDecomposition(variable: variable) {
                    return LinearComponents(coefficient: l.coefficient + r.coefficient, constant: l.constant + r.constant)
                }
            case .subtract:
                if let l = lhs.linearDecomposition(variable: variable), let r = rhs.linearDecomposition(variable: variable) {
                    return LinearComponents(coefficient: l.coefficient - r.coefficient, constant: l.constant - r.constant)
                }
            case .multiply:
                if let l = lhs.linearDecomposition(variable: variable), case .number(let rightValue) = rhs {
                    return LinearComponents(coefficient: l.coefficient * rightValue, constant: l.constant * rightValue)
                }
                if let r = rhs.linearDecomposition(variable: variable), case .number(let leftValue) = lhs {
                    return LinearComponents(coefficient: r.coefficient * leftValue, constant: r.constant * leftValue)
                }
            case .divide:
                if let l = lhs.linearDecomposition(variable: variable), case .number(let divisor) = rhs, abs(divisor) > 1e-10 {
                    return LinearComponents(coefficient: l.coefficient / divisor, constant: l.constant / divisor)
                }
            case .power:
                break
            }
        case .function:
            break
        }
        if let constant = evaluateConstant() {
            return LinearComponents(coefficient: 0, constant: constant)
        }
        return nil
    }

    func evaluateConstant() -> Double? {
        do {
            return try evaluate(variables: [:])
        } catch {
            return nil
        }
    }
}
