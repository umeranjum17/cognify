import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/oauth_auth_provider.dart';

/// OAuth callback screen that handles the OAuth callback processing
class OAuthCallbackScreen extends StatefulWidget {
  final String? code;
  final String? state;
  final String? error;

  const OAuthCallbackScreen({
    super.key,
    this.code,
    this.state,
    this.error,
  });

  @override
  State<OAuthCallbackScreen> createState() => _OAuthCallbackScreenState();
}

class _OAuthCallbackScreenState extends State<OAuthCallbackScreen> {
  bool _isProcessing = true;
  String _status = 'Processing OAuth callback...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ],
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _processOAuthCallback();
  }

  Future<void> _processOAuthCallback() async {
    try {
      print('🔄 Processing OAuth callback in dedicated screen...');
      print('🔄 Code: ${widget.code != null && widget.code!.length > 10 ? '${widget.code!.substring(0, 10)}...' : widget.code}, State: ${widget.state != null && widget.state!.length > 20 ? '${widget.state!.substring(0, 20)}...' : widget.state}, Error: ${widget.error}');

      final oauthProvider = Provider.of<OAuthAuthProvider>(context, listen: false);
      
      // Handle the OAuth callback
      await oauthProvider.handleOAuthCallback(widget.code, widget.state, widget.error);

      // Wait a bit for the authentication state to be properly updated
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // After processing callback, redirect to root route which will handle navigation
        if (oauthProvider.isAuthenticated) {
          print('✅ OAuth callback successful, redirecting...');
          setState(() {
            _status = 'Authentication successful! Redirecting...';
          });
        } else {
          print('❌ OAuth callback failed, redirecting...');
          setState(() {
            _status = 'Authentication failed. Redirecting...';
          });
        }

        // Use a brief delay to show the status message, then redirect to root
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      print('❌ Error processing OAuth callback: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _status = 'Error processing authentication. Redirecting...';
        });

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          context.go('/');
        }
      }
    }
  }
} 