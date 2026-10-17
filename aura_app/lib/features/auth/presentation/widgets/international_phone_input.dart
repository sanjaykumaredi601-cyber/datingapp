import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/phone_number_helper.dart';

/// Interactive International Phone Input with searchable Country Code Picker
/// Dual-Country Launch Support: Canada (+1) & India (+91) pinned at top
/// Supports full E.164 compliance and real-time network validation
class InternationalPhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<PhoneNumberValidationResult> onValidationChanged;
  final String initialCountryIso;
  final FocusNode? focusNode;

  const InternationalPhoneInput({
    super.key,
    required this.controller,
    required this.onValidationChanged,
    this.initialCountryIso = 'CA', // Default to Canada (+1)
    this.focusNode,
  });

  @override
  State<InternationalPhoneInput> createState() => _InternationalPhoneInputState();
}

class _InternationalPhoneInputState extends State<InternationalPhoneInput> {
  late CountryInfo _selectedCountry;
  PhoneNumberValidationResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _selectedCountry = PhoneNumberHelper.findByIsoCode(widget.initialCountryIso);
    widget.controller.addListener(_validateCurrentInput);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validateCurrentInput);
    super.dispose();
  }

  void _validateCurrentInput() {
    final result = PhoneNumberHelper.validate(
      country: _selectedCountry,
      rawInput: widget.controller.text,
    );
    if (!mounted) return;
    setState(() => _lastResult = result);
    widget.onValidationChanged(result);
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CountryPickerSheet(
        selectedCountry: _selectedCountry,
        onSelect: (country) {
          setState(() {
            _selectedCountry = country;
          });
          _validateCurrentInput();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _lastResult?.isValid ?? false;
    final hasInput = widget.controller.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xBF131924), // Smoked glass rgba(19, 25, 36, 0.75)
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasInput
                  ? (isValid
                      ? const Color(0xFFFF4D67) // Velvet Crimson
                      : AppColors.error.withValues(alpha: 0.6))
                  : const Color(0x33FF4D67),
              width: 1.5,
            ),
            boxShadow: [
              if (isValid)
                const BoxShadow(
                  color: Color(0x33FF4D67),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              // Country Selector Pill
              InkWell(
                onTap: _showCountryPicker,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountry.flag,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCountry.dialCode,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Vertical Divider
              Container(
                height: 28,
                width: 1,
                color: const Color(0x33FFFFFF),
              ),

              // Phone Number Text Field
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    hintText: 'e.g. ${_selectedCountry.example}',
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
                    suffixIcon: hasInput
                        ? Icon(
                            isValid ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            color: isValid ? const Color(0xFFFF4D67) : AppColors.error,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Real-time helper / error message
        if (hasInput && !isValid && _lastResult?.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _lastResult!.errorMessage!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (isValid && _lastResult?.formattedE164 != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFFFF4D67)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${_selectedCountry.name}: ${_lastResult?.formattedNational ?? _lastResult!.formattedE164}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFF4D67),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryInfo selectedCountry;
  final ValueChanged<CountryInfo> onSelect;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryInfo> _filteredCountries = PhoneNumberHelper.supportedCountries;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = PhoneNumberHelper.supportedCountries;
      } else {
        _filteredCountries = PhoneNumberHelper.supportedCountries.where((c) {
          return c.name.toLowerCase().contains(query) ||
              c.isoCode.toLowerCase().contains(query) ||
              c.dialCode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Color(0xF2080A0F), // 95% Deep Midnight Obsidian
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0x33FF4D67), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.public_rounded, color: Color(0xFFFF4D67), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Select Country / Region',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xBF131924),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33FF4D67)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Search by country or code...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white60, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),

          // Pinned Launch Regions Quick Select (Canada & India pinned at top)
          if (_searchController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x2BFF4D67),
                      Color(0x1F131924),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x4DFF4D67),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFF59E0B)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'PRIMARY LAUNCH REGIONS (PINNED)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Canada Quick Pill
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final caCountry = PhoneNumberHelper.findByIsoCode('CA');
                              widget.onSelect(caCountry);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: widget.selectedCountry.isoCode == 'CA'
                                    ? const Color(0x33FF4D67)
                                    : const Color(0x1FFFFFFF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.selectedCountry.isoCode == 'CA'
                                      ? const Color(0xFFFF4D67)
                                      : const Color(0x1FFFFFFF),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🇨🇦', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Canada (+1)',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // India Quick Pill
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final inCountry = PhoneNumberHelper.findByIsoCode('IN');
                              widget.onSelect(inCountry);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              decoration: BoxDecoration(
                                color: widget.selectedCountry.isoCode == 'IN'
                                    ? const Color(0x33FF4D67)
                                    : const Color(0x1FFFFFFF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: widget.selectedCountry.isoCode == 'IN'
                                      ? const Color(0xFFFF4D67)
                                      : const Color(0x1FFFFFFF),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'India (+91)',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Country list
          Expanded(
            child: ListView.separated(
              itemCount: _filteredCountries.length,
              separatorBuilder: (_, __) => const Divider(
                color: Color(0x1FFFFFFF),
                height: 1,
                indent: 64,
              ),
              itemBuilder: (context, index) {
                final country = _filteredCountries[index];
                final isSelected = country.isoCode == widget.selectedCountry.isoCode;

                return InkWell(
                  onTap: () {
                    widget.onSelect(country);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Text(country.flag, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            country.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFFF4D67) : Colors.white,
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          country.dialCode,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFF4D67) : Colors.white60,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFFFF4D67), size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
