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

import 'adha_bloc_test.mocks.dart';

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
      'emits [AdhaLoading, AdhaConversationsList] when conversations are loaded',
      () async {
        final expectedStates = [
          const AdhaLoading(),
          AdhaConversationsList(const []),
        ];
        expectLater(adhaBloc.stream, emitsInOrder(expectedStates));
        adhaBloc.add(const LoadConversations());
      },
    );
  });
}
