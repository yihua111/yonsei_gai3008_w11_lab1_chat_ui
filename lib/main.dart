import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FE4)),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

/// 대화 한 줄. 서버 없이 화면만 만들기 위한 최소 모델.
class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// 실습용 가짜 대화 — API를 붙이기 전까지 이 목록으로 화면을 만든다.
  final List<ChatMessage> _messages = [
    ChatMessage(text: '오늘 뭐 배워?', isUser: true),
    ChatMessage(text: 'AI 챗봇에 움직이는 응답을 붙입니다.', isUser: false),
    ChatMessage(text: '타이핑 점은 왜 필요해요?', isUser: true),
    ChatMessage(text: '응답이 1초를 넘으면 앱이 멈춘 것처럼 보이기 때문입니다.', isUser: false),
  ];

  final _controller = TextEditingController();

  String? _error;
  String? _lastFailedText;
  bool _sending = false;
  int _retryCount = 0;

  Future<void> _send() async {
    if (_sending) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _sending = true;
      _error = null;
      _retryCount = 0;
      _lastFailedText = null;
    });

    _controller.clear();

    await _requestReply(text);
  }

  Future<void> _requestReply(String text) async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (text.contains('401')) {
        throw 401;
      } else if (text.contains('429')) {
        throw 429;
      } else if (text.contains('500')) {
        throw 500;
      } else if (text.contains('timeout')) {
        throw 408;
      }

      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(text: '메시지를 받았습니다: $text', isUser: false));
        _error = null;
        _lastFailedText = null;
        _sending = false;
        _retryCount = 0;
      });
    } catch (e) {
      if (!mounted) return;

      String msg;

      if (e == 401) {
        msg = '키/권한을 확인해 주세요';
      } else if (e == 429) {
        msg = '잠시 후 다시 시도해 주세요';
      } else if (e == 500) {
        msg = '응답을 받지 못했습니다';
      } else {
        msg = '네트워크를 확인해 주세요';
      }

      setState(() {
        _error = msg;
        _lastFailedText = text;
        _sending = false;
      });
    }
  }

  Future<void> _retry() async {
    if (_sending || _lastFailedText == null) return;

    final text = _lastFailedText!;

    setState(() {
      _sending = true;
      _error = null;
      _retryCount++;
    });

    if (text.contains('429')) {
      final seconds = _retryCount == 1 ? 1 : 2;
      await Future.delayed(Duration(seconds: seconds));
    }

    if (!mounted) return;

    await _requestReply(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      // TODO 5 — 키보드가 입력창을 가리지 않게
      // TIP: Scaffold의 resizeToAvoidBottomInset은 기본값이 true다.
      //      body를 SafeArea로 감싸 홈 인디케이터와 노치를 피한다.
      appBar: AppBar(title: const Text('AI Chat — 실습 1')),
      body: SafeArea(
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────
            // ✅ 할 일 1 — 완료된 부분
            //    ListView.builder + reverse: true
            //    · reverse:true면 index 0이 화면 맨 아래(최신)다.
            //    · 그래서 _messages[length - 1 - i]로 거꾸로 꺼낸다.
            // ─────────────────────────────────────────────────────────

            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('무엇이든 물어보세요'))
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[_messages.length - 1 - index];
                        return _Bubble(message: message);
                      },
                    ),
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _sending
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.all(12),
                      child: Text('응답을 기다리는 중...'),
                    )
                  : _error != null
                  ? Container(
                      key: const ValueKey('error'),
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          TextButton(
                            onPressed: _retry,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(key: ValueKey('idle')),
            ),

            // ─────────────────────────────────────────────────────────
            // TODO 4 — 빈 상태
            // TIP: ListView를 Stack으로 감싸고, 목록이 비었을 때만
            //      Center(child: Text('무엇이든 물어보세요'))를 위에 띄운다.
            //      지금은 목록에 가짜 대화가 있어 빈 상태가 보이지 않는다.
            //      _messages를 비우고 확인해 보자.
            // ─────────────────────────────────────────────────────────

            // ─────────────────────────────────────────────────────────
            // TODO 3 — 입력창 (TextField + 전송 버튼)
            // TIP:
            //  · final _controller = TextEditingController(); 를 State에 둔다.
            //  · Row(children: [Expanded(TextField(...)), IconButton.filled(...)])
            //  · TextField(textInputAction: TextInputAction.send,
            //             onSubmitted: (_) => _send())
            //  · 보낼 때 _controller.clear() 하고 setState로 목록에 추가한다.
            //  · dispose()에서 _controller.dispose()를 잊지 않는다.
            // ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ───────────────────────────────────────────────────────────────
/// TODO 2 — 말풍선 2종 (사용자 오른쪽 / AI 왼쪽)
///
/// 지금은 글자만 보이는 상자다. 다음을 채워 넣자.
///
/// TIP:
///  · Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft)
///  · Container(
///      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
///      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
///      constraints: BoxConstraints(maxWidth: 420),
///      decoration: BoxDecoration(
///        color: isUser ? colorScheme.primaryContainer
///                      : colorScheme.surfaceContainerHighest,
///        borderRadius: BorderRadius.circular(14),
///      ),
///    )
///  · 색은 Theme.of(context).colorScheme에서 꺼내면 다크 모드에서도 안전하다.
///  · 긴 글은 자동으로 줄바꿈된다. maxWidth만 잡아 주면 된다.
/// ───────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message.text),
      ),
    );
  }
}

/// TODO 3이 끝나면 지운다. 지금은 입력창 자리를 보여 주는 표시일 뿐이다.
class _TodoBar extends StatelessWidget {
  const _TodoBar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
