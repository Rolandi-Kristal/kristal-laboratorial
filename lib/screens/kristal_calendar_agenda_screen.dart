import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_constants.dart';
import '../models/kristal_appointment_record.dart';
import '../services/kristal_appointment_store_service.dart';

class KristalCalendarAgendaScreen extends StatefulWidget {
  const KristalCalendarAgendaScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
    required this.preAppointmentMode,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String type;
  final bool preAppointmentMode;

  @override
  State<KristalCalendarAgendaScreen> createState() =>
      _KristalCalendarAgendaScreenState();
}

class _KristalCalendarAgendaScreenState
    extends State<KristalCalendarAgendaScreen> {
  final KristalAppointmentStoreService _store =
      KristalAppointmentStoreService.instance;

  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _documentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _examController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  String _priority = 'normal';
  bool _loading = true;
  String _status = 'Carregando agenda...';

  List<KristalAppointmentRecord> _selectedRecords =
      <KristalAppointmentRecord>[];
  Map<DateTime, int> _dayCount = <DateTime, int>{};

  @override
  void initState() {
    super.initState();
    _timeController.text = DateFormat('HH:mm').format(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _documentController.dispose();
    _phoneController.dispose();
    _examController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final List<KristalAppointmentRecord> records =
          await _store.loadByDate(type: widget.type, date: _selectedDate);
      final Map<DateTime, int> countByDay = await _store.countByDay(
        type: widget.type,
        month: _visibleMonth,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedRecords = records;
        _dayCount = countByDay;
        _status = 'Agenda carregada.';
      });
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Erro de arquivo: ${error.message}';
      });
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Dados inválidos: ${error.message}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final String patientName = _patientNameController.text.trim();
    final String exam = _examController.text.trim();
    final String time = _timeController.text.trim();

    if (patientName.isEmpty || exam.isEmpty || time.isEmpty) {
      setState(() {
        _status = 'Preencha paciente, exame/procedimento e horário.';
      });
      return;
    }

    await _store.create(
      type: widget.type,
      patientName: patientName,
      patientDocument: _documentController.text.trim(),
      phone: _phoneController.text.trim(),
      examDescription: exam,
      appointmentDate: _selectedDate,
      appointmentTime: time,
      priority: _priority,
      notes: _notesController.text.trim(),
      status: widget.preAppointmentMode ? 'pre_agendado' : 'agendado',
    );

    _patientNameController.clear();
    _documentController.clear();
    _phoneController.clear();
    _examController.clear();
    _notesController.clear();

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = widget.preAppointmentMode
          ? 'Pré-agendamento salvo com retenção permanente.'
          : 'Agendamento salvo com retenção permanente.';
    });
  }

  Future<void> _archive(String id) async {
    await _store.archive(
      type: widget.type,
      id: id,
      reason: 'Registro preservado permanentemente para consulta histórica.',
    );

    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _status = 'Registro arquivado sem exclusão física.';
    });
  }

  Future<void> _confirmPreAppointment(String id) async {
    await _store.confirmPreAppointment(id);
    await _load();

    if (!mounted) {
      return;
    }

    setState(() {
      _status =
          'Pré-agendamento confirmado. O registro original foi preservado no histórico.';
    });
  }

  Future<void> _export() async {
    try {
      final File file = await _store.exportJson(widget.type);

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Exportado para ${file.path}';
      });
    } on FileSystemException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Erro ao exportar: ${error.message}';
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month);
    });
    _load();
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF06111D),
      child: Column(
        children: <Widget>[
          _Header(
            title: widget.title,
            subtitle: widget.subtitle,
            icon: widget.icon,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool narrow = constraints.maxWidth < 940;

                  if (narrow) {
                    return SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          _buildCalendarAndForm(),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 460,
                            child: _buildSchedulePanel(),
                          ),
                        ],
                      ),
                    );
                  }

                  return Row(
                    children: <Widget>[
                      SizedBox(
                        width: 430,
                        child: _buildCalendarAndForm(),
                      ),
                      const SizedBox(width: 18),
                      Expanded(child: _buildSchedulePanel()),
                    ],
                  );
                },
              ),
            ),
          ),
          _Footer(status: _status),
        ],
      ),
    );
  }

  Widget _buildCalendarAndForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildCalendarHeader(),
            const SizedBox(height: 10),
            _buildCalendar(),
            const SizedBox(height: 14),
            _field(
              controller: _patientNameController,
              label: 'Paciente *',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _documentController,
              label: 'CPF / PREC-CP',
              icon: Icons.badge_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _phoneController,
              label: 'Telefone',
              icon: Icons.phone_rounded,
            ),
            const SizedBox(height: 10),
            _field(
              controller: _examController,
              label: 'Exames / Procedimentos *',
              icon: Icons.biotech_rounded,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _field(
                    controller: _timeController,
                    label: 'Horário *',
                    icon: Icons.schedule_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _prioritySelector()),
              ],
            ),
            const SizedBox(height: 10),
            _field(
              controller: _notesController,
              label: 'Observações',
              icon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                widget.preAppointmentMode
                    ? 'Salvar pré-agendamento'
                    : 'Salvar agendamento',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _export,
              icon: const Icon(Icons.file_download_rounded),
              label: const Text('Exportar agenda'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(42),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
          color: const Color(0xFF73D7FF),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy', 'pt_BR')
                .format(_visibleMonth)
                .toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
          color: const Color(0xFF73D7FF),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final DateTime firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final int leadingEmpty = firstDay.weekday % 7;
    final int totalDays =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final int totalCells = ((leadingEmpty + totalDays) / 7).ceil() * 7;

    return Column(
      children: <Widget>[
        Row(
          children: const <Widget>[
            _WeekDay('D'),
            _WeekDay('S'),
            _WeekDay('T'),
            _WeekDay('Q'),
            _WeekDay('Q'),
            _WeekDay('S'),
            _WeekDay('S'),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          itemCount: totalCells,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (BuildContext context, int index) {
            final int dayNumber = index - leadingEmpty + 1;

            if (dayNumber < 1 || dayNumber > totalDays) {
              return const SizedBox.shrink();
            }

            final DateTime day = DateTime(
              _visibleMonth.year,
              _visibleMonth.month,
              dayNumber,
            );
            final bool selected = DateUtils.isSameDay(day, _selectedDate);
            final int count = _dayCount[day] ?? 0;

            return InkWell(
              onTap: () => _selectDay(day),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1F527C)
                      : const Color(0xFF071827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: count > 0
                        ? const Color(0xFFFFC857)
                        : const Color(0xFF244B6D),
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Center(
                      child: Text(
                        dayNumber.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFC857),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              count.toString(),
                              style: const TextStyle(
                                color: Color(0xFF06111D),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSchedulePanel() {
    final String selectedDateText =
        DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${widget.title} - $selectedDateText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                color: const Color(0xFF73D7FF),
                tooltip: 'Atualizar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _selectedRecords.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhum registro para a data selecionada.',
                          style: TextStyle(
                            color: Color(0xFFB7D7F1),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _selectedRecords.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          return _recordTile(_selectedRecords[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _recordTile(KristalAppointmentRecord record) {
    final bool archived = record.archived;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: archived ? const Color(0xFF182536) : const Color(0xFF071827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: archived ? const Color(0xFFFFC857) : const Color(0xFF244B6D),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            archived ? Icons.archive_rounded : Icons.event_available_rounded,
            color: archived ? const Color(0xFFFFC857) : const Color(0xFF73D7FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                _chip('Horário', record.appointmentTime),
                _chip('Paciente', record.patientName),
                _chip('CPF/PREC-CP', record.patientDocument),
                _chip('Telefone', record.phone),
                _chip('Exames', record.examDescription),
                _chip('Prioridade', record.priority),
                _chip('Status', record.status),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (widget.preAppointmentMode && !archived)
            IconButton(
              tooltip: 'Confirmar como agendamento',
              onPressed: () => _confirmPreAppointment(record.id),
              icon: const Icon(Icons.event_available_rounded),
              color: const Color(0xFF34D399),
            ),
          archived
              ? const Text(
                  'Histórico',
                  style: TextStyle(
                    color: Color(0xFFFFC857),
                    fontWeight: FontWeight.w900,
                  ),
                )
              : IconButton(
                  tooltip: 'Arquivar sem excluir',
                  onPressed: () => _archive(record.id),
                  icon: const Icon(Icons.archive_outlined),
                  color: const Color(0xFFFFC857),
                ),
        ],
      ),
    );
  }

  Widget _prioritySelector() {
    return DropdownButtonFormField<String>(
      value: _priority,
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
        DropdownMenuItem<String>(value: 'normal', child: Text('Normal')),
        DropdownMenuItem<String>(
          value: 'prioritário',
          child: Text('Prioritário'),
        ),
        DropdownMenuItem<String>(value: 'urgente', child: Text('Urgente')),
      ],
      onChanged: (String? value) {
        if (value == null) {
          return;
        }

        setState(() {
          _priority = value;
        });
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
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

  Widget _chip(String label, String value) {
    return SizedBox(
      width: 210,
      child: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF73D7FF),
                fontWeight: FontWeight.w900,
              ),
            ),
            TextSpan(
              text: value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: const Color(0xFF0D2033),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF244B6D)),
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

class _WeekDay extends StatelessWidget {
  const _WeekDay(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF73D7FF),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: const Color(0xFF06111D),
      child: Text(
        status,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFFC857),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
