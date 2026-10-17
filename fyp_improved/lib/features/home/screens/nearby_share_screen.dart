import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class NearbyShareScreen extends StatefulWidget {
  final String? initialText;

  const NearbyShareScreen({super.key, this.initialText});

  @override
  State<NearbyShareScreen> createState() => _NearbyShareScreenState();
}

class _NearbyShareScreenState extends State<NearbyShareScreen> {
  final String userName = "User_${Random().nextInt(10000)}";
  final Strategy strategy = Strategy.P2P_STAR;
  final String serviceId = "com.paypalm.nearby_share";

  bool isAdvertising = false;
  bool isDiscovering = false;
  bool isManualSenderMode = false;

  Map<String, ConnectionInfo> endpointMap = {};
  String? connectedEndpointId;
  String receivedText = "";

  final TextEditingController textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      textController.text = widget.initialText!;
      isManualSenderMode = true;
    }
    _checkPermissions();
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    textController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    bool allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      if (isManualSenderMode) {
        _startDiscovery();
      } else {
        _startAdvertising();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions required for Nearby Share'),
          ),
        );
      }
    }
  }

  Future<void> _startAdvertising() async {
    try {
      await Nearby().startAdvertising(
        userName,
        strategy,
        serviceId: serviceId,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() => connectedEndpointId = id);
            Nearby().stopAdvertising();
          }
        },
        onDisconnected: (id) => setState(() => connectedEndpointId = null),
      );
      setState(() => isAdvertising = true);
    } catch (e) {
      debugPrint("Advertising Error: $e");
    }
  }

  Future<void> _startDiscovery() async {
    try {
      await Nearby().startDiscovery(
        userName,
        strategy,
        serviceId: serviceId,
        onEndpointFound: (id, name, serviceId) {
          setState(() => endpointMap[id] = ConnectionInfo(name, "", false));
        },
        onEndpointLost: (id) => setState(() => endpointMap.remove(id)),
      );
      setState(() => isDiscovering = true);
    } catch (e) {
      debugPrint("Discovery Error: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: Text(
          "Connect to ${info.endpointName}?",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Reject", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (id, payload) {
                  if (payload.type == PayloadType.BYTES) {
                    setState(
                      () => receivedText = String.fromCharCodes(payload.bytes!),
                    );
                  }
                },
                onPayloadTransferUpdate: (id, update) {},
              );
            },
            child: const Text("Accept", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _sendPayload() {
    if (connectedEndpointId != null && textController.text.isNotEmpty) {
      Nearby().sendBytesPayload(
        connectedEndpointId!,
        Uint8List.fromList(textController.text.codeUnits),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sent!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Nearby Share",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 32),
            if (isManualSenderMode) _buildSenderUI() else _buildReceiverUI(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeTab("Receive", !isManualSenderMode)),
          Expanded(child: _buildModeTab("Send", isManualSenderMode)),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (isActive) return;
        setState(() {
          isManualSenderMode = !isManualSenderMode;
          endpointMap.clear();
          connectedEndpointId = null;
          Nearby().stopAdvertising();
          Nearby().stopDiscovery();
        });
        _checkPermissions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFB300) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white60,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Text to Share",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Paste your transcription here...",
            hintStyle: const TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            const Text(
              "Nearby Devices",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFFB300),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (endpointMap.isEmpty)
          _buildEmptyState("Scanning for nearby phones...")
        else
          ...endpointMap.entries
              .map((e) => _buildDeviceTile(e.key, e.value))
              ,
      ],
    );
  }

  Widget _buildReceiverUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.wifi_tethering,
                color: Color(0xFFFFB300),
                size: 48,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            "Waiting for Sender",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            "Visible to others as $userName",
            style: const TextStyle(color: Colors.white38),
          ),
        ),
        const SizedBox(height: 40),
        if (receivedText.isNotEmpty) ...[
          const Text(
            "Received Content",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              receivedText,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeviceTile(String id, ConnectionInfo info) {
    bool isConnected = connectedEndpointId == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android, color: Colors.white70),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              info.endpointName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isConnected)
            ElevatedButton(
              onPressed: _sendPayload,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Send", style: TextStyle(color: Colors.black)),
            )
          else
            TextButton(
              onPressed: () => Nearby().requestConnection(
                userName,
                id,
                onConnectionInitiated: _onConnectionInit,
                onConnectionResult: (id, status) {
                  if (status == Status.CONNECTED) {
                    setState(() => connectedEndpointId = id);
                  }
                },
                onDisconnected: (id) =>
                    setState(() => connectedEndpointId = null),
              ),
              child: const Text(
                "Connect",
                style: TextStyle(color: Color(0xFFFFB300)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_rounded,
            color: Colors.white.withValues(alpha: 0.1),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}
