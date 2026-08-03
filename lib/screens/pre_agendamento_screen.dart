import 'package:flutter/material.dart';

class PreAgendamentoScreen extends StatelessWidget {
  const PreAgendamentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AgendaFormScreen(
      titulo: 'PrÃ©-agendamento',
      subtitulo: 'SolicitaÃ§Ãµes pendentes, confirmaÃ§Ã£o e preservaÃ§Ã£o histÃ³rica',
      icone: Icons.event_note_rounded,
      botaoSalvar: 'Salvar prÃ©-agendamento',
      mensagemSalvo: 'PrÃ©-agendamento registrado com retenÃ§Ã£o permanente.',
    );
  }
}

class AgendaFormScreen extends StatefulWidget {
  const AgendaFormScreen({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    required this.botaoSalvar,
    required this.mensagemSalvo,
  });

  final String titulo;
  final String subtitulo;
  final IconData icone;
  final String botaoSalvar;
  final String mensagemSalvo;

  @override
  State<AgendaFormScreen> createState() => _AgendaFormScreenState();
}

class _AgendaFormScreenState extends State<AgendaFormScreen> {
  final TextEditingController paciente = TextEditingController();
  final TextEditingController documento = TextEditingController();
  final TextEditingController telefone = TextEditingController();
  final TextEditingController exames = TextEditingController();
  final TextEditingController data = TextEditingController();
  final TextEditingController horario = TextEditingController();
  final TextEditingController observacoes = TextEditingController();

  String prioridade = 'Normal';
  String status = 'Tela real carregada.';

  @override
  void dispose() {
    paciente.dispose();
    documento.dispose();
    telefone.dispose();
    exames.dispose();
    data.dispose();
    horario.dispose();
    observacoes.dispose();
    super.dispose();
  }

  void salvar() {
    if (paciente.text.trim().isEmpty ||
        exames.text.trim().isEmpty ||
        horario.text.trim().isEmpty) {
      setState(() {
        status = 'Preencha paciente, exame/procedimento e horÃ¡rio.';
      });
      return;
    }

    setState(() {
      status = widget.mensagemSalvo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          Container(
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            color: const Color(0xFF18344F),
            child: Row(
              children: <Widget>[
                Icon(widget.icone, color: const Color(0xFF73D7FF), size: 34),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        widget.titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.subtitulo,
                        style: const TextStyle(
                          color: Color(0xFFB7D7F1),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2033),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF244B6D)),
                ),
                child: Column(
                  children: <Widget>[
                    _campo(paciente, 'Paciente *', Icons.person_rounded),
                    const SizedBox(height: 10),
                    _campo(documento, 'CPF / PREC-CP', Icons.badge_rounded),
                    const SizedBox(height: 10),
                    _campo(telefone, 'Telefone', Icons.phone_rounded),
                    const SizedBox(height: 10),
                    _campo(exames, 'Exames / Procedimentos *', Icons.biotech_rounded),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: _campo(data, 'Data', Icons.calendar_month_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _campo(horario, 'HorÃ¡rio *', Icons.schedule_rounded)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: prioridade,
                      isExpanded: true,
                      menuMaxHeight: 260,
                      dropdownColor: const Color(0xFF0D2033),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.priority_high_rounded),
                        filled: true,
                        fillColor: Color(0xFF071827),
                        border: OutlineInputBorder(),
                      ),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'Normal', child: Text('Normal')),
                        DropdownMenuItem<String>(value: 'PrioritÃ¡rio', child: Text('PrioritÃ¡rio')),
                        DropdownMenuItem<String>(value: 'Urgente', child: Text('Urgente')),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => prioridade = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    _campo(observacoes, 'ObservaÃ§Ãµes', Icons.notes_rounded, maxLines: 3),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: salvar,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(widget.botaoSalvar),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF06111D),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFC857),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF071827),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
