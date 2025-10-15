import Foundation

struct Token {
    enum Kind {
        case number(Double)
        case identifier(String)
        case plus
        case minus
        case multiply
        case divide
        case power
        case leftParen
        case rightParen
        case equals
        case comma
    }

    let kind: Kind
}

struct ParserError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

final class MathExpressionParser {
    private var tokens: [Token] = []
    private var currentIndex: Int = 0

    func parseEquation(from input: String) throws -> (ExpressionNode, ExpressionNode) {
        tokens = tokenize(input: input)
        currentIndex = 0
        let lhs = try parseExpression()
        guard match(.equals) else {
            throw ParserError(message: "Equation must contain '=' symbol.")
        }
        let rhs = try parseExpression()
        if currentIndex < tokens.count {
            throw ParserError(message: "Unexpected token after equation: \(tokens[currentIndex]).")
        }
        return (lhs, rhs)
    }

    func parseExpression(from input: String) throws -> ExpressionNode {
        tokens = tokenize(input: input)
        currentIndex = 0
        let expression = try parseExpression()
        if currentIndex < tokens.count {
            throw ParserError(message: "Unexpected token at end of expression.")
        }
        return expression
    }

    private func tokenize(input: String) -> [Token] {
        var tokens: [Token] = []
        var index = input.startIndex
        while index < input.endIndex {
            let character = input[index]
            if character.isWhitespace {
                index = input.index(after: index)
                continue
            }

            switch character {
            case "+":
                tokens.append(Token(kind: .plus))
                index = input.index(after: index)
            case "-":
                tokens.append(Token(kind: .minus))
                index = input.index(after: index)
            case "*":
                tokens.append(Token(kind: .multiply))
                index = input.index(after: index)
            case "/":
                tokens.append(Token(kind: .divide))
                index = input.index(after: index)
            case "^":
                tokens.append(Token(kind: .power))
                index = input.index(after: index)
            case "(":
                tokens.append(Token(kind: .leftParen))
                index = input.index(after: index)
            case ")":
                tokens.append(Token(kind: .rightParen))
                index = input.index(after: index)
            case "=":
                tokens.append(Token(kind: .equals))
                index = input.index(after: index)
            case ",":
                tokens.append(Token(kind: .comma))
                index = input.index(after: index)
            default:
                if character.isNumber || character == "." {
                    var end = index
                    while end < input.endIndex && (input[end].isNumber || input[end] == ".") {
                        end = input.index(after: end)
                    }
                    let numberString = String(input[index..<end])
                    if let value = Double(numberString) {
                        tokens.append(Token(kind: .number(value)))
                    }
                    index = end
                } else if character.isLetter {
                    var end = index
                    while end < input.endIndex && (input[end].isLetter || input[end].isNumber) {
                        end = input.index(after: end)
                    }
                    let identifier = String(input[index..<end])
                    tokens.append(Token(kind: .identifier(identifier)))
                    index = end
                } else {
                    index = input.index(after: index)
                }
            }
        }
        return tokens
    }

    private func parseExpression() throws -> ExpressionNode {
        return try parseAddition()
    }

    private func parseAddition() throws -> ExpressionNode {
        var expression = try parseMultiplication()
        while true {
            if match(.plus) {
                let rhs = try parseMultiplication()
                expression = .binary(.add, expression, rhs)
            } else if match(.minus) {
                let rhs = try parseMultiplication()
                expression = .binary(.subtract, expression, rhs)
            } else {
                break
            }
        }
        return expression
    }

    private func parseMultiplication() throws -> ExpressionNode {
        var expression = try parsePower()
        while true {
            if match(.multiply) {
                let rhs = try parsePower()
                expression = .binary(.multiply, expression, rhs)
            } else if match(.divide) {
                let rhs = try parsePower()
                expression = .binary(.divide, expression, rhs)
            } else {
                break
            }
        }
        return expression
    }

    private func parsePower() throws -> ExpressionNode {
        var expression = try parseUnary()
        while match(.power) {
            let rhs = try parseUnary()
            expression = .binary(.power, expression, rhs)
        }
        return expression
    }

    private func parseUnary() throws -> ExpressionNode {
        if match(.plus) {
            return .unary(.plus, try parseUnary())
        } else if match(.minus) {
            return .unary(.minus, try parseUnary())
        }
        return try parsePrimary()
    }

    private func parsePrimary() throws -> ExpressionNode {
        guard currentIndex < tokens.count else {
            throw ParserError(message: "Unexpected end of input.")
        }
        let token = tokens[currentIndex]
        currentIndex += 1
        switch token.kind {
        case .number(let value):
            return .number(value)
        case .identifier(let name):
            if match(.leftParen) {
                var arguments: [ExpressionNode] = []
                if !match(.rightParen) {
                    repeat {
                        let argument = try parseExpression()
                        arguments.append(argument)
                    } while match(.comma)
                    guard match(.rightParen) else {
                        throw ParserError(message: "Unclosed parenthesis in function call.")
                    }
                }
                return .function(name, arguments)
            }
            return .variable(name)
        case .leftParen:
            let expression = try parseExpression()
            guard match(.rightParen) else {
                throw ParserError(message: "Missing closing parenthesis.")
            }
            return expression
        default:
            throw ParserError(message: "Unexpected token encountered.")
        }
    }

    @discardableResult
    private func match(_ kind: Token.Kind) -> Bool {
        guard currentIndex < tokens.count else { return false }
        let token = tokens[currentIndex]
        switch (token.kind, kind) {
        case (.plus, .plus), (.minus, .minus), (.multiply, .multiply), (.divide, .divide), (.power, .power), (.leftParen, .leftParen), (.rightParen, .rightParen), (.equals, .equals), (.comma, .comma):
            currentIndex += 1
            return true
        case (.number, .number), (.identifier, .identifier):
            return false
        default:
            return false
        }
    }
}
