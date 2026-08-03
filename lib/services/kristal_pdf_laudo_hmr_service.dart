import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/app_constants.dart';
import '../models/professional_signature_model.dart';
import '../models/technical_responsible_model.dart';
import 'professional_signature_service.dart';
import 'technical_responsible_service.dart';

class KristalPdfExamItem {
  const KristalPdfExamItem({
    required this.name,
    required this.result,
    required this.unit,
    required this.reference,
    required this.material,
    required this.method,
    this.previousResults = const <String>[],
    this.observation,
  });

  final String name;
  final String result;
  final String unit;
  final String reference;
  final String material;
  final String method;
  final List<String> previousResults;
  final String? observation;
}

class KristalPdfPatientInfo {
  const KristalPdfPatientInfo({
    required this.name,
    required this.birthDate,
    required this.age,
    required this.sex,
    required this.attendanceNumber,
    required this.agreement,
    required this.precCp,
    required this.collectionDate,
    required this.reportDate,
    required this.requestingProfessional,
  });

  final String name;
  final String birthDate;
  final String age;
  final String sex;
  final String attendanceNumber;
  final String agreement;
  final String precCp;
  final String collectionDate;
  final String reportDate;
  final String requestingProfessional;
}

class KristalPdfLaudoHmrService {
  KristalPdfLaudoHmrService._();

  static final KristalPdfLaudoHmrService instance =
      KristalPdfLaudoHmrService._();

