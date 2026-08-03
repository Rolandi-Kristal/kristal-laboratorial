import 'dart:async';

import 'package:flutter/material.dart';

import '../core/kristal_operational_rules.dart';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_constants.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WindowListener {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  final FocusNode usuarioFocus = FocusNode();
  final FocusNode senhaFocus = FocusNode();

  bool _senhaOculta = true;
  bool _carregando = false;
  bool _isMaximized = false;

  String _erro = '';
  String _status = 'Acesso restrito. Informe suas credenciais.';
  int _tentativasFalhas = 0;

  Timer? _bloqueioTimer;
  DateTime? _bloqueadoAte;

  bool get _estaBloqueado {
    final DateTime? ate = _bloqueadoAte;
    if (ate == null) return false;
    return DateTime.now().isBefore(ate);
  }

  int get _segundosBloqueioRestantes {
    final DateTime? ate = _bloqueadoAte;
    if (ate == null) return 0;
    final int seconds = ate.difference(DateTime.now()).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);
    _sincronizarEstadoJanela();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        usuarioFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);

    _bloqueioTimer?.cancel();

    usuarioController.dispose();
    senhaController.dispose();

    usuarioFocus.dispose();
    senhaFocus.dispose();

    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (!mounted) return;
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (!mounted) return;
    setState(() => _isMaximized = false);
  }

  Future<void> _sincronizarEstadoJanela() async {
    try {
      final bool maximized = await windowManager.isMaximized();
      if (!mounted) return;
      setState(() => _isMaximized = maximized);
    } catch (_) {
      // Mantém a tela funcional mesmo se a API nativa de janela não responder.
    }
  }

  Future<void> _minimizarJanela() async {
    try {
      await windowManager.minimize();
    } catch (_) {
      // Proteção para execução em ambiente sem suporte ao window_manager.
    }
  }

  Future<void> _maximizarOuRestaurarJanela() async {
    try {
      final bool maximized = await windowManager.isMaximized();

      if (maximized) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }

      await _sincronizarEstadoJanela();
    } catch (_) {
      // Proteção para execução em ambiente sem suporte ao window_manager.
    }
  }

  Future<void> _fecharSistema() async {
    if (_carregando) return;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Fechar sistema'),
          content: const Text(
            'Deseja realmente fechar a KRISTAL LABORATORIAL?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.close),
              label: const Text('Fechar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await windowManager.close();
    } catch (_) {
      if (!mounted) return;
      SystemNavigator.pop();
    }
  }

  void _iniciarBloqueioTemporario() {
    _bloqueadoAte = DateTime.now().add(const Duration(seconds: 20));
    _bloqueioTimer?.cancel();

    _bloqueioTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!_estaBloqueado) {
        timer.cancel();
        setState(() {
          _bloqueadoAte = null;
          _status = 'Bloqueio encerrado. Informe suas credenciais.';
          _erro = '';
        });
        return;
      }

      setState(() {
        _status =
            'Muitas tentativas inválidas. Aguarde $_segundosBloqueioRestantes segundo(s).';
      });
    });
  }

  void _registrarFalhaLogin() {
    _tentativasFalhas += 1;

    if (_tentativasFalhas >= 5) {
      _iniciarBloqueioTemporario();
    }
  }

  void _limparErroAoDigitar() {
    if (_erro.isEmpty) return;
    setState(() => _erro = '');
  }

  Future<void> _entrar() async {
    if (_carregando) return;

    if (_estaBloqueado) {
      setState(() {
        _erro =
            'Acesso temporariamente bloqueado. Aguarde $_segundosBloqueioRestantes segundo(s).';
      });
      return;
    }

    final String usuario = usuarioController.text.trim();
    final String senha = senhaController.text;

    if (usuario.isEmpty) {
      setState(() {
        _erro = 'Informe o usuário.';
        _status = 'Usuário obrigatório.';
      });
      usuarioFocus.requestFocus();
      return;
    }

    if (senha.isEmpty) {
      setState(() {
        _erro = 'Informe a senha.';
        _status = 'Senha obrigatória.';
      });
      senhaFocus.requestFocus();
      return;
    }

    setState(() {
      _carregando = true;
      _erro = '';
      _status = 'Validando credenciais...';
    });

    AuthSession? session;

    try {
      session = await AuthService.instance.login(
        login: usuario,
        password: senha,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _carregando = false;
        _erro = 'Falha ao validar acesso: $e';
        _status = 'Erro de autenticação.';
      });

      return;
    }

    if (!mounted) return;

    if (session == null) {
      _registrarFalhaLogin();

      setState(() {
        _carregando = false;
        _erro = 'Usuário ou senha inválidos.';
        _status = _estaBloqueado
            ? 'Muitas tentativas inválidas. Aguarde $_segundosBloqueioRestantes segundo(s).'
            : 'Acesso negado. Verifique as credenciais.';
      });

      senhaController.clear();
      senhaFocus.requestFocus();
      return;
    }

    usuarioController.clear();
    senhaController.clear();

    setState(() {
      _carregando = false;
      _erro = '';
      _status = 'Acesso autorizado.';
      _tentativasFalhas = 0;
      _bloqueadoAte = null;
    });

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(session: session!),
      ),
    );
  }

  Widget _buildBrasao() {
    return Semantics(
      label: 'Brasão do sistema KRISTAL LABORATORIAL',
      image: true,
      child: SizedBox(
        width: 340,
        height: 340,
        child: Image.asset(
          AppConstants.logoPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return const Icon(
              Icons.biotech,
              size: 180,
              color: Colors.white70,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPainelIdentidade() {
    return Expanded(
      flex: 5,
      child: Container(
        color: const Color(0xFF102235),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildBrasao(),
                const SizedBox(height: 24),
                const Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConstants.appSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  AppConstants.institutionName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 38),
                const Text(
                  KristalOperationalRules.fullDeveloperCredit,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampoUsuario() {
    return TextField(
      controller: usuarioController,
      focusNode: usuarioFocus,
      enabled: !_carregando && !_estaBloqueado,
      autofocus: true,
      autofillHints: const <String>[AutofillHints.username],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Usuário',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => _limparErroAoDigitar(),
      onSubmitted: (_) {
        senhaFocus.requestFocus();
      },
    );
  }

  Widget _buildCampoSenha() {
    return TextField(
      controller: senhaController,
      focusNode: senhaFocus,
      enabled: !_carregando && !_estaBloqueado,
      obscureText: _senhaOculta,
      autofillHints: const <String>[AutofillHints.password],
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Senha',
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _senhaOculta ? 'Mostrar senha' : 'Ocultar senha',
          icon: Icon(
            _senhaOculta ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: _carregando
              ? null
              : () {
                  setState(() => _senhaOculta = !_senhaOculta);
                },
        ),
      ),
      onChanged: (_) => _limparErroAoDigitar(),
      onSubmitted: (_) => _entrar(),
    );
  }

  Widget _buildMensagemErro() {
    if (_erro.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF4A1111),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _erro,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBox() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF102235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(
              _estaBloqueado ? Icons.lock_clock : Icons.shield,
              color: _estaBloqueado ? Colors.amberAccent : Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoEntrar() {
    return SizedBox(
      height: 60,
      child: ElevatedButton.icon(
        onPressed: (_carregando || _estaBloqueado) ? null : _entrar,
        icon: _carregando
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login),
        label: Text(
          _carregando ? 'VALIDANDO...' : 'ENTRAR',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }

  Widget _buildPainelLogin() {
    return Expanded(
      flex: 4,
      child: Container(
        color: const Color(0xFF08131D),
        padding: const EdgeInsets.all(54),
        child: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(
                      Icons.verified_user,
                      color: Color(0xFF4EA3FF),
                      size: 58,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ACESSO AO SISTEMA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildStatusBox(),
                    const SizedBox(height: 22),
                    _buildCampoUsuario(),
                    const SizedBox(height: 20),
                    _buildCampoSenha(),
                    _buildMensagemErro(),
                    const SizedBox(height: 30),
                    _buildBotaoEntrar(),
                    const SizedBox(height: 35),
                    const Text(
                      'Ambiente protegido • Acesso auditado • KRISTAL LABORATORIAL',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlesJanela() {
    return Positioned(
      top: 10,
      right: 12,
      child: Row(
        children: <Widget>[
          _WindowButton(
            tooltip: 'Minimizar',
            icon: Icons.remove,
            onPressed: _minimizarJanela,
          ),
          const SizedBox(width: 6),
          _WindowButton(
            tooltip: _isMaximized ? 'Restaurar' : 'Maximizar',
            icon: _isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
            onPressed: _maximizarOuRestaurarJanela,
          ),
          const SizedBox(width: 6),
          _WindowButton(
            tooltip: 'Fechar',
            icon: Icons.close,
            danger: true,
            onPressed: _fecharSistema,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.enter): const _LoginIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadEnter): const _LoginIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _CloseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _LoginIntent: CallbackAction<_LoginIntent>(
            onInvoke: (_) {
              _entrar();
              return null;
            },
          ),
          _CloseIntent: CallbackAction<_CloseIntent>(
            onInvoke: (_) {
              _fecharSistema();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: Stack(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _buildPainelIdentidade(),
                    _buildPainelLogin(),
                  ],
                ),
                _buildControlesJanela(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  const _WindowButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: danger ? const Color(0xFF7A1E1E) : const Color(0xFF1F4E79),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 38,
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginIntent extends Intent {
  const _LoginIntent();
}

class _CloseIntent extends Intent {
  const _CloseIntent();
}
