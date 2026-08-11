import 'package:flutter/material.dart';

import '../core/app_constants.dart';

class DesenvolvedorSistemaScreen extends StatelessWidget {
  const DesenvolvedorSistemaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          _Header(
            title: 'Desenvolvedor / Sistema',
            subtitle:
                'Créditos, identidade, versão e dados técnicos do KRISTAL',
            icon: Icons.developer_board_rounded,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const <Widget>[
                        _SectionTitle(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Crédito oficial do sistema',
                        ),
                        SizedBox(height: 18),
                        _CreditCard(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        _SectionTitle(
                          icon: Icons.info_rounded,
                          title: 'Dados do sistema',
                        ),
                        SizedBox(height: 14),
                        _InfoRow(
                            label: 'Sistema', value: 'KRISTAL LABORATORIAL'),
                        _InfoRow(
                          label: 'Descrição',
                          value:
                              'Sistema Avançado Adaptativo para Laboratório de Análises Clínicas',
                        ),
                        _InfoRow(
                            label: 'Instituição',
                            value: 'Hospital Militar de Resende'),
                        _InfoRow(label: 'Versão', value: '1.0.0+1'),
                        _InfoRow(
                            label: 'Plataforma principal', value: 'Windows'),
                        _InfoRow(
                            label: 'Modo operacional',
                            value:
                                'Local, nuvem, portal e integrações por servidor'),
                        _InfoRow(
                            label: 'Retenção de dados',
                            value:
                                'Permanente, com arquivamento lógico sem exclusão física'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const <Widget>[
                        _SectionTitle(
                          icon: Icons.security_rounded,
                          title: 'Princípios técnicos fixos',
                        ),
                        SizedBox(height: 14),
                        _Bullet(
                            'Todos os dados clínicos e laboratoriais devem ser preservados permanentemente.'),
                        _Bullet(
                            'Registros antigos devem ir para histórico, sem exclusão física.'),
                        _Bullet(
                            'Rotas de servidor local, nuvem, portal e SIRE devem permanecer separadas.'),
                        _Bullet(
                            'Menus e botões devem abrir telas reais e executar ações reais.'),
                        _Bullet(
                            'Assinatura profissional e responsável técnico devem constar nos laudos quando cadastrados.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF18344F),
        border: Border(bottom: BorderSide(color: Color(0xFF26577D))),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF0E88C6).withOpacity(0.24),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3EC6FF)),
            ),
            child: Icon(icon, color: const Color(0xFF73D7FF), size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFB7D7F1),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Image.asset(
            AppConstants.hmrLogoPath,
            width: 52,
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_hospital_rounded,
              color: Color(0xFF73D7FF),
              size: 42,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF071827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC857), width: 1.2),
      ),
      child: Column(
        children: const <Widget>[
          Text(
            'Desenvolvedor: 3° Sgt Rolandi',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFC857),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'H Mil Resende',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFC857),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2033),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF244B6D)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: const Color(0xFF73D7FF)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 170,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF73D7FF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF34D399), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFF06111D),
      child: const Text(
        'Desenvolvedor: 3° Sgt Rolandi\nH Mil Resende',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFFFFC857),
          fontWeight: FontWeight.w900,
          height: 1.25,
        ),
      ),
    );
  }
}
