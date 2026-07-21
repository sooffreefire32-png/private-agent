import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/story_script.dart';
import '../services/ai_service.dart';
import '../services/story_parser_service.dart';
import 'settings_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Main screen for the AI Movie Studio feature
class AiMovieStudioScreen extends StatefulWidget {
  final AiService aiService;

  const AiMovieStudioScreen({super.key, required this.aiService});

  @override
  State<AiMovieStudioScreen> createState() => _AiMovieStudioScreenState();
}

class _AiMovieStudioScreenState extends State<AiMovieStudioScreen>
    with SingleTickerProviderStateMixin {
  late final StoryParserService _parser;
  late final TabController _tabController;

  final TextEditingController _scriptController = TextEditingController();
  final ScrollController _sceneScrollController = ScrollController();

  bool _isParsing = false;
  StoryScript? _currentScript;
  String? _errorMessage;
  StoryScript? _lastSuccessfulScript;

  // Expanded/collapsed scenes
  final Set<int> _expandedScenes = {};

  @override
  void initState() {
    super.initState();
    _parser = StoryParserService(widget.aiService);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _scriptController.dispose();
    _sceneScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _parseScript() async {
    final script = _scriptController.text.trim();
    if (script.isEmpty) {
      _showSnackBar('Please enter a story script first.');
      return;
    }

    if (!widget.aiService.isConfigured) {
      _showSnackBar(
        'API is not configured. Go to Settings to add your API key.',
      );
      return;
    }

    setState(() {
      _isParsing = true;
      _errorMessage = null;
      _currentScript = null;
    });

    try {
      final result = await _parser.parseScript(script);

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _currentScript = result.script;
          _lastSuccessfulScript = result.script;
          _expandedScenes.clear();
          // Auto-expand first scene
          if (result.script.scenes.isNotEmpty) {
            _expandedScenes.add(0);
          }
        });
        _showSnackBar(
          '✅ Parsed ${result.script.totalSceneCount} scenes with '
          '${result.script.characters.length} characters!',
        );
      } else {
        setState(() {
          _errorMessage = result.errorMessage;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 20,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            children: [
              TextSpan(
                text: 'AI Movie ',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const TextSpan(
                text: 'Studio',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    aiService: widget.aiService,
                    shizukuService: widget.aiService as dynamic,
                    screenAutomationService: widget.aiService as dynamic,
                    telegramService: widget.aiService as dynamic,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar for Script / Timeline
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 16),
                      const SizedBox(width: 6),
                      const Text('Script'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timeline_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Timeline${_currentScript != null ? " (${_currentScript!.totalSceneCount})" : ""}',
                      ),
                    ],
                  ),
                ),
              ],
              onTap: (index) {
                setState(() {});
              },
            ),
          ),

          // Content area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScriptTab(isDark, primaryColor),
                _buildTimelineTab(isDark, primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Script Input Tab ─────────────────────────────────────

  Widget _buildScriptTab(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    color: primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Paste your story script below. AI will parse it into scenes '
                    'with camera angles, characters, and timing for 3D animation.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Script input
          Text(
            'STORY SCRIPT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: TextField(
              controller: _scriptController,
              maxLines: 12,
              minLines: 6,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    'Paste your story here...\n\nExample:\n"Once upon a time, a young inventor named Alex created a robot in their garage. One day, the robot came to life and they embarked on an adventure to save the city..."',
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                  fontSize: 13,
                  height: 1.5,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Parse button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isParsing ? null : _parseScript,
              icon: _isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                _isParsing ? 'Parsing story...' : 'Parse Story into Scenes',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Quick example button
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _scriptController.text = _exampleScript;
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text(
                'Load example story',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Timeline Tab ────────────────────────────────────────

  Widget _buildTimelineTab(bool isDark, Color primaryColor) {
    if (_currentScript == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.movie_creation_outlined,
                size: 64,
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
              const SizedBox(height: 16),
              Text(
                'No script parsed yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to the Script tab, paste your story,\nand tap "Parse Story into Scenes"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _tabController.animateTo(0);
                },
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: const Text('Go to Script'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final script = _currentScript!;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Project header card
        _buildProjectHeader(script, isDark, primaryColor),

        const SizedBox(height: 20),

        // Characters section
        if (script.characters.isNotEmpty) ...[
          Text(
            'CHARACTERS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color:
                  isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: script.characters.length,
              itemBuilder: (context, index) {
                final character = script.characters[index];
                return _buildCharacterChip(character, isDark, primaryColor);
              },
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Scenes timeline
        Text(
          'SCENES (${script.totalSceneCount})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color:
                isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),

        // Total duration bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16),
              const SizedBox(width: 8),
              Text(
                'Total Duration: ${script.totalDurationFormatted}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${script.estimatedTotalFrames} frames @ 24fps',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Scene cards
        ...script.scenes.asMap().entries.map((entry) {
          return _buildSceneCard(
            entry.key,
            entry.value,
            isDark,
            primaryColor,
          );
        }),

        // Action buttons
        const SizedBox(height: 24),
        if (_lastSuccessfulScript != null) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showSnackBar(
                      'Prisma3D automation coming in Phase 2! 🎬',
                    );
                  },
                  icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                  label: const Text(
                    'Render in Prisma3D',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showSnackBar(
                      'Flame Engine 2D animation coming in Phase 4! 🎨',
                    );
                  },
                  icon: const Icon(Icons.animation_rounded, size: 18),
                  label: const Text(
                    '2D Anime (Flame)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(color: Colors.orangeAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ─── Widget Builders ──────────────────────────────────────

  Widget _buildProjectHeader(
    StoryScript script,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.15),
            primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.movie_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      script.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${script.genre.toUpperCase()}  ·  '
                      '${script.totalSceneCount} scenes  ·  '
                      '${script.characters.length} characters',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            script.originalScript.length > 150
                ? '${script.originalScript.substring(0, 150)}...'
                : script.originalScript,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterChip(
    AnimationCharacter character,
    bool isDark,
    Color primaryColor,
  ) {
    final colors = [
      primaryColor,
      Colors.amber,
      Colors.green,
      Colors.pink,
      Colors.cyan,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    final color = colors[character.name.hashCode.abs() % colors.length];

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            radius: 18,
            child: Text(
              character.name[0].toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  character.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  character.description.length > 28
                      ? '${character.description.substring(0, 25)}...'
                      : character.description,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneCard(
    int index,
    StoryScene scene,
    bool isDark,
    Color primaryColor,
  ) {
    final isExpanded = _expandedScenes.contains(index);
    final moodColors = {
      'happy': Colors.green,
      'sad': Colors.indigo,
      'tense': Colors.red,
      'mysterious': Colors.purple,
      'romantic': Colors.pink,
      'action': Colors.orange,
      'dramatic': Colors.deepPurple,
      'neutral': Colors.grey,
    };
    final moodColor =
        moodColors[scene.mood.toLowerCase()] ?? Colors.grey;
    final cameraIconMap = {
      CameraDirection.front: Icons.camera_front_rounded,
      CameraDirection.side: Icons.switch_camera_rounded,
      CameraDirection.top: Icons.flight_rounded,
      CameraDirection.closeUp: Icons.center_focus_strong_rounded,
      CameraDirection.wide: Icons.photo_camera_rounded,
      CameraDirection.lowAngle: Icons.arrow_upward_rounded,
      CameraDirection.highAngle: Icons.arrow_downward_rounded,
      CameraDirection.tracking: Icons.direction_run_rounded,
      CameraDirection.dolly: Icons.zoom_in_rounded,
    };
    final cameraIcon = cameraIconMap[scene.cameraDirection] ??
        Icons.camera_alt_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151D30) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF243049).withOpacity(0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedScenes.remove(index);
              } else {
                _expandedScenes.add(index);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scene header (always visible)
                Row(
                  children: [
                    // Scene number badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${scene.sceneNumber}',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scene.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            '${scene.location}  ·  ${scene.durationSeconds.toStringAsFixed(0)}s',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mood indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: moodColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scene.mood.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: moodColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),

                // Expanded details
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),

                        // Camera + Duration row
                        Row(
                          children: [
                            Icon(cameraIcon, size: 14, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              scene.cameraDirection.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.timer_outlined,
                                size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${scene.durationSeconds.toStringAsFixed(0)}s',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Description
                        if (scene.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              scene.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                                height: 1.4,
                              ),
                            ),
                          ),

                        // Dialogue
                        if (scene.dialogue.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.format_quote_rounded,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    scene.dialogue,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF475569),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Action description
                        if (scene.actionDescription != null &&
                            scene.actionDescription!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.directions_run_rounded,
                                  size: 14, color: Colors.orange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  scene.actionDescription!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Characters in scene
                        if (scene.charactersInScene.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: scene.charactersInScene.map((name) {
                              return Chip(
                                label: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: primaryColor.withOpacity(0.08),
                                side: BorderSide(
                                  color: primaryColor.withOpacity(0.2),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input Bar (Bottom) ───────────────────────────────────

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0F19) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.5)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _scriptController,
                decoration: InputDecoration(
                  hintText: 'Type more story details...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _parseScript(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: _isParsing ? null : _parseScript,
              icon: _isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

const String _exampleScript = '''
Title: The Last Light

Genre: Sci-Fi Drama

Characters:
- Dr. Elena Voss: A brilliant astrophysicist in her 40s, determined but weary
- Kael: A sentient AI from a dying star system, curious and gentle
- Commander Reed: A practical military leader, skeptical of the unknown

Story:
In the year 2157, Earth's astronomers detect a mysterious signal from a dying star at the edge of the galaxy. Dr. Elena Voss leads a team aboard the starship Horizon to investigate. They discover an ancient AI named Kael, who has been maintaining a light-based civilization. Kael reveals that their star is dying and asks for help to preserve their species' knowledge. Commander Reed is suspicious, fearing a trap. Elena must choose between following protocol and trusting an alien intelligence. In the end, she convinces the crew to help Kael transmit their civilization's data into a new star, creating "The Last Light" - a beacon of hope across the galaxy.
''';
