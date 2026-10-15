import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/adha/bloc/adha_bloc.dart';
import 'package:wanzo/features/adha/bloc/adha_event.dart';
import 'package:wanzo/features/adha/bloc/adha_state.dart';
import 'package:wanzo/features/adha/repositories/adha_repository.dart';
import 'package:wanzo/features/adha/models/adha_message.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:wanzo/features/auth/repositories/auth_repository.dart';
import 'package:wanzo/features/dashboard/repositories/operation_journal_repository.dart';
import 'package:wanzo/features/adha/services/audio_streaming_service.dart'
    as audio;
import 'package:wanzo/features/adha/services/adha_stream_service.dart';
import 'package:wanzo/features/adha/models/adha_stream_models.dart';

import 'adha_bloc_test.mocks.dart';

// Services audio et temps réel factices : les vrais ouvrent des canaux de
// plateforme (micro, haut-parleur, socket) indisponibles en test.
class _AudioFactice extends Fake implements audio.AudioStreamingService {
  @override
  Stream<audio.AudioConnectionState> get connectionState =>
      const Stream.empty();
  @override
  Stream<bool> get isRecording => const Stream.empty();
  @override
  Stream<bool> get isPlaying => const Stream.empty();
  @override
  Stream<double> get audioLevel => const Stream.empty();
  @override
  void dispose() {}
}

class _FluxFactice extends Fake implements AdhaStreamService {
  @override
  Stream<AdhaStreamChunkEvent> get chunkStream => const Stream.empty();
  @override
  Stream<AdhaAudioChunkEvent> get audioChunkStream => const Stream.empty();
  @override
  Stream<AdhaStreamConnectionState> get connectionState =>
      const Stream.empty();
  @override
  void dispose() {}
}

@GenerateMocks([AdhaRepository, AuthRepository, OperationJournalRepository])
void main() {
  late AdhaBloc adhaBloc;
  late MockAdhaRepository mockAdhaRepository;
  late MockAuthRepository mockAuthRepository;
  late MockOperationJournalRepository mockOperationJournalRepository;

  setUp(() {
    mockAdhaRepository = MockAdhaRepository();
    mockAuthRepository = MockAuthRepository();
    mockOperationJournalRepository = MockOperationJournalRepository();

    when(
      mockAdhaRepository.getConversations(),
    ).thenAnswer((_) async => <AdhaConversation>[]);
    when(mockAdhaRepository.getConversation(any)).thenAnswer((_) async => null);
    when(mockAdhaRepository.saveConversation(any)).thenAnswer((_) async {
      return;
    });
    when(mockAdhaRepository.deleteConversation(any)).thenAnswer((_) async {
      return;
    });
    when(
      mockAdhaRepository.sendMessage(
        conversationId: anyNamed('conversationId'),
        message: anyNamed('message'),
        contextInfo: anyNamed('contextInfo'),
      ),
    ).thenAnswer(
      (_) async => (
        content: 'Mocked AI Response',
        conversationId: 'mock-conv-id',
      ),
    );

    adhaBloc = AdhaBloc(
      adhaRepository: mockAdhaRepository,
      authRepository: mockAuthRepository,
      operationJournalRepository: mockOperationJournalRepository,
      audioStreamingService: _AudioFactice(),
      streamService: _FluxFactice(),
    );
  });

  tearDown(() {
    adhaBloc.close();
  });

  group('AdhaBloc', () {
    test('initial state is correct', () {
      expect(adhaBloc.state, equals(const AdhaInitial()));
    });

    test(
      // Sans conversation active, le chargement revient à l'écran d'accueil.
      'emits [AdhaLoading, AdhaInitial] when no conversation is active',
      () async {
        final expectedStates = [
          const AdhaLoading(),
          const AdhaInitial(),
        ];
        final attendu = expectLater(
          adhaBloc.stream,
          emitsInOrder(expectedStates),
        );
        adhaBloc.add(const LoadConversations());
        await attendu;
      },
    );
  });
}
