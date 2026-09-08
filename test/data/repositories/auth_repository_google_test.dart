import 'package:av_pointage/core/constants/api_constants.dart';
import 'package:av_pointage/core/errors/exceptions.dart';
import 'package:av_pointage/core/errors/failures.dart';
import 'package:av_pointage/data/models/models.dart';
import 'package:av_pointage/data/repositories/auth_repository.dart';
import 'package:av_pointage/data/services/google_sign_in_service.dart';
import 'package:av_pointage/data/services/http_service.dart';
import 'package:av_pointage/data/services/token_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpService extends Mock implements HttpService {}

class MockTokenStorageService extends Mock implements TokenStorageService {}

class MockGoogleSignInService extends Mock implements GoogleSignInService {}

const idToken = 'google-id-token';
const apiToken = 'api-token';
const userUuid = '550e8400-e29b-41d4-a716-446655440000';

Map<String, dynamic> authenticatedUserJson() => {
      'uuid': userUuid,
      'email': 'john.doe@gmail.com',
      'firstName': 'John',
      'lastName': 'Doe',
      'isMailVerified': true,
      'isActive': true,
      'createdAt': '2026-06-24T11:08:36+02:00',
      'updatedAt': '2026-06-24T11:08:36+02:00',
      'role': {'uuid': 'role-1', 'nom': 'Utilisateur', 'color': '#123456'},
      'token': apiToken,
      'pictureUrl': 'http://api/uploads/pictures/x.jpg',
      'isCouchette': false,
    };

Map<String, dynamic> needsRegistrationJson() => {
      'success': true,
      'status': 'NEEDS_REGISTRATION',
      'message':
          "Aucun compte n'existe pour cet email. Veuillez compléter votre inscription.",
      'user': null,
      'googleProfile': {
        'email': 'john.doe@gmail.com',
        'firstName': 'John',
        'lastName': 'Doe',
        'pictureUrl': 'https://lh3.googleusercontent.com/a/x',
      },
    };

