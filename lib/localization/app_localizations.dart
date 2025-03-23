import 'dart:async';
import 'package:flutter/material.dart';
import 'package:time_clock/providers/time_clock_provider.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations? of(BuildContext? context) {
    return Localizations.of<AppLocalizations>(context!, AppLocalizations);
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    // Use the translations from TimeClockProvider
    final provider = TimeClockProvider();
    return provider.translations[locale.languageCode]?[key] ?? key;
  }
}

// LocalizationsDelegate is a factory for a set of localized resources
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  // This delegate instance will never change (it doesn't even have fields!)
  // It can provide a constant constructor.
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all of your supported language codes here
    return ['en', 'is'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading actually runs
    AppLocalizations localizations = AppLocalizations(locale);
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
