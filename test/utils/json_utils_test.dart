import 'package:flutter_test/flutter_test.dart';
import 'package:cognify_flutter/utils/json_utils.dart';

void main() {
  group('JsonUtils', () {
    test('deepStringKeyMap handles nested dynamic maps', () {
      final input = <dynamic, dynamic>{
        'key1': 'value1',
        123: 'numeric_key',
        'nested': <dynamic, dynamic>{
          'inner': 'value',
          456: 'another_numeric'
        }
      };
      
      final result = JsonUtils.deepStringKeyMap(input);
      
      expect(result['key1'], equals('value1'));
      expect(result['123'], equals('numeric_key'));
      expect(result['nested']['inner'], equals('value'));
      expect(result['nested']['456'], equals('another_numeric'));
    });

    test('deepStringKeyMap handles lists with dynamic maps', () {
      final input = <dynamic, dynamic>{
        'items': <dynamic>[
          <dynamic, dynamic>{'id': 1, 'name': 'item1'},
          <dynamic, dynamic>{'id': 2, 'name': 'item2'},
        ]
      };
      
      final result = JsonUtils.deepStringKeyMap(input);
      
      expect(result['items'], isA<List>());
      final items = result['items'] as List<dynamic>;
      expect(items[0], isA<Map<String, dynamic>>());
      final item0 = items[0] as Map<String, dynamic>;
      final item1 = items[1] as Map<String, dynamic>;
      expect(item0['id'], equals(1));
      expect(item0['name'], equals('item1'));
      expect(item1['id'], equals(2));
      expect(item1['name'], equals('item2'));
    });

    test('safeStringKeyMap returns null for non-map input', () {
      expect(JsonUtils.safeStringKeyMap('string'), isNull);
      expect(JsonUtils.safeStringKeyMap(123), isNull);
      expect(JsonUtils.safeStringKeyMap(null), isNull);
    });

    test('safeStringKeyMap handles Map<String, dynamic>', () {
      final input = <String, dynamic>{'key': 'value'};
      final result = JsonUtils.safeStringKeyMap(input);
      
      expect(result, equals(input));
    });

    test('safeStringKeyMap converts Map<dynamic, dynamic>', () {
      final input = <dynamic, dynamic>{'key': 'value'};
      final result = JsonUtils.safeStringKeyMap(input);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result, isNotNull);
      expect(result!['key'], equals('value'));
    });

    test('safeList returns null for non-list input', () {
      expect(JsonUtils.safeList('string'), isNull);
      expect(JsonUtils.safeList(123), isNull);
      expect(JsonUtils.safeList(null), isNull);
    });

    test('safeList handles List with nested maps', () {
      final input = <dynamic>[
        <dynamic, dynamic>{'id': 1},
        <dynamic, dynamic>{'id': 2},
      ];
      
      final result = JsonUtils.safeList(input);
      
      expect(result, isA<List>());
      expect(result, isNotNull);
      final nonNullResult = result!;
      expect(nonNullResult[0]['id'], equals(1));
      expect(nonNullResult[1]['id'], equals(2));
    });

    test('deepNormalize handles mixed structures', () {
      final input = <dynamic, dynamic>{
        'string': 'value',
        'number': 123,
        'list': <dynamic>[
          <dynamic, dynamic>{'nested': 'value'},
        ],
        'map': <dynamic, dynamic>{
          'inner': <dynamic, dynamic>{'deep': 'value'},
        },
      };
      
      final result = JsonUtils.deepNormalize(input);
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result['string'], equals('value'));
      expect(result['number'], equals(123));
      expect(result['list'], isA<List>());
      expect(result['list'][0]['nested'], equals('value'));
      expect(result['map']['inner']['deep'], equals('value'));
    });

    test('isValidStringKeyMap validates correctly', () {
      expect(JsonUtils.isValidStringKeyMap(<String, dynamic>{'key': 'value'}), isTrue);
      expect(JsonUtils.isValidStringKeyMap(<dynamic, dynamic>{'key': 'value'}), isTrue);
      expect(JsonUtils.isValidStringKeyMap('string'), isFalse);
      expect(JsonUtils.isValidStringKeyMap(null), isFalse);
    });

    test('isValidList validates correctly', () {
      expect(JsonUtils.isValidList(<dynamic>[]), isTrue);
      expect(JsonUtils.isValidList(<String>[]), isTrue);
      expect(JsonUtils.isValidList('string'), isFalse);
      expect(JsonUtils.isValidList(null), isFalse);
    });
  });
} 