  Future<File> generateExamReport({
    required KristalPdfPatientInfo patient,
    required List<KristalPdfExamItem> exams,
    required String outputDirectory,
    String? fileName,
  }) async {
    final ProfessionalSignatureModel signature =
        await ProfessionalSignatureService.instance.load();
    final TechnicalResponsibleModel technicalResponsible =
        await TechnicalResponsibleService.instance.load();

    final pw.Document document = pw.Document(
      title: 'Laudo Laboratorial - ${patient.name}',
      author: AppConstants.appFullTitle,
      creator: AppConstants.developerCredit,
    );

    final pw.MemoryImage? hmrLogo = await _loadImage(AppConstants.hmrLogoPath);
    final pw.MemoryImage? secondLogo = await _loadImage(AppConstants.logoPath);
    final pw.MemoryImage? signatureImage =
        await _loadImage(signature.signatureImagePath);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 28),
        header: (pw.Context context) {
          return _buildHeader(
            hmrLogo: hmrLogo,
            secondLogo: secondLogo,
          );
        },
        footer: (pw.Context context) {
          return _buildFooter(
            technicalResponsible: technicalResponsible,
            pageNumber: context.pageNumber,
            pagesCount: context.pagesCount,
          );
        },
        build: (pw.Context context) {
          return <pw.Widget>[
            _buildPatientBlock(patient),
            pw.SizedBox(height: 10),
            pw.Divider(borderStyle: pw.BorderStyle.dashed),
            pw.SizedBox(height: 8),
            for (final KristalPdfExamItem exam in exams) ...<pw.Widget>[
              _buildExamBlock(exam),
              pw.SizedBox(height: 12),
              pw.Divider(borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 8),
            ],
            pw.SizedBox(height: 10),
            _buildProfessionalSignature(
              signature: signature,
              signatureImage: signatureImage,
            ),
          ];
        },
      ),
    );

    final Directory directory = Directory(outputDirectory);
    await directory.create(recursive: true);

    final String safeFileName = fileName ??
        'laudo_${patient.name.replaceAll(RegExp(r"[^a-zA-Z0-9]+"), "_")}_${DateTime.now().millisecondsSinceEpoch}.pdf';

    final File file = File('$outputDirectory${Platform.pathSeparator}$safeFileName');
    await file.writeAsBytes(await document.save());
    return file;
  }

  pw.Widget _buildHeader({
    required pw.MemoryImage? hmrLogo,
    required pw.MemoryImage? secondLogo,
  }) {
    return pw.Column(
      children: <pw.Widget>[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            _imageOrPlaceholder(hmrLogo, width: 54, height: 54),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: <pw.Widget>[
                  pw.Text(
                    AppConstants.institutionName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'LABORATÓRIO DE ANÁLISES CLÍNICAS',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'KRISTAL LABORATORIAL - SISTEMA ADAPTATIVO AVANÇADO',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    'Rodovia Presidente Dutra, km 306 S/N - Agulhas Negras - Resende/RJ',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                  pw.Text(
                    '(24) 3388-4745',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            _imageOrPlaceholder(secondLogo, width: 54, height: 54),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildPatientBlock(KristalPdfPatientInfo patient) {
    pw.Widget row(String leftLabel, String leftValue, String rightLabel,
        String rightValue) {
      return pw.Row(
        children: <pw.Widget>[
          pw.Expanded(child: _labelValue(leftLabel, leftValue)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: _labelValue(rightLabel, rightValue)),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        row('Paciente', patient.name, 'Nasc.', patient.birthDate),
        row('Idade', patient.age, 'Convênio', patient.agreement),
        row('Sexo', patient.sex, 'PREC-CP', patient.precCp),
        row('Nº Atendimento', patient.attendanceNumber, 'Data Coleta',
            patient.collectionDate),
        row('Solicitante', patient.requestingProfessional, 'Data Laudo',
            patient.reportDate),
      ],
    );
  }

  pw.Widget _buildExamBlock(KristalPdfExamItem exam) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          exam.name.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: <pw.Widget>[
            pw.Text(
              'Resultado:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(width: 180),
            pw.Text(
              '${exam.result} ${exam.unit}'.trim(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        if (exam.reference.trim().isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 6),
          pw.Text(
            'Valores de referência: ${exam.reference}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        if (exam.previousResults.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Text(
            'Resultados Anteriores',
            style: const pw.TextStyle(fontSize: 8),
          ),
          for (final String item in exam.previousResults)
            pw.Text(
              item,
              style: const pw.TextStyle(fontSize: 7),
            ),
        ],
        if (exam.observation != null && exam.observation!.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Nota: ${exam.observation}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Material: ${exam.material}   Método: ${exam.method}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  pw.Widget _buildProfessionalSignature({
    required ProfessionalSignatureModel signature,
    required pw.MemoryImage? signatureImage,
  }) {
    if (signature.professionalName.trim().isEmpty &&
        signatureImage == null) {
      return pw.SizedBox(height: 62);
    }

    return pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: <pw.Widget>[
          if (signatureImage != null)
            pw.Image(signatureImage, width: 120, height: 58, fit: pw.BoxFit.contain)
          else
            pw.SizedBox(height: 58),
          pw.Container(width: 170, height: 0.6, color: PdfColors.black),
          pw.Text(
            signature.professionalName.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            '${signature.rankOrGrade} - ${signature.specialty}'.trim(),
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6),
          ),
          pw.Text(
            signature.fullCouncil,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 6),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter({
    required TechnicalResponsibleModel technicalResponsible,
    required int pageNumber,
    required int pagesCount,
  }) {
    return pw.Column(
      children: <pw.Widget>[
        pw.SizedBox(height: 8),
        pw.Text(
          technicalResponsible.printableLine,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              'PNCQ',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'SELO DE QUALIDADE',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'SBAC',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 1, color: PdfColors.black),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página $pageNumber de $pagesCount',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
      ],
    );
  }

  pw.Widget _labelValue(String label, String value) {
    return pw.RichText(
      text: pw.TextSpan(
        children: <pw.TextSpan>[
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.TextSpan(
            text: value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _imageOrPlaceholder(
    pw.MemoryImage? image, {
    required double width,
    required double height,
  }) {
    if (image == null) {
      return pw.Container(
        width: width,
        height: height,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey),
        ),
      );
    }

    return pw.Image(image, width: width, height: height, fit: pw.BoxFit.contain);
  }

  Future<pw.MemoryImage?> _loadImage(String path) async {
    final String cleanPath = path.trim();

    if (cleanPath.isEmpty) {
      return null;
    }

    final File file = File(cleanPath);

    if (await file.exists()) {
      return pw.MemoryImage(await file.readAsBytes());
    }

    return null;
  }
}
