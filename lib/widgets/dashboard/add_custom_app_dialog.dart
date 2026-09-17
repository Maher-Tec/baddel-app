import 'package:flutter/material.dart';

import '../../platform/keyboard_hook.dart';
import '../../settings/app_settings.dart';

class AddCustomAppDialog extends StatefulWidget {
  const AddCustomAppDialog({super.key, required this.settings, required this.hook});

  final AppSettings settings;
  final KeyboardHookClient hook;

  @override
  State<AddCustomAppDialog> createState() => AddCustomAppDialogState();
}

class AddCustomAppDialogState extends State<AddCustomAppDialog> {
  final TextEditingController _processController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> _runningApps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _isLoadingRunning = true;
  int _selectedTab = 0; // 0: Running Apps, 1: Popular Presets, 2: Manual Input

  final List<Map<String, String>> _popularApps = const [
    {'process': 'whatsapp.exe', 'label': 'WhatsApp', 'cat': 'Messaging'},
    {'process': 'antigravity.exe', 'label': 'AntiGravity', 'cat': 'IDE / AI'},
    {'process': 'telegram.exe', 'label': 'Telegram', 'cat': 'Messaging'},
    {'process': 'discord.exe', 'label': 'Discord', 'cat': 'Chat'},
    {'process': 'slack.exe', 'label': 'Slack', 'cat': 'Work Chat'},
    {'process': 'brave.exe', 'label': 'Brave Browser', 'cat': 'Browser'},
    {'process': 'firefox.exe', 'label': 'Firefox', 'cat': 'Browser'},
    {'process': 'msedge.exe', 'label': 'Microsoft Edge', 'cat': 'Browser'},
    {'process': 'obsidian.exe', 'label': 'Obsidian', 'cat': 'Notes'},
    {'process': 'notion.exe', 'label': 'Notion', 'cat': 'Notes'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRunningApps();
  }

  Future<void> _fetchRunningApps() async {
    final apps = await widget.hook.getRunningApps();
    if (!mounted) return;
    setState(() {
      _runningApps = apps;
      _filterApps(_searchController.text);
      _isLoadingRunning = false;
    });
  }

  void _filterApps(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _filteredApps = List.from(_runningApps);
    } else {
      _filteredApps = _runningApps.where((app) {
        final title = app['title']!.toLowerCase();
        final proc = app['processName']!.toLowerCase();

        return title.contains(q) || proc.contains(q);
      }).toList();
    }
  }

