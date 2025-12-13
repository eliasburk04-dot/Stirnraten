import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../services/game_service.dart';
import 'lobby_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  final String playerName;

  const JoinRoomScreen({
    super.key,
    required this.playerName,
  });

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final _codeController = TextEditingController();
  bool _isJoining = false;
  bool _showQrScanner = false;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _qrController;

  @override
  void dispose() {
    _codeController.dispose();
    _qrController?.dispose();
    super.dispose();
  }

  Future<void> _joinRoom(String code) async {
    if (code.isEmpty) {
      _showError('Please enter a room code');
      return;
    }

    if (code.length < 6) {
      _showError('Room code must be 6 characters');
      return;
    }

    setState(() => _isJoining = true);

    final gameService = context.read<GameService>();
    final success = await gameService.joinRoom(code, widget.playerName);

    setState(() => _isJoining = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LobbyScreen()),
      );
    } else if (gameService.errorMessage != null && mounted) {
      _showError(gameService.errorMessage!);
      gameService.clearError();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    _qrController = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        // Pause camera and join room
        controller.pauseCamera();
        setState(() => _showQrScanner = false);
        _joinRoom(scanData.code!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: _showQrScanner ? _buildQrScanner() : _buildCodeEntry(),
        ),
      ),
    );
  }

  Widget _buildCodeEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      widget.playerName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Joining as',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        widget.playerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Room code input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Room Code',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      hintStyle: TextStyle(
                        color: Colors.white24,
                        letterSpacing: 8,
                      ),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    onSubmitted: _joinRoom,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Join button
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isJoining ? null : () => _joinRoom(_codeController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              icon: _isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.login),
              label: Text(
                _isJoining ? 'Joining...' : 'Join Room',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ],
          ),
          const SizedBox(height: 24),

          // Scan QR button
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showQrScanner = true),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).colorScheme.primary),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Scan QR Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrScanner() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              QRView(
                key: _qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Theme.of(context).colorScheme.primary,
                  borderRadius: 16,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 250,
                ),
              ),
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Point camera at QR code',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showQrScanner = false),
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter code manually'),
            ),
          ),
        ),
      ],
    );
  }
}
