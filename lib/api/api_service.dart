import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bsciapp/config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 20);
  static const _storage = FlutterSecureStorage();

  String get baseUrl => AppConfig.apiBaseUrl;
  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<Map<String, String>> _headers({bool authenticated = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      return {
        'status': 'error',
        'message': 'The server returned an invalid response.',
      };
    }
  }

  String _error(Map<String, dynamic> data, String fallback) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return data['message']?.toString() ?? fallback;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: await _headers(),
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200 && data['token'] is String) {
        await saveToken(data['token'] as String);
        return {'status': 'success', 'user': data['user']};
      }
      return {'status': 'error', 'message': _error(data, 'Login failed.')};
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'The server took too long to respond.',
      };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not connect to the BSCI server.',
      };
    }
  }

  Future<Map<String, dynamic>> registerApplication({
    required Map<String, String> fields,
    required String photoPath,
    required String identityPath,
    required List<String> academicCertificatePaths,
    String? trainingCertificatePath,
  }) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/register'))
            ..headers.addAll({'Accept': 'application/json'})
            ..fields.addAll(fields)
            ..files.add(await http.MultipartFile.fromPath('photo', photoPath))
            ..files.add(
              await http.MultipartFile.fromPath(
                'identity_attachment',
                identityPath,
              ),
            );
      for (final path in academicCertificatePaths) {
        request.files.add(
          await http.MultipartFile.fromPath('academic_certificates[]', path),
        );
      }
      if (trainingCertificatePath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'training_certificate',
            trainingCertificatePath,
          ),
        );
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 90)),
      );
      final data = _decode(response);
      return response.statusCode == 201
          ? {'status': 'success', 'message': data['message']}
          : {
              'status': 'error',
              'message': _error(data, 'Registration failed.'),
              'errors': data['errors'],
            };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'The server took too long to respond.',
      };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not connect to the BSCI server.',
      };
    }
  }

  Future<List<dynamic>> getMembershipTiers() =>
      _getList('/membership-tiers', 'membership_tiers');
  Future<Map<String, dynamic>> getHomepage() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/homepage'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) return _decode(response);
    } catch (_) {}
    return {};
  }

  Future<List<dynamic>> getEvents() => _getList('/events', 'events');
  Future<List<dynamic>> getSliders() => _getList('/sliders', 'sliders');
  Future<List<dynamic>> getNotices() => _getList('/notices', 'notices');
  Future<Map<String, dynamic>> getMembers({
    int page = 1,
    String? query,
    String? tier,
  }) async {
    try {
      final queryParams = <String, String>{'page': '$page'};
      if (query != null && query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }
      if (tier != null && tier.trim().isNotEmpty && tier != 'All') {
        queryParams['tier'] = tier.trim();
      }
      final uri = Uri.parse(
        '$baseUrl/members',
      ).replace(queryParameters: queryParams);
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) return _decode(response);
    } catch (_) {}
    return {
      'status': 'error',
      'message': 'Could not load the member directory.',
    };
  }

  Future<List<dynamic>> getPublications() =>
      _getList('/publications', 'publications');
  Future<Map<String, dynamic>> getPublication(int publicationId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/publications/$publicationId'),
            headers: await _headers(),
          )
          .timeout(_timeout);
      final data = _decode(response);
      return response.statusCode == 200
          ? data
          : {
              'status': 'error',
              'message': _error(data, 'Publication not found.'),
            };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not update publication analytics.',
      };
    }
  }

  Future<Map<String, dynamic>> recordPublicationDownload(
    int publicationId,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/publications/$publicationId/download'),
            headers: await _headers(),
          )
          .timeout(_timeout);
      final data = _decode(response);
      return response.statusCode == 200
          ? data
          : {
              'status': 'error',
              'message': _error(data, 'Download could not be recorded.'),
            };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not update download analytics.',
      };
    }
  }

  Future<Map<String, dynamic>> getPublicationReaderPages(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) return _decode(response);
    } catch (_) {}
    return {
      'status': 'error',
      'pages': <dynamic>[],
      'message': 'The book reader is still being prepared.',
    };
  }

  Future<List<dynamic>> getFaculties() => _getList('/faculties', 'faculties');
  Future<List<dynamic>> getCases() => _getList('/cases', 'cases');
  Future<Map<String, dynamic>> getCaseDetails(int caseId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/cases/$caseId'), headers: await _headers())
          .timeout(_timeout);
      final data = _decode(response);
      return response.statusCode == 200
          ? {'status': 'success', 'case': data['case']}
          : {'status': 'error', 'message': _error(data, 'Case not found.')};
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not load this clinical case.',
      };
    }
  }

  Future<Map<String, dynamic>> submitCaseDiscussion(
    int caseId,
    String comment,
  ) => _authenticatedJson(
    'POST',
    '/cases/$caseId/discussions',
    body: {'comment_body': comment},
  );

  Future<Map<String, dynamic>> voteCasePoll(int caseId, int optionIndex) =>
      _authenticatedJson(
        'POST',
        '/cases/$caseId/vote',
        body: {'option_index': optionIndex.toString()},
      );
  Future<List<dynamic>> getGallery() => _getList('/gallery', 'photos');
  Future<List<dynamic>> getPastCommittees() =>
      _getList('/past-committees', 'sessions');

  Future<Map<String, dynamic>> getAbout() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/about'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return (_decode(response)['about'] as Map?)?.cast<String, dynamic>() ??
            {};
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>?> getConference() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/conference'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return _decode(response)['conference'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/settings'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return (_decode(response)['settings'] as Map?)
                ?.cast<String, dynamic>() ??
            {};
      }
    } catch (_) {}
    return {};
  }

  Future<List<dynamic>> _getList(String path, String key) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'), headers: await _headers())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return (_decode(response)[key] as List?) ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> getMemberProfile() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/member/profile'),
            headers: await _headers(authenticated: true),
          )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200) {
        return {'status': 'success', 'data': data};
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearToken();
      }
      return {
        'status': 'error',
        'message': _error(data, 'Failed to retrieve profile.'),
        'code': response.statusCode,
      };
    } catch (_) {
      return {'status': 'error', 'message': 'Network connection failed.'};
    }
  }

  Future<Map<String, dynamic>> getMemberOverview() =>
      _authenticatedJson('GET', '/member/overview');

  Future<Map<String, dynamic>> requestMembershipRenewal() =>
      _authenticatedJson('POST', '/member/membership/renew');

  Future<Map<String, dynamic>> submitMembershipPaymentReference({
    required String provider,
    required String reference,
  }) => _authenticatedJson(
    'POST',
    '/member/membership/payment',
    body: {'provider': provider, 'provider_reference': reference},
  );

  Future<Map<String, dynamic>> downloadMembershipDocument(String path) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(authenticated: true),
          )
          .timeout(_timeout);
      if (response.statusCode == 200 &&
          response.headers['content-type']?.contains('application/pdf') ==
              true) {
        return {
          'status': 'success',
          'bytes': Uint8List.fromList(response.bodyBytes),
        };
      }
      final data = _decode(response);
      return {
        'status': 'error',
        'message': _error(data, 'Document is not available.'),
      };
    } catch (_) {
      return {'status': 'error', 'message': 'Could not download document.'};
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, String> fields) =>
      _authenticatedJson('PUT', '/member/profile', body: fields);

  Future<Map<String, dynamic>> submitAbstract({
    required int conferenceId,
    required String submittedName,
    required String submittedEmail,
    required String designation,
    required String workplace,
    required String title,
    required String abstractSummary,
    required String filePath,
  }) => _multipart(
    '/submit-abstract',
    {
      'conference_id': conferenceId.toString(),
      'submitted_name': submittedName,
      'submitted_email': submittedEmail,
      'designation': designation,
      'workplace': workplace,
      'title': title,
      'abstract_summary': abstractSummary,
    },
    'manuscript',
    filePath,
  );

  Future<Map<String, dynamic>> submitCase({
    required String title,
    required String description,
    String? filePath,
  }) => _multipart(
    '/submit-case',
    {'title': title, 'description': description},
    'attachment',
    filePath,
  );

  Future<Map<String, dynamic>> _authenticatedJson(
    String method,
    String path, {
    Map<String, String>? body,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers.addAll(await _headers(authenticated: true));
      if (body != null) request.body = jsonEncode(body);
      final streamed = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'status': 'success', 'data': data};
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearToken();
      }
      return {
        'status': 'error',
        'message': _error(data, 'Request failed.'),
        'code': response.statusCode,
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'The server took too long to respond.',
      };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not connect to the BSCI server.',
      };
    }
  }

  Future<Map<String, dynamic>> _multipart(
    String path,
    Map<String, String> fields,
    String fileField,
    String? filePath,
  ) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'))
        ..headers.addAll(await _headers(authenticated: true))
        ..headers.remove('Content-Type')
        ..fields.addAll(fields);
      if (filePath != null && filePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(fileField, filePath),
        );
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 60)),
      );
      final data = _decode(response);
      return response.statusCode >= 200 && response.statusCode < 300
          ? {
              'status': 'success',
              'message': data['message'] ?? 'Submitted successfully.',
            }
          : {'status': 'error', 'message': _error(data, 'Submission failed.')};
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Upload failed. Check your connection and file.',
      };
    }
  }

  Future<bool> hasValidSession() async {
    if (await getToken() == null) return false;
    return (await getMemberProfile())['status'] == 'success';
  }

  Future<Map<String, dynamic>> registerForEvent(
    int eventId, {
    String? discountCode,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/events/$eventId/register'),
            headers: await _headers(authenticated: true),
            body: jsonEncode({'discount_code': discountCode}),
          )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'success',
          'message': data['message'] ?? 'Registration confirmed.',
        };
      }
      return {
        'status': 'error',
        'message': _error(data, 'Registration could not be completed.'),
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'The server took too long to respond.',
      };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not connect to the BSCI server.',
      };
    }
  }

  Future<Map<String, dynamic>> registerGuestForEvent(
    int eventId,
    Map<String, String> fields,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/events/$eventId/guest-register'),
            headers: await _headers(),
            body: jsonEncode(fields),
          )
          .timeout(_timeout);
      final data = _decode(response);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'success',
          'message': data['message'] ?? 'Event registration confirmed.',
        };
      }
      return {
        'status': 'error',
        'message': _error(data, 'Registration could not be completed.'),
      };
    } on TimeoutException {
      return {
        'status': 'error',
        'message': 'The server took too long to respond.',
      };
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not connect to the BSCI server.',
      };
    }
  }

  Future<Map<String, dynamic>> submitEventPayment(
    int eventId,
    Map<String, String> fields,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/events/$eventId/payment'),
            headers: await _headers(authenticated: true),
            body: jsonEncode(fields),
          )
          .timeout(_timeout);
      final data = _decode(response);
      return response.statusCode == 201
          ? {
              'status': 'success',
              'message': data['message'] ?? 'Payment submitted.',
            }
          : {'status': 'error', 'message': _error(data, 'Payment failed.')};
    } catch (_) {
      return {
        'status': 'error',
        'message': 'Could not submit payment. Check your connection.',
      };
    }
  }

  Future<bool> logout() async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/member/logout'),
            headers: await _headers(authenticated: true),
          )
          .timeout(_timeout);
    } catch (_) {}
    await clearToken();
    return true;
  }
}