  @override
  void dispose() {
    _processController.dispose();
    _labelController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _addApp(String process, String label, String cat) {
    widget.settings.addCustomApp(
      processName: process,
      label: label,
      category: cat,
    );
    Navigator.of(context).pop();
  }

  IconData _getAppIcon(String processName) {
    final proc = processName.toLowerCase();
    if (proc.contains('whatsapp') ||
        proc.contains('telegram') ||
        proc.contains('discord') ||
        proc.contains('slack')) {
      return Icons.chat_rounded;
    }
    if (proc.contains('chrome') ||
        proc.contains('browser') ||
        proc.contains('firefox') ||
        proc.contains('edge') ||
        proc.contains('brave')) {
      return Icons.public_rounded;
    }
    if (proc.contains('code') ||
        proc.contains('antigravity') ||
        proc.contains('studio') ||
        proc.contains('idea')) {
      return Icons.code_rounded;
    }
    if (proc.contains('terminal') ||
        proc.contains('cmd') ||
        proc.contains('powershell')) {
      return Icons.terminal_rounded;
    }
    return Icons.laptop_windows_rounded;
  }

  Color _getAppIconBg(String processName) {
    final proc = processName.toLowerCase();
    if (proc.contains('whatsapp') || proc.contains('telegram')) {
      return const Color(0xFFDCFCE7);
    }
    if (proc.contains('chrome') ||
        proc.contains('browser') ||
        proc.contains('brave')) {
      return const Color(0xFFE0F2FE);
    }
    if (proc.contains('code') || proc.contains('antigravity')) {
      return const Color(0xFFE0E7FF);
    }
    return const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 650,
        height: 580,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dialog Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_to_photos_rounded,
                    color: Color(0xFF0F766E),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Protected Application',

                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Choose from live PC apps, popular presets, or enter a process name.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tab Selector Chips
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 0
                              ? [
                                  const BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: _selectedTab == 0
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Running PC Apps (${_runningApps.length})',

                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 0
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 1
                              ? [
                                  const BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              size: 18,
                              color: _selectedTab == 1
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Popular Presets',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 1
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedTab = 2),
                      borderRadius: BorderRadius.circular(10),

                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 2
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: _selectedTab == 2
                              ? [
                                  const BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: _selectedTab == 2
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Manual Input',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTab == 2
                                    ? const Color(0xFF0F766E)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tab Content 0: Running Apps
            if (_selectedTab == 0) ...[
              // Search Input & Refresh Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _filterApps(val)),
                      decoration: InputDecoration(
                        hintText:
                            'Search running PC apps (e.g. "WhatsApp", "Chrome")...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Color(0xFF0F766E),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),

                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() => _isLoadingRunning = true);
                      _fetchRunningApps();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Spacious Running Apps List View
              Expanded(
                child: _isLoadingRunning
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 14),
                            Text(
                              'Scanning active desktop applications...',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : _filteredApps.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),

                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.screen_search_desktop_rounded,
                              size: 48,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No matching running apps found.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Launch your app on Windows and click Refresh above.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(10),
                            itemCount: _filteredApps.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final app = _filteredApps[index];
                              final proc = app['processName']!;
                              final title = app['title']!;
                              final isAlreadyAdded = widget.settings
                                  .isTargetApp(proc);
                              final displayTitle = title
                                  .split('-')
                                  .first
                                  .trim();

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isAlreadyAdded
                                        ? const Color(0xFF86EFAC)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),

                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _getAppIconBg(proc),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getAppIcon(proc),
                                        size: 22,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title.length > 45
                                                      ? '${title.substring(0, 45)}...'
                                                      : title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF0F172A),
                                                  ),

                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFE2E8F0,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  proc,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF475569),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              const Text(
                                                '● Running',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF10B981),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    isAlreadyAdded
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 16,
                                                  color: Color(0xFF16A34A),
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  'Protected',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,

                                                    color: Color(0xFF16A34A),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF0F766E,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            onPressed: () => _addApp(
                                              proc,
                                              displayTitle.isEmpty
                                                  ? proc
                                                  : displayTitle,
                                              'Running PC App',
                                            ),
                                            icon: const Icon(
                                              Icons.add_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Add App',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
            ],

            // Tab Content 1: Popular Presets
            if (_selectedTab == 1) ...[
              const Text(
                'Click any popular application to add protection immediately:',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final app in _popularApps) ...[
                        InkWell(
                          onTap: () => _addApp(
                            app['process']!,
                            app['label']!,
                            app['cat']!,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 180,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getAppIconBg(app['process']!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getAppIcon(app['process']!),
                                    size: 20,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app['label']!,

                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        app['process']!,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            // Tab Content 2: Manual Input
            if (_selectedTab == 2) ...[
              const Text(
                'Type the executable name of any application installed on your PC:',

                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _processController,
                decoration: InputDecoration(
                  labelText: 'Process Name (e.g. whatsapp.exe or antigravity)',
                  hintText: 'antigravity.exe',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.app_shortcut_rounded,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Display Label (Optional)',
                  hintText: 'AntiGravity AI',

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(
                    Icons.label_outline_rounded,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,

                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                  ),
                  onPressed: () {
                    if (_processController.text.trim().isNotEmpty) {
                      _addApp(
                        _processController.text,
                        _labelController.text,
                        'Custom App',
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Add Application',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
