import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';

/// Consistent scaffold wrapper with standard back navigation.
class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final String? fallbackRoute;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.showBackButton = true,
    this.fallbackRoute,
    this.onBackPressed,
    this.backgroundColor,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (onBackPressed != null) {
                    onBackPressed!();
                  } else {
                    context.goBackOr(fallbackRoute ?? RoutePaths.dashboard);
                  }
                },
              )
            : null,
        automaticallyImplyLeading: showBackButton,
        actions: actions,
        bottom: bottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

/// Scaffold with loading overlay support.
class AppScaffoldWithLoading extends StatelessWidget {
  final String title;
  final Widget body;
  final bool isLoading;
  final String? loadingMessage;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final String? fallbackRoute;

  const AppScaffoldWithLoading({
    super.key,
    required this.title,
    required this.body,
    this.isLoading = false,
    this.loadingMessage,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = true,
    this.fallbackRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppScaffold(
          title: title,
          body: body,
          actions: actions,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
          showBackButton: showBackButton,
          fallbackRoute: fallbackRoute,
        ),
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      if (loadingMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(loadingMessage!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
