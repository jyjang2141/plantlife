import UIKit

// MARK: - Result model

/// What the AI sends back about a photo. Every field except `isPlant` is optional
/// so a "that's not a plant" answer still decodes cleanly.
struct PlantInfo: Decodable, Equatable {
    let isPlant: Bool
    let commonName: String?
    let scientificName: String?
    let confidence: String?        // "high", "medium", or "low"
    let summary: String?
    let funFact: String?
    let whereItGrows: String?
    let needs: PlantNeeds?
    let dangers: [String]?
    let safetyNote: String?
    let message: String?           // only used when isPlant == false

    enum CodingKeys: String, CodingKey {
        case isPlant = "is_plant"
        case commonName = "common_name"
        case scientificName = "scientific_name"
        case confidence
        case summary
        case funFact = "fun_fact"
        case whereItGrows = "where_it_grows"
        case needs
        case dangers
        case safetyNote = "safety_note"
        case message
    }
}

struct PlantNeeds: Decodable, Equatable {
    let sunlight: String?
    let water: String?
    let soil: String?
}

// MARK: - Errors

enum PlantIdentifierError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case badResponse(status: Int, message: String)
    case noResult
    case unexpectedFormat(status: Int, raw: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key yet. Paste your Google AI Studio key into Secret.swift and run the app again."
        case .imageEncodingFailed:
            return "Couldn't prepare that photo. Try a different one."
        case .badResponse(let status, let message):
            switch status {
            case 400:
                return "Google rejected the request (400): \(message)"
            case 401, 403:
                return "The API key was rejected. Check the key in Secret.swift."
            case 429:
                return "You've hit the free daily limit for this model. Try again tomorrow, or switch to gemini-2.5-flash-lite in PlantIdentifier.swift, which has a much higher free limit."
            default:
                return "The AI service returned an error (\(status)): \(message)"
            }
        case .noResult:
            return "The AI didn't send back an answer. Try again."
        case .unexpectedFormat(let status, let raw):
            // DEBUG: dumps the raw server reply so we can see its actual shape.
            // Once things are working, this can go back to a plain friendly message.
            return "Got an HTTP \(status) but couldn't parse the reply. Raw text:\n\(raw)"
        }
    }
}

// MARK: - Service

/// Sends a photo to Gemini and gets back structured plant info.
///
/// Gemini's `responseSchema` forces the reply into the exact JSON shape we want,
/// so it decodes straight into `PlantInfo` with no text-scraping needed.
struct PlantIdentifier {
    /// Flash-Lite models get a much higher free daily request limit than plain Flash models.
    /// Swap this if Google renames/retires the model.
    private let model = "gemini-3.5-flash-lite"

    private var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

    func identify(image: UIImage) async throws -> PlantInfo {
        let apiKey = Secret.geminiAPIKey
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_KEY_HERE" else {
            throw PlantIdentifierError.missingAPIKey
        }

        // Shrink the photo: smaller upload, faster answer, same accuracy for this use.
        guard let jpeg = image.resizedForUpload(maxDimension: 1024)
            .jpegData(compressionQuality: 0.7) else {
            throw PlantIdentifierError.imageEncodingFailed
        }

