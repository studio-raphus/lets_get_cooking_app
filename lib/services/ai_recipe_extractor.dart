import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class AIRecipeExtractor {
  // NOTE: In production, this should be in environment variables or secure backend
  static const String _anthropicApiKey = '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';
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';

  // ===========================================================================
  // 1. EXTRACT FROM URL (Video or Web)
  // ===========================================================================

  Future<Recipe> extractFromUrl(String url) async {
    try {
      String content = '';
      String title = 'New Recipe';

      if (_isVideoURL(url)) {
        // Handle Video (YouTube, TikTok, etc.)
        final videoData = await _extractVideoMetadata(url);
        content = videoData['description'] ?? '';
        title = videoData['title'] ?? 'Video Recipe';

        if (content.length < 50) {
          content += "\n[Note: This is a video link ($url). Please try to infer the recipe based on the title and standard preparation for this dish if details are missing.]";
        }
      } else {
        // Handle Standard Website
        content = await _fetchURLContent(url);
      }

      // We pass 'content' as text to the AI
      return await _generateRecipeFromText(content, title, url, 'url');

    } catch (e) {
      throw Exception('Failed to extract recipe from URL: $e');
    }
  }

  // ===========================================================================
  // 2. EXTRACT FROM IMAGE (Camera/Gallery)
  // ===========================================================================

  Future<Recipe> extractFromImage(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception("Image file not found at $imagePath");
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine media type (basic check)
      String mediaType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mediaType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.webp')) {
        mediaType = 'image/webp';
      }

      return await _generateRecipeFromImage(base64Image, mediaType);

    } catch (e) {
      throw Exception('Failed to extract recipe from image: $e');
    }
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  bool _isVideoURL(String url) {
    final videoPatterns = [
      'tiktok.com', 'instagram.com', 'youtube.com', 'youtu.be', 'facebook.com/watch', 'vimeo.com',
    ];
    return videoPatterns.any((pattern) => url.toLowerCase().contains(pattern));
  }

  Future<Map<String, String>> _extractVideoMetadata(String url) async {
    // 1. YouTube oEmbed
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      try {
        // Strip extra params like &t=49s for cleaner oEmbed call if needed,
        // though YouTube usually handles them.
        final oEmbedUrl = 'https://www.youtube.com/oembed?url=$url&format=json';
        final response = await http.get(Uri.parse(oEmbedUrl));
        // TODO: Delete after testing
        if (kDebugMode) {
          print(response);
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'title': data['title'],
            'description': "Video Title: ${data['title']}. \nLink: $url. \n(Please generate a recipe matching this video title.)"
          };
        }
      } catch (e) {
        // Fallback
      }
    }
    // 2. Generic fallback
    return {
      'title': 'Recipe from Link',
      'description': "Video Link: $url. \n(The content is a video. Please generate the most likely recipe for this dish based on the URL or Title.)"
    };
  }

  Future<String> _fetchURLContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // Basic HTML strip
        return response.body.replaceAll(RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false), ' ');
      }
      return "Could not fetch page content. URL: $url";
    } catch (e) {
      return "Could not fetch page content. URL: $url";
    }
  }

  // ===========================================================================
  // AI GENERATION METHODS
  // ===========================================================================

  Future<Recipe> _generateRecipeFromText(String content, String defaultTitle, String source, String sourceType) async {
    // Truncate to avoid token limits
    if (content.length > 10000) content = content.substring(0, 10000);

    final prompt = '''
    Extract a structured recipe from the following content. 
    If the content is just a title or URL, generate a plausible recipe for that dish.
    
    Content:
    $content
    
    Return ONLY raw JSON (no markdown) with this structure:
    {
      "title": "Recipe Title",
      "ingredients": [
        {"item": "ingredient name", "quantity": 1.0, "unit": "cup"}
      ],
      "instructions": ["Step 1", "Step 2"],
      "prepTime": "15 mins",
      "cookTime": "30 mins",
      "servings": 4
    }
    ''';

    return _callClaudeAPI(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      defaultTitle: defaultTitle,
      sourceUrl: source,
      sourceType: sourceType,
    );
  }

  Future<Recipe> _generateRecipeFromImage(String base64Image, String mediaType) async {
    final prompt = '''
    Analyze this image of a recipe (or food). 
    Extract the recipe title, ingredients, and instructions.
    If it's a photo of a finished dish, infer a likely recipe.
    
    Return ONLY raw JSON (no markdown) with this structure:
    {
      "title": "Recipe Title",
      "ingredients": [
        {"item": "ingredient name", "quantity": 1.0, "unit": "cup"}
      ],
      "instructions": ["Step 1", "Step 2"],
      "prepTime": "15 mins",
      "cookTime": "30 mins",
      "servings": 4
    }
    ''';

    return _callClaudeAPI(
      messages: [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': base64Image,
              }
            },
            {
              'type': 'text',
              'text': prompt,
            }
          ]
        }
      ],
      defaultTitle: 'Scanned Recipe',
      sourceUrl: null, // No URL for image scan
      sourceType: 'image',
    );
  }

  Future<Recipe> _callClaudeAPI({
    required List<Map<String, dynamic>> messages,
    required String defaultTitle,
    String? sourceUrl,
    required String sourceType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key': _anthropicApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': 'claude-3-haiku-20240307',
          'max_tokens': 2000,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiContent = data['content'][0]['text'];

        final cleanJson = aiContent.replaceAll('```json', '').replaceAll('```', '').trim();
        final recipeMap = jsonDecode(cleanJson);

        return _parseRecipeData(recipeMap, sourceUrl, sourceType, defaultTitle);
      } else {
        throw Exception('AI API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('AI processing failed: $e');
    }
  }

  Recipe _parseRecipeData(Map<String, dynamic> data, String? sourceUrl, String sourceType, String fallbackTitle) {
    final ingredients = (data['ingredients'] as List?)
        ?.map((i) => Ingredient(
      item: i['item'] ?? '',
      quantity: (i['quantity'] is num) ? (i['quantity'] as num).toDouble() : 0.0,
      unit: i['unit'] ?? '',
    ))
        .toList() ??
        [];

    final instructions = (data['instructions'] as List?)
        ?.map((i) => i.toString())
        .toList() ??
        [];

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: data['title'] ?? fallbackTitle,
      ingredients: ingredients,
      instructions: instructions,
      sourceUrl: sourceUrl,
      sourceType: sourceType,
      prepTime: data['prepTime'],
      cookTime: data['cookTime'],
      servings: data['servings'] is int ? data['servings'] : int.tryParse(data['servings'].toString()),
      wantToCook: true,
      createdAt: DateTime.now(),
    );
  }
}