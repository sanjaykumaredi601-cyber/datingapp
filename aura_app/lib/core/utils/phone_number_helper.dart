/// Production-grade International Phone Number and E.164 Validation Helper
/// Supports Dual-Country Launch: Canada (+1) & India (+91) with strict national numbering plans
library;

class CountryInfo {
  final String name;
  final String isoCode;
  final String dialCode;
  final String flag;
  final String example;
  final int minLength;
  final int maxLength;
  final RegExp validationRegex;

  const CountryInfo({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    required this.example,
    required this.minLength,
    required this.maxLength,
    required this.validationRegex,
  });
}

class PhoneNumberValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? formattedE164;
  final String? formattedNational;

  const PhoneNumberValidationResult({
    required this.isValid,
    this.errorMessage,
    this.formattedE164,
    this.formattedNational,
  });
}

class PhoneNumberHelper {
  // E.164 international standard regex: +[1-9]\d{7,14}
  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');

  /// Whitelisted development & QA test phone numbers for Canada, US and India
  static const Set<String> testNumbers = {
    '4165550199',
    '4165550123',
    '6505551234',
    '1234567890',
    '9876543210',
    '9999999999',
  };

  /// Curated list of high-priority countries with Canada (+1) and India (+91) pinned at the top
  static final List<CountryInfo> supportedCountries = [
    // 1. Canada (NANP +1) - Pinned
    CountryInfo(
      name: 'Canada',
      isoCode: 'CA',
      dialCode: '+1',
      flag: '🇨🇦',
      example: '4165550199',
      minLength: 10,
      maxLength: 10,
      // North American Numbering Plan: area code [2-9]\d{2}, followed by 7 digits [0-9]\d{6}
      // Allows standard Canadian mobile/landline/VoIP exchanges and Firebase test numbers
      validationRegex: RegExp(r'^[2-9]\d{9}$'),
    ),
    // 2. India (+91) - Pinned
    CountryInfo(
      name: 'India',
      isoCode: 'IN',
      dialCode: '+91',
      flag: '🇮🇳',
      example: '9876543210',
      minLength: 10,
      maxLength: 10,
      // India: 10 digits starting with 6, 7, 8, or 9
      validationRegex: RegExp(r'^[6-9]\d{9}$'),
    ),
    // 3. United States (NANP +1)
    CountryInfo(
      name: 'United States',
      isoCode: 'US',
      dialCode: '+1',
      flag: '🇺🇸',
      example: '6505551234',
      minLength: 10,
      maxLength: 10,
      validationRegex: RegExp(r'^[2-9]\d{9}$'),
    ),
    // 4. United Kingdom
    CountryInfo(
      name: 'United Kingdom',
      isoCode: 'GB',
      dialCode: '+44',
      flag: '🇬🇧',
      example: '7911123456',
      minLength: 10,
      maxLength: 10,
      validationRegex: RegExp(r'^7\d{9}$'),
    ),
    // 5. Australia
    CountryInfo(
      name: 'Australia',
      isoCode: 'AU',
      dialCode: '+61',
      flag: '🇦🇺',
      example: '412345678',
      minLength: 9,
      maxLength: 9,
      validationRegex: RegExp(r'^4\d{8}$'),
    ),
    // 6. United Arab Emirates
    CountryInfo(
      name: 'United Arab Emirates',
      isoCode: 'AE',
      dialCode: '+971',
      flag: '🇦🇪',
      example: '501234567',
      minLength: 9,
      maxLength: 9,
      validationRegex: RegExp(r'^5\d{8}$'),
    ),
    // 7. Singapore
    CountryInfo(
      name: 'Singapore',
      isoCode: 'SG',
      dialCode: '+65',
      flag: '🇸🇬',
      example: '81234567',
      minLength: 8,
      maxLength: 8,
      validationRegex: RegExp(r'^[89]\d{7}$'),
    ),
    // 8. Japan
    CountryInfo(
      name: 'Japan',
      isoCode: 'JP',
      dialCode: '+81',
      flag: '🇯🇵',
      example: '9012345678',
      minLength: 10,
      maxLength: 10,
      validationRegex: RegExp(r'^[789]0\d{8}$'),
    ),
  ];

