import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../theme/app_theme.dart';

class ConnectionStatusIndicator extends StatefulWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  State<ConnectionStatusIndicator> createState() => _ConnectionStatusIndicatorState();
}

class _ConnectionStatusIndicatorState extends State<ConnectionStatusIndicator> {
  bool _isConnected = true;
  bool _isChecking = false;
  String _statusMessage = 'Connected';

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);
      
      final response = await dio.get('${AppConfig.baseUrl}/api/health');
      
      setState(() {
        _isConnected = response.statusCode == 200;
        _statusMessage = _isConnected ? 'Connected' : 'Server Error';
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage = 'Server Offline';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isConnected) {
      return const SizedBox.shrink(); // Don't show anything when connected
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isChecking)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            )
          else
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.orange,
            ),
          const SizedBox(width: 8),
          Text(
            _isChecking ? 'Checking...' : _statusMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          if (!_isChecking)
            InkWell(
              onTap: _checkConnection,
              child: Icon(
                Icons.refresh,
                size: 16,
                color: Colors.orange,
              ),
            ),
        ],
      ),
    );
  }
}

class ConnectionStatusBanner extends StatefulWidget {
  final Widget child;
  
  const ConnectionStatusBanner({
    super.key,
    required this.child,
  });

  @override
  State<ConnectionStatusBanner> createState() => _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<ConnectionStatusBanner> {
  bool _isConnected = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 3);
      dio.options.receiveTimeout = const Duration(seconds: 3);
      
      await dio.get('${AppConfig.baseUrl}/api/health');
      
      setState(() {
        _isConnected = true;
        _showBanner = false;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
        _showBanner = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        if (_showBanner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: Colors.red.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Connection Lost',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Please check if the server is running at ${AppConfig.baseUrl}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _checkConnection,
                  child: Text(
                    'Retry',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showBanner = false;
                    });
                  },
                  icon: Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

// Helper function to check server connectivity
class ConnectionHelper {
  static Future<bool> checkServerConnection() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 3);
      dio.options.receiveTimeout = const Duration(seconds: 3);
      
      final response = await dio.get('${AppConfig.baseUrl}/api/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getServerStatus() async {
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 5);
      dio.options.receiveTimeout = const Duration(seconds: 5);
      
      final response = await dio.get('${AppConfig.baseUrl}/api/health');
      
      return {
        'connected': true,
        'status': 'online',
        'message': 'Server is running normally',
        'url': AppConfig.baseUrl,
      };
    } catch (e) {
      return {
        'connected': false,
        'status': 'offline',
        'message': 'Cannot connect to server',
        'error': e.toString(),
        'url': AppConfig.baseUrl,
      };
    }
  }
}
