import 'package:flutter_test/flutter_test.dart';
import 'package:kristal_laboratorial/models/equipment_connection_config.dart';
import 'package:kristal_laboratorial/services/equipment_protocol_service.dart';
import 'package:kristal_laboratorial/services/serial_port_service.dart';

void main() {
  group('EquipmentProtocolService', () {
    test('interpreta múltiplos resultados em frames ASTM reais', () {
      const String message = '\x021H|\\^&|||ANALISADOR|||||||P|1\r\x03AA\r\n'
          '\x022O|1|ATD000123||^^^GLI\r\x03BB\r\n'
          '\x023R|1|^^^GLI|5.30|mmol/L|3.9-5.8\r\x03CC\r\n'
          '\x024R|2|^^^CRE|NEGATIVO||\r\x03DD\r\n'
          '\x025L|1|N\r\x03EE\r\n';

      final Map<String, dynamic> parsed = EquipmentProtocolService.instance
          .parseResultado(protocolo: 'ASTM', raw: message);
      final List<dynamic> results = parsed['resultados'] as List<dynamic>;

      expect(parsed['sampleId'], 'ATD000123');
      expect(results, hasLength(2));
      expect((results[0] as Map<String, String>)['exame'], '^^^GLI');
      expect((results[0] as Map<String, String>)['valor'], '5.30');
      expect((results[1] as Map<String, String>)['valor'], 'NEGATIVO');
      expect(parsed['raw'], message);
    });

    test('interpreta envelope MLLP HL7 e preserva valor textual', () {
      const String message =
          '\x0bMSH|^~\\&|ANALISADOR|LAB|KRISTAL|HMR|202608101900||ORU^R01|1|P|2.3.1\r'
          'PID|1||PAC0001||PACIENTE^TESTE\r'
          'OBR|1|PED0001|ATD000124|^^^CULT\r'
          'OBX|1|ST|CULT||Não detectado|||N|||F\r\x1c\r';

      final Map<String, dynamic> parsed = EquipmentProtocolService.instance
          .parseResultado(protocolo: 'HL7', raw: message);
      final List<dynamic> results = parsed['resultados'] as List<dynamic>;

      expect(parsed['patientId'], 'PAC0001');
      expect(parsed['sampleId'], 'ATD000124');
      expect(results, hasLength(1));
      expect((results.single as Map<String, String>)['valor'], 'Não detectado');
      expect(parsed['raw'], message);
    });

    test('rejeita mensagem vazia', () {
      expect(
        () => EquipmentProtocolService.instance
            .parseResultado(protocolo: 'ASTM', raw: ''),
        throwsFormatException,
      );
    });
  });

  group('SerialPortService', () {
    EquipmentConnectionConfig config({
      String porta = 'COM12',
      String baudRate = '9600',
      String dataBits = '8',
      String stopBits = '1',
      String parity = 'NONE',
    }) {
      return EquipmentConnectionConfig.empty().copyWith(
        tipoConexao: 'SERIAL_USB',
        portaCom: porta,
        baudRate: baudRate,
        dataBits: dataBits,
        stopBits: stopBits,
        paridade: parity,
      );
    }

    test('gera definição DCB válida para a API do Windows', () {
      expect(
        SerialPortService.instance.dcbDefinition(config()),
        'COM12 baud=9600 parity=n data=8 stop=1',
      );
      expect(
        SerialPortService.instance
            .dcbDefinition(config(parity: 'EVEN', stopBits: '2')),
        'COM12 baud=9600 parity=e data=8 stop=2',
      );
    });

    test('rejeita porta, baud rate e framing inválidos', () {
      expect(
        () => SerialPortService.instance.dcbDefinition(config(porta: 'USB1')),
        throwsArgumentError,
      );
      expect(
        () => SerialPortService.instance.dcbDefinition(config(baudRate: '0')),
        throwsArgumentError,
      );
      expect(
        () => SerialPortService.instance.dcbDefinition(config(dataBits: '9')),
        throwsArgumentError,
      );
      expect(
        () => SerialPortService.instance
            .dcbDefinition(config(parity: 'INVALIDA')),
        throwsArgumentError,
      );
    });
  });
}