  /// Find country by ISO code (case-insensitive)
  static CountryInfo findByIsoCode(String isoCode) {
    return supportedCountries.firstWhere(
      (c) => c.isoCode.toUpperCase() == isoCode.toUpperCase(),
      orElse: () => supportedCountries.first, // Fallback to Canada
    );
  }

  /// Find country by dial code
  static CountryInfo? findByDialCode(String dialCode) {
    try {
      return supportedCountries.firstWhere((c) => c.dialCode == dialCode);
    } catch (_) {
      return null;
    }
  }

  /// Clean input string to digits only
  static String extractDigits(String input) {
    return input.replaceAll(RegExp(r'\D'), '');
  }

  /// Formats national number into country-specific presentation format
  /// - Canada/NANP: (416) 555-0123
  /// - India: 98765-43210
  static String formatNationalDisplay(CountryInfo country, String nationalNumber) {
    final digits = extractDigits(nationalNumber);
    if (country.isoCode == 'CA' || country.isoCode == 'US') {
      if (digits.length == 10) {
        return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
      }
    } else if (country.isoCode == 'IN') {
      if (digits.length == 10) {
        return '${digits.substring(0, 5)}-${digits.substring(5)}';
      }
    }
    return digits;
  }

  /// Formats raw national number and dial code into standard E.164 string: `+14165550123` or `+919876543210`
  static String formatE164(String dialCode, String nationalNumber) {
    var digits = extractDigits(nationalNumber);
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    final cleanDial = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    return '$cleanDial$digits';
  }

  /// Validates national numbering plan constraints and global ITU E.164 compliance
  static PhoneNumberValidationResult validate({
    required CountryInfo country,
    required String rawInput,
  }) {
    var digits = extractDigits(rawInput);
    final dialDigits = extractDigits(country.dialCode);
    if (digits.startsWith(dialDigits) && digits.length > country.maxLength) {
      digits = digits.substring(dialDigits.length);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.isEmpty) {
      return const PhoneNumberValidationResult(
        isValid: false,
        errorMessage: 'Phone number cannot be empty',
      );
    }

    if (digits.length < country.minLength) {
      return PhoneNumberValidationResult(
        isValid: false,
        errorMessage: '${country.name} numbers require at least ${country.minLength} digits',
      );
    }

    if (digits.length > country.maxLength) {
      return PhoneNumberValidationResult(
        isValid: false,
        errorMessage: '${country.name} numbers cannot exceed ${country.maxLength} digits',
      );
    }

    final isTestNumber = testNumbers.contains(digits);
    if (!isTestNumber && !country.validationRegex.hasMatch(digits)) {
      if (country.isoCode == 'CA') {
        return PhoneNumberValidationResult(
          isValid: false,
          errorMessage: 'Invalid Canadian number format (e.g. ${formatNationalDisplay(country, country.example)})',
        );
      } else if (country.isoCode == 'IN') {
        return PhoneNumberValidationResult(
          isValid: false,
          errorMessage: 'Indian numbers must start with 6, 7, 8, or 9 (e.g. ${formatNationalDisplay(country, country.example)})',
        );
      }
      return PhoneNumberValidationResult(
        isValid: false,
        errorMessage: 'Invalid number format for ${country.name} (e.g. ${country.example})',
      );
    }

    final e164 = formatE164(country.dialCode, digits);
    if (!_e164Regex.hasMatch(e164)) {
      return const PhoneNumberValidationResult(
        isValid: false,
        errorMessage: 'Failed international E.164 compliance check',
      );
    }

    return PhoneNumberValidationResult(
      isValid: true,
      formattedE164: e164,
      formattedNational: formatNationalDisplay(country, digits),
    );
  }

  static bool isValidE164String(String e164) {
    return _e164Regex.hasMatch(e164);
  }
}
