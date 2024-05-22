import 'package:get_it/get_it.dart';
import 'location_service.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton<LocationService>(LocationService());
}
