// lib/presentation/screens/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/message.dart';
import '../../../data/services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String shelterName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.shelterName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _messages    = <Message>[];
  late final RealtimeChannel _channel;
  bool _loading = true;
  bool _sending = false;

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _channel = _chatService.subscribeToMessages(widget.chatId, (msg) {
      // Si ya existe como temporal, reemplazar; si es nuevo, agregar
      final tempIdx = _messages.indexWhere(
        (m) =>
            m.id.startsWith('temp_') &&
            m.content == msg.content &&
            m.senderId == msg.senderId,
      );
      if (tempIdx >= 0) {
        setState(() => _messages[tempIdx] = msg);
      } else {
        if (_messages.any((m) => m.id == msg.id)) return;
        setState(() => _messages.add(msg));
      }
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _channel.unsubscribe();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _chatService.getMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _messages.addAll(msgs);
          _loading = false;
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    final target = _scrollCtrl.position.maxScrollExtent;
    if (animated) {
      _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() => _sending = true);

    // Optimistic UI: mensaje temporal inmediato
    final temp = Message(
      id:        'temp_${DateTime.now().millisecondsSinceEpoch}',
      chatId:    widget.chatId,
      senderId:  _myId,
      content:   text,
      isRead:    false,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(temp));
    _scrollToBottom();

    try {
      await _chatService.sendMessage(widget.chatId, text);
    } catch (e) {
      // Quitar el temporal si falló
      setState(() => _messages.removeWhere((m) => m.id == temp.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Helpers de fecha ─────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _needsSeparator(int index) {
    if (index == 0) return true;
    return !_isSameDay(
      _messages[index - 1].createdAt,
      _messages[index].createdAt,
    );
  }

  String _separatorLabel(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'Hoy';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'Ayer';
    if (dt.year == now.year) {
      return DateFormat("EEEE d 'de' MMMM", 'es').format(dt);
    }
    return DateFormat('d MMM yyyy', 'es').format(dt);
  }

  // ── Agrupamiento de burbujas ─────────────────────────────────
  // Misma persona + menos de 2 min de diferencia → misma "burbuja"
  bool _isSameGroup(int index) {
    if (index == 0) return false;
    final prev = _messages[index - 1];
    final curr = _messages[index];
    return prev.senderId == curr.senderId &&
        curr.createdAt.difference(prev.createdAt).inMinutes < 2;
  }

  bool _isLastInGroup(int index) {
    if (index == _messages.length - 1) return true;
    final curr = _messages[index];
    final next = _messages[index + 1];
    return curr.senderId != next.senderId ||
        next.createdAt.difference(curr.createdAt).inMinutes >= 2;
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textMain,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withOpacity(0.15),
            child: const Icon(Icons.pets, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.shelterName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const Text(
                'Refugio verificado',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSub,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('Inicia la conversación',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textMain)),
            const SizedBox(height: 4),
            const Text('Pregunta sobre la mascota o el proceso de adopción',
                style: TextStyle(color: AppTheme.textSub, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Construir lista con separadores de fecha intercalados
    final items = <_ChatItem>[];
    for (var i = 0; i < _messages.length; i++) {
      if (_needsSeparator(i)) {
        items.add(_ChatItem.separator(_separatorLabel(_messages[i].createdAt)));
      }
      items.add(_ChatItem.message(
        msg:         _messages[i],
        sameGroup:   _isSameGroup(i),
        lastInGroup: _isLastInGroup(i),
      ));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item.isSeparator) return _DateSeparator(label: item.label!);
        return _Bubble(
          msg:         item.msg!,
          myId:        _myId,
          sameGroup:   item.sameGroup,
          lastInGroup: item.lastInGroup,
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: _controller,
                maxLines: null, // multilinea
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                )
              : Material(
                  color: AppTheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _send,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ── Modelo interno de lista ──────────────────────────────────────
class _ChatItem {
  final bool isSeparator;
  final String? label;
  final Message? msg;
  final bool sameGroup;
  final bool lastInGroup;

  const _ChatItem._({
    required this.isSeparator,
    this.label,
    this.msg,
    this.sameGroup   = false,
    this.lastInGroup = true,
  });

  factory _ChatItem.separator(String label) =>
      _ChatItem._(isSeparator: true, label: label);

  factory _ChatItem.message({
    required Message msg,
    required bool sameGroup,
    required bool lastInGroup,
  }) =>
      _ChatItem._(
        isSeparator: false,
        msg:         msg,
        sameGroup:   sameGroup,
        lastInGroup: lastInGroup,
      );
}

// ── Separador de fecha ───────────────────────────────────────────
class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

// ── Burbuja de mensaje ───────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final Message msg;
  final String  myId;
  final bool    sameGroup;
  final bool    lastInGroup;

  const _Bubble({
    required this.msg,
    required this.myId,
    required this.sameGroup,
    required this.lastInGroup,
  });

  @override
  Widget build(BuildContext context) {
    final isMe    = msg.senderId == myId;
    final isTemp  = msg.id.startsWith('temp_');
    final maxW    = MediaQuery.sizeOf(context).width * 0.72;

    // Espaciado: mensajes del mismo grupo van más juntos
    final topMargin    = sameGroup ? 2.0 : 10.0;
    final bottomMargin = lastInGroup ? 2.0 : 0.0;

    // Radio de las esquinas — sin cola en intermedios, con cola al final
    final radius = BorderRadius.only(
      topLeft:     const Radius.circular(18),
      topRight:    const Radius.circular(18),
      bottomLeft:  Radius.circular(isMe ? 18 : (lastInGroup ? 4 : 18)),
      bottomRight: Radius.circular(isMe ? (lastInGroup ? 4 : 18) : 18),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top:    topMargin,
          bottom: bottomMargin,
          left:   isMe ? 48 : 0,
          right:  isMe ? 0 : 48,
        ),
        constraints: BoxConstraints(maxWidth: maxW),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.primary : Colors.white,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.content,
                style: TextStyle(
                  color:    isMe ? Colors.white : AppTheme.textMain,
                  fontSize: 15,
                  height:   1.4,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.createdAt),
                    style: TextStyle(
                      color:    isMe ? Colors.white60 : Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isTemp ? Icons.access_time : Icons.done,
                      size:  12,
                      color: Colors.white60,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