        let textPart: [String: Any] = [
            "text": "What plant is in this photo?"
        ]
        let imagePart: [String: Any] = [
            "inlineData": [
                "mimeType": "image/jpeg",
                "data": jpeg.base64EncodedString()
            ]
        ]
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [textPart, imagePart]]],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1200,
                "responseMimeType": "application/json",
                "responseSchema": responseSchema
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PlantIdentifierError.noResult
        }

        let rawText = String(data: responseData, encoding: .utf8) ?? "(couldn't read response as text)"

        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: responseData))?.error.message
                ?? String(rawText.prefix(300))
            throw PlantIdentifierError.badResponse(status: http.statusCode, message: message)
        }

        let decoded: GeminiResponse
        do {
            decoded = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        } catch {
            throw PlantIdentifierError.unexpectedFormat(status: http.statusCode, raw: String(rawText.prefix(1500)))
        }

        guard let text = decoded.candidates?.first?.content?.parts?.first?.text,
              let jsonData = text.data(using: .utf8) else {
            throw PlantIdentifierError.unexpectedFormat(status: http.statusCode, raw: String(rawText.prefix(1500)))
        }

        do {
            return try JSONDecoder().decode(PlantInfo.self, from: jsonData)
        } catch {
            throw PlantIdentifierError.unexpectedFormat(status: http.statusCode, raw: String(text.prefix(1500)))
        }
    }

    // MARK: Prompt

    private var systemPrompt: String {
        """
        You are a friendly plant guide inside an app for kids in 2nd to 5th grade.
        Look at the photo, identify the main plant, and fill in the JSON fields described
        by the response schema.

        Writing rules:
        - Use a 3rd-grade reading level: short sentences, simple words, a warm and curious tone.
        - If you use a science word (like "photosynthesis"), explain it in a few words.
        - Be accurate. Do not make things up.

        Honesty rules:
        - If the photo is blurry, far away, or you can't tell the exact species, give your best guess
          and set confidence to "low" (or "medium"). Use the plant's group name if that's all you know.
        - If there is no plant in the photo, set is_plant to false and write a friendly message
          asking the student to try another photo. Leave the other fields as empty strings.

        Safety rules:
        - Never say a plant is safe to eat or touch.
        - If the plant could be poisonous, prickly, or cause a rash, say so in safety_note.
        - For any plant you're unsure about, remind the student to never eat or touch
          unknown plants without a grown-up.
        """
    }

    // MARK: Response schema (the shape of the answer we want back)

    private func prop(_ type: String, _ description: String) -> [String: Any] {
        ["type": type, "description": description]
    }

    private var responseSchema: [String: Any] {
        let needs: [String: Any] = [
            "type": "object",
            "description": "What the plant needs to stay healthy.",
            "properties": [
                "sunlight": prop("string", "How much light it needs, in one short sentence."),
                "water": prop("string", "How much and how often it needs water, in one short sentence."),
                "soil": prop("string", "What kind of soil or ground it likes, in one short sentence.")
            ] as [String: Any],
            "required": ["sunlight", "water", "soil"]
        ]

        let dangers: [String: Any] = [
            "type": "array",
            "description": "2 to 3 short items about things in the environment that can hurt this plant "
                + "(for example: too little water, frost, bugs that eat its leaves, pollution).",
            "items": ["type": "string"]
        ]

        let properties: [String: Any] = [
            "is_plant": prop("boolean", "True if the photo mainly shows a living plant (tree, flower, grass, houseplant, etc.)."),
            "common_name": prop("string", "The everyday name a kid would know, like 'Sunflower'. Empty string if is_plant is false."),
            "scientific_name": prop("string", "The Latin name, like 'Helianthus annuus'. Use just the genus if unsure of the species. Empty string if is_plant is false."),
            "confidence": [
                "type": "string",
                "enum": ["high", "medium", "low"],
                "description": "How sure you are about the identification."
            ],
            "summary": prop("string", "2 to 3 short sentences about what this plant is. Empty string if is_plant is false."),
            "fun_fact": prop("string", "One true, surprising fact in 1 or 2 short sentences. Empty string if is_plant is false."),
            "where_it_grows": prop("string", "One sentence about where in the world or what kinds of places it grows. Empty string if is_plant is false."),
            "needs": needs,
            "dangers": dangers,
            "safety_note": prop("string", "Only if the plant is poisonous, prickly, or irritating. Otherwise an empty string."),
            "message": prop("string", "Only when is_plant is false: a friendly sentence asking for another photo. Otherwise an empty string.")
        ]

        return [
            "type": "object",
            "properties": properties,
            "required": ["is_plant", "common_name", "scientific_name", "confidence", "summary",
                         "fun_fact", "where_it_grows", "needs", "dangers", "safety_note", "message"]
        ]
    }
}

// MARK: - Response decoding

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}

private struct GeminiErrorEnvelope: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

// MARK: - Image helper

extension UIImage {
    /// Redraws the image so the longest side is at most `maxDimension`.
    /// Redrawing also bakes in the camera's rotation so the AI sees it upright.
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > 0 else { return self }
        let scale = min(1, maxDimension / longest)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
