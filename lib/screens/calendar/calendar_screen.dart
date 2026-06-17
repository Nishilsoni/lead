import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_theme.dart';
import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import '../leads/lead_activities_screen.dart';

enum CalendarView { month, week, day, list }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _service = CalendarService();

  CalendarView _view = CalendarView.month;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  // Toggles (web: Task & Appointment / Activity)
  bool _showAppointments = true;
  bool _showActivities = true;

  // Filters (empty set = show all)
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedAssignees = {}; // by assignee id

  List<CalendarEvent> _events = [];
  bool _loading = true;
  String? _error;

  // Loaded date window (the 6-week grid around the focused month)
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Data ──────────────────────────────────────────────────────────

  List<DateTime> _gridDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    // Sunday-first grid to match the web version.
    final start = first.subtract(Duration(days: first.weekday % 7));
    return List.generate(42, (i) => DateTime(start.year, start.month, start.day + i));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final grid = _gridDays(_focusedMonth);
    _rangeStart = grid.first;
    _rangeEnd = grid.last.add(const Duration(hours: 23, minutes: 59));
    try {
      final events = await _service.getEvents(since: _rangeStart, until: _rangeEnd);
      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Reload only if the requested day falls outside the loaded window.
  Future<void> _ensureRange(DateTime day) async {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(_rangeStart) || d.isAfter(_rangeEnd)) {
      _focusedMonth = DateTime(day.year, day.month);
      await _load();
    }
  }

  List<CalendarEvent> get _filtered => _events.where((e) {
        if (e.isAppointment && !_showAppointments) return false;
        if (e.isActivity && !_showActivities) return false;
        if (_selectedCategories.isNotEmpty &&
            !_selectedCategories.contains(e.category)) {
          return false;
        }
        if (_selectedAssignees.isNotEmpty &&
            !_selectedAssignees.contains(e.assigneeId)) {
          return false;
        }
        return true;
      }).toList();

  List<CalendarEvent> _eventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _filtered.where((e) => e.dayKey == key).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Map<String, String> get _availableAssignees {
    final map = <String, String>{};
    for (final e in _events) {
      if (e.assigneeId.isNotEmpty) map[e.assigneeId] = e.assigneeName;
    }
    return map;
  }

  List<String> get _availableCategories {
    final set = <String>{};
    for (final e in _events) {
      if (e.category.isNotEmpty) set.add(e.category);
    }
    final list = set.toList()..sort();
    return list;
  }

  // ── Navigation between periods ────────────────────────────────────

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = DateTime(now.year, now.month, now.day);
      _focusedMonth = DateTime(now.year, now.month);
    });
    _load();
  }

  Future<void> _goPrev() async {
    switch (_view) {
      case CalendarView.month:
      case CalendarView.list:
        setState(() => _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month - 1));
        await _load();
        break;
      case CalendarView.week:
        final d = _selectedDay.subtract(const Duration(days: 7));
        setState(() => _selectedDay = d);
        await _ensureRange(d);
        break;
      case CalendarView.day:
        final d = _selectedDay.subtract(const Duration(days: 1));
        setState(() => _selectedDay = d);
        await _ensureRange(d);
        break;
    }
  }

  Future<void> _goNext() async {
    switch (_view) {
      case CalendarView.month:
      case CalendarView.list:
        setState(() => _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month + 1));
        await _load();
        break;
      case CalendarView.week:
        final d = _selectedDay.add(const Duration(days: 7));
        setState(() => _selectedDay = d);
        await _ensureRange(d);
        break;
      case CalendarView.day:
        final d = _selectedDay.add(const Duration(days: 1));
        setState(() => _selectedDay = d);
        await _ensureRange(d);
        break;
    }
  }

  String get _periodTitle {
    switch (_view) {
      case CalendarView.month:
      case CalendarView.list:
        return DateFormat('MMMM yyyy').format(_focusedMonth);
      case CalendarView.week:
        final week = _weekDays(_selectedDay);
        final a = week.first, b = week.last;
        if (a.month == b.month) {
          return '${DateFormat('MMM d').format(a)} – ${DateFormat('d').format(b)}';
        }
        return '${DateFormat('MMM d').format(a)} – ${DateFormat('MMM d').format(b)}';
      case CalendarView.day:
        return DateFormat('EEE, MMM d').format(_selectedDay);
    }
  }

  List<DateTime> _weekDays(DateTime day) {
    final start = day.subtract(Duration(days: day.weekday % 7));
    return List.generate(
        7, (i) => DateTime(start.year, start.month, start.day + i));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text('Calendar',
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlBar(),
          _buildViewSwitcher(),
          _buildFilterRow(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Control bar: ‹ Today › + period title ─────────────────────────

  Widget _buildControlBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          _circleBtn(Icons.chevron_left_rounded, _goPrev),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: _goToday,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              foregroundColor: AppTheme.primaryBlue,
            ),
            child: Text('Today',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          _circleBtn(Icons.chevron_right_rounded, _goNext),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _periodTitle,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF1F5F9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  // ── View switcher: Month / Week / Day / List ──────────────────────

  Widget _buildViewSwitcher() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: CalendarView.values.map((v) {
            final selected = _view == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _view = v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _viewLabel(v),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? AppTheme.primaryBlue
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _viewLabel(CalendarView v) {
    switch (v) {
      case CalendarView.month:
        return 'Month';
      case CalendarView.week:
        return 'Week';
      case CalendarView.day:
        return 'Day';
      case CalendarView.list:
        return 'List';
    }
  }

  // ── Filter row ────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              label: _selectedCategories.isEmpty
                  ? 'Categories'
                  : 'Categories (${_selectedCategories.length})',
              icon: Icons.filter_list_rounded,
              active: _selectedCategories.isNotEmpty,
              onTap: _openCategoryFilter,
            ),
            const SizedBox(width: 8),
            _filterChip(
              label: _selectedAssignees.isEmpty
                  ? 'Assignees'
                  : 'Assignees (${_selectedAssignees.length})',
              icon: Icons.people_alt_rounded,
              active: _selectedAssignees.isNotEmpty,
              onTap: _openAssigneeFilter,
            ),
            const SizedBox(width: 8),
            _toggleChip(
              label: 'Appointments',
              dotColor: const Color(0xFF1A73E8),
              on: _showAppointments,
              onTap: () =>
                  setState(() => _showAppointments = !_showAppointments),
            ),
            const SizedBox(width: 8),
            _toggleChip(
              label: 'Activity',
              dotColor: const Color(0xFF8B5CF6),
              on: _showActivities,
              onTap: () => setState(() => _showActivities = !_showActivities),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? AppTheme.primaryBlue.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.primaryBlue.withValues(alpha: 0.4)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? AppTheme.primaryBlue : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppTheme.primaryBlue
                          : AppTheme.textSecondary)),
              const SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: active ? AppTheme.primaryBlue : AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required Color dotColor,
    required bool on,
    required VoidCallback onTap,
  }) {
    return Material(
      color: on ? dotColor.withValues(alpha: 0.10) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: on ? dotColor.withValues(alpha: 0.5) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: on ? dotColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: on ? dotColor : AppTheme.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: on
                    ? const Icon(Icons.check, size: 9, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 7),
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? dotColor : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body dispatch ─────────────────────────────────────────────────

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 12),
              Text('Failed to load calendar',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppTheme.textTertiary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    switch (_view) {
      case CalendarView.month:
        return _buildMonthView();
      case CalendarView.week:
        return _buildWeekView();
      case CalendarView.day:
        return _buildDayView();
      case CalendarView.list:
        return _buildListView();
    }
  }

  // ── Month view ────────────────────────────────────────────────────

  Widget _buildMonthView() {
    final days = _gridDays(_focusedMonth);
    final dayEvents = _eventsForDay(_selectedDay);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _weekdayHeader(),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.74,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: days.length,
          itemBuilder: (_, i) => _monthCell(days[i]),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        ..._dayEventSection(
          dayEvents,
          DateFormat('EEEE, MMMM d').format(_selectedDay),
        ),
      ],
    );
  }

  Widget _weekdayHeader() {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Row(
        children: labels.map((l) {
          final isWeekend = l == 'Sun' || l == 'Sat';
          return Expanded(
            child: Center(
              child: Text(
                l,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isWeekend
                        ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                        : AppTheme.textTertiary),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _monthCell(DateTime day) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isSelected = day.year == _selectedDay.year &&
        day.month == _selectedDay.month &&
        day.day == _selectedDay.day;
    final inMonth = day.month == _focusedMonth.month;
    final isWeekend = day.weekday == DateTime.sunday || day.weekday == DateTime.saturday;
    final events = _eventsForDay(day);

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.08)
              : (isWeekend && inMonth
                  ? const Color(0xFFFEF2F2)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppTheme.primaryBlue, width: 1.5)
              : Border.all(color: const Color(0xFFF1F5F9)),
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isToday ? AppTheme.primaryBlue : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? Colors.white
                        : (inMonth
                            ? (isWeekend
                                ? const Color(0xFFEF4444)
                                : AppTheme.textPrimary)
                            : AppTheme.textTertiary.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            _eventDots(events),
          ],
        ),
      ),
    );
  }

  Widget _eventDots(List<CalendarEvent> events) {
    if (events.isEmpty) return const SizedBox.shrink();
    final shown = events.take(3).toList();
    final extra = events.length - shown.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 2,
      children: [
        ...shown.map((e) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: e.color, shape: BoxShape.circle),
            )),
        if (extra > 0)
          Text('+$extra',
              style: GoogleFonts.inter(
                  fontSize: 8,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary)),
      ],
    );
  }

  // ── Week view ─────────────────────────────────────────────────────

  Widget _buildWeekView() {
    final week = _weekDays(_selectedDay);
    final dayEvents = _eventsForDay(_selectedDay);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Row(
            children: week.map((day) {
              final isSelected = day.day == _selectedDay.day &&
                  day.month == _selectedDay.month &&
                  day.year == _selectedDay.year;
              final now = DateTime.now();
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;
              final count = _eventsForDay(day).length;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: AppTheme.primaryBlue, width: 1.2)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E').format(day).substring(0, 1),
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppTheme.textTertiary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: count > 0
                                ? (isSelected ? Colors.white : AppTheme.primaryBlue)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Container(height: 1, color: const Color(0xFFF1F5F9)),
        ..._dayEventSection(
          dayEvents,
          DateFormat('EEEE, MMMM d').format(_selectedDay),
        ),
      ],
    );
  }

  // ── Day view ──────────────────────────────────────────────────────

  Widget _buildDayView() {
    final dayEvents = _eventsForDay(_selectedDay);
    return ListView(
      padding: EdgeInsets.zero,
      children: _dayEventSection(
        dayEvents,
        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
        showTime: true,
      ),
    );
  }

  // ── List view ─────────────────────────────────────────────────────

  Widget _buildListView() {
    final events = _filtered
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (events.isEmpty) {
      return _emptyState('No events this month',
          'Nothing scheduled or logged for ${DateFormat('MMMM yyyy').format(_focusedMonth)}.');
    }
    // Group by day
    final groups = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(e.dayKey, () => []).add(e);
    }
    final keys = groups.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final day = keys[i];
        final dayEvents = groups[day]!;
        final now = DateTime.now();
        final isToday =
            day.year == now.year && day.month == now.month && day.day == now.day;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Text(
                    DateFormat('EEE, MMM d').format(day),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isToday
                            ? AppTheme.primaryBlue
                            : AppTheme.textPrimary),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Today',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue)),
                    ),
                  ],
                ],
              ),
            ),
            ...dayEvents.map((e) => _eventCard(e)),
          ],
        );
      },
    );
  }

  // ── Shared: day event section (returns list items for a scroll view) ─

  List<Widget> _dayEventSection(List<CalendarEvent> events, String header,
      {bool showTime = false}) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(header,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ),
            if (events.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${events.length}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue)),
              ),
          ],
        ),
      ),
      if (events.isEmpty)
        _inlineEmpty('No events', 'Nothing scheduled or logged for this day.')
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            children: events.map((e) => _eventCard(e, showTime: showTime)).toList(),
          ),
        ),
    ];
  }

  Widget _inlineEmpty(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                size: 34, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textTertiary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_rounded,
                  size: 34, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.textTertiary, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // ── Event card ────────────────────────────────────────────────────

  Widget _eventCard(CalendarEvent e, {bool showTime = false}) {
    return GestureDetector(
      onTap: () => _showEventDetail(e),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: e.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(e.icon, size: 19, color: e.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: e.color.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(e.category,
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: e.color)),
                                ),
                                const SizedBox(width: 6),
                                _typePill(e),
                                const Spacer(),
                                Text(
                                  DateFormat('h:mm a').format(e.dateTime),
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              e.leadName,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (e.note.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                e.note,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.35),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 13, color: AppTheme.textTertiary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    e.assigneeName,
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textTertiary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (e.status != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: e.statusColor
                                          .withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: e.statusColor
                                              .withValues(alpha: 0.25)),
                                    ),
                                    child: Text(e.status!,
                                        style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: e.statusColor)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typePill(CalendarEvent e) {
    final isApp = e.isAppointment;
    final color = isApp ? const Color(0xFF1A73E8) : const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(isApp ? 'Appointment' : 'Activity',
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Event detail sheet ────────────────────────────────────────────

  void _showEventDetail(CalendarEvent e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(e.icon, color: e.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.leadName,
                          style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      Text('${e.category} · ${e.isAppointment ? 'Appointment' : 'Activity'}',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: e.color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (e.status != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: e.statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: e.statusColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(e.status!,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: e.statusColor)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.schedule_rounded, 'When',
                DateFormat('EEEE, MMM d, yyyy · h:mm a').format(e.dateTime)),
            const SizedBox(height: 14),
            _detailRow(Icons.person_outline_rounded, 'Assigned to', e.assigneeName),
            if (e.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailRow(Icons.notes_rounded, 'Note', e.note),
            ],
            if (e.leadId != null && e.leadId!.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeadActivitiesScreen(
                          leadId: e.leadId!,
                          leadName: e.leadName,
                          assignedUserId: e.assigneeId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('View Lead Activities'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textTertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Filter bottom sheets ──────────────────────────────────────────

  void _openCategoryFilter() {
    final categories = _availableCategories;
    _openMultiSelectSheet(
      title: 'Filter by Category',
      options: {for (final c in categories) c: c},
      selected: _selectedCategories,
      onApply: (sel) => setState(() {
        _selectedCategories
          ..clear()
          ..addAll(sel);
      }),
    );
  }

  void _openAssigneeFilter() {
    _openMultiSelectSheet(
      title: 'Filter by Assignee',
      options: _availableAssignees, // id -> name
      selected: _selectedAssignees,
      onApply: (sel) => setState(() {
        _selectedAssignees
          ..clear()
          ..addAll(sel);
      }),
    );
  }

  /// [options] maps value-key -> display label.
  void _openMultiSelectSheet({
    required String title,
    required Map<String, String> options,
    required Set<String> selected,
    required ValueChanged<Set<String>> onApply,
  }) {
    final temp = Set<String>.from(selected);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(title,
                        style: GoogleFonts.inter(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (temp.isNotEmpty)
                      TextButton(
                        onPressed: () => setSheet(() => temp.clear()),
                        child: Text('Clear',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFEF4444))),
                      ),
                  ],
                ),
              ),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Nothing to filter yet',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.textTertiary)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: options.entries.map((entry) {
                      final isOn = temp.contains(entry.key);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setSheet(() {
                            if (isOn) {
                              temp.remove(entry.key);
                            } else {
                              temp.add(entry.key);
                            }
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isOn
                                        ? AppTheme.primaryBlue
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isOn
                                          ? AppTheme.primaryBlue
                                          : const Color(0xFFCBD5E1),
                                      width: 1.6,
                                    ),
                                  ),
                                  child: isOn
                                      ? const Icon(Icons.check,
                                          size: 15, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(entry.value,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onApply(temp);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Apply',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
