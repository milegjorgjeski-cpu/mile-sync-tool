// lib/core/id3_writer.dart
// Writes ID3v2.3/v2.4 tags including SYLT (synced lyrics) and USLT
// Uses pure Dart to construct and inject ID3 header into MP3 files.

import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'models.dart';

class Id3Writer {
  // ── Public entry point ────────────────────────────────────
  /// Embeds ID3 tags (including SYLT if lyrics provided) into [mp3Path]
  /// and writes the result to [outputPath].
  static Future<ProcessingResult> embedTags(
    String mp3Path,
    String outputPath, {
    String? title,
    String? artist,
    String? album,
    String? comment,
    LyricsDocument? lyrics,
    bool embedSylt = true,
    bool embedUslt = false,
  }) async {
    try {
      final inputFile = File(mp3Path);
      if (!inputFile.existsSync()) {
        return ProcessingResult.fail('Input file not found: $mp3Path');
      }

      final inputBytes = await inputFile.readAsBytes();

      // Strip any existing ID3v2 header
      final stripped = _stripId3v2(inputBytes);

      // Build new ID3v2.3 header
      final frames = <Uint8List>[];

      if (title != null && title.isNotEmpty) {
        frames.add(_buildTextFrame('TIT2', title));
      }
      if (artist != null && artist.isNotEmpty) {
        frames.add(_buildTextFrame('TPE1', artist));
      }
      if (album != null && album.isNotEmpty) {
        frames.add(_buildTextFrame('TALB', album));
      }
      if (comment != null && comment.isNotEmpty) {
        frames.add(_buildCommentFrame('eng', comment));
      }

      // USLT - Unsynchronized lyrics (plain text)
      if (embedUslt && lyrics != null) {
        final plainText = lyrics.toPlainText();
        frames.add(_buildUsltFrame('eng', '', plainText));
      }

      // SYLT - Synchronized lyrics
      if (embedSylt && lyrics != null && lyrics.isSynced) {
        frames.add(_buildSyltFrame('eng', lyrics));
      }

      // Tool tag
      frames.add(_buildTextFrame(
          'TSSE', 'Mile Sync Tool - Balkan Live Performer App'));

      final id3Header = _buildId3Header(frames);

      // Write output
      final outputFile = File(outputPath);
      final combined = Uint8List(id3Header.length + stripped.length);
      combined.setAll(0, id3Header);
      combined.setAll(id3Header.length, stripped);
      await outputFile.writeAsBytes(combined);

      return ProcessingResult.ok(outputPath);
    } catch (e) {
      return ProcessingResult.fail('ID3 write error: $e');
    }
  }

  // ── Strip existing ID3v2 header ───────────────────────────
  static Uint8List _stripId3v2(Uint8List data) {
    if (data.length < 10) return data;
    // ID3v2 magic: 0x49 0x44 0x33 = "ID3"
    if (data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33) {
      // Size is encoded as 4 bytes synchsafe int
      final size = _synchsafeToInt(data, 6);
      final headerTotal = 10 + size;
      if (headerTotal < data.length) {
        return Uint8List.sublistView(data, headerTotal);
      }
    }
    return data;
  }

  // ── Build full ID3v2.3 header ─────────────────────────────
  static Uint8List _buildId3Header(List<Uint8List> frames) {
    // Concatenate all frames
    int totalFrameSize = 0;
    for (final f in frames) {
      totalFrameSize += f.length;
    }

    final header = Uint8List(10 + totalFrameSize);
    // Magic
    header[0] = 0x49; // I
    header[1] = 0x44; // D
    header[2] = 0x33; // 3
    // Version 2.3.0
    header[3] = 0x03;
    header[4] = 0x00;
    // Flags
    header[5] = 0x00;
    // Size as synchsafe int
    _intToSynchsafe(totalFrameSize, header, 6);

    int offset = 10;
    for (final f in frames) {
      header.setAll(offset, f);
      offset += f.length;
    }
    return header;
  }

  // ── Build text frame (TIT2, TPE1, etc.) ──────────────────
  static Uint8List _buildTextFrame(String frameId, String text) {
    // Encoding byte: 0x00 = Latin-1, 0x01 = UTF-16
    // We'll use UTF-8 via encoding byte 0x03 (ID3v2.4) or UTF-16 (2.3)
    final encoded = _encodeUtf16(text);
    final frameData = Uint8List(1 + encoded.length);
    frameData[0] = 0x01; // UTF-16 encoding
    frameData.setAll(1, encoded);

    return _wrapFrame(frameId, frameData);
  }

  // ── Build COMM (comment) frame ────────────────────────────
  static Uint8List _buildCommentFrame(String lang, String text) {
    final langBytes = Uint8List.fromList(latin1.encode(lang.padRight(3).substring(0, 3)));
    final encoded = _encodeUtf16(text);

    final frameData = Uint8List(1 + 3 + 2 + encoded.length);
    frameData[0] = 0x01; // encoding UTF-16
    frameData.setAll(1, langBytes);
    // Empty description + BOM
    frameData[4] = 0xFF;
    frameData[5] = 0xFE;
    frameData.setAll(6, encoded);

    return _wrapFrame('COMM', frameData);
  }

