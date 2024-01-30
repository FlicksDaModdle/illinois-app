import 'package:flutter/material.dart';
import 'package:illinois/utils/AppUtils.dart';
import 'package:intl/intl.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:illinois/model/CustomCourses.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/CustomCourses.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'package:table_calendar/table_calendar.dart';

class StreakPanel extends StatefulWidget {
  final UserCourse userCourse;
  final CourseConfig? courseConfig;
  final DateTime? firstScheduleItemCompleted;

  const StreakPanel({required this.userCourse, this.courseConfig, this.firstScheduleItemCompleted});

  @override
  State<StreakPanel> createState() => _StreakPanelState();
}

class _StreakPanelState extends State<StreakPanel> {
  CourseConfig? _courseConfig;
  bool _loading = false;
  late int _streak;
  int? _pauses;

  @override
  void initState() {
    _streak = widget.userCourse.streak ?? 0;
    _pauses = widget.userCourse.pauses;
    if (widget.courseConfig != null) {
      _courseConfig = widget.courseConfig;
    } else {
      _loadCourseConfig();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    double circleSize = 100.0;
    if (_streak >= 100) {
      circleSize += 60.0;
    } else if (_streak >= 10) {
      circleSize += 10.0;
    }
    Widget bigCircle = new Container(
      width: circleSize,
      height: circleSize,
      decoration: new BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );

    List<Widget> pauseIconWidgets = [];
    for(int i = 0; i < (_courseConfig?.maxPauses ?? 0); i++) {
      pauseIconWidgets.add(Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: i < (_pauses ?? 0) ? Styles().images.getImage('pause-filled-blue') : Styles().images.getImage('pause-empty-blue'),
      ));
    }

    String earnedPausesText = Localization().getStringEx('panel.essential_skills_coach.pauses.missing.text', 'Your number of pauses could not be determined.');
    if (_pauses != null) {
      if (_courseConfig?.maxPauses != null) {
        earnedPausesText = 'You have earned $_pauses of ${_courseConfig!.maxPauses} pauses.';
      } else {
        earnedPausesText = 'You have earned $_pauses ${_pauses! == 1 ? 'pause' : 'pauses'}.';
      }
    }
    String pauseRewardText = Localization().getStringEx('panel.essential_skills_coach.pauses_reward.missing.text', 'Pauses can be earned by responding to tasks daily. Check in daily to keep your streak going!');
    if (_courseConfig?.pauseRewardStreak != null) {
      pauseRewardText = 'Pauses can be earned by responding to a task for ${_courseConfig!.pauseRewardStreak} consecutive days. Check in daily to keep your streak going!';
    }

    return Scaffold(
      appBar: HeaderBar(title: Localization().getStringEx('panel.essential_skills_coach.streak.header.title', 'Streak'),
        textStyle: Styles().textStyles.getTextStyle('header_bar'),),
      body: _loading ? Center(child: CircularProgressIndicator()) :
        SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            alignment: AlignmentDirectional.center,
                            children: [
                              bigCircle,
                              Text(_streak.toString(), style: TextStyle(fontSize: 80, color: Styles().colors.fillColorPrimary), textAlign: TextAlign.center,)
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(Localization().getStringEx('panel.essential_skills_coach.streak.days.suffix', "Day Streak!"), style: Styles().textStyles.getTextStyle("widget.title.light.huge.fat")),
                          )
                        ],
                      ),
                      Styles().images.getImage("streak") ?? Container()
                    ],
                  ),
                ),
                Padding(
                  padding:EdgeInsets.only(left: 16, top: 16),
                  child:Text(Localization().getStringEx('panel.essential_skills_coach.streak.calendar.header', "Calender"), style: Styles().textStyles.getTextStyle("widget.title.light.large.fat")),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Styles().colors.gradientColorPrimary),
                      borderRadius: BorderRadius.all(
                          Radius.circular(5.0)
                      ),
                    ),
                    child: TableCalendar(
                      selectedDayPredicate: (day) {
                        Duration startOfDayWithTolerance = Duration(minutes: 5, seconds: _courseConfig?.streaksProcessTime ?? 0);
                        return widget.userCourse.isDateStreak(day, widget.firstScheduleItemCompleted, startOfDayWithTolerance);
                      },
                      holidayPredicate: (day) {
                        Duration startOfDayWithTolerance = Duration(minutes: 5, seconds: _courseConfig?.streaksProcessTime ?? 0);
                        return widget.userCourse.isDatePauseUse(day, startOfDayWithTolerance);
                      },
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        titleTextStyle: Styles().textStyles.getTextStyle("widget.title.light.large.fat") ?? TextStyle(),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: Colors.white,
                        ),
                        rightChevronIcon: Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                        )
                      ),
                      availableCalendarFormats: const {
                        CalendarFormat.month : 'Month'
                      },
                      availableGestures: AvailableGestures.horizontalSwipe,
                      pageJumpingEnabled: true,
                      rangeSelectionMode: RangeSelectionMode.disabled,
                      daysOfWeekStyle: DaysOfWeekStyle(
                        dowTextFormatter: (date, locale) => DateFormat.E(locale).format(date).substring(0, 2),
                        weekdayStyle: Styles().textStyles.getTextStyle("widget.title.light.small.fat") ?? TextStyle(),
                        weekendStyle: Styles().textStyles.getTextStyle("widget.title.light.small.fat") ?? TextStyle(),
                      ),
                      calendarStyle: CalendarStyle(
                        // outsideDaysVisible: false,
                        defaultTextStyle: Styles().textStyles.getTextStyle("widget.title.light.large.fat") ?? TextStyle(),
                        holidayTextStyle: Styles().textStyles.getTextStyle("widget.title.light.large.fat") ?? TextStyle(),  // used for pauses
                        holidayDecoration: BoxDecoration(color: Styles().colors.fillColorPrimary, border: Border.all(color: Styles().colors.gradientColorPrimary, width: 2.0), shape: BoxShape.circle),  // used for pauses
                        weekendTextStyle: Styles().textStyles.getTextStyle("widget.title.light.large.fat") ?? TextStyle(),
                        todayDecoration: BoxDecoration(color: Styles().colors.surfaceAccent, shape: BoxShape.circle),
                        todayTextStyle: Styles().textStyles.getTextStyle("widget.detail.large.fat") ?? TextStyle(),
                        selectedTextStyle: Styles().textStyles.getTextStyle("widget.title.light.large.fat") ?? TextStyle(),
                        selectedDecoration: BoxDecoration(color: Styles().colors.gradientColorPrimary, shape: BoxShape.rectangle),
                      ),
                      firstDay: widget.userCourse.dateCreated ?? DateTime(2024, 2, 1),
                      lastDay: DateTime.now().add(Duration(days: 365)),
                      focusedDay: DateTime(2024 ,2, 1),
                    ),
                  ),
                ),

                Padding(
                  padding:EdgeInsets.only(left: 16, top: 16),
                  child:Text(Localization().getStringEx('panel.essential_skills_coach.streak.pauses.header', "Pauses"), style: Styles().textStyles.getTextStyle("widget.title.light.large.fat")),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Styles().colors.gradientColorPrimary),
                      borderRadius: BorderRadius.all(
                          Radius.circular(5.0)
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pauseIconWidgets.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: pauseIconWidgets,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(earnedPausesText, style: Styles().textStyles.getTextStyle("widget.title.light.regular.fat")),
                          ),
                          Text(pauseRewardText, style: Styles().textStyles.getTextStyle("widget.title.light.regular.thin")),
                        ]
                      ),
                    ),
                  ),
                ),
              ],
          ),
        ),
      ),
      backgroundColor: Styles().colors.fillColorPrimary,
    );
  }

  // Widget? _buildToday(BuildContext context, DateTime day, DateTime focusedDay) {
  //   return Center(
  //     child: Stack(
  //       alignment: AlignmentDirectional.center,
  //       children: [
  //         Container(
  //           width: 32,
  //           height: 32,
  //           decoration: new BoxDecoration(
  //             color: Colors.white,
  //             shape: BoxShape.circle,
  //           ),
  //         ),
  //         Text(day.day.toString(), style: Styles().textStyles.getTextStyle("widget.detail.small.fat"), textAlign: TextAlign.center,)
  //       ],
  //     ),
  //   );
  // }

  Future<void> _loadCourseConfig() async {
    if (StringUtils.isNotEmpty(Config().essentialSkillsCoachKey)) {
      _setLoading(true);
      CourseConfig? courseConfig = await CustomCourses().loadCourseConfig(Config().essentialSkillsCoachKey!);
      if (courseConfig != null) {
        setStateIfMounted(() {
          _courseConfig = courseConfig;
          _loading = false;
        });
      } else {
        _setLoading(false);
      }
    }
  }

  void _setLoading(bool value) {
    setStateIfMounted(() {
      _loading = value;
    });
  }
}