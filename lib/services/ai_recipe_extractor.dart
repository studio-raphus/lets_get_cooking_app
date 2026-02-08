import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';
import '../secrets.dart';

class AIRecipeExtractor {
  static const String _anthropicApiKey = Secrets.anthropicApiKey; // Replace in secrets.dart
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514'; // Use Sonnet 4 for best results

  // ===========================================================================
  // 1. EXTRACT FROM URL (Video or Web)
  // ===========================================================================

  Future<Recipe> extractFromUrl(String url) async {
    try {
      debugPrint('📱 Extracting recipe from URL: $url');

      String content = '';
      String title = 'Recipe from Link';
      String? thumbnailUrl;

      if (_isVideoURL(url)) {
        debugPrint('🎥 Detected video URL');
        final videoData = await _extractVideoMetadata(url);
        title = videoData['title'] ?? 'Video Recipe';
        content = videoData['description'] ?? '';
        thumbnailUrl = videoData['thumbnail'];

        // Enhanced prompt for video links
        final prompt = '''
You are analyzing a recipe video. Here's what we know:

Title: $title
URL: $url
Description: ${content.isNotEmpty ? content : 'No description available'}

Your task: Generate a complete, practical recipe that someone could actually cook from.

Guidelines:
1. If the title clearly indicates a dish (e.g., "Spaghetti Carbonara", "Chocolate Chip Cookies"), provide the standard recipe for that dish
2. Include realistic ingredient measurements (use common US measurements: cups, tablespoons, teaspoons, ounces, pounds)
3. Provide step-by-step instructions that are clear and actionable
4. Estimate reasonable prep and cook times
5. Standard servings (usually 4-6 for main dishes, 12-24 for cookies/baked goods)

Return ONLY a JSON object (no markdown, no code blocks) with this exact structure:
{
  "title": "Exact dish name",
  "ingredients": [
    {"item": "ingredient name", "quantity": 2.0, "unit": "cups"},
    {"item": "ingredient name", "quantity": 1.0, "unit": "tablespoon"}
  ],
  "instructions": [
    "Step 1 instruction",
    "Step 2 instruction"
  ],
  "prepTime": "15 mins",
  "cookTime": "30 mins",
  "servings": 4,
  "tags": ["dinner", "pasta", "italian"]
}

Remember: Make it cookable! Someone should be able to follow this recipe successfully.
''';

        return await _callClaudeAPI(
          prompt: prompt,
          sourceUrl: url,
          sourceType: 'video',
          thumbnailUrl: thumbnailUrl,
        );
      } else {
        // Regular website
        debugPrint('🌐 Detected web URL');
        content = await _fetchWebContent(url);

        final prompt = '''
Extract a recipe from this webpage content. Focus on finding the actual recipe instructions and ingredients.

Webpage content:
${content.length > 8000 ? content.substring(0, 8000) + '...' : content}

Return ONLY a JSON object (no markdown, no code blocks) with this exact structure:
{
  "title": "Recipe title from the page",
  "ingredients": [
    {"item": "ingredient name", "quantity": 2.0, "unit": "cups"}
  ],
  "instructions": [
    "Step 1 instruction"
  ],
  "prepTime": "15 mins",
  "cookTime": "30 mins",
  "servings": 4,
  "tags": ["tag1", "tag2"]
}

Important:
- Extract actual measurements from the page
- Keep ingredient names clean (no extra descriptors in the item name)
- Instructions should be clear steps
- If multiple recipes are present, choose the main one
''';

        return await _callClaudeAPI(
          prompt: prompt,
          sourceUrl: url,
          sourceType: 'url',
        );
      }
    } catch (e) {
      debugPrint('❌ Error extracting from URL: $e');
      throw Exception('Failed to extract recipe: $e');
    }
  }

  // ===========================================================================
  // 2. EXTRACT FROM IMAGE
  // ===========================================================================

  Future<Recipe> extractFromImage(String imagePath) async {
    try {
      debugPrint('📸 Extracting recipe from image: $imagePath');

      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception("Image file not found");
      }

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      String mediaType = 'image/jpeg';
      if (imagePath.toLowerCase().endsWith('.png')) {
        mediaType = 'image/png';
      } else if (imagePath.toLowerCase().endsWith('.webp')) {
        mediaType = 'image/webp';
      } else if (imagePath.toLowerCase().endsWith('.gif')) {
        mediaType = 'image/gif';
      }

      return await _generateRecipeFromImage(base64Image, mediaType);
    } catch (e) {
      debugPrint('❌ Error extracting from image: $e');
      throw Exception('Failed to extract recipe from image: $e');
    }
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  bool _isVideoURL(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('tiktok.com') ||
        lowerUrl.contains('instagram.com') ||
        lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be') ||
        lowerUrl.contains('facebook.com/watch') ||
        lowerUrl.contains('vimeo.com') ||
        lowerUrl.contains('reels');
  }

