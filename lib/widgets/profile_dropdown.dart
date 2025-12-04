import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/theme/colors.dart';
import '../core/theme/theme_provider.dart';

class ProfileDropdown extends StatefulWidget {
  const ProfileDropdown({super.key});

  @override
  State<ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<ProfileDropdown> {
  bool _isDropdownOpen = false;
  final GlobalKey _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // User data from SharedPreferences
  String _fullName = "Not set";
  String _phoneNumber = "Not set";
  String _gender = "Not set";
  String _birthDate = "Not set";
  int _age = 0;
  bool _isLoading = true;

  @override
  void dispose() {
    // Remove overlay without calling setState
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fullName = prefs.getString('user_fullName') ?? "Not set";
        _phoneNumber = prefs.getString('user_phoneNumber') ?? "Not set";
        _gender = prefs.getString('user_gender') ?? "Not set";
        _age = prefs.getInt('user_age') ?? 0;
        
        final birthdayString = prefs.getString('user_birthday');
        if (birthdayString != null) {
          final birthday = DateTime.parse(birthdayString);
          _birthDate = '${birthday.day}/${birthday.month}/${birthday.year}';
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      // Handle error
    }
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final RenderBox renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildDropdownOverlay(offset, size),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isDropdownOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return GestureDetector(
      key: _dropdownKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode 
              ? AppColors.darkBackgroundMid.withOpacity(0.9)
              : Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.darkBackgroundDeep.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.person,
          size: 20,
          color: isDarkMode ? Colors.white : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildDropdownOverlay(Offset offset, Size size) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDarkMode = themeProvider.isDarkMode;
        final today = DateTime.now();
        final todayFormatted = '${today.day}/${today.month}/${today.year}';
        final screenSize = MediaQuery.of(context).size;
        
        // Calculate proper positioning to avoid overflow
        double left = offset.dx + size.width - 280; // Align right edge of dropdown with button
        double top = offset.dy + size.height + 8;
        
        // Ensure dropdown doesn't go off screen
        if (left < 16) left = 16; // Minimum left margin
        if (left + 280 > screenSize.width - 16) left = screenSize.width - 280 - 16; // Maximum right margin
        if (top + 400 > screenSize.height - 100) top = offset.dy - 400 - 8; // Flip upward if no space below
        
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Invisible barrier to detect outside taps
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDropdown,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
              
              // Dropdown Menu
              Positioned(
                left: left,
                top: top,
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping inside dropdown
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 280,
                      constraints: const BoxConstraints(maxHeight: 400),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? AppColors.darkBackgroundDeep
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode 
                              ? Colors.white.withOpacity(0.1) 
                              : Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: _isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: Color(0xFFFF6B6B),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFF6B6B).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Color(0xFFFF6B6B),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Profile',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode ? Colors.white : AppColors.lightTextPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Full Name
                                  _buildInfoRow(
                                    icon: Icons.badge_outlined,
                                    label: 'Full Name',
                                    value: _fullName,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(height: 12),

                                  // Phone Number
                                  _buildInfoRow(
                                    icon: Icons.phone_outlined,
                                    label: 'Phone Number',
                                    value: _phoneNumber,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(height: 12),

                                  // Gender
                                  _buildInfoRow(
                                    icon: Icons.person_pin_outlined,
                                    label: 'Gender',
                                    value: _gender,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(height: 12),

                                  // Birth Date & Age
                                  _buildInfoRow(
                                    icon: Icons.cake_outlined,
                                    label: 'Birth Date',
                                    value: _age > 0 ? '$_birthDate (Age: $_age)' : _birthDate,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(height: 12),

                                  // Today's Date
                                  _buildInfoRow(
                                    icon: Icons.today_outlined,
                                    label: 'Today\'s Date',
                                    value: todayFormatted,
                                    isDarkMode: isDarkMode,
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 12),

                                  // Sign Out Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: _signOut,
                                      icon: const Icon(
                                        Icons.logout,
                                        size: 16,
                                        color: Color(0xFFFF6B6B),
                                      ),
                                      label: Text(
                                        'Sign Out',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFFF6B6B),
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDarkMode,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}