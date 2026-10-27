import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'l10n.dart';
import 'widgets.dart';

/// Mohamed's public portfolio website, linked from the developer-contact
/// surfaces (AI "contact the developer" popup, Settings contact dialog).
const portfolioUrl = 'https://mohamed5946.github.io/portfolio/';

/// Opens the portfolio in the external browser. On failure, shows a
/// snackbar carrying the URL text itself (so it stays visible/copyable)
/// instead of failing silently.
Future<void> openPortfolioLink(BuildContext context) async {
  final uri = Uri.parse(portfolioUrl);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showSnack(context, '${t('linkOpenFailed')} $portfolioUrl', error: true);
  }
}
