import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'api.dart';
import 'models/task.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TodoApp());
}

String defaultBaseUrl() {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}

/// Цвета как в `web_client/index.html` (:root).
class AppColors {
  static const bg = Color(0xFFF0F4F8);
  static const text = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const accent = Color(0xFF0D9488);
  static const danger = Color(0xFFDC2626);
  static const ghostBorder = Color(0xFF99F6E4);
  static const line = Color(0xFFE2E8F0);
  static const meta = Color(0xFF94A3B8);
  static const secondaryBtn = Color(0xFF64748B);
  static const errBg = Color(0xFFFEF2F2);
  static const errText = Color(0xFF991B1B);
  static const errBorder = Color(0xFFFECACA);
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Список задач',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.light),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.accent, width: 2),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TodoApi _api;
  final _baseUrl = TextEditingController();
  final _email = TextEditingController(text: 'demo@example.com');
  final _password = TextEditingController(text: 'secret12');
  final _newTitle = TextEditingController();
  final _newDesc = TextEditingController();
  final _newOwnerId = TextEditingController();

  List<Task> _tasks = [];
  String? _authMsg;
  String? _appMsg;
  bool _busy = false;
  bool _hasToken = false;
  bool _isAdmin = false;
  bool _ready = false;

  String _filterStatus = 'all';
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';
  bool _titleInvalid = false;

  @override
  void initState() {
    super.initState();
    _api = TodoApi(baseUrl: normalizeApiBase(defaultBaseUrl()));
    _bootstrap();
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _email.dispose();
    _password.dispose();
    _newTitle.dispose();
    _newDesc.dispose();
    _newOwnerId.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final probe = TodoApi(baseUrl: normalizeApiBase(defaultBaseUrl()));
    final savedUrl = await probe.getSavedBaseUrl();
    final url = normalizeApiBase(savedUrl ?? defaultBaseUrl());
    final savedEmail = await probe.getSavedEmail();
    final token = await probe.getToken();

    if (!mounted) {
      return;
    }
    setState(() {
      _api = TodoApi(baseUrl: url);
      _baseUrl.text = url;
      if (savedEmail != null && savedEmail.isNotEmpty) {
        _email.text = savedEmail;
      }
      _ready = true;
      _hasToken = token != null;
    });

    if (token != null) {
      try {
        await _api.fetchMe();
      } on UnauthorizedException {
        await _logout();
        if (mounted) {
          setState(() => _authMsg = 'Сессия истекла. Войдите снова.');
        }
        return;
      } catch (e) {
        if (mounted) {
          setState(() => _authMsg = 'Не удалось синхронизировать профиль: $e');
        }
      }
      if (!mounted) {
        return;
      }
      final admin = await _api.isAdmin();
      if (!mounted) {
        return;
      }
      setState(() => _isAdmin = admin);
      await _load();
    }
  }

