class LabIndicatorsService {
  static Map<String, int> build(
          {required int pacientes,
          required int pedidos,
          required int resultados,
          required int criticos}) =>
      {
        'Pacientes': pacientes,
        'Pedidos': pedidos,
        'Resultados': resultados,
        'Críticos': criticos
      };
}
