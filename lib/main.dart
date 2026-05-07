import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ClosikApp());
}

class ClosikApp extends StatelessWidget {
  const ClosikApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Closik',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.purpleAccent,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return const MainScreen();
          return const AuthScreen();
        },
      ),
    );
  }
}

// --- MÀN HÌNH ĐĂNG NHẬP (Giữ nguyên) ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool isLogin = true;

  Future<void> _submit() async {
    try {
      if (_emailC.text.isEmpty || _passC.text.isEmpty) return;
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailC.text.trim(), password: _passC.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailC.text.trim(), password: _passC.text.trim());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
               Text("CLOSIK",
                  style: TextStyle(
                      fontSize: 45,
                     fontWeight: FontWeight.w900,
                     color: Colors.purpleAccent,
                      letterSpacing: 8)),
              const SizedBox(height: 50),
              TextField(
                  controller: _emailC,
                  decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 20),
              TextField(
                  controller: _passC,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: "Mật khẩu",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15)))),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: Text(isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "Tạo tài khoản mới" : "Đã có tài khoản? Đăng nhập",
                    style: const TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MÀN HÌNH CHÍNH (CÓ TÌM KIẾM & PHÓNG TO) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _searchQuery = "";
  Map<String, dynamic>? _currentSong;

  // Animation controller cho đĩa xoay
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    // Lắng nghe trạng thái phát nhạc để xoay/dừng đĩa
    _player.playerStateStream.listen((state) {
      if (state.playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  void _play(Map<String, dynamic> songData) async {
    try {
      setState(() { _currentSong = songData; });
      if (songData['url'] != null && songData['url'].isNotEmpty) {
        await _player.setUrl(songData['url']);
        _player.play();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Lỗi phát nhạc: $e")));
      }
    }
  }

  // Bảng thêm nhạc
  void _showUploadDialog() {
    final tC = TextEditingController();
    final aC = TextEditingController();
    final uC = TextEditingController();
    final imgC = TextEditingController(); // Thêm trường link ảnh

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Chia sẻ nhạc"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tC, decoration: const InputDecoration(labelText: "Tên bài")),
            TextField(controller: aC, decoration: const InputDecoration(labelText: "Ca sĩ")),
            TextField(controller: imgC, decoration: const InputDecoration(labelText: "Link ảnh bìa (tùy chọn)")),
            TextField(controller: uC, decoration: const InputDecoration(labelText: "Link .mp3 (Discord)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              if (tC.text.isNotEmpty && uC.text.isNotEmpty) {
                await _firestore.collection('songs').add({
                  'title': tC.text,
                  'artist': aC.text,
                  'url': uC.text,
                  'image_url': imgC.text, // Lưu link ảnh
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (!mounted) return;
              }
            },
            child: const Text("Đăng"),
          )
        ],
      ),
    );
  }

  // --- MÀN HÌNH PHÓNG TO (NOW PLAYING) ---
  void _showNowPlaying() {
    if (_currentSong == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép kéo lên toàn màn hình
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9, // Chiếm 90% chiều cao
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // Thanh kéo xuống
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 30),
            
            // --- ĐĨA NHẠC XOAY XOAY ---
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * pi, // Xoay 360 độ
                  child: child,
                );
              },
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 5)],
                  image: _currentSong!['image_url'] != null && _currentSong!['image_url'].isNotEmpty
                      ? DecorationImage(image: NetworkImage(_currentSong!['image_url']), fit: BoxFit.cover)
                      : const DecorationImage(image: AssetImage('assets/vinyl_placeholder.png')), // Cần ảnh placeholder
                ),
                // Lỗ tròn ở giữa đĩa
                child: Center(child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle))),
              ),
            ),
            const SizedBox(height: 40),
            
            // Thông tin bài hát
            Text(_currentSong!['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24), textAlign: TextAlign.center),
            Text(_currentSong!['artist'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 18)),
            const SizedBox(height: 30),
            
            // --- THANH KÉO TUA NHẠC ---
            StreamBuilder<Duration?>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = _player.duration ?? Duration.zero;
                return Column(
                  children: [
                    Slider(
                      activeColor: Colors.purpleAccent,
                      inactiveColor: Colors.white24,
                      max: total.inMilliseconds.toDouble() > 0 ? total.inMilliseconds.toDouble() : 1.0,
                      value: position.inMilliseconds.toDouble().clamp(0.0, total.inMilliseconds.toDouble() > 0 ? total.inMilliseconds.toDouble() : 1.0),
                      onChanged: (v) => _player.seek(Duration(milliseconds: v.toInt())),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position)),
                          Text(_formatDuration(total)),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            
            // --- NÚT ĐIỀU KHIỂN ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Nút Lặp lại
                StreamBuilder<LoopMode>(
                  stream: _player.loopModeStream,
                  builder: (context, snapshot) {
                    final loopMode = snapshot.data ?? LoopMode.off;
                    const icons = [Icons.repeat, Icons.repeat_one];
                    const colors = [Colors.white54, Colors.purpleAccent];
                    final index = loopMode == LoopMode.one ? 1 : 0;
                    return IconButton(
                      icon: Icon(icons[index], color: colors[index]),
                      onPressed: () {
                        _player.setLoopMode(loopMode == LoopMode.off ? LoopMode.one : LoopMode.off);
                      },
                    );
                  },
                ),
                IconButton(icon: const Icon(Icons.replay_10), onPressed: () => _player.seek(Duration(seconds: _player.position.inSeconds - 10))),
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      iconSize: 70,
                      icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.purpleAccent),
                      onPressed: playing ? _player.pause : _player.play,
                    );
                  },
                ),
                IconButton(icon: const Icon(Icons.forward_10), onPressed: () => _player.seek(Duration(seconds: _player.position.inSeconds + 10))),
                IconButton(icon: const Icon(Icons.shuffle), color: Colors.white54, onPressed: () {}), // Shuffle tạm thời chưa dùng
              ],
            )
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CLOSIK", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout, color: Colors.white54))],
      ),
      body: Column(
        children: [
          // --- THANH TÌM KIẾM ---
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              onChanged: (v) => setState(() { _searchQuery = v.toLowerCase(); }),
              decoration: InputDecoration(
                hintText: "Tìm kiếm bài hát, ca sĩ...",
                prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // Danh sách nhạc
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('songs').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                
                // Lọc bài hát theo từ khóa tìm kiếm
                var ds = snapshot.data!.docs.where((doc) {
                  String title = (doc['title'] ?? '').toString().toLowerCase();
                  String artist = (doc['artist'] ?? '').toString().toLowerCase();
                  return title.contains(_searchQuery) || artist.contains(_searchQuery);
                }).toList();

                if (ds.isEmpty) return const Center(child: Text("Không tìm thấy bài nào Khang ơi!"));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: ds.length,
                  itemBuilder: (context, index) {
                    var s = ds[index];
                    Map<String, dynamic> songData = s.data() as Map<String, dynamic>;
                    bool isPlaying = _currentSong != null && s.id == _currentSong!['id']; // Cần lưu id để so sánh

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                       color: isPlaying ? Colors.purpleAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: songData['image_url'] != null && songData['image_url'].isNotEmpty
                              ? DecorationImage(image: NetworkImage(songData['image_url']), fit: BoxFit.cover)
                              : const DecorationImage(image: AssetImage('assets/vinyl_placeholder.png')), // Cần ảnh placeholder
                          ),
                          child: songData['image_url'] == null || songData['image_url'].isEmpty 
                              ? const Icon(Icons.music_note, color: Colors.purpleAccent) : null,
                        ),
                        title: Text(songData['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isPlaying ? Colors.purpleAccent : Colors.white)),
                        subtitle: Text(songData['artist'] ?? '', style: const TextStyle(color: Colors.grey)),
                        trailing: isPlaying 
                          ? const Icon(Icons.volume_up, color: Colors.purpleAccent)
                          : const Icon(Icons.play_arrow, color: Colors.white24),
                        onTap: () {
                          Map<String, dynamic> dataToPlay = Map.from(songData);
                          dataToPlay['id'] = s.id; // Lưu ID để biết bài nào đang phát
                          _play(dataToPlay);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // --- BỘ ĐIỀU KHIỂN NHỎ BÊN DƯỚI (NHẤN VÀO ĐỂ PHÓNG TO) ---
          if (_currentSong != null)
            GestureDetector(
              onTap: _showNowPlaying, // Nhấn để phóng to
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    // Đĩa nhạc xoay nhỏ
                    AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) => Transform.rotate(angle: _rotationController.value * 2 * pi, child: child),
                      child: Container(
                        width: 45, height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: _currentSong!['image_url'] != null && _currentSong!['image_url'].isNotEmpty
                            ? DecorationImage(image: NetworkImage(_currentSong!['image_url']), fit: BoxFit.cover)
                            : const DecorationImage(image: AssetImage('assets/vinyl_placeholder.png')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_currentSong!['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text(_currentSong!['artist'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: _player.playerStateStream,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                          onPressed: playing ? _player.pause : _player.play,
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: _currentSong != null ? 70 : 0), // Tránh đè lên bộ điều khiển
        child: FloatingActionButton(onPressed: _showUploadDialog, backgroundColor: Colors.purpleAccent, child: const Icon(Icons.add, color: Colors.white)),
      ),
    );
  }
}