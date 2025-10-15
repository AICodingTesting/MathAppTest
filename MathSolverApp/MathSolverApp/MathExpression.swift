import Foundation

enum ExpressionError: LocalizedError {
    case divisionByZero
    case undefined(String)

    var errorDescription: String? {
        switch self {
        case .divisionByZero:
            return "Division by zero is undefined."
        case .undefined(let message):
            return message
        }
    }
}

enum BinaryOperator: String {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
    case power = "^"
}

enum UnaryOperator {
    case plus
    case minus
}

indirect enum ExpressionNode: Equatable {
    case number(Double)
    case variable(String)
    case binary(BinaryOperator, ExpressionNode, ExpressionNode)
    case unary(UnaryOperator, ExpressionNode)
    case function(String, [ExpressionNode])

    func evaluate(variables: [String: Double]) throws -> Double {
        switch self {
        case .number(let value):
            return value
        case .variable(let name):
            guard let value = variables[name] else {
                throw ExpressionError.undefined("Missing value for variable \(name).")
            }
            return value
        case .binary(let op, let lhs, let rhs):
            let left = try lhs.evaluate(variables: variables)
            let right = try rhs.evaluate(variables: variables)
            switch op {
            case .add: return left + right
            case .subtract: return left - right
            case .multiply: return left * right
            case .divide:
                if right == 0 { throw ExpressionError.divisionByZero }
                return left / right
            case .power:
                return pow(left, right)
            }
        case .unary(let op, let value):
            let evaluated = try value.evaluate(variables: variables)
            switch op {
            case .plus: return evaluated
            case .minus: return -evaluated
            }
        case .function(let name, let arguments):
            let values = try arguments.map { try $0.evaluate(variables: variables) }
            return try Self.evaluate(function: name, arguments: values)
        }
    }

    private static func evaluate(function name: String, arguments: [Double]) throws -> Double {
        switch name.lowercased() {
        case "sin": return sin(arguments[0])
        case "cos": return cos(arguments[0])
        case "tan": return tan(arguments[0])
        case "log": return log10(arguments[0])
        case "ln": return log(arguments[0])
        case "sqrt": return sqrt(arguments[0])
        case "exp": return exp(arguments[0])
        default:
            throw ExpressionError.undefined("Function \(name) is not supported.")
        }
    }

    func derivative(variable: String) -> ExpressionNode {
        switch self {
        case .number:
            return .number(0)
        case .variable(let name):
            return .number(name == variable ? 1 : 0)
        case .unary(let op, let value):
            let dv = value.derivative(variable: variable)
            switch op {
            case .plus: return dv
            case .minus: return .unary(.minus, dv)
            }
        case .binary(let op, let lhs, let rhs):
            switch op {
            case .add:
                return .binary(.add, lhs.derivative(variable: variable), rhs.derivative(variable: variable))
            case .subtract:
                return .binary(.subtract, lhs.derivative(variable: variable), rhs.derivative(variable: variable))
            case .multiply:
                let uPrime = lhs.derivative(variable: variable)
                let vPrime = rhs.derivative(variable: variable)
                let term1 = .binary(.multiply, uPrime, rhs)
                let term2 = .binary(.multiply, lhs, vPrime)
                return .binary(.add, term1, term2)
            case .divide:
                let uPrime = lhs.derivative(variable: variable)
                let vPrime = rhs.derivative(variable: variable)
                let numerator = .binary(
                    .subtract,
                    .binary(.multiply, uPrime, rhs),
                    .binary(.multiply, lhs, vPrime)
                )
                let denominator = .binary(.power, rhs, .number(2))
                return .binary(.divide, numerator, denominator)
            case .power:
                if case .number(let exponent) = rhs {
                    let newExponent = ExpressionNode.number(exponent - 1)
                    let baseDerivative = lhs.derivative(variable: variable)
                    return .binary(
                        .multiply,
                        .binary(.multiply, .number(exponent), .binary(.power, lhs, newExponent)),
                        baseDerivative
                    )
                } else {
                    // General case using logarithmic differentiation
                    let fPrime = lhs.derivative(variable: variable)
                    let gPrime = rhs.derivative(variable: variable)
                    let term1 = .binary(.multiply, rhs, .binary(.divide, fPrime, lhs))
                    let term2 = .binary(.multiply, gPrime, .function("ln", [lhs]))
                    let sum = .binary(.add, term1, term2)
                    return .binary(.multiply, self, sum)
                }
            }
        case .function(let name, let arguments):
            let argument = arguments[0]
            let derivativeArgument = argument.derivative(variable: variable)
            switch name.lowercased() {
            case "sin":
                return .binary(.multiply, .function("cos", [argument]), derivativeArgument)
            case "cos":
                return .binary(.multiply, .unary(.minus, .function("sin", [argument])), derivativeArgument)
            case "tan":
                let cosine = ExpressionNode.function("cos", [argument])
                let denominator = ExpressionNode.binary(.power, cosine, .number(2))
                return .binary(.multiply, .binary(.divide, .number(1), denominator), derivativeArgument)
            case "exp":
                return .binary(.multiply, self, derivativeArgument)
            case "ln":
                return .binary(.multiply, .binary(.divide, .number(1), argument), derivativeArgument)
            case "sqrt":
                let denom = .binary(.multiply, .number(2), .function("sqrt", [argument]))
                return .binary(.multiply, .binary(.divide, .number(1), denom), derivativeArgument)
            default:
                return .number(0)
            }
        }
    }

    func simplified() -> ExpressionNode {
        switch self {
        case .binary(let op, let lhs, let rhs):
            let left = lhs.simplified()
            let right = rhs.simplified()
            if case .number(let l) = left, case .number(let r) = right {
                switch op {
                case .add: return .number(l + r)
                case .subtract: return .number(l - r)
                case .multiply: return .number(l * r)
                case .divide: return .number(r == 0 ? Double.nan : l / r)
                case .power: return .number(pow(l, r))
                }
            }
            return .binary(op, left, right)
        case .unary(let op, let value):
            let simplifiedValue = value.simplified()
            if case .number(let number) = simplifiedValue {
                switch op {
                case .plus: return .number(number)
                case .minus: return .number(-number)
                }
            }
            return .unary(op, simplifiedValue)
        case .function(let name, let arguments):
            let simplifiedArgs = arguments.map { $0.simplified() }
            if simplifiedArgs.count == 1, case .number(let number) = simplifiedArgs[0] {
                if let value = try? Self.evaluate(function: name, arguments: [number]) {
                    return .number(value)
                }
            }
            return .function(name, simplifiedArgs)
        default:
            return self
        }
    }

    func toString() -> String {
        switch self {
        case .number(let value):
            if abs(value.rounded() - value) < 1e-10 {
                return String(format: "%.0f", value.rounded())
            }
            return String(value)
        case .variable(let name):
            return name
        case .binary(let op, let lhs, let rhs):
            let left = lhs.toString()
            let right = rhs.toString()
            switch op {
            case .add: return "\(left) + \(right)"
            case .subtract: return "\(left) - \(right)"
            case .multiply:
                if rhs.isNegativeNumber {
                    return "\(left) * (\(right))"
                }
                return "\(left) * \(right)"
            case .divide:
                return "(\(left)) / (\(right))"
            case .power:
                return "(\(left))^(\(right))"
            }
        case .unary(let op, let value):
            switch op {
            case .plus: return "+\(value.toString())"
            case .minus: return "-\(value.toString())"
            }
        case .function(let name, let arguments):
            let argsString = arguments.map { $0.toString() }.joined(separator: ", ")
            return "\(name)(\(argsString))"
        }
    }

    private var isNegativeNumber: Bool {
        if case .number(let value) = self {
            return value < 0
        }
        return false
    }
}

