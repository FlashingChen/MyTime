import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mytime/blocs/settings/settings_event.dart';
import 'package:mytime/blocs/settings/settings_bloc.dart';
import 'package:mytime/core/theme/app_theme_ext.dart';
import 'package:mytime/data/models/app_settings.dart';
import 'package:mytime/data/services/ai_insight_service.dart';

/// Form sheet for configuring an OpenAI-compatible chat completion endpoint.
class AiModelConfigSheet extends StatefulWidget {
  const AiModelConfigSheet({super.key, required this.settings, this.service});

  final AppSettings settings;
  final AiInsightService? service;

  static Future<void> show(BuildContext context, AppSettings settings) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<SettingsBloc>(),
        child: AiModelConfigSheet(settings: settings),
      ),
    );
  }

  @override
  State<AiModelConfigSheet> createState() => _AiModelConfigSheetState();
}

class _AiModelConfigSheetState extends State<AiModelConfigSheet> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  bool _obscureKey = true;
  bool _testing = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.settings.aiBaseUrl);
    _apiKey = TextEditingController(text: widget.settings.aiApiKey ?? '');
    _model = TextEditingController(text: widget.settings.aiModel ?? '');
    for (final controller in [_baseUrl, _apiKey, _model]) {
      controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  bool get _valid {
    final uri = Uri.tryParse(_baseUrl.text.trim());
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        _apiKey.text.trim().isNotEmpty &&
        _model.text.trim().isNotEmpty;
  }

  void _onChanged() => setState(() => _result = null);

  AiConfiguration get _configuration => AiConfiguration(
    baseUrl: _baseUrl.text.trim(),
    apiKey: _apiKey.text.trim(),
    model: _model.text.trim(),
  );

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await (widget.service ?? AiInsightService()).testConnection(
        _configuration,
      );
      if (mounted) setState(() => _result = '连接成功');
    } on AiInsightException catch (error) {
      if (mounted) setState(() => _result = '连接失败：${error.message}');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _save() {
    context.read<SettingsBloc>().add(
      AiSettingsChanged(
        baseUrl: _baseUrl.text.trim(),
        apiKey: _apiKey.text.trim(),
        model: _model.text.trim(),
      ),
    );
    Navigator.pop(context);
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
              'AI 模型配置',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _baseUrl,
              label: '服务地址',
              hint: 'https://api.example.com/v1',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _apiKey,
              label: 'API Key',
              obscureText: _obscureKey,
              suffix: IconButton(
                tooltip: _obscureKey ? '显示 API Key' : '隐藏 API Key',
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
                icon: Icon(
                  _obscureKey
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _field(controller: _model, label: '模型名称', hint: '由服务商提供'),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Text(
                _result!,
                style: TextStyle(
                  color: _result == '连接成功'
                      ? Colors.green
                      : context.colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _valid && !_testing ? _test : null,
                    child: Text(_testing ? '测试中...' : '测试连接'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _valid && !_testing ? _save : null,
                    child: const Text('保存配置'),
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
