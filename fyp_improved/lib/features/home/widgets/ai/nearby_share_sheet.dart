import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class NearbyShareSheet extends StatefulWidget {
  final String? textToShare;

  const NearbyShareSheet({super.key, this.textToShare});

  @override
  State<NearbyShareSheet> createState() => _NearbyShareSheetState();
}

class _NearbyShareSheetState extends State<NearbyShareSheet> {
  final String userName = "User_${Random().nextInt(10000)}";
  final Strategy strategy = Strategy.P2P_STAR;

  bool isAdvertising = false;
  bool isDiscovering = false;

  Map<String, ConnectionInfo> endpointMap = {};
  String? connectedEndpointId;

  String receivedText = "";
  final TextEditingController manualTextController = TextEditingController();
  bool isManualSenderMode = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
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

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    if (allGranted) {
      if (widget.textToShare != null) {
        _startDiscovery(); // Sender looks for receivers
      } else {
        _startAdvertising(); // Receiver waits for senders
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
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            setState(() {
              connectedEndpointId = id;
            });
            Nearby().stopAdvertising();
          }
        },
        onDisconnected: (id) {
          setState(() {
            connectedEndpointId = null;
          });
        },
      );
      setState(() {
        isAdvertising = a;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          setState(() {
            endpointMap[id] = ConnectionInfo(name, "", false);
          });
        },
        onEndpointLost: (id) {
          setState(() {
            endpointMap.remove(id);
          });
        },
      );
      setState(() {
        isDiscovering = a;
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text("Connect to ${info.endpointName}?"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: const Text("Reject"),
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await Nearby().rejectConnection(id);
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                    },
                  ),
                  ElevatedButton(
                    child: const Text("Accept"),
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() {
                        endpointMap[id] = info;
                      });
                      try {
                        await Nearby().acceptConnection(
                          id,
                          onPayLoadRecieved: (endpointId, payload) {
                            if (payload.type == PayloadType.BYTES) {
                              String str = String.fromCharCodes(payload.bytes!);
                              setState(() {
                                receivedText = str;
                              });
                            }
                          },
                          onPayloadTransferUpdate:
                              (endpointId, payloadTransferUpdate) {},
                        );
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendPayload(String text) {
    if (connectedEndpointId != null) {
      Nearby().sendBytesPayload(
        connectedEndpointId!,
        Uint8List.fromList(text.codeUnits),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sent successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (widget.textToShare != null || isManualSenderMode)
                ? 'Share Text'
                : 'Receive Text',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (widget.textToShare != null || isManualSenderMode) ...[
            // SENDER UI
            Text(
              "Looking for devices...",
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (endpointMap.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              ...endpointMap.entries.map((entry) {
                String id = entry.key;
                ConnectionInfo info = entry.value;
                return ListTile(
                  title: Text(info.endpointName),
                  trailing: connectedEndpointId == id
                      ? IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: () => _sendPayload(
                            widget.textToShare ?? manualTextController.text,
                          ),
                        )
                      : ElevatedButton(
                          child: const Text("Connect"),
                          onPressed: () async {
                            try {
                              await Nearby().requestConnection(
                                userName,
                                id,
                                onConnectionInitiated: _onConnectionInit,
                                onConnectionResult: (id, status) {
                                  if (status == Status.CONNECTED) {
                                    setState(() {
                                      connectedEndpointId = id;
                                    });
                                  }
                                },
                                onDisconnected: (id) {
                                  setState(() {
                                    connectedEndpointId = null;
                                  });
                                },
                              );
                            } catch (e) {
                              debugPrint(e.toString());
                            }
                          },
                        ),
                );
              }),
          ] else ...[
            // RECEIVER UI
            if (receivedText.isNotEmpty) ...[
              const Text(
                "Received Text:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(receivedText),
              ),
            ] else ...[
              TextField(
                controller: manualTextController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: "Paste text to send...",
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    onPressed: () async {
                      if (manualTextController.text.isNotEmpty) {
                        await Nearby().stopAdvertising();
                        setState(() {
                          isManualSenderMode = true;
                        });
                        _startDiscovery();
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "OR waiting to receive...",
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
          ],

          const SizedBox(height: 20),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
