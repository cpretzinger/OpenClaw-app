//
//  TokenService.swift
//  OpenClaw
//
//  Fetches conversation tokens from ElevenLabs for private agent authentication
//

import Foundation

enum TokenServiceError: Error, LocalizedError {
    case invalidURL
    case apiError(statusCode: Int)
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .apiError(let statusCode):
            return "API error: HTTP \(statusCode)"
        case .decodingError:
            return "Failed to decode token response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

private struct TokenResponse: Codable, Sendable {
    nonisolated(unsafe) let token: String
}

actor TokenService {
    static let shared = TokenService()
    
    // Use the token endpoint for private agents (returns JWT for LiveKit)
    private let baseURL = "https://api.elevenlabs.io/v1/convai/conversation/token"
    
    private init() {}
    
    func fetchToken(agentId: String, apiKey: String) async throws -> String {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw TokenServiceError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "agent_id", value: agentId)
        ]
        
        guard let url = urlComponents.url else {
            throw TokenServiceError.invalidURL
        }
        
        print("[OpenClaw] ========== TOKEN REQUEST ==========")
        print("[OpenClaw] URL: \(url)")
        print("[OpenClaw] Agent ID: \(agentId)")
        print("[OpenClaw] API Key prefix: \(apiKey.prefix(8))...")
        print("[OpenClaw] API Key length: \(apiKey.count)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TokenServiceError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TokenServiceError.apiError(statusCode: 0)
        }
        
        print("[OpenClaw] Token API response: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("[OpenClaw] Token API error body: \(errorBody)")
            }
            throw TokenServiceError.apiError(statusCode: httpResponse.statusCode)
        }
        
        return try Self.parseToken(from: data)
    }
    
    private nonisolated static func parseToken(from data: Data) throws -> String {
        do {
            let response = try JSONDecoder().decode(TokenResponse.self, from: data)
            print("[OpenClaw] Got token successfully")
            return response.token
        } catch {
            print("[OpenClaw] Failed to decode: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw TokenServiceError.decodingError
        }
    }
}
