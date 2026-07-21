import 'dart:convert';
import 'dart:developer' as developer;
import '../models/story_script.dart';
import 'ai_service.dart';

/// AI-powered service that converts a user's story script into a structured
/// [StoryScript] with parsed scenes, characters, and camera directions.
class StoryParserService {
  final AiService _aiService;

  StoryParserService(this._aiService);

  /// System prompt that tells the AI how to parse story scripts
  static const String _parseSystemPrompt = '''
You are a professional movie script analyst and animation director. Your job is to take a user's story script and break it down into structured scenes for 3D animation production.

Analyze the story and respond with ONLY a JSON object (no markdown, no code fences) in this exact format:

{
  "title": "Story Title",
  "genre": "Action/Drama/Comedy/etc",
  "characters": [
    {
      "name": "Character Name",
      "description": "Physical description, age, appearance details"
    }
  ],
  "scenes": [
    {
      "sceneNumber": 1,
      "title": "Scene Title",
      "description": "What happens in this scene visually",
      "dialogue": "Character dialogue in this scene",
      "location": "Where the scene takes place",
      "cameraDirection": "front/side/top/closeUp/wide/lowAngle/highAngle/tracking/dolly",
      "durationSeconds": 10.0,
      "charactersInScene": ["Character1", "Character2"],
      "mood": "happy/sad/tense/mysterious/romantic/action/dramatic/neutral",
      "actionDescription": "Any physical actions or movements in this scene"
    }
  ]
}

RULES:
1. Each scene should be 5-30 seconds depending on complexity
2. Camera directions should vary between scenes for visual interest
3. Character descriptions must be detailed enough for consistent 3D modeling
4. Dialogue should capture the key spoken lines (if any)
5. Mood affects lighting and color grading
6. Duration should reflect scene complexity
7. Split the story into logical scenes (scene changes = location change, time jump, or major event)
8. If the user doesn't specify enough details, make reasonable cinematic assumptions
9. Characters must have unique, descriptive details for consistent animation
''';

  /// Parse a user's story script into a structured [StoryScript]
  Future<StoryParseResult> parseScript(String userScript) async {
    developer.log(
      'StoryParser: Parsing script of length ${userScript.length}',
      name: 'PrivateAgent',
    );

    if (!_aiService.isConfigured) {
      return StoryParseResult(
        script: StoryScript(
          title: 'Untitled',
          originalScript: userScript,
          scenes: [],
        ),
        success: false,
        errorMessage:
            'API is not configured. Please add your API key in Settings first.',
      );
    }

    try {
      final prompt =
          'Parse this story into animation scenes:\n\n---\n$userScript\n---\n\nRespond with JSON only.';

      final response =
          await _aiService.sendTaskMessage(_parseSystemPrompt, prompt);

      developer.log(
        'StoryParser: Raw AI response:\n${response.content}',
        name: 'PrivateAgent',
      );

      // Extract JSON from the response
      final jsonStr = _extractJson(response.content);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Parse characters
      final characters = <AnimationCharacter>[];
      if (json['characters'] is List) {
        for (final c in json['characters'] as List) {
          final charMap = c as Map<String, dynamic>;
          characters.add(AnimationCharacter(
            name: charMap['name'] as String? ?? 'Unknown',
            description: charMap['description'] as String? ?? '',
          ));
        }
      }

      // Parse scenes
      final scenes = <StoryScene>[];
      if (json['scenes'] is List) {
        for (final s in json['scenes'] as List) {
          final sceneMap = s as Map<String, dynamic>;
          scenes.add(StoryScene(
            sceneNumber: sceneMap['sceneNumber'] as int? ?? (scenes.length + 1),
            title: sceneMap['title'] as String? ?? 'Scene ${scenes.length + 1}',
            description: sceneMap['description'] as String? ?? '',
            dialogue: sceneMap['dialogue'] as String? ?? '',
            location: sceneMap['location'] as String? ?? 'Unknown',
            cameraDirection: _parseCameraDirection(
                sceneMap['cameraDirection'] as String?),
            durationSeconds:
                (sceneMap['durationSeconds'] as num?)?.toDouble() ?? 5.0,
            charactersInScene:
                (sceneMap['charactersInScene'] as List?)?.cast<String>() ?? [],
            mood: sceneMap['mood'] as String? ?? 'neutral',
            actionDescription: sceneMap['actionDescription'] as String?,
          ));
        }
      }

      // Calculate total frames (assuming 24fps for 3D)
      final totalFrames = scenes.fold<int>(
        0,
        (sum, scene) => sum + (scene.durationSeconds * 24).round(),
      );

      final script = StoryScript(
        title: json['title'] as String? ?? 'Untitled',
        originalScript: userScript,
        genre: json['genre'] as String? ?? 'general',
        characters: characters,
        scenes: scenes,
        estimatedTotalFrames: totalFrames,
      );

      developer.log(
        'StoryParser: Successfully parsed ${scenes.length} scenes, '
        '$totalFrames total frames, ${characters.length} characters',
        name: 'PrivateAgent',
      );

      return StoryParseResult(
        script: script,
        success: true,
        tokensUsed: response.totalTokens,
      );
    } catch (e) {
      developer.log(
        'StoryParser: Error parsing script: $e',
        name: 'PrivateAgent',
      );
      return StoryParseResult(
        script: StoryScript(
          title: 'Untitled',
          originalScript: userScript,
          scenes: [],
        ),
        success: false,
        errorMessage: 'Failed to parse script: $e',
      );
    }
  }

  /// Extract JSON from AI response (handles markdown code blocks)
  String _extractJson(String text) {
    // Try to find a markdown json code block
    final codeBlockRegex = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```');
    final match = codeBlockRegex.firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }

    // Fallback: find the first { and the last }
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      return text.substring(startIndex, endIndex + 1);
    }

    return text.trim();
  }

  /// Parse camera direction string to enum
  CameraDirection _parseCameraDirection(String? dir) {
    if (dir == null) return CameraDirection.front;
    switch (dir.toLowerCase()) {
      case 'side':
        return CameraDirection.side;
      case 'top':
        return CameraDirection.top;
      case 'closeup':
      case 'close-up':
      case 'close_up':
        return CameraDirection.closeUp;
      case 'wide':
        return CameraDirection.wide;
      case 'lowangle':
      case 'low-angle':
      case 'low_angle':
        return CameraDirection.lowAngle;
      case 'highangle':
      case 'high-angle':
      case 'high_angle':
        return CameraDirection.highAngle;
      case 'tracking':
        return CameraDirection.tracking;
      case 'dolly':
        return CameraDirection.dolly;
      default:
        return CameraDirection.front;
    }
  }
}

/// Extended version of [StoryScript] with render-ready metadata for 3D export
class RenderReadyProject {
  final StoryScript script;
  final String outputFormat; // 'prisma3d' or 'video'
  final bool useExistingModels;
  final String? customModelPaths;
  final int targetFps;
  final String resolution; // '1080p', '4k', etc.

  RenderReadyProject({
    required this.script,
    this.outputFormat = 'prisma3d',
    this.useExistingModels = true,
    this.customModelPaths,
    this.targetFps = 24,
    this.resolution = '1080p',
  });

  Map<String, dynamic> toJson() => {
        'script': script.toJson(),
        'outputFormat': outputFormat,
        'useExistingModels': useExistingModels,
        'customModelPaths': customModelPaths,
        'targetFps': targetFps,
        'resolution': resolution,
      };
}