extension ExpressionNode {
    func integrates(variable: String) -> ExpressionNode? {
        switch self {
        case .number(let value):
            return .binary(.multiply, .number(value), .variable(variable))
        case .variable(let name) where name == variable:
            return .binary(.divide, .binary(.power, .variable(variable), .number(2)), .number(2))
        case .binary(let op, let lhs, let rhs):
            switch op {
            case .add:
                guard let left = lhs.integrates(variable: variable), let right = rhs.integrates(variable: variable) else { return nil }
                return .binary(.add, left, right)
            case .subtract:
                guard let left = lhs.integrates(variable: variable), let right = rhs.integrates(variable: variable) else { return nil }
                return .binary(.subtract, left, right)
            case .multiply:
                if case .number(let constant) = lhs {
                    return rhs.integrates(variable: variable).map { .binary(.multiply, .number(constant), $0) }
                } else if case .number(let constant) = rhs {
                    return lhs.integrates(variable: variable).map { .binary(.multiply, .number(constant), $0) }
                }
                return nil
            case .divide:
                if case .number(let constant) = rhs {
                    return lhs.integrates(variable: variable).map { .binary(.divide, $0, .number(constant)) }
                }
                return nil
            case .power:
                if case .variable(let name) = lhs, name == variable, case .number(let exponent) = rhs, exponent != -1 {
                    let newExponent = exponent + 1
                    let numerator = .binary(.power, .variable(variable), .number(newExponent))
                    return .binary(.divide, numerator, .number(newExponent))
                }
                return nil
            }
        case .function(let name, let arguments):
            let lower = name.lowercased()
            let argument = arguments[0]
            if case .variable(let varName) = argument, varName == variable {
                switch lower {
                case "sin":
                    return .unary(.minus, .function("cos", [argument]))
                case "cos":
                    return .function("sin", [argument])
                case "exp":
                    return .function("exp", [argument])
                case "tan":
                    return .unary(.minus, .function("ln", [.function("cos", [argument])]))
                default:
                    return nil
                }
            }
            return nil
        default:
            return nil
        }
    }
}