  Future<void> _logout() async {
    await _api.clearToken();
    await _api.clearSavedEmail();
    _newOwnerId.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasToken = false;
      _isAdmin = false;
      _tasks = [];
      _appMsg = null;
    });
  }

  bool? get _filterIsDone {
    switch (_filterStatus) {
      case 'active':
        return false;
      case 'done':
        return true;
      default:
        return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _appMsg = null;
    });
    try {
      final tasks = await _api.listTasks(
        isDone: _filterIsDone,
        sort: _sortBy,
        order: _sortOrder,
      );
      if (mounted) {
        setState(() => _tasks = tasks);
      }
    } on UnauthorizedException {
      await _logout();
      if (mounted) {
        setState(() => _authMsg = 'Сессия истекла. Войдите снова.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _appMsg = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _validateAuth() {
    final em = _email.text.trim();
    final okEmail = em.isNotEmpty && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(em);
    final okPass = _password.text.length >= 6;
    return okEmail && okPass;
  }

  Future<void> _registerAndLogin() async {
    setState(() {
      _authMsg = null;
      _busy = true;
    });
    if (!_validateAuth()) {
      setState(() {
        _busy = false;
        _authMsg = 'Проверьте email и пароль (не короче 6 символов).';
      });
      return;
    }

    final base = normalizeApiBase(_baseUrl.text);
    await _api.saveBaseUrl(base);
    if (!mounted) {
      return;
    }
    setState(() => _api = TodoApi(baseUrl: base));

    final email = _email.text.trim();
    final password = _password.text;

    try {
      await _api.register(email: email, password: password);
    } on http.ClientException {
      if (mounted) {
        setState(() {
          _busy = false;
          _authMsg = 'Сеть: не удалось связаться с сервером. Запущен ли backend?';
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _authMsg = '$e';
        });
      }
      return;
    }

    try {
      await _api.login(email: email, password: password);
      await _api.saveEmail(email);
      if (!mounted) {
        return;
      }
      final admin = await _api.isAdmin();
      if (!mounted) {
        return;
      }
      setState(() {
        _hasToken = true;
        _isAdmin = admin;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _authMsg = 'Вход не выполнен: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addTask() async {
    setState(() {
      _appMsg = null;
      _titleInvalid = false;
    });
    final title = _newTitle.text.trim();
    if (title.isEmpty) {
      setState(() {
        _titleInvalid = true;
        _appMsg = 'Введите заголовок задачи.';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final desc = _newDesc.text.trim();
      final ownerRaw = _newOwnerId.text.trim();
      final assignId = _isAdmin && ownerRaw.isNotEmpty ? int.tryParse(ownerRaw) : null;
      if (_isAdmin && ownerRaw.isNotEmpty && assignId == null) {
        if (mounted) {
          setState(() => _appMsg = 'Введите числовой id владельца или оставьте поле пустым для себя.');
        }
        return;
      }
      await _api.createTask(
        title: title,
        description: desc.isEmpty ? null : desc,
        assignToUserId: assignId,
      );
      _newTitle.clear();
      _newDesc.clear();
      _newOwnerId.clear();
      await _load();
    } on UnauthorizedException {
      await _logout();
      if (mounted) {
        setState(() => _authMsg = 'Сессия истекла. Войдите снова.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _appMsg = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _fmtDate(DateTime d) {
    return DateFormat('dd.MM.yyyy, HH:mm', 'ru').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.fact_check_rounded, color: AppColors.accent, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Список задач',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          fontSize: 22,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Веб-приложение: регистрация, вход (JWT), задачи. Запустите API на порту 8000.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            if (!_hasToken) ...[
              _AuthCard(
                baseUrl: _baseUrl,
                email: _email,
                password: _password,
                busy: _busy,
                message: _authMsg,
                onSubmit: _registerAndLogin,
              ),
            ] else ...[
              _UserSessionCard(
                email: _email.text.trim(),
                isAdmin: _isAdmin,
                busy: _busy,
                onLogout: _logout,
              ),
              _TasksMainCard(
                isAdmin: _isAdmin,
                filterStatus: _filterStatus,
                sortBy: _sortBy,
                sortOrder: _sortOrder,
                onFilterStatus: (v) {
                  setState(() => _filterStatus = v);
                  _load();
                },
                onSortBy: (v) {
                  setState(() => _sortBy = v);
                  _load();
                },
                onSortOrder: (v) {
                  setState(() => _sortOrder = v);
                  _load();
                },
                onRefresh: _load,
                newTitle: _newTitle,
                newDesc: _newDesc,
                newOwnerId: _newOwnerId,
                titleInvalid: _titleInvalid,
                onAdd: _addTask,
                appMsg: _appMsg,
                busy: _busy,
                tasks: _tasks,
                fmtDate: _fmtDate,
                onToggle: (task, v) async {
                  if (v == null) {
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await _api.patchTask(task.id, isDone: v);
                    await _load();
                  } on UnauthorizedException {
                    await _logout();
                    if (mounted) {
                      setState(() => _authMsg = 'Сессия истекла. Войдите снова.');
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _appMsg = e.toString());
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _busy = false);
                    }
                  }
                },
                onDelete: (task) async {
                  setState(() => _busy = true);
                  try {
                    await _api.deleteTask(task.id);
                    await _load();
                  } on UnauthorizedException {
                    await _logout();
                    if (mounted) {
                      setState(() => _authMsg = 'Сессия истекла. Войдите снова.');
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _appMsg = e.toString());
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _busy = false);
                    }
                  }
                },
                onRename: (task, title) async {
                  if (title.isEmpty || title == task.title) {
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await _api.patchTask(task.id, title: title);
                    await _load();
                  } on UnauthorizedException {
                    await _logout();
                    if (mounted) {
                      setState(() => _authMsg = 'Сессия истекла. Войдите снова.');
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _appMsg = e.toString());
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _busy = false);
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShadowCard extends StatelessWidget {
  const _ShadowCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.baseUrl,
    required this.email,
    required this.password,
    required this.busy,
    required this.message,
    required this.onSubmit,
  });

  final TextEditingController baseUrl;
  final TextEditingController email;
  final TextEditingController password;
  final bool busy;
  final String? message;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LabeledField(
              icon: Icons.link_rounded,
              label: 'Адрес API',
              child: TextField(
                controller: baseUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  isDense: true,
                ),
              ),
            ),
            _LabeledField(
              icon: Icons.email_outlined,
              label: 'Email',
              child: TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            _LabeledField(
              icon: Icons.lock_outline_rounded,
              label: 'Пароль (от 6 символов)',
              child: TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text('Войти / зарегистрироваться', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errBorder),
                ),
                child: Text(message!, style: const TextStyle(color: AppColors.errText, fontSize: 14)),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              const _ShimmerLoadingBar(),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserSessionCard extends StatelessWidget {
  const _UserSessionCard({
    required this.email,
    required this.isAdmin,
    required this.busy,
    required this.onLogout,
  });

  final String email;
  final bool isAdmin;
  final bool busy;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                email.isEmpty
                    ? ''
                    : 'Вы вошли как $email${isAdmin ? ' · администратор' : ''}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ),
            FilledButton.icon(
              onPressed: busy ? null : onLogout,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryBtn,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Выйти', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksMainCard extends StatelessWidget {
  const _TasksMainCard({
    required this.isAdmin,
    required this.filterStatus,
    required this.sortBy,
    required this.sortOrder,
    required this.onFilterStatus,
    required this.onSortBy,
    required this.onSortOrder,
    required this.onRefresh,
    required this.newTitle,
    required this.newDesc,
    required this.newOwnerId,
    required this.titleInvalid,
    required this.onAdd,
    required this.appMsg,
    required this.busy,
    required this.tasks,
    required this.fmtDate,
    required this.onToggle,
    required this.onDelete,
    required this.onRename,
  });

  final bool isAdmin;
  final String filterStatus;
  final String sortBy;
  final String sortOrder;
  final void Function(String) onFilterStatus;
  final void Function(String) onSortBy;
  final void Function(String) onSortOrder;
  final VoidCallback onRefresh;
  final TextEditingController newTitle;
  final TextEditingController newDesc;
  final TextEditingController newOwnerId;
  final bool titleInvalid;
  final VoidCallback onAdd;
  final String? appMsg;
  final bool busy;
  final List<Task> tasks;
  final String Function(DateTime) fmtDate;
  final void Function(Task, bool?) onToggle;
  final void Function(Task) onDelete;
  final Future<void> Function(Task, String) onRename;

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _MiniLabel(icon: Icons.filter_list_rounded, text: 'Статус'),
                _DropdownChip<String>(
                  value: filterStatus,
                  items: const [
                    ('all', 'Все'),
                    ('active', 'Активные'),
                    ('done', 'Выполненные'),
                  ],
                  onChanged: onFilterStatus,
                ),
                const _MiniLabel(icon: Icons.swap_vert_rounded, text: 'Сортировка'),
                _DropdownChip<String>(
                  value: sortBy,
                  items: const [
                    ('created_at', 'По дате'),
                    ('status', 'По статусу'),
                  ],
                  onChanged: onSortBy,
                ),
                _DropdownChip<String>(
                  value: sortOrder,
                  items: const [
                    ('desc', 'По убыванию'),
                    ('asc', 'По возрастанию'),
                  ],
                  onChanged: onSortOrder,
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onRefresh,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.ghostBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Обновить', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _MiniLabel(icon: Icons.add_rounded, text: 'Новая задача'),
                      TextField(
                        controller: newTitle,
                        maxLength: 200,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                            const SizedBox.shrink(),
                        decoration: InputDecoration(
                          hintText: 'Заголовок',
                          isDense: true,
                          errorText: titleInvalid ? '' : null,
                          errorStyle: const TextStyle(height: 0),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: titleInvalid ? AppColors.danger : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => onAdd(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: FilledButton.icon(
                    onPressed: busy ? null : onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                    label: const Text('Добавить', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _LabeledField(
              icon: Icons.format_align_left_rounded,
              label: 'Описание (необязательно)',
              child: TextField(
                controller: newDesc,
                maxLength: 4000,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Описание',
                  isDense: true,
                ),
              ),
            ),
            if (isAdmin)
              _LabeledField(
                icon: Icons.badge_outlined,
                label: 'Владелец новой задачи (id; пусто — вы)',
                child: TextField(
                  controller: newOwnerId,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Например, 2',
                    isDense: true,
                  ),
                ),
              ),
            if (appMsg != null && appMsg!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errBorder),
                ),
                child: Text(appMsg!, style: const TextStyle(color: AppColors.errText, fontSize: 14)),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 10),
              const _ShimmerLoadingBar(),
            ],
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.line),
              itemBuilder: (context, i) {
                final t = tasks[i];
                return _TaskRow(
                  key: ValueKey(t.id),
                  task: t,
                  busy: busy,
                  showOwner: isAdmin,
                  fmtDate: fmtDate,
                  onToggle: (v) => onToggle(t, v),
                  onDelete: () => onDelete(t),
                  onRename: (title) => onRename(t, title),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    super.key,
    required this.task,
    required this.busy,
    required this.showOwner,
    required this.fmtDate,
    required this.onToggle,
    required this.onDelete,
    required this.onRename,
  });

  final Task task;
  final bool busy;
  final bool showOwner;
  final String Function(DateTime) fmtDate;
  final void Function(bool?) onToggle;
  final VoidCallback onDelete;
  final Future<void> Function(String title) onRename;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _editing = false;
  late TextEditingController _edit;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _edit = TextEditingController(text: widget.task.title);
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing && mounted) {
        _finishEdit();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.title != widget.task.title && !_editing) {
      _edit.text = widget.task.title;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _edit.dispose();
    super.dispose();
  }

  Future<void> _finishEdit() async {
    if (!_editing) {
      return;
    }
    final v = _edit.text.trim();
    setState(() => _editing = false);
    await widget.onRename(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final showEdited = t.updatedAt.difference(t.createdAt).inSeconds.abs() > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: t.isDone,
            onChanged: widget.busy ? null : widget.onToggle,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editing)
                  TextField(
                    controller: _edit,
                    focusNode: _focus,
                    maxLength: 200,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _finishEdit(),
                  )
                else
                  GestureDetector(
                    onTap: widget.busy
                        ? null
                        : () {
                            setState(() => _editing = true);
                          },
                    child: Tooltip(
                      message: 'Нажмите, чтобы редактировать',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: Text(
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            decoration: t.isDone ? TextDecoration.lineThrough : null,
                            color: t.isDone ? AppColors.muted : AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (t.description != null && t.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    t.description!,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.25),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (widget.showOwner) ...[
                      const Icon(Icons.person_outline, size: 13, color: AppColors.meta),
                      Text(
                        t.ownerEmail.isNotEmpty
                            ? '${t.ownerEmail} · id ${t.ownerId}'
                            : 'id ${t.ownerId}',
                        style: const TextStyle(fontSize: 12, color: AppColors.meta, height: 1.2),
                      ),
                      const Text('·', style: TextStyle(fontSize: 12, color: AppColors.meta)),
                    ],
                    const Icon(Icons.schedule_outlined, size: 13, color: AppColors.meta),
                    Text(
                      widget.fmtDate(t.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.meta, height: 1.2),
                    ),
                    if (showEdited) ...[
                      const Text('·', style: TextStyle(fontSize: 12, color: AppColors.meta)),
                      const Icon(Icons.edit_outlined, size: 12, color: AppColors.meta),
                      Text(
                        widget.fmtDate(t.updatedAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.meta, height: 1.2),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.busy ? null : widget.onDelete,
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
      ],
    );
  }
}

class _DropdownChip<T extends String> extends StatelessWidget {
  const _DropdownChip({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final void Function(T) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e.$1,
                  child: Text(e.$2, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}

class _ShimmerLoadingBar extends StatefulWidget {
  const _ShimmerLoadingBar();

  @override
  State<_ShimmerLoadingBar> createState() => _ShimmerLoadingBarState();
}

class _ShimmerLoadingBarState extends State<_ShimmerLoadingBar> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: const [AppColors.accent, Color(0xFF5EEAD4), AppColors.accent],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1 + _c.value * 2, 0),
              end: Alignment(1 + _c.value * 2, 0),
            ),
          ),
        );
      },
    );
  }
}
