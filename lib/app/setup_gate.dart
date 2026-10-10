import 'package:flutter/material.dart';

import '../features/chat/domain/gemma_chat_backend.dart';
import '../features/knowledge/domain/knowledge_base.dart';
import '../features/sendlater/domain/profile_repository.dart';
import '../features/sendlater/domain/user_profile.dart';
import '../features/sendlater/presentation/profile_form.dart';
import '../features/speech/domain/speech_test_backend.dart';
import '../ui/theme.dart';
import '../ui/floodini_mascot.dart';
import '../ui/status_chip.dart';

/// First-run flow: welcome, about you (name, emergency contacts, disclaimer),
/// then the one-time model downloads. Shows [child] once the profile exists and
/// every on-device model is installed. Anything already done is skipped.
class SetupGate extends StatefulWidget {
  const SetupGate({
    super.key,
    required this.chatBackend,
    required this.speechBackend,
    required this.knowledgeBase,
    required this.profileRepository,
    required this.child,
  });

  final GemmaChatBackend chatBackend;
  final SpeechTestBackend speechBackend;
  final LocalKnowledgeBase knowledgeBase;
  final ProfileRepository profileRepository;
  final Widget child;

  @override
  State<SetupGate> createState() => _SetupGateState();
}

class _Step {
  _Step(this.title, this.size, this.isReady, this.install);

  final String title;
  final String size;
  final Future<bool> Function() isReady;
  final Future<void> Function(void Function(String? detail, int? percent))
  install;
  bool done = false;
  bool active = false;
  String? detail;
  int? percent;
}

enum _Phase { checking, wizard, ready }

enum _Page { welcome, about, downloads }

class _SetupGateState extends State<SetupGate> {
  late final List<_Step> _steps = [
    _Step(
      'Speech recognition (Whisper)',
      '~150 MB',
      widget.speechBackend.isWhisperInstalled,
      (report) => widget.speechBackend.installWhisper(
        onProgress: (percent) => report(null, percent),
      ),
    ),
    _Step(
      'Offline safety guides',
      '~115 MB',
      widget.knowledgeBase.restoreIfAvailable,
      (report) => widget.knowledgeBase.installAndIndex(
        onProgress: (p) => report(p.message, p.percent),
      ),
    ),
    _Step(
      'On-device AI model (Gemma 4)',
      '~2.6 GB',
      widget.chatBackend.isModelInstalled,
      (report) => widget.chatBackend.installModel(
        onProgress: (percent) => report(null, percent),
      ),
    ),
  ];
  _Phase _phase = _Phase.checking;
  List<_Page> _pages = const [];
  int _pageIndex = 0;
  bool _installing = false;
  bool _profileDone = false;
  UserProfile? _draft;
  String? _error;

