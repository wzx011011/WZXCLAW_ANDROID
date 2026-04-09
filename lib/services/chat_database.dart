import 'package:sqflite/sqflite.dart';
import '../models/chat_message.dart';

class ChatDatabase {
  static final ChatDatabase _instance = ChatDatabase._();
  static ChatDatabase get instance => _instance;
  ChatDatabase._();

  static const _dbName = 'wzxclaw_chat.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> _ensureDb() async {
    _db ??= await openDatabase(
      _dbName,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role INTEGER NOT NULL,
            content TEXT NOT NULL,
            tool_name TEXT,
            tool_status INTEGER,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> insertMessage(ChatMessage msg) async {
    final db = await _ensureDb();
    final id = await db.insert('messages', msg.toDbMap());
    // Return a copy with the id set — caller can ignore or use it
    msg.copyWith(id: id);
  }

  Future<List<ChatMessage>> getMessages({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _ensureDb();
    final rows = await db.query(
      'messages',
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => ChatMessage.fromDbMap(r)).toList();
  }

  Future<int> getMessageCount() async {
    final db = await _ensureDb();
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM messages');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearAll() async {
    final db = await _ensureDb();
    await db.delete('messages');
  }

  Future<void> updateMessage(ChatMessage msg) async {
    if (msg.id == null) return;
    final db = await _ensureDb();
    await db.update(
      'messages',
      msg.toDbMap(),
      where: 'id = ?',
      whereArgs: [msg.id],
    );
  }

  Future<void> deleteMessage(int id) async {
    final db = await _ensureDb();
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }
}
