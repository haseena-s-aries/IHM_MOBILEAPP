import 'http_override_initializer_stub.dart'
    if (dart.library.io) 'http_override_initializer_io.dart';

void initializeHttpOverrides() => initializeHttpOverridesImpl();

Future<bool> hasInternetConnection() => hasInternetConnectionImpl();
