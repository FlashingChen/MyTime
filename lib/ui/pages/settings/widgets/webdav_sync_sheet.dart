import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/categories/categories.dart';
import 'package:mytime/blocs/records/records.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/sync/sync_local_store.dart';
import 'package:mytime/data/sync/sync_service.dart';
import 'package:mytime/data/sync/webdav_sync_coordinator.dart';

/// Configures a secure WebDAV target and starts an explicit manual sync.
class WebDavSyncSheet extends StatefulWidget {
  const WebDavSyncSheet({super.key, required this.settings});

  final AppSettings settings;

  /// Opens the sheet while preserving the parent settings and sync providers.
  static Future<void> show(BuildContext context, AppSettings settings) {
    final settingsBloc = context.read<SettingsBloc>();
    final coordinator = context.read<WebDavSyncCoordinator>();
    final categoriesBloc = context.read<CategoriesBloc>();
    final recordsBloc = context.read<RecordsBloc>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiRepositoryProvider(
        providers: [RepositoryProvider.value(value: coordinator)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: settingsBloc),
            BlocProvider.value(value: categoriesBloc),
            BlocProvider.value(value: recordsBloc),
          ],
          child: WebDavSyncSheet(settings: settings),
        ),
      ),
    );
  }

  @override
  State<WebDavSyncSheet> createState() => _WebDavSyncSheetState();
}

class _WebDavSyncSheetState extends State<WebDavSyncSheet> {
  late final TextEditingController _endpoint;
  late final TextEditingController _username;
  late final TextEditingController _password;
  bool _obscurePassword = true;
  bool _syncing = false;
  String? _result;
  bool _resultIsError = false;

  @override
  void initState() {
    super.initState();
    _endpoint = TextEditingController(text: widget.settings.webDavEndpoint);
    _username = TextEditingController(text: widget.settings.webDavUsername);
    _password = TextEditingController(
      text: widget.settings.webDavPassword ?? '',
    );
    for (final controller in [_endpoint, _username, _password]) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _valid {
    final uri = Uri.tryParse(_endpoint.text.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        _username.text.trim().isNotEmpty &&
        _password.text.isNotEmpty;
  }

  WebDavConfiguration get _configuration => WebDavConfiguration(
    endpoint: _endpoint.text.trim(),
    username: _username.text.trim(),
    password: _password.text,
  );

  void _onChanged() => setState(() => _result = null);

  Future<void> _saveConfiguration() {
    final completion = Completer<void>();
    context.read<SettingsBloc>().add(
      WebDavSettingsChanged(
        endpoint: _endpoint.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        completion: completion,
      ),
    );
    return completion.future;
  }

  Future<void> _save() async {
    try {
      await _saveConfiguration();
      if (!mounted) return;
      setState(() {
        _result = '配置已保存到本机；密码使用系统安全存储。';
        _resultIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = '保存失败：配置未更改，请检查系统安全存储后重试。';
        _resultIsError = true;
      });
    }
  }

  Future<void> _sync() async {
    try {
      await _saveConfiguration();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = '保存失败：配置未更改，请检查系统安全存储后重试。';
        _resultIsError = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _syncing = true;
      _result = null;
    });
    try {
      final result = await context.read<WebDavSyncCoordinator>().synchronize(
        _configuration,
      );
      if (!mounted) return;
      setState(() {
        _result = switch (result.resolution) {
          SyncResolution.merged => '同步成功：已合并记录并安全上传。',
        };
        _resultIsError = false;
      });
      context.read<CategoriesBloc>().add(const LoadCategories());
      context.read<RecordsBloc>().add(LoadRecords());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = _messageFor(error);
        _resultIsError = true;
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _messageFor(Object error) {
    if (error is ArgumentError || error is FormatException) {
      return '同步失败：配置或远端数据格式无效。';
    }
    if (error is SocketException || error is HttpException) {
      return '同步失败：无法连接 WebDAV 服务，请检查地址、账户、密码和网络。';
    }
    if (error is SyncRollbackException) {
      return '同步失败：远端数据未能安全写入本机，原有数据已尝试恢复。';
    }
    return '同步失败：本机数据未更改，请稍后重试。';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'WebDAV 同步',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '本地编辑后将在网络可用时自动同步。同一记录冲突时保留本机版本。',
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _endpoint,
              label: '文档地址',
              hint: 'https://dav.example.com/mytime.json',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _field(controller: _username, label: '用户名'),
            const SizedBox(height: 12),
            _field(
              controller: _password,
              label: '密码',
              obscureText: _obscurePassword,
              suffix: IconButton(
                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                style: TextStyle(
                  color: _resultIsError
                      ? context.colorScheme.error
                      : context.colorScheme.primary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _valid && !_syncing ? _save : null,
                    child: const Text('保存配置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _valid && !_syncing ? _sync : null,
                    icon: const Icon(Icons.sync, size: 18),
                    label: Text(_syncing ? '同步中...' : '立即同步'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
    );
  }
}