  // ── Build USLT frame ─────────────────────────────────────
  static Uint8List _buildUsltFrame(
      String lang, String description, String text) {
    final langBytes = Uint8List.fromList(latin1.encode(lang.padRight(3).substring(0, 3)));
    final encodedDesc = _encodeUtf16(description);
    final encodedText = _encodeUtf16(text);

    // encoding + lang(3) + desc + null(2) + text
    final frameData = Uint8List(
        1 + 3 + encodedDesc.length + 2 + encodedText.length);
    int o = 0;
    frameData[o++] = 0x01; // encoding UTF-16
    frameData.setAll(o, langBytes);
    o += 3;
    frameData.setAll(o, encodedDesc);
    o += encodedDesc.length;
    // UTF-16 null terminator
    frameData[o++] = 0x00;
    frameData[o++] = 0x00;
    frameData.setAll(o, encodedText);

    return _wrapFrame('USLT', frameData);
  }

  // ── Build SYLT frame (synchronized lyrics) ───────────────
  static Uint8List _buildSyltFrame(String lang, LyricsDocument lyrics) {
    // SYLT format:
    // encoding(1) + language(3) + timeStampFormat(1) + contentType(1) + desc + null
    // then pairs of: text + null + timestamp(4 big-endian ms)

    final langBytes = Uint8List.fromList(
        latin1.encode(lang.padRight(3).substring(0, 3)));

    // Build syllable data
    final dataBuffer = BytesBuilder();
    dataBuffer.addByte(0x01); // encoding: UTF-16
    dataBuffer.add(langBytes); // language
    dataBuffer.addByte(0x01); // timestamp format: 1=ms, 2=MPEG frames
    dataBuffer.addByte(0x01); // content type: 1=lyrics

    // Empty description (UTF-16 BOM + null terminator)
    dataBuffer.add([0xFF, 0xFE, 0x00, 0x00]);

    for (final line in lyrics.lines) {
      if (!line.isSynced) continue;

      final text = line.text.trim();
      if (text.isEmpty) continue;

      final textEncoded = _encodeUtf16(text);
      dataBuffer.add(textEncoded);
      // UTF-16 null terminator for the text
      dataBuffer.add([0x00, 0x00]);

      // Timestamp in milliseconds (4 bytes big-endian)
      final ms = line.startTime!.inMilliseconds;
      dataBuffer.addByte((ms >> 24) & 0xFF);
      dataBuffer.addByte((ms >> 16) & 0xFF);
      dataBuffer.addByte((ms >> 8) & 0xFF);
      dataBuffer.addByte(ms & 0xFF);
    }

    return _wrapFrame('SYLT', dataBuffer.toBytes());
  }

  // ── Wrap data in ID3v2 frame envelope ────────────────────
  static Uint8List _wrapFrame(String frameId, Uint8List data) {
    assert(frameId.length == 4);
    final frame = Uint8List(10 + data.length);
    // Frame ID
    final idBytes = ascii.encode(frameId);
    frame.setAll(0, idBytes);
    // Size (4 bytes big-endian, NOT synchsafe in ID3v2.3)
    final size = data.length;
    frame[4] = (size >> 24) & 0xFF;
    frame[5] = (size >> 16) & 0xFF;
    frame[6] = (size >> 8) & 0xFF;
    frame[7] = size & 0xFF;
    // Flags (2 bytes, zero)
    frame[8] = 0x00;
    frame[9] = 0x00;
    // Data
    frame.setAll(10, data);
    return frame;
  }

  // ── UTF-16 LE encoding with BOM ───────────────────────────
  static Uint8List _encodeUtf16(String text) {
    final codeUnits = text.codeUnits;
    // BOM (FF FE) + 2 bytes per character
    final result = Uint8List(2 + codeUnits.length * 2);
    result[0] = 0xFF;
    result[1] = 0xFE;
    for (int i = 0; i < codeUnits.length; i++) {
      result[2 + i * 2] = codeUnits[i] & 0xFF;
      result[2 + i * 2 + 1] = (codeUnits[i] >> 8) & 0xFF;
    }
    return result;
  }

  // ── Synchsafe integer helpers ─────────────────────────────
  static int _synchsafeToInt(Uint8List data, int offset) {
    return (data[offset] & 0x7F) << 21 |
        (data[offset + 1] & 0x7F) << 14 |
        (data[offset + 2] & 0x7F) << 7 |
        (data[offset + 3] & 0x7F);
  }

  static void _intToSynchsafe(int value, Uint8List buf, int offset) {
    buf[offset + 3] = value & 0x7F;
    value >>= 7;
    buf[offset + 2] = value & 0x7F;
    value >>= 7;
    buf[offset + 1] = value & 0x7F;
    value >>= 7;
    buf[offset] = value & 0x7F;
  }
}