  Future<Map<String, String>> _extractVideoMetadata(String url) async {
    // YouTube oEmbed API
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      try {
        final encodedUrl = Uri.encodeComponent(url);
        final oEmbedUrl = 'https://www.youtube.com/oembed?url=$encodedUrl&format=json';

        debugPrint('🔍 Fetching YouTube metadata: $oEmbedUrl');
        final response = await http.get(Uri.parse(oEmbedUrl)).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('✅ Got YouTube metadata: ${data['title']}');

          return {
            'title': data['title'] ?? 'YouTube Recipe',
            'description': 'Video recipe: ${data['title']}',
            'thumbnail': data['thumbnail_url'],
          };
        }
      } catch (e) {
        debugPrint('⚠️ YouTube metadata fetch failed: $e');
      }
    }

    // TikTok oEmbed API
    if (url.contains('tiktok.com')) {
      try {
        final encodedUrl = Uri.encodeComponent(url);
        final oEmbedUrl = 'https://www.tiktok.com/oembed?url=$encodedUrl';

        debugPrint('🔍 Fetching TikTok metadata: $oEmbedUrl');
        final response = await http.get(Uri.parse(oEmbedUrl)).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('✅ Got TikTok metadata: ${data['title']}');

          return {
            'title': data['title'] ?? 'TikTok Recipe',
            'description': 'TikTok recipe video: ${data['title']}',
            'thumbnail': data['thumbnail_url'],
          };
        }
      } catch (e) {
        debugPrint('⚠️ TikTok metadata fetch failed: $e');
      }
    }

    // Instagram - Extract from URL structure
    if (url.contains('instagram.com')) {
      return {
        'title': 'Instagram Recipe',
        'description': 'Recipe from Instagram: $url',
      };
    }

    // Generic fallback
    return {
      'title': 'Recipe from Video',
      'description': 'Video recipe link: $url',
    };
  }

  Future<String> _fetchWebContent(String url) async {
    try {
      debugPrint('🌐 Fetching web content from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; RecipeBot/1.0)',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Strip HTML tags but keep text content
        String content = response.body;

        // Remove script and style tags with their content
        content = content.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', multiLine: true), ' ');
        content = content.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', multiLine: true), ' ');

        // Remove HTML tags
        content = content.replaceAll(RegExp(r'<[^>]*>'), ' ');

        // Clean up whitespace
        content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

        debugPrint('✅ Fetched ${content.length} characters');
        return content;
      }

      debugPrint('⚠️ HTTP ${response.statusCode} from $url');
      return 'Could not fetch page content from: $url';
    } catch (e) {
      debugPrint('❌ Error fetching web content: $e');
      return 'Could not fetch page content from: $url';
    }
  }

  // ===========================================================================
  // AI GENERATION METHODS
  // ===========================================================================

  Future<Recipe> _generateRecipeFromImage(String base64Image, String mediaType) async {
    final prompt = '''
Analyze this image carefully. It could be:
1. A recipe card or cookbook page with written instructions
2. A photo of prepared food/dish
3. A screenshot of a recipe from a website or app

Your task: Extract or infer a complete, cookable recipe.

If it's a recipe card:
- Extract the exact ingredients and measurements
- Extract the exact instructions
- Extract title, times, and servings if visible

If it's a food photo:
- Identify the dish
- Provide the standard recipe for that dish
- Include realistic measurements and steps

Return ONLY a JSON object (no markdown, no code blocks) with this exact structure:
{
  "title": "Dish name",
  "ingredients": [
    {"item": "flour", "quantity": 2.0, "unit": "cups"},
    {"item": "sugar", "quantity": 1.0, "unit": "cup"}
  ],
  "instructions": [
    "Preheat oven to 350°F",
    "Mix dry ingredients"
  ],
  "prepTime": "15 mins",
  "cookTime": "30 mins",
  "servings": 4,
  "tags": ["dessert", "baking"]
}

Important:
- Quantities must be numbers (use 1.5 for "1 1/2", 0.5 for "half")
- Units should be standard: cup, tablespoon, teaspoon, ounce, pound, gram, ml, etc.
- Instructions should be actionable steps
- Make it cookable!
''';

    return await _callClaudeAPIWithImage(
      base64Image: base64Image,
      mediaType: mediaType,
      prompt: prompt,
    );
  }

  Future<Recipe> _callClaudeAPI({
    required String prompt,
    required String sourceUrl,
    required String sourceType,
    String? thumbnailUrl,
  }) async {
    try {
      debugPrint('🤖 Calling Claude API...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key': _anthropicApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 4000,
          'temperature': 0.7,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['content'][0]['text'] as String;

        debugPrint('✅ Got AI response: ${aiResponse.length} characters');

        // Clean the response - remove markdown code blocks
        String cleanJson = aiResponse
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        // Find the JSON object (in case there's text before/after)
        final jsonStart = cleanJson.indexOf('{');
        final jsonEnd = cleanJson.lastIndexOf('}');

        if (jsonStart != -1 && jsonEnd != -1) {
          cleanJson = cleanJson.substring(jsonStart, jsonEnd + 1);
        }

        final recipeData = jsonDecode(cleanJson) as Map<String, dynamic>;

        return _parseRecipeData(
          recipeData,
          sourceUrl: sourceUrl,
          sourceType: sourceType,
          thumbnailUrl: thumbnailUrl,
        );
      } else {
        final errorBody = response.body;
        debugPrint('❌ API Error ${response.statusCode}: $errorBody');
        throw Exception('AI API returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error calling Claude API: $e');
      rethrow;
    }
  }

  Future<Recipe> _callClaudeAPIWithImage({
    required String base64Image,
    required String mediaType,
    required String prompt,
  }) async {
    try {
      debugPrint('🤖 Calling Claude API with image...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key': _anthropicApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 4000,
          'temperature': 0.7,
          'messages': [
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
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['content'][0]['text'] as String;

        debugPrint('✅ Got AI response from image');

        String cleanJson = aiResponse
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final jsonStart = cleanJson.indexOf('{');
        final jsonEnd = cleanJson.lastIndexOf('}');

        if (jsonStart != -1 && jsonEnd != -1) {
          cleanJson = cleanJson.substring(jsonStart, jsonEnd + 1);
        }

        final recipeData = jsonDecode(cleanJson) as Map<String, dynamic>;

        return _parseRecipeData(
          recipeData,
          sourceUrl: null,
          sourceType: 'image',
        );
      } else {
        throw Exception('AI API returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error calling Claude API with image: $e');
      rethrow;
    }
  }

  Recipe _parseRecipeData(
      Map<String, dynamic> data, {
        String? sourceUrl,
        required String sourceType,
        String? thumbnailUrl,
      }) {
    debugPrint('📝 Parsing recipe data...');

    // Parse ingredients
    final ingredientsList = data['ingredients'] as List?;
    final ingredients = ingredientsList?.map((i) {
      final item = i['item'] as String;
      final quantity = (i['quantity'] is num)
          ? (i['quantity'] as num).toDouble()
          : double.tryParse(i['quantity'].toString()) ?? 1.0;
      final unit = (i['unit'] as String? ?? '').trim();

      return Ingredient(
        item: item.trim(),
        quantity: quantity,
        unit: unit,
      );
    }).toList() ?? [];

    // Parse instructions
    final instructionsList = data['instructions'] as List?;
    final instructions = instructionsList?.map((i) => i.toString().trim()).toList() ?? [];

    // Parse tags
    final tagsList = data['tags'] as List?;
    final tags = tagsList?.map((t) => t.toString()).toList() ?? [];

    final recipe = Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: (data['title'] as String? ?? 'Untitled Recipe').trim(),
      ingredients: ingredients,
      instructions: instructions,
      sourceUrl: sourceUrl,
      sourceType: sourceType,
      imageUrl: thumbnailUrl,
      prepTime: data['prepTime'] as String?,
      cookTime: data['cookTime'] as String?,
      servings: data['servings'] is int
          ? data['servings']
          : int.tryParse(data['servings']?.toString() ?? ''),
      tags: tags,
      wantToCook: true,
      createdAt: DateTime.now(),
    );

    debugPrint('✅ Recipe parsed successfully: ${recipe.title}');
    debugPrint('   - ${recipe.ingredients.length} ingredients');
    debugPrint('   - ${recipe.instructions.length} steps');

    return recipe;
  }
}