void main() {
  late MockHttpService httpService;
  late MockTokenStorageService tokenStorage;
  late MockGoogleSignInService googleSignIn;
  late AuthRepository repository;

  setUp(() {
    httpService = MockHttpService();
    tokenStorage = MockTokenStorageService();
    googleSignIn = MockGoogleSignInService();

    // Le constructeur restaure la session : rien en cache par défaut.
    when(() => tokenStorage.getToken()).thenReturn(null);
    when(() => tokenStorage.getUserData()).thenReturn(null);
    when(() => tokenStorage.hasToken()).thenReturn(false);
    when(() => tokenStorage.saveToken(any())).thenAnswer((_) async {});
    when(() => tokenStorage.saveUserData(any())).thenAnswer((_) async {});
    when(() => tokenStorage.clearAll()).thenAnswer((_) async {});
    when(() => googleSignIn.signOut()).thenAnswer((_) async {});

    repository = AuthRepository(
      httpService: httpService,
      tokenStorage: tokenStorage,
      googleSignInService: googleSignIn,
    );
  });

  GoogleAuthResponse expectRight(dynamic result) => result.fold(
        (failure) => fail('Right attendu, reçu $failure'),
        (response) => response as GoogleAuthResponse,
      );

  Failure expectLeft(dynamic result) => result.fold(
        (failure) => failure as Failure,
        (response) => fail('Left attendu, reçu $response'),
      );

  group('signInWithGoogle', () {
    test('should_persist_session_when_status_is_authenticated', () async {
      when(() => googleSignIn.requestIdToken())
          .thenAnswer((_) async => idToken);
      when(() => httpService.post(AuthEndpoints.google,
          body: {'idToken': idToken})).thenAnswer((_) async => {
            'success': true,
            'status': 'AUTHENTICATED',
            'message': 'Connexion réussie',
            'user': authenticatedUserJson(),
            'googleProfile': null,
          });

      final response = expectRight(await repository.signInWithGoogle());

      expect(response.status, GoogleAuthStatus.authenticated);
      expect(response.user?.email, 'john.doe@gmail.com');
      expect(response.user?.token, apiToken);
      expect(response.googleProfile, isNull);
      expect(response.idToken, idToken);
      expect(repository.getCachedUser()?.uuid, userUuid);
      verify(() => tokenStorage.saveToken(apiToken)).called(1);
      verify(() => httpService.setAuthToken(apiToken)).called(1);
      verify(() => tokenStorage.saveUserData(any())).called(1);
    });

    test('should_return_profile_and_id_token_when_status_is_needs_registration',
        () async {
      when(() => googleSignIn.requestIdToken())
          .thenAnswer((_) async => idToken);
      when(() => httpService.post(AuthEndpoints.google,
              body: {'idToken': idToken}))
          .thenAnswer((_) async => needsRegistrationJson());

      final response = expectRight(await repository.signInWithGoogle());

      expect(response.status, GoogleAuthStatus.needsRegistration);
      expect(response.user, isNull);
      expect(
        response.googleProfile,
        const GoogleProfile(
          email: 'john.doe@gmail.com',
          firstName: 'John',
          lastName: 'Doe',
          pictureUrl: 'https://lh3.googleusercontent.com/a/x',
        ),
      );
      expect(response.idToken, idToken);
      expect(repository.getCachedUser(), isNull);
      verifyNever(() => tokenStorage.saveToken(any()));
    });

    test('should_return_cancelled_failure_without_calling_api_when_user_closes_picker',
        () async {
      when(() => googleSignIn.requestIdToken())
          .thenThrow(const OperationCancelledException());

      final failure = expectLeft(await repository.signInWithGoogle());

      expect(failure, isA<CancelledFailure>());
      verifyNever(() => httpService.post(any(), body: any(named: 'body')));
    });

    test('should_return_auth_failure_when_sdk_fails', () async {
      when(() => googleSignIn.requestIdToken()).thenThrow(
        const AuthException(
          message:
              'Connexion Google indisponible : configuration invalide (client OAuth, empreinte SHA-1 ou services Google Play).',
        ),
      );

      final failure = expectLeft(await repository.signInWithGoogle());

      expect(failure, isA<AuthFailure>());
      expect(failure.message, contains('configuration invalide'));
      verifyNever(() => httpService.post(any(), body: any(named: 'body')));
    });

    test('should_return_server_failure_with_api_message_when_api_returns_400',
        () async {
      when(() => googleSignIn.requestIdToken())
          .thenAnswer((_) async => idToken);
      when(() => httpService.post(AuthEndpoints.google,
          body: {'idToken': idToken})).thenThrow(
        const ServerException(
          message: "Le compte n'est pas activé",
          statusCode: 400,
        ),
      );

      final failure = expectLeft(await repository.signInWithGoogle());

      expect(failure, isA<ServerFailure>());
      expect(failure.message, "Le compte n'est pas activé");
      expect((failure as ServerFailure).statusCode, 400);
      verifyNever(() => tokenStorage.saveToken(any()));
    });

    test('should_return_network_failure_when_offline', () async {
      when(() => googleSignIn.requestIdToken())
          .thenAnswer((_) async => idToken);
      when(() => httpService.post(AuthEndpoints.google,
          body: {'idToken': idToken})).thenThrow(const NetworkException());

      final failure = expectLeft(await repository.signInWithGoogle());

      expect(failure, isA<NetworkFailure>());
    });

    test('should_return_server_failure_when_authenticated_without_user',
        () async {
      when(() => googleSignIn.requestIdToken())
          .thenAnswer((_) async => idToken);
      when(() => httpService.post(AuthEndpoints.google,
          body: {'idToken': idToken})).thenAnswer((_) async => {
            'success': true,
            'status': 'AUTHENTICATED',
            'message': 'Connexion réussie',
            'user': null,
            'googleProfile': null,
          });

      final failure = expectLeft(await repository.signInWithGoogle());

      expect(failure, isA<ServerFailure>());
      verifyNever(() => tokenStorage.saveToken(any()));
    });
  });

  group('registerWithGoogle', () {
    test('should_return_pending_activation_when_register_succeeds', () async {
      when(() => httpService.post(AuthEndpoints.googleRegister, body: {
            'idToken': idToken,
            'firstName': 'John',
            'lastName': 'Doe',
          })).thenAnswer((_) async => {
            'success': true,
            'status': 'PENDING_ACTIVATION',
            'message':
                'Votre compte a été créé via Google. Il doit être activé par un administrateur avant la première connexion.',
            'user': null,
            'googleProfile': null,
          });

      final response = expectRight(await repository.registerWithGoogle(
        const GoogleRegisterRequest(
          idToken: idToken,
          firstName: 'John',
          lastName: 'Doe',
        ),
      ));

      expect(response.status, GoogleAuthStatus.pendingActivation);
      expect(response.message, contains('activé par un administrateur'));
      expect(response.user, isNull);
      expect(response.idToken, idToken);
      verifyNever(() => tokenStorage.saveToken(any()));
    });

    test('should_omit_blank_names_so_api_falls_back_to_google_values',
        () async {
      when(() => httpService.post(AuthEndpoints.googleRegister,
          body: {'idToken': idToken})).thenAnswer((_) async => {
            'success': true,
            'status': 'PENDING_ACTIVATION',
            'message': 'ok',
          });

      final result = await repository.registerWithGoogle(
        const GoogleRegisterRequest(
          idToken: idToken,
          firstName: '   ',
          lastName: '',
        ),
      );

      expect(result.isRight(), isTrue);
      verify(() => httpService.post(AuthEndpoints.googleRegister,
          body: {'idToken': idToken})).called(1);
    });

    test('should_return_server_failure_when_email_already_registered',
        () async {
      when(() => httpService.post(AuthEndpoints.googleRegister,
          body: any(named: 'body'))).thenThrow(
        const ServerException(
          message: 'Un compte existe déjà pour cet email : john.doe@gmail.com',
          statusCode: 400,
        ),
      );

      final failure = expectLeft(await repository.registerWithGoogle(
        const GoogleRegisterRequest(idToken: idToken),
      ));

      expect(failure, isA<ServerFailure>());
      expect(failure.message, startsWith('Un compte existe déjà'));
    });

    test('should_return_network_failure_when_offline', () async {
      when(() => httpService.post(AuthEndpoints.googleRegister,
          body: any(named: 'body'))).thenThrow(const NetworkException());

      final failure = expectLeft(await repository.registerWithGoogle(
        const GoogleRegisterRequest(idToken: idToken),
      ));

      expect(failure, isA<NetworkFailure>());
    });
  });

  group('logout', () {
    test('should_clear_local_session_and_sign_out_from_google', () async {
      final result = await repository.logout();

      expect(result.isRight(), isTrue);
      verify(() => tokenStorage.clearAll()).called(1);
      verify(() => httpService.setAuthToken(null)).called(1);
      verify(() => googleSignIn.signOut()).called(1);
    });
  });
}
