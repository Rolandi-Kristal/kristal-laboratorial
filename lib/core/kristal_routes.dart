import 'package:flutter/material.dart';

import '../screens/catalogo_exames_completo_screen.dart';
import '../screens/codigo_barras_etiquetas_screen.dart';
import '../screens/financeiro_sire_screen.dart';
import '../screens/servidor_nuvem_screen.dart';

class KristalRoutes {
  const KristalRoutes._();

  static const String servidorNuvem = '/servidor-nuvem';
  static const String financeiroSire = '/financeiro-sire';
  static const String codigoBarrasEtiquetas = '/codigo-barras-etiquetas';
  static const String catalogoExamesCompleto = '/catalogo-exames-completo';

  static Map<String, WidgetBuilder> routes() {
    return <String, WidgetBuilder>{
      servidorNuvem: (_) => const ServidorNuvemScreen(),
      financeiroSire: (_) => const FinanceiroSireScreen(),
      codigoBarrasEtiquetas: (_) => const CodigoBarrasEtiquetasScreen(),
      catalogoExamesCompleto: (_) => const CatalogoExamesCompletoScreen(),
    };
  }

  static Future<void> openServidorNuvem(BuildContext context) {
    return Navigator.of(context).pushNamed(servidorNuvem);
  }

  static Future<void> openFinanceiroSire(BuildContext context) {
    return Navigator.of(context).pushNamed(financeiroSire);
  }

  static Future<void> openCodigoBarrasEtiquetas(BuildContext context) {
    return Navigator.of(context).pushNamed(codigoBarrasEtiquetas);
  }

  static Future<void> openCatalogoExamesCompleto(BuildContext context) {
    return Navigator.of(context).pushNamed(catalogoExamesCompleto);
  }
}
