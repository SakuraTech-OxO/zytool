import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ProtobufPage extends StatefulWidget {
  const ProtobufPage({super.key});

  @override
  State<ProtobufPage> createState() => _ProtobufPageState();
}

class _ProtobufPageState extends State<ProtobufPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _decodeInputController = TextEditingController();
  final TextEditingController _encodeInputController = TextEditingController();
  String _decodeResult = '';
  String _encodeResult = '';
  bool _decodeSuccess = false;
  bool _encodeSuccess = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _decodeInputController.dispose();
    _encodeInputController.dispose();
    super.dispose();
  }

  void _decode() {
    final input = _decodeInputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _decodeResult = '请输入要解码的数据';
        _decodeSuccess = false;
      });
      return;
    }

    try {
      Uint8List buffer;
      if (RegExp(r'^[a-f0-9]+$', caseSensitive: false).hasMatch(input)) {
        buffer = _hexToBytes(input);
      } else {
        final decoded = base64Decode(input);
        buffer = Uint8List.fromList(decoded);
      }

      final result = ProtobufCodec().decode(buffer);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(_convertBigIntToString(result));
      
      setState(() {
        _decodeResult = jsonStr;
        _decodeSuccess = true;
      });
    } catch (e) {
      setState(() {
        _decodeResult = '解码失败: $e';
        _decodeSuccess = false;
      });
    }
  }

  void _encode() {
    final input = _encodeInputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _encodeResult = '请输入要编码的JSON数据';
        _encodeSuccess = false;
      });
      return;
    }

    try {
      final jsonData = jsonDecode(input);
      if (jsonData is! Map) {
        setState(() {
          _encodeResult = 'JSON必须是对象格式，如 {"1": 123, "2": "test"}';
          _encodeSuccess = false;
        });
        return;
      }

      final mapData = Map<int, dynamic>.from(
        jsonData.map((key, value) => MapEntry(int.parse(key), value)),
      );

      final encoded = ProtobufCodec().encode(mapData);
      final hexStr = _bytesToHex(encoded);
      final base64Str = base64Encode(encoded);
      
      setState(() {
        _encodeResult = 'Hex: $hexStr\nBase64: $base64Str\n长度: ${encoded.length} 字节';
        _encodeSuccess = true;
      });
    } catch (e) {
      setState(() {
        _encodeResult = '编码失败: $e';
        _encodeSuccess = false;
      });
    }
  }

  dynamic _convertBigIntToString(dynamic value) {
    if (value is BigInt) {
      return value.toString();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _convertBigIntToString(v)));
    } else if (value is List) {
      return value.map((e) => _convertBigIntToString(e)).toList();
    }
    return value;
  }

  Uint8List _hexToBytes(String hex) {
    hex = hex.replaceAll(RegExp(r'\s'), '');
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              '🔧 Protobuf 工具',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Protocol Buffers 编码解码工具',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: const [
                  Tab(text: '解码 (Decode)'),
                  Tab(text: '编码 (Encode)'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDecodeTab(),
                  _buildEncodeTab(),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDecodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '输入 Protobuf 数据 (Hex 或 Base64):',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _decodeInputController,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '请输入 Hex 或 Base64 格式的 Protobuf 数据',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _decode,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '🔍 解码',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildExample(
            '📝 示例数据:',
            'Hex: 08961a12047465737418c801\nBase64: CJYaEgR0ZXN0GMgB',
            () {
              _decodeInputController.text = '08961a12047465737418c801';
            },
          ),
          if (_decodeResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildResultWidget(_decodeResult, _decodeSuccess),
          ],
        ],
      ),
    );
  }

  Widget _buildEncodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '输入 JSON 数据:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _encodeInputController,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.white),
            maxLines: 6,
            decoration: InputDecoration(
              hintText: '{"1": 1234, "2": "test", "3": 200}',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _encode,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '🔧 编码',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildExample(
            '📝 示例数据:',
            '{\n  "1": 1234,\n  "2": "test",\n  "3": 200\n}',
            () {
              _encodeInputController.text = '{"1": 1234, "2": "test", "3": 200}';
            },
          ),
          if (_encodeResult.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildResultWidget(_encodeResult, _encodeSuccess),
          ],
        ],
      ),
    );
  }

  Widget _buildExample(String title, String content, VoidCallback onCopy) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF5B7).withOpacity(0.2),
            const Color(0xFFFFEAA7).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFFF39C12), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white70, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '📋 复制示例',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultWidget(String result, bool isSuccess) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFF38A169).withOpacity(0.2)
            : const Color(0xFFE53E3E).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF38A169).withOpacity(0.5)
              : const Color(0xFFE53E3E).withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSuccess ? '✅ 成功' : '❌ 错误',
            style: TextStyle(
              color: isSuccess ? const Color(0xFF38A169) : const Color(0xFFE53E3E),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              result,
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class LongBits {
  int lo;
  int hi;

  LongBits(this.lo, this.hi);

  static LongBits from(dynamic value) {
    if (value is BigInt) {
      value = value.toString();
    }
    if (value is String) {
      final num = BigInt.parse(value);
      final lo = (num & BigInt.from(0xffffffff)).toInt();
      final hi = (num >> 32).toInt();
      return LongBits(lo, hi);
    }
    if (value == 0) {
      return zero;
    }
    final sign = value < 0;
    if (sign) value = -value;
    int lo = value.toInt();
    int hi = ((value - lo) / 4294967296).toInt();
    if (sign) {
      hi = ~hi;
      lo = ~lo;
      if (++lo > 4294967295) {
        lo = 0;
        if (++hi > 4294967295) hi = 0;
      }
    }
    return LongBits(lo, hi);
  }

  int length() {
    final part0 = lo;
    final part1 = (lo >> 28 | hi << 4);
    final part2 = hi >> 24;
    return part2 == 0
        ? part1 == 0
            ? part0 < 16384
                ? part0 < 128 ? 1 : 2
                : part0 < 2097152 ? 3 : 4
            : part1 < 16384
                ? part1 < 128 ? 5 : 6
                : part1 < 2097152 ? 7 : 8
        : part2 < 128 ? 9 : 10;
  }

  static final zero = LongBits(0, 0);
}

class ProtobufWriter {
  final List<int> buf = [];
  int len = 0;

  ProtobufWriter uint32(int value) {
    if (value < 0x80) {
      buf.add(value);
      len++;
    } else if (value < 0x4000) {
      buf.add((value & 0x7f) | 0x80);
      buf.add(value >> 7);
      len += 2;
    } else if (value < 0x200000) {
      buf.add((value & 0x7f) | 0x80);
      buf.add((value >> 7 & 0x7f) | 0x80);
      buf.add(value >> 14);
      len += 3;
    } else if (value < 0x10000000) {
      buf.add((value & 0x7f) | 0x80);
      buf.add((value >> 7 & 0x7f) | 0x80);
      buf.add((value >> 14 & 0x7f) | 0x80);
      buf.add(value >> 21);
      len += 4;
    } else {
      buf.add((value & 0x7f) | 0x80);
      buf.add((value >> 7 & 0x7f) | 0x80);
      buf.add((value >> 14 & 0x7f) | 0x80);
      buf.add((value >> 21 & 0x7f) | 0x80);
      buf.add(value >> 28);
      len += 5;
    }
    return this;
  }

  ProtobufWriter int32(int value) {
    if (value < 0) {
      final bits = LongBits.from(value);
      for (var i = 0; i < 10; i++) {
        int b;
        if (bits.hi != 0) {
          b = bits.lo & 127 | 128;
          bits.lo = (bits.lo >> 7 | bits.hi << 25);
          bits.hi >>= 7;
        } else {
          b = i < 9 ? bits.lo & 127 | 128 : bits.lo;
          bits.lo >>= 7;
        }
        buf.add(b);
      }
      len += 10;
      return this;
    }
    return uint32(value);
  }

  ProtobufWriter sint32(int value) {
    return uint32((value << 1 ^ value >> 31));
  }

  ProtobufWriter int64(dynamic value) {
    final bits = LongBits.from(value);
    final length = bits.length();
    for (var i = 0; i < length; i++) {
      int b;
      if (bits.hi != 0) {
        b = bits.lo & 127 | 128;
        bits.lo = (bits.lo >> 7 | bits.hi << 25);
        bits.hi >>= 7;
      } else {
        b = i < length - 1 ? bits.lo & 127 | 128 : bits.lo;
        bits.lo >>= 7;
      }
      buf.add(b);
    }
    len += length;
    return this;
  }

  ProtobufWriter uint64(dynamic value) {
    return int64(value);
  }

  ProtobufWriter boolean(bool value) {
    buf.add(value ? 1 : 0);
    len++;
    return this;
  }

  ProtobufWriter string(String value) {
    final encoded = utf8.encode(value);
    return writeBytes(encoded);
  }

  ProtobufWriter writeBytes(List<int> value) {
    uint32(value.length);
    buf.addAll(value);
    len += value.length;
    return this;
  }

  ProtobufWriter fixed32(int value) {
    buf.add(value & 0xff);
    buf.add((value >> 8) & 0xff);
    buf.add((value >> 16) & 0xff);
    buf.add((value >> 24) & 0xff);
    len += 4;
    return this;
  }

  ProtobufWriter fixed64(dynamic value) {
    final bits = LongBits.from(value);
    return fixed32(bits.lo).fixed32(bits.hi);
  }

  Uint8List finish() {
    return Uint8List.fromList(buf);
  }
}

class ProtobufReader {
  final Uint8List buf;
  int pos = 0;
  final int len;

  ProtobufReader(this.buf) : len = buf.length;

  int uint32() {
    int result = 0;
    int shift = 0;
    int b;
    do {
      if (pos >= len) throw Exception('Premature end of buffer');
      b = buf[pos++];
      result |= (b & 0x7f) << shift;
      shift += 7;
    } while ((b & 0x80) != 0);
    return result;
  }

  int int32() {
    return uint32();
  }

  int sint32() {
    final value = uint32();
    return value >> 1 ^ -(value & 1);
  }

  LongBits int64() {
    final bits = LongBits(0, 0);
    int i = 0;
    if (len - pos > 4) {
      for (; i < 4; ++i) {
        bits.lo = (bits.lo | (buf[pos] & 127) << i * 7);
        if (buf[pos++] < 128) return bits;
      }
      bits.lo = (bits.lo | (buf[pos] & 127) << 28);
      bits.hi = (bits.hi | (buf[pos] & 127) >> 4);
      if (buf[pos++] < 128) return bits;
      i = 0;
    } else {
      for (; i < 3; ++i) {
        if (pos >= len) throw Exception('Premature end of buffer');
        bits.lo = (bits.lo | (buf[pos] & 127) << i * 7);
        if (buf[pos++] < 128) return bits;
      }
      bits.lo = (bits.lo | (buf[pos++] & 127) << i * 7);
      return bits;
    }
    if (len - pos > 4) {
      for (; i < 5; ++i) {
        bits.hi = (bits.hi | (buf[pos] & 127) << i * 7 + 3);
        if (buf[pos++] < 128) return bits;
      }
    } else {
      for (; i < 5; ++i) {
        if (pos >= len) throw Exception('Premature end of buffer');
        bits.hi = (bits.hi | (buf[pos] & 127) << i * 7 + 3);
        if (buf[pos++] < 128) return bits;
      }
    }
    throw Exception('Invalid varint encoding');
  }

  dynamic uint64() {
    return int64();
  }

  bool boolean() {
    return uint32() != 0;
  }

  String string() {
    final length = uint32();
    final end = pos + length;
    if (end > len) throw Exception('Premature end of buffer');
    final bytes = buf.sublist(pos, end);
    pos = end;
    return utf8.decode(bytes);
  }

  Uint8List bytes() {
    final length = uint32();
    final end = pos + length;
    if (end > len) throw Exception('Premature end of buffer');
    final result = buf.sublist(pos, end);
    pos = end;
    return result;
  }

  int fixed32() {
    if (pos + 4 > len) throw Exception('Premature end of buffer');
    final result = buf[pos] |
        (buf[pos + 1] << 8) |
        (buf[pos + 2] << 16) |
        (buf[pos + 3] << 24);
    pos += 4;
    return result;
  }

  LongBits fixed64() {
    if (pos + 8 > len) throw Exception('Premature end of buffer');
    final lo = buf[pos] |
        (buf[pos + 1] << 8) |
        (buf[pos + 2] << 16) |
        (buf[pos + 3] << 24);
    pos += 4;
    final hi = buf[pos] |
        (buf[pos + 1] << 8) |
        (buf[pos + 2] << 16) |
        (buf[pos + 3] << 24);
    pos += 4;
    return LongBits(lo, hi);
  }

  void skip(dynamic length) {
    if (length is int) {
      if (pos + length > len) throw Exception('Index out of range');
      pos += length;
    } else {
      do {
        if (pos >= len) throw Exception('Index out of range');
      } while (buf[pos++] & 128 != 0);
    }
  }
}

class ProtobufCodec {
  Uint8List encode(Map<int, dynamic> obj) {
    final writer = ProtobufWriter();
    for (final entry in obj.entries) {
      _encode(writer, entry.key, entry.value);
    }
    return writer.finish();
  }

  void _encode(ProtobufWriter writer, int tag, dynamic value) {
    if (value == null) return;

    if (value is int) {
      writer.uint32((tag << 3) | 0).int32(value);
    } else if (value is BigInt) {
      writer.uint32((tag << 3) | 0).int64(value);
    } else if (value is String) {
      if (value.startsWith('base64://')) {
        final bytes = base64Decode(value.substring(9));
        writer.uint32((tag << 3) | 2).writeBytes(bytes);
      } else {
        writer.uint32((tag << 3) | 2).string(value);
      }
    } else if (value is bool) {
      writer.uint32((tag << 3) | 0).boolean(value);
    } else if (value is Uint8List || value is List<int>) {
      writer.uint32((tag << 3) | 2).writeBytes(value);
    } else if (value is List) {
      for (final item in value) {
        _encode(writer, tag, item);
      }
    } else if (value is Map) {
      final nestedBuffer = encode(Map<int, dynamic>.from(value));
      writer.uint32((tag << 3) | 2).writeBytes(nestedBuffer);
    } else {
      throw Exception('Unsupported type: ${value.runtimeType}');
    }
  }

  Map<String, dynamic> decode(Uint8List buffer) {
    final result = <String, dynamic>{};
    final reader = ProtobufReader(buffer);

    while (reader.pos < reader.len) {
      final k = reader.uint32();
      final tag = k >> 3;
      final type = k & 0x07;

      dynamic value;
      switch (type) {
        case 0:
          value = _long2int(reader.int64());
          break;
        case 1:
          value = _long2int(reader.fixed64());
          break;
        case 2:
          final bytes = reader.bytes();
          try {
            value = decode(bytes);
          } catch (_) {
            try {
              final decoded = utf8.decode(bytes);
              final reEncoded = utf8.encode(decoded);
              if (reEncoded.length == bytes.length) {
                bool match = true;
                for (var i = 0; i < reEncoded.length; i++) {
                  if (reEncoded[i] != bytes[i]) {
                    match = false;
                    break;
                  }
                }
                if (match) {
                  value = decoded;
                } else {
                  value = 'base64://${base64Encode(bytes)}';
                }
              } else {
                value = 'base64://${base64Encode(bytes)}';
              }
            } catch (_) {
              value = 'base64://${base64Encode(bytes)}';
            }
          }
          break;
        case 5:
          value = reader.fixed32();
          break;
        default:
          throw Exception('Unsupported wire type: $type');
      }

      final tagStr = tag.toString();
      if (result.containsKey(tagStr)) {
        if (result[tagStr] is List) {
          (result[tagStr] as List).add(value);
        } else {
          result[tagStr] = [result[tagStr], value];
        }
      } else {
        result[tagStr] = value;
      }
    }
    return result;
  }

  dynamic _long2int(LongBits long) {
    if (long.hi == 0) return long.lo;
    final bigint = (BigInt.from(long.hi) << 32) | BigInt.from(long.lo);
    final intValue = bigint.toInt();
    return intValue;
  }
}