  _Page get _page => _pages[_pageIndex];
  bool get _modelsMissing => _steps.any((s) => !s.done);

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final profile = await widget.profileRepository.load();
      _profileDone = profile?.isComplete ?? false;
    } catch (_) {
      _profileDone = false;
    }
    for (final step in _steps) {
      try {
        step.done = await step.isReady();
      } catch (_) {
        step.done = false;
      }
    }
    if (!mounted) return;
    setState(() {
      _pages = [
        if (!_profileDone) ...[_Page.welcome, _Page.about],
        if (_modelsMissing) _Page.downloads,
      ];
      _phase = _pages.isEmpty ? _Phase.ready : _Phase.wizard;
    });
  }

  void _next() => setState(() {
    _error = null;
    _pageIndex++;
  });

  void _back() => setState(() {
    _error = null;
    _pageIndex--;
  });

  Future<bool> _saveProfile() async {
    if (_profileDone) return true;
    final draft = _draft;
    if (draft == null) return false;
    try {
      await widget.profileRepository.save(draft);
      _profileDone = true;
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not save your details: $error');
      }
      return false;
    }
  }

  Future<void> _finishAbout() async {
    if (!await _saveProfile() || !mounted) return;
    if (_pageIndex + 1 < _pages.length) {
      _next();
    } else {
      setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _download() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    for (final step in _steps) {
      if (step.done) continue;
      setState(() {
        step.active = true;
        step.detail = null;
        step.percent = null;
      });
      try {
        await step.install((detail, percent) {
          if (!mounted) return;
          setState(() {
            step.detail = detail ?? step.detail;
            step.percent = percent;
          });
        });
        step.done = true;
      } catch (error) {
        if (!mounted) return;
        setState(() {
          step.active = false;
          _installing = false;
          _error = '${step.title}: $error';
        });
        return;
      }
      if (mounted) setState(() => step.active = false);
    }
    if (mounted) {
      setState(() {
        _installing = false;
        _phase = _Phase.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.ready:
        return widget.child;
      case _Phase.checking:
        return const _Splash();
      case _Phase.wizard:
        return _buildWizard(context);
    }
  }

  Widget _buildWizard(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final welcome = _page == _Page.welcome;
    return Scaffold(
      backgroundColor: welcome && !dark
          ? FloodiniPalette.cream
          : theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (_pages.length > 1) _buildProgress(theme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: switch (_page) {
                  _Page.welcome => _welcomeContent(theme),
                  _Page.about => _aboutContent(theme),
                  _Page.downloads => _downloadContent(theme),
                },
              ),
            ),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(
      children: [
        for (var i = 0; i < _pages.length; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i == _pages.length - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: i <= _pageIndex
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    ),
  );

  List<Widget> _welcomeContent(ThemeData theme) => [
    const SizedBox(height: 24),
    const Center(child: FloodiniMascot(height: 220)),
    const SizedBox(height: 24),
    Text(
      'Meet Floodini.',
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineLarge,
    ),
    const SizedBox(height: 8),
    Text(
      'Your emergency companion, ready even without internet.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyLarge,
    ),
    const SizedBox(height: 16),
    Text(
      'Handa kahit offline.',
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium!.copyWith(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.primary
            : FloodiniPalette.deepTeal,
      ),
    ),
    const SizedBox(height: 32),
    Text(
      'Floodini is not an official emergency service. It cannot see live '
      'weather, evacuation orders, or facility status.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall,
    ),
  ];

  List<Widget> _aboutContent(ThemeData theme) => [
    Text('About you', style: theme.textTheme.headlineMedium),
    const SizedBox(height: 4),
    Text(
      'Who should Floodini text if you need help?',
      style: theme.textTheme.bodyLarge,
    ),
    const SizedBox(height: 16),
    ProfileForm(
      initial: _draft,
      onChanged: (profile) => setState(() => _draft = profile),
    ),
    if (_error != null) _errorText(theme),
  ];

  List<Widget> _downloadContent(ThemeData theme) => [
    Row(
      children: [
        const FloodiniAvatar(size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Download once', style: theme.textTheme.headlineMedium),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Text(
      'Floodini runs its AI on your phone. Download the AI model and safety '
      'guides once, then they work without a signal.',
      style: theme.textTheme.bodyLarge,
    ),
    const SizedBox(height: 12),
    const Align(
      alignment: Alignment.centerLeft,
      child: StatusChip(
        label: 'Use Wi-Fi · keep this screen open',
        tone: StatusTone.caution,
        icon: Icons.wifi,
      ),
    ),
    const SizedBox(height: 16),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _buildStep(theme, _steps[i]),
            ],
          ],
        ),
      ),
    ),
    if (_error != null) _errorText(theme),
  ];

  Widget _errorText(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: SelectableText(
      _error!,
      style: TextStyle(color: theme.colorScheme.error),
    ),
  );

  Widget _buildBottomBar(ThemeData theme) {
    final lastPage = _pageIndex == _pages.length - 1;
    final VoidCallback? onPressed;
    final Key key;
    final String label;
    IconData? icon;
    switch (_page) {
      case _Page.welcome:
        key = const Key('welcome-start-button');
        label = 'Magsimula';
        onPressed = _next;
      case _Page.about:
        key = Key(lastPage ? 'get-started-button' : 'profile-next-button');
        label = lastPage ? 'Get Started' : 'Next';
        onPressed = _draft != null || _profileDone ? _finishAbout : null;
      case _Page.downloads:
        key = const Key('get-started-button');
        label = _error == null ? 'Get Started' : 'Retry';
        icon = _error == null ? Icons.download : Icons.refresh;
        onPressed = _installing ? null : _download;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainerLow
            : theme.colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (_pageIndex > 0 && !_installing) ...[
            OutlinedButton(
              key: const Key('wizard-back-button'),
              onPressed: _back,
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              key: key,
              onPressed: onPressed,
              icon: icon == null ? const SizedBox.shrink() : Icon(icon),
              label: Text(label),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(ThemeData theme, _Step step) {
    final colors = context.floodini;
    final leading = step.done
        ? Icon(Icons.check_circle, color: colors.safe, size: 28)
        : step.active
        ? const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
        : Icon(
            Icons.circle_outlined,
            color: theme.colorScheme.outline,
            size: 28,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Text(step.title, style: theme.textTheme.titleSmall),
            ),
            Text(step.size, style: theme.textTheme.bodySmall),
          ],
        ),
        if (step.active) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step.percent == null ? null : step.percent! / 100,
            ),
          ),
          if (step.detail != null) ...[
            const SizedBox(height: 4),
            Text(step.detail!, style: theme.textTheme.bodySmall),
          ],
        ],
      ],
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? theme.colorScheme.surface : FloodiniPalette.cream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FloodiniMascot(height: 200),
            const SizedBox(height: 16),
            Text('Floodini', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 4),
            Text(
              'Handa kahit offline.',
              style: theme.textTheme.titleMedium!.copyWith(
                color: dark
                    ? theme.colorScheme.primary
                    : FloodiniPalette.deepTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
