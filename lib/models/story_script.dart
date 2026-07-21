/// Direction of the camera for a 3D scene
enum CameraDirection {
  front,
  side,
  top,
  closeUp,
  wide,
  lowAngle,
  highAngle,
  tracking,
  dolly;

  String get displayName {
    switch (this) {
      case CameraDirection.front:
        return 'Front View';
      case CameraDirection.side:
        return 'Side View';
      case CameraDirection.top:
        return 'Top Down';
      case CameraDirection.closeUp:
        return 'Close-up';
      case CameraDirection.wide:
        return 'Wide Shot';
      case CameraDirection.lowAngle:
        return 'Low Angle';
      case CameraDirection.highAngle:
        return 'High Angle';
      case CameraDirection.tracking:
        return 'Tracking Shot';
      case CameraDirection.dolly:
        return 'Dolly Zoom';
    }
  }

  String toJson() => name;
  factory CameraDirection.fromJson(String json) {
    return CameraDirection.values.firstWhere(
      (e) => e.name == json,
      orElse: () => CameraDirection.front,
    );
  }
}

/// Represents a character in the story/animation
class AnimationCharacter {
  final String name;
  final String description;
  final String? modelFile;
  final String? colorScheme;
  final bool isConsistentAcrossScenes;

  AnimationCharacter({
    required this.name,
    required this.description,
    this.modelFile,
    this.colorScheme,
    this.isConsistentAcrossScenes = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'modelFile': modelFile,
        'colorScheme': colorScheme,
        'isConsistentAcrossScenes': isConsistentAcrossScenes,
      };

  factory AnimationCharacter.fromJson(Map<String, dynamic> json) =>
      AnimationCharacter(
        name: json['name'] as String,
        description: json['description'] as String,
        modelFile: json['modelFile'] as String?,
        colorScheme: json['colorScheme'] as String?,
        isConsistentAcrossScenes:
            json['isConsistentAcrossScenes'] as bool? ?? true,
      );
}

/// A single scene in the story with all animation metadata
class StoryScene {
  final int sceneNumber;
  final String title;
  final String description;
  final String dialogue;
  final String location;
  final CameraDirection cameraDirection;
  final double durationSeconds;
  final List<String> charactersInScene;
  final String mood;
  final String? actionDescription;

  StoryScene({
    required this.sceneNumber,
    required this.title,
    required this.description,
    required this.dialogue,
    required this.location,
    this.cameraDirection = CameraDirection.front,
    this.durationSeconds = 5.0,
    this.charactersInScene = const [],
    this.mood = 'neutral',
    this.actionDescription,
  });

  Map<String, dynamic> toJson() => {
        'sceneNumber': sceneNumber,
        'title': title,
        'description': description,
        'dialogue': dialogue,
        'location': location,
        'cameraDirection': cameraDirection.toJson(),
        'durationSeconds': durationSeconds,
        'charactersInScene': charactersInScene,
        'mood': mood,
        'actionDescription': actionDescription,
      };

  factory StoryScene.fromJson(Map<String, dynamic> json) => StoryScene(
        sceneNumber: json['sceneNumber'] as int,
        title: json['title'] as String? ?? 'Scene ${json['sceneNumber']}',
        description: json['description'] as String,
        dialogue: json['dialogue'] as String? ?? '',
        location: json['location'] as String? ?? '',
        cameraDirection: json['cameraDirection'] != null
            ? CameraDirection.fromJson(json['cameraDirection'] as String)
            : CameraDirection.front,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 5.0,
        charactersInScene:
            (json['charactersInScene'] as List?)?.cast<String>() ?? [],
        mood: json['mood'] as String? ?? 'neutral',
        actionDescription: json['actionDescription'] as String?,
      );

  /// Human-readable summary for UI display
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('Scene $sceneNumber: $title');
    buffer.writeln('Location: $location');
    buffer.writeln('Camera: ${cameraDirection.displayName}');
    if (charactersInScene.isNotEmpty) {
      buffer.writeln('Characters: ${charactersInScene.join(', ')}');
    }
    buffer.writeln('Mood: $mood');
    if (dialogue.isNotEmpty) {
      buffer.writeln('Dialogue: "$dialogue"');
    }
    buffer.writeln('Duration: ${durationSeconds.toStringAsFixed(0)}s');
    return buffer.toString();
  }
}

/// Complete story script parsed from user input
class StoryScript {
  final String title;
  final String originalScript;
  final String genre;
  final List<AnimationCharacter> characters;
  final List<StoryScene> scenes;
  final DateTime createdAt;
  final int estimatedTotalFrames;

  StoryScript({
    required this.title,
    required this.originalScript,
    this.genre = 'general',
    this.characters = const [],
    required this.scenes,
    DateTime? createdAt,
    this.estimatedTotalFrames = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalSceneCount => scenes.length;
  double get totalDurationSeconds =>
      scenes.fold(0.0, (sum, scene) => sum + scene.durationSeconds);
  String get totalDurationFormatted {
    final totalSec = totalDurationSeconds.round();
    final minutes = totalSec ~/ 60;
    final seconds = totalSec % 60;
    return '${minutes}m ${seconds}s';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'originalScript': originalScript,
        'genre': genre,
        'characters': characters.map((c) => c.toJson()).toList(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'estimatedTotalFrames': estimatedTotalFrames,
      };

  factory StoryScript.fromJson(Map<String, dynamic> json) => StoryScript(
        title: json['title'] as String,
        originalScript: json['originalScript'] as String,
        genre: json['genre'] as String? ?? 'general',
        characters: (json['characters'] as List?)
                ?.map(
                    (c) => AnimationCharacter.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
        scenes: (json['scenes'] as List)
            .map((s) => StoryScene.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        estimatedTotalFrames: json['estimatedTotalFrames'] as int? ?? 0,
      );
}

/// Results from AI parsing of a story script
class StoryParseResult {
  final StoryScript script;
  final bool success;
  final String? errorMessage;
  final int tokensUsed;

  StoryParseResult({
    required this.script,
    required this.success,
    this.errorMessage,
    this.tokensUsed = 0,
  });
}
