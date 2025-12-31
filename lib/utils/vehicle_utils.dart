import 'dart:math';

class VehicleUtils {
  static final Random _random = Random();

  /// Araç resmini getirir.
  /// [brand]: Araç markası
  /// [model]: Araç modeli
  /// [index]: İstenen resim indeksi (opsiyonel)
  /// [vehicleId]: Araç ID'si (opsiyonel, tutarlı rastgelelik için)
  static String? getVehicleImage(String brand, String model, {int? index, String? vehicleId}) {
    // Helper to get index
    int getIndex(int max) {
      if (index != null) return index.clamp(1, max);
      if (vehicleId != null) {
        return (vehicleId.hashCode.abs() % max) + 1;
      }
      return 1 + _random.nextInt(max);
    }

    // 1. Bavora
    if (brand == 'Bavora') {
      if (model == 'E Serisi') return 'assets/car_images/bavora/e_series/e_series_${getIndex(6)}.png';
      if (model == 'A Serisi') return 'assets/car_images/bavora/a_series/a_series_${getIndex(6)}.png';
      if (model == 'D Serisi') return 'assets/car_images/bavora/d_series/d_series_${getIndex(6)}.png';
      // C Serisi ve diğerleri için eski yapı (bavora_X.png)
      return 'assets/car_images/bavora/bavora_${getIndex(6)}.png';
    }
    
    // 2. Renauva
    if (brand == 'Renauva') {
      if (model == 'Slim') return 'assets/car_images/renauva/slim/slim_${getIndex(6)}.png';
      if (model == 'Magna') return 'assets/car_images/renauva/magna/magna_${getIndex(6)}.png';
      if (model == 'Flow') return 'assets/car_images/renauva/flow/flow_${getIndex(6)}.png';
      if (model == 'Signa') return 'assets/car_images/renauva/signa/signa_${getIndex(6)}.png';
      if (model == 'Tallion') return 'assets/car_images/renauva/tallion/tallion_${getIndex(6)}.png';
    }

    // 3. Fortran
    if (brand == 'Fortran') {
      if (model == 'Odak') return 'assets/car_images/fortran/odak/odak_${getIndex(6)}.png';
      if (model == 'Vista') return 'assets/car_images/fortran/vista/vista_${getIndex(6)}.png';
      if (model == 'Avger') return 'assets/car_images/fortran/avger/avger_${getIndex(6)}.png';
      if (model == 'Tupa') return 'assets/car_images/fortran/tupa/tupa_${getIndex(6)}.png';
    }

    // 4. Oplon
    if (brand == 'Oplon') {
      if (model == 'Mornitia') return 'assets/car_images/oplon/mornitia/mornitia_${getIndex(6)}.png';
      if (model == 'Lorisa') return 'assets/car_images/oplon/lorisa/lorisa_${getIndex(6)}.png';
      if (model == 'Tasra') return 'assets/car_images/oplon/tasra/tasra_${getIndex(6)}.png';
    }

    // 5. Fialto
    if (brand == 'Fialto') {
      if (model == 'Agna') return 'assets/car_images/fialto/agna/agna_${getIndex(4)}.png';
      if (model == 'Lagua') return 'assets/car_images/fialto/lagua/lagua_${getIndex(6)}.png';
      if (model == 'Zorno') return 'assets/car_images/fialto/zorno/zorno_${getIndex(6)}.png';
    }

    // 6. Volkstar
    if (brand == 'Volkstar') {
      if (model == 'Paso') return 'assets/car_images/volkstar/paso/paso_${getIndex(6)}.png';
      if (model == 'Colo') return 'assets/car_images/volkstar/colo/colo_${getIndex(6)}.png';
      if (model == 'Jago') return 'assets/car_images/volkstar/jago/jago_${getIndex(6)}.png';
      if (model == 'Tenis') return 'assets/car_images/volkstar/tenis/tenis_${getIndex(6)}.png';
    }

    // 7. Mercurion
    if (brand == 'Mercurion') {
      if (model == '1 Serisi') return 'assets/car_images/mercurion/1/1_serisi_${getIndex(6)}.png';
      if (model == 'GJE') return 'assets/car_images/mercurion/gje/gje_${getIndex(6)}.png';
      if (model == '3 Serisi') return 'assets/car_images/mercurion/3/3_serisi_${getIndex(6)}.png';
      if (model == '5 Serisi') return 'assets/car_images/mercurion/5/5_serisi_${getIndex(6)}.png';
      if (model == '8 Serisi') return 'assets/car_images/mercurion/8/8_serisi_${getIndex(6)}.png';
    }

    // 8. Hanto
    if (brand == 'Hanto') {
      if (model == 'Vice') return 'assets/car_images/hanto/vice/vice_${getIndex(4)}.png';
      if (model == 'VHL') return 'assets/car_images/hanto/vhl/vhl_${getIndex(6)}.png';
      if (model == 'Caz') return 'assets/car_images/hanto/caz/caz_${getIndex(6)}.png';
    }

    // 9. Audira
    if (brand == 'Audira') {
      if (model == 'B3') return 'assets/car_images/audira/b3/b3_${getIndex(4)}.png';
      if (model == 'B4') return 'assets/car_images/audira/b4/b4_${getIndex(6)}.png';
      if (model == 'B5') return 'assets/car_images/audira/b5/b5_${getIndex(6)}.png';
      if (model == 'B6') return 'assets/car_images/audira/b6/b6_${getIndex(4)}.png';
    }

    // 10. Koyoro
    if (brand == 'Koyoro') {
      if (model == 'Airoko') return 'assets/car_images/koyoro/airoko/airoko_${getIndex(6)}.png';
      if (model == 'Karma') return 'assets/car_images/koyoro/karma/karma_${getIndex(6)}.png';
      if (model == 'Lotus') return 'assets/car_images/koyoro/lotus/lotus_${getIndex(6)}.png';
    }

    // Fallback: Varsayılan Tek Resim Yapısı
    final safeModelName = model.replaceAll(' ', '_');
    return 'assets/car_images/$brand/$safeModelName.png';
  }
}
