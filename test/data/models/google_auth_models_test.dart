import 'package:av_pointage/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoogleAuthStatus.fromValue', () {
    test('should_map_known_statuses_case_insensitively', () {
      expect(
        GoogleAuthStatus.fromValue('AUTHENTICATED'),
        GoogleAuthStatus.authenticated,
      );
      expect(
        GoogleAuthStatus.fromValue('needs_registration'),
        GoogleAuthStatus.needsRegistration,
      );
      expect(
        GoogleAuthStatus.fromValue(' PENDING_ACTIVATION '),
        GoogleAuthStatus.pendingActivation,
      );
    });

    test('should_return_unknown_when_value_is_missing_or_unexpected', () {
      expect(GoogleAuthStatus.fromValue(null), GoogleAuthStatus.unknown);
      expect(GoogleAuthStatus.fromValue(''), GoogleAuthStatus.unknown);
      expect(
        GoogleAuthStatus.fromValue('SOMETHING_NEW'),
        GoogleAuthStatus.unknown,
      );
    });
  });

  group('GoogleAuthResponse.fromJson', () {
    test('should_parse_needs_registration_and_attach_id_token', () {
      final response = GoogleAuthResponse.fromJson(
        {
          'success': true,
          'status': 'NEEDS_REGISTRATION',
          'message': 'Aucun compte',
          'user': null,
          'googleProfile': {
            'email': 'john.doe@gmail.com',
            'firstName': 'John',
            'lastName': null,
            'pictureUrl': null,
          },
        },
        idToken: 'tok',
      );

      expect(response.success, isTrue);
      expect(response.status, GoogleAuthStatus.needsRegistration);
      expect(response.message, 'Aucun compte');
      expect(response.user, isNull);
      expect(response.googleProfile?.email, 'john.doe@gmail.com');
      expect(response.googleProfile?.firstName, 'John');
      expect(response.googleProfile?.lastName, '');
      expect(response.idToken, 'tok');
    });

    test('should_parse_authenticated_user_with_token', () {
      final response = GoogleAuthResponse.fromJson(
        {
          'success': true,
          'status': 'AUTHENTICATED',
          'message': 'Connexion réussie',
          'user': {
            'uuid': 'u1',
            'email': 'john.doe@gmail.com',
            'firstName': 'John',
            'lastName': 'Doe',
            'isMailVerified': true,
            'isActive': true,
            'createdAt': '2026-06-24T11:08:36+02:00',
            'updatedAt': '2026-06-24T11:08:36+02:00',
            'token': 'api-token',
          },
          'googleProfile': null,
        },
        idToken: 'tok',
      );

      expect(response.status, GoogleAuthStatus.authenticated);
      expect(response.user?.uuid, 'u1');
      expect(response.user?.token, 'api-token');
      expect(response.googleProfile, isNull);
    });

    test('should_tolerate_missing_optional_fields', () {
      final response = GoogleAuthResponse.fromJson(
        {'status': 'PENDING_ACTIVATION'},
        idToken: 'tok',
      );

      expect(response.success, isTrue);
      expect(response.status, GoogleAuthStatus.pendingActivation);
      expect(response.message, '');
      expect(response.user, isNull);
      expect(response.googleProfile, isNull);
    });
  });

  group('GoogleProfile', () {
    test('should_build_initials_from_first_and_last_name', () {
      const profile = GoogleProfile(
        email: 'a@b.c',
        firstName: 'john',
        lastName: 'doe',
      );

      expect(profile.initials, 'JD');
      expect(profile.fullName, 'john doe');
    });

    test('should_fall_back_to_email_initial_when_names_are_empty', () {
      expect(const GoogleProfile(email: 'zoe@b.c').initials, 'Z');
      expect(const GoogleProfile(email: '').initials, '?');
    });
  });

  group('GoogleRegisterRequest.toJson', () {
    test('should_trim_names_and_omit_blank_ones', () {
      const request = GoogleRegisterRequest(
        idToken: 't',
        firstName: ' John ',
        lastName: '   ',
      );

      expect(request.toJson(), {'idToken': 't', 'firstName': 'John'});
    });

    test('should_send_only_id_token_when_names_are_null', () {
      expect(
        const GoogleRegisterRequest(idToken: 't').toJson(),
        {'idToken': 't'},
      );
    });
  });

  group('GoogleAuthRequest.toJson', () {
    test('should_send_id_token_only', () {
      expect(
        const GoogleAuthRequest(idToken: 'abc').toJson(),
        {'idToken': 'abc'},
      );
    });
  });
}
