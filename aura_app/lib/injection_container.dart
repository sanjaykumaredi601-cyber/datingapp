import 'package:get_it/get_it.dart';
import 'core/services/firestore_service.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/radar/domain/repositories/radar_profile_repository.dart';
import 'features/radar/data/repositories/radar_profile_repository_impl.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/data/repositories/chat_repository_impl.dart';
import 'features/settings/domain/repositories/support_ticket_repository.dart';
import 'features/settings/data/repositories/support_ticket_repository_impl.dart';
import 'features/chat/presentation/screens/chat_screen.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  // Register Singleton Services
  if (!sl.isRegistered<SocketService>()) {
    sl.registerLazySingleton<SocketService>(() => SocketService());
  }

  if (!sl.isRegistered<FirestoreService>()) {
    sl.registerLazySingleton<FirestoreService>(() => FirestoreService());
  }

  // Register Production Repositories
  if (!sl.isRegistered<AuthRepository>()) {
    sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl());
  }

  if (!sl.isRegistered<RadarProfileRepository>()) {
    sl.registerLazySingleton<RadarProfileRepository>(() => RadarProfileRepositoryImpl());
  }

  if (!sl.isRegistered<ChatRepository>()) {
    sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl());
  }

  if (!sl.isRegistered<SupportTicketRepository>()) {
    sl.registerLazySingleton<SupportTicketRepository>(() => SupportTicketRepositoryImpl());
  }
}
