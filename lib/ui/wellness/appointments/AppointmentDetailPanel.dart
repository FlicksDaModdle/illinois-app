/*
 * Copyright 2022 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:geolocator/geolocator.dart' as Core;
import 'package:illinois/ext/Explore.dart';
import 'package:illinois/ext/Appointment.dart';
import 'package:illinois/model/wellness/Appointment.dart';
import 'package:illinois/service/Appointments.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/ui/widgets/LinkButton.dart';
import 'package:illinois/utils/AppUtils.dart';
import 'package:rokwire_plugin/model/auth2.dart';
import 'package:illinois/service/Auth2.dart';
import 'package:rokwire_plugin/service/location_services.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/ui/widgets/rounded_button.dart';
import 'package:rokwire_plugin/utils/utils.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/TabBar.dart' as uiuc;
import 'package:url_launcher/url_launcher.dart';

class AppointmentDetailPanel extends StatefulWidget {
  final Appointment? appointment;
  final String? appointmentId;
  final Core.Position? initialLocationData;

  AppointmentDetailPanel({this.appointment, this.appointmentId, this.initialLocationData});

  @override
  _AppointmentDetailPanelState createState() => _AppointmentDetailPanelState();
}

class _AppointmentDetailPanelState extends State<AppointmentDetailPanel> implements NotificationsListener {
  static final double _horizontalPadding = 24;

  Appointment? _appointment;
  Core.Position? _locationData;
  bool _loading = false;
  bool _isCanceling = false;

  @override
  void initState() {
    NotificationService().subscribe(this, [
      LocationServices.notifyStatusChanged,
      Auth2UserPrefs.notifyPrivacyLevelChanged,
      Auth2UserPrefs.notifyFavoritesChanged,
      FlexUI.notifyChanged,
    ]);

    if (widget.appointment != null) {
      _appointment = widget.appointment;
    } else {
      _loadAppointment();
    }

    _locationData = widget.initialLocationData;
    _loadCurrentLocation().then((_) {
      setStateIfMounted(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  void _loadAppointment() {
    _setLoading(true);
    Appointments().loadAppointment(widget.appointmentId).then((app) {
      _appointment = app;
      _setLoading(false);
    });
  }

  Future<void> _loadCurrentLocation() async {
    _locationData = FlexUI().isLocationServicesAvailable ? await LocationServices().location : null;
  }

  void _updateCurrentLocation() {
    _loadCurrentLocation().then((_) {
      setStateIfMounted(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildContent(), backgroundColor: Styles().colors!.background, bottomNavigationBar: uiuc.TabBar());
  }

  Widget _buildContent() {
    if (_loading) {
      return _buildLoadingContent();
    } else if (_appointment != null) {
      return _buildAppointmentContent();
    } else {
      return _buildErrorContent();
    }
  }

  Widget _buildLoadingContent() {
    return Column(children: <Widget>[
      HeaderBar(),
      Expanded(child:
        Center(child:
          CircularProgressIndicator(strokeWidth: 2, color: Styles().colors!.fillColorSecondary)
        )
      )
    ]);
  }

  Widget _buildErrorContent() {
    return Column(children: <Widget>[
      HeaderBar(),
      Expanded(child:
        Center(child:
          Padding(padding: EdgeInsets.symmetric(horizontal: 32), child:
            Text(Localization().getStringEx("panel.appointment.detail.error.msg", 'Failed to load appointment data.'), style:
              Styles().textStyles?.getTextStyle('widget.message.large.fat')
            )
          )
        )
      )
    ]);
  }

  Widget _buildAppointmentContent() {
    String? toutImageKey = _appointment?.imageKeyBasedOnCategory;

    return Column(children: <Widget>[
      Expanded(child: Container(child:
        CustomScrollView(scrollDirection: Axis.vertical, slivers: <Widget>[
        SliverToutHeaderBar(flexImageKey: toutImageKey, flexRightToLeftTriangleColor: Colors.white),
        SliverList(delegate: SliverChildListDelegate([
          Padding(padding: EdgeInsets.symmetric(horizontal: 0), child:
            Column(mainAxisAlignment: MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Container(padding: EdgeInsets.symmetric(horizontal: _horizontalPadding), color: Colors.white, child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  _buildTitle(),
                  _buildDetails(),
                  _buildCommands(),
                ])
              ),
              Container(padding: EdgeInsets.symmetric(horizontal: _horizontalPadding), child:
                Column(children: [
                  _buildInstructionsDescription(),
                  _buildCancelDescription()
                ])
              )
            ])
          )
        ], addSemanticIndexes: false))
      ])))
    ]);
  }

  Widget _buildTitle() {
    bool isFavorite = Auth2().isFavorite(_appointment);
    bool starVisible = Auth2().canFavorite && _appointment!.isUpcoming;
    String semanticsTitle = isFavorite
      ? Localization().getStringEx('widget.card.button.favorite.off.title', 'Remove From Favorites')
      : Localization().getStringEx('widget.card.button.favorite.on.title', 'Add To Favorites');
    String semanticsHint = isFavorite
      ? Localization().getStringEx('widget.card.button.favorite.off.hint', '')
      : Localization().getStringEx('widget.card.button.favorite.on.hint', '');

    return Padding(padding: EdgeInsets.only(bottom: 8), child:
      Row(children: <Widget>[
        Expanded(child:
          Text(_appointment!.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style:
            Styles().textStyles?.getTextStyle("widget.title.medium_large")
          )
        ),
        Visibility(visible: starVisible, child:
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: _onFavorite, child:
            Container(padding: EdgeInsets.only(left: 8, top: 16, bottom: 12), child:
              Semantics(label: semanticsTitle, hint: semanticsHint, button: true, child:
                Styles().images?.getImage(isFavorite ? 'star-filled' : 'star-outline-gray', excludeFromSemantics: true)
              )
            )
          )
        )
      ])
    );
  }

  Widget _buildDetails() {
    List<Widget> details = [];

    Widget? timeCancelled = _buildTimeAndCancelledRowDetail();
    if (timeCancelled != null) {
      details.add(timeCancelled);
    }

    Widget? location = _buildLocationDetail();
    if (location != null) {
      details.add(location);
    }

    Widget? online = _buildOnlineOnlineDetails();
    if (online != null) {
      details.add(online);
    }

    Widget? host = _buildHostDetail();
    if (host != null) {
      details.add(host);
    }

    Widget? instructions = _buildInstructionsDetail();
    if (instructions != null) {
      details.add(instructions);
    }

    Widget? phone = _buildPhoneDetail();
    if (phone != null) {
      details.add(phone);
    }

    Widget? url = _buildUrlDetail();
    if (url != null) {
      details.add(url);
    }

    return (0 < details.length) ? Padding( padding: EdgeInsets.symmetric(vertical: 10), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: details)
    ) : Container();
  }

  Widget _buildCommands() {
    List<Widget> commands = <Widget>[];
    
    if (_canReschedule) {
      if (commands.isNotEmpty) {
        commands.add(Container(width: 12,));
      }
      commands.add(Expanded(child:
        RoundedButton(
          label: Localization().getStringEx('panel.appointment.detail.reschedule.button.title', 'Reschedule'),
          onTap: _onReschedule,
        ),
      ));
    }

    if (_canCancel) {
      if (commands.isNotEmpty) {
        commands.add(Container(width: 12,));
      }
      commands.add(Expanded(child:
        RoundedButton(
          label: Localization().getStringEx('panel.appointment.detail.cancel.button.title', 'Cancel'),
          progress: _isCanceling,
          onTap: _onCancel,
        ),
      ));
    }

    return (0 < commands.length) ? Padding(padding: EdgeInsets.only(top: 12, bottom: 24), child:
      Row(children: commands,)
    ) : Container();

    /*return Padding(padding: EdgeInsets.only(top: 12, bottom: 24), child:
      Row(children: [
        Expanded(child:
          Opacity(opacity: _canReschedule ? 1 : 0, child:
            RoundedButton(
              label: Localization().getStringEx('panel.appointment.detail.reschedule.button.title', 'Reschedule'),
              onTap: _onReschedule,
            ),
          )
        ),
        Container(width: 12,),
        Expanded(child:
          Opacity(opacity: _canCancel ? 1 : 0, child:
            RoundedButton(
              label: Localization().getStringEx('panel.appointment.detail.cancel.button.title', 'Cancel'),
              progress: _isCanceling,
              onTap: _onCancel,
            ),
          ),
        ),
      ],),
    );*/
  }

  Widget? _buildTimeAndCancelledRowDetail() {
    Widget? time = _buildTimeDetail();
    Widget? cancelled = _buildCancelDetail();
    if ((time != null) && (cancelled != null)) {
      return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [Flexible(child: time, fit: FlexFit.loose), cancelled]);
    } else if (time != null) {
      return time;
    } else if (cancelled != null) {
      return Row(mainAxisSize: MainAxisSize.max, mainAxisAlignment: MainAxisAlignment.end, children: [cancelled]);
    } else {
      return null;
    }
  }

  Widget? _buildTimeDetail() {
    String? displayTime = _appointment!.displayDate;
    return StringUtils.isNotEmpty(displayTime) ? Semantics(label: displayTime, excludeSemantics: true, child:
      Padding(padding: EdgeInsets.only(bottom: 8), child:
        Row(children: <Widget>[
          Padding(padding: EdgeInsets.only(right: 7), child:
            Styles().images?.getImage('calendar', excludeFromSemantics: true)
          ),
          Expanded(child:
            Text(displayTime!, style: Styles().textStyles?.getTextStyle("widget.item.regular"))
          )
        ])
      )
    ) : null;
  }

  Widget? _buildCancelDetail() {
    return (_appointment!.cancelled == true) ? Padding(padding: EdgeInsets.only(left: 7), child:
      Text(Localization().getStringEx('panel.appointment.detail.cancelled.label', 'Cancelled'),style:
        Styles().textStyles?.getTextStyle("panel.appointment_detail.title.large")
      )
    ) : null;
  }

  Widget? _buildLocationDetail() {
    AppointmentType? type = _appointment!.type;
    if (type != AppointmentType.in_person) {
      return null;
    }
    String typeLabel = appointmentTypeToDisplayString(type)!;
    String? longDisplayLocation = _appointment?.getLongDisplayLocation(_locationData) ?? "";
    String? locationTitle = _appointment?.locationTitle;
    String? locationTextValue;
    if (StringUtils.isNotEmpty(longDisplayLocation)) {
      locationTextValue = longDisplayLocation;
    } else if (StringUtils.isNotEmpty(locationTitle)) {
      if (locationTextValue != null) {
        locationTextValue += ', $locationTitle';
      } else {
        locationTextValue = locationTitle;
      }
    }
    bool isLocationTextVisible = StringUtils.isNotEmpty(locationTextValue);
    return InkWell(
        onTap: _onLocationDetailTapped,
        child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Padding(padding: EdgeInsets.only(right: 6), child: Styles().images?.getImage('location', excludeFromSemantics: true)),
                    Text(typeLabel,
                        style: Styles().textStyles?.getTextStyle("widget.button.light.title.medium.underline"))
                  ]),
                  Container(height: 4),
                  Visibility(
                      visible: isLocationTextVisible,
                      child: Container(
                          padding: EdgeInsets.only(left: 26),
                          child: Container(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Text(StringUtils.ensureNotEmpty(locationTextValue),
                                  style: Styles().textStyles?.getTextStyle("widget.button.light.title.medium.underline")))))
                ])));
  }

  Widget? _buildOnlineOnlineDetails() {
    AppointmentType? type = _appointment!.type;
    if (type != AppointmentType.online) {
      return null;
    }

    String typeLabel = appointmentTypeToDisplayString(type)!;
    String? meetingUrl = _appointment!.onlineDetails?.url;
    String? meetingId = _appointment!.onlineDetails?.meetingId;
    String? meetingPasscode = _appointment!.onlineDetails?.meetingPasscode;
    return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Padding(padding: EdgeInsets.only(right: 6), child: Styles().images?.getImage('laptop', excludeFromSemantics: true)),
                Container(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(typeLabel,
                        style: Styles().textStyles?.getTextStyle("widget.item.regular")))
              ]),
              Visibility(
                  visible: StringUtils.isNotEmpty(meetingUrl),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 4),
                    Container(
                        padding: EdgeInsets.only(left: 26),
                        child: Container(
                            padding: EdgeInsets.only(bottom: 2),
                            child: LinkButton(
                              padding: EdgeInsets.zero,
                              title: meetingUrl,
                              hint: '',
                              fontSize: 16,
                              onTap: () => _launchUrl(meetingUrl),
                            )))
                  ])),
              Visibility(
                  visible: StringUtils.isNotEmpty(meetingId),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 4),
                    Container(
                        padding: EdgeInsets.only(left: 26),
                        child: Container(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                                Localization().getStringEx('panel.appointment.detail.meeting.id.label', 'Meeting ID:') + ' $meetingId',
                                style: Styles().textStyles?.getTextStyle("widget.item.regular"))))
                  ])),
              Visibility(
                  visible: StringUtils.isNotEmpty(meetingPasscode),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 4),
                    Container(
                        padding: EdgeInsets.only(left: 26),
                        child: Container(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                                Localization().getStringEx('panel.appointment.detail.meeting.passcode.label', 'Passcode:') +
                                    ' $meetingPasscode',
                                style: Styles().textStyles?.getTextStyle("widget.item.regular"))))
                  ]))
            ]));
  }

  Widget? _buildHostDetail() {
    String? displayHostName = _appointment!.displayHostName;
    if (StringUtils.isEmpty(displayHostName)) {
      return null;
    }
    return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(children: <Widget>[
          Padding(padding: EdgeInsets.only(right: 12), child: Styles().images?.getImage('person', excludeFromSemantics: true)),
          Expanded(
              child: Text(displayHostName!,
                  style: Styles().textStyles?.getTextStyle("widget.item.regular")))
        ]));
  }

  Widget? _buildInstructionsDetail() {
    if (StringUtils.isEmpty(_appointment!.instructions)) {
      return null;
    }
    return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(children: <Widget>[
          Padding(padding: EdgeInsets.only(right: 10), child: Styles().images?.getImage('info', excludeFromSemantics: true)),
          Expanded(
              child: Text(Localization().getStringEx('panel.appointment.detail.instructions.label', 'Required prep'),
                  style: Styles().textStyles?.getTextStyle("widget.item.regular")))
        ]));
  }

  Widget? _buildPhoneDetail() {
    String? phone = _appointment!.location?.phone;
    if (StringUtils.isEmpty(phone)) {
      return null;
    }
    return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(children: <Widget>[
          Padding(padding: EdgeInsets.only(right: 11), child: Styles().images?.getImage('phone', excludeFromSemantics: true)),
          Expanded(
              child: Text(phone!,
                  style: Styles().textStyles?.getTextStyle("widget.item.regular")))
        ]));
  }

  Widget? _buildUrlDetail() {
    String? url = Config().saferMcKinleyUrl;
    if (StringUtils.isEmpty(url)) {
      return null;
    }
    return InkWell(
        onTap: () => _launchUrl(url),
        child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(children: <Widget>[
              Padding(padding: EdgeInsets.only(right: 10), child: Styles().images?.getImage('external-link', excludeFromSemantics: true)),
              Expanded(
                  child: Text(url!,
                      style:Styles().textStyles?.getTextStyle("widget.item.regular")))
            ])));
  }

  Widget _buildInstructionsDescription() {
    String? instructions = _appointment!.instructions;
    if (StringUtils.isEmpty(instructions)) {
      return Container();
    }
    String instructionsHtml =
        '<b>${Localization().getStringEx('panel.appointment.detail.instructions.label', 'Required prep')}: </b> $instructions';
    return Padding(
        padding: EdgeInsets.only(top: 10),
        child:
        HtmlWidget(
            StringUtils.ensureNotEmpty(instructionsHtml),
            onTapUrl : (url) {_launchUrl(url); return true;},
            textStyle:  Styles().textStyles?.getTextStyle("widget.info.regular"),
            customStylesBuilder: (element) => (element.localName == "a") ? {"color": ColorUtils.toHex(Styles().colors!.textSurface ?? Colors.blue)} : null
        )
    );
  }

  Widget _buildCancelDescription() {
    final String urlLabelMacro = '{{mckinley_url_label}}';
    final String urlMacro = '{{mckinley_url}}';
    final String externalLinkIconMacro = '{{external_link_icon}}';
    final String phoneMacro = '{{mckinley_phone}}';
    String descriptionHtml = Localization().getStringEx("panel.appointment.detail.cancel.description",
        "<b>To cancel an appointment,</b> go to  <a href='{{mckinley_url}}'>{{mckinley_url_label}}</a>&nbsp;<img src='asset:{{external_link_icon}}' alt=''/> or call <a href='tel:{{mckinley_phone}}'>(<u>{{mckinley_phone}}</u>)</a> during business hours. To avoid a missed appointment charge, you must cancel your appointment at least two hours prior to your scheduled appointment time.");
    descriptionHtml = descriptionHtml.replaceAll(urlMacro, Config().saferMcKinleyUrl ?? '');
    descriptionHtml = descriptionHtml.replaceAll(urlLabelMacro, Config().saferMcKinleyUrlLabel ?? '');
    descriptionHtml = descriptionHtml.replaceAll(externalLinkIconMacro, 'images/external-link.png');
    descriptionHtml = descriptionHtml.replaceAll(phoneMacro, Config().saferMcKinleyPhone ?? '');
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: HtmlWidget(
            StringUtils.ensureNotEmpty(descriptionHtml),
            onTapUrl : (url) {_launchUrl(url); return true;},
            textStyle:  Styles().textStyles?.getTextStyle("widget.info.regular"),
            customStylesBuilder: (element) => (element.localName == "a") ? {"color": ColorUtils.toHex(Styles().colors!.textSurface ?? Colors.blue)} : null
        )
    );
  }

  void _onFavorite() {
    Analytics().logSelect(target: "Favorite: ${_appointment!.title}");
    Auth2().prefs?.toggleFavorite(_appointment);
  }

  bool get _canReschedule => true;

  void _onReschedule() {
    AppAlert.showDialogResult(context, 'Comming soon...');
  }

  bool get _canCancel => _appointment?.cancelled != true;

  void _onCancel() {
    _promptCancel().then((bool? result) {
      if (result == true) {
        setStateIfMounted(() {
          _isCanceling = true;
        });
        Appointments().updateAppointment(Appointment.fromOther(_appointment,
          cancelled: true
        )).then((Appointment? appointment) {
          setStateIfMounted(() {
            _appointment = appointment;
          });
        }).catchError((e) {
          AppAlert.showDialogResult(context, Localization().getStringEx('panel.appointment.detail.cancel.failed.message', 'Failed to cancel appointment:') + '\n' + e.toString());
        }).whenComplete(() {
          setStateIfMounted(() {
            _isCanceling = false;
          });
        });
      }
    });
  }

  Future<bool?> _promptCancel() async {
    String message = Localization().getStringEx('panel.appointment.detail.cancel.prompt.message', 'Cancel this appointment?');
    return await showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(child: Text(Localization().getStringEx("dialog.yes.title", "Yes")),
            onPressed:(){
              Analytics().logAlert(text: message, selection: "Yes");
              Navigator.pop(context, true);
            }),
          TextButton(child: Text(Localization().getStringEx("dialog.no.title", "No")),
            onPressed:(){
              Analytics().logAlert(text: message, selection: "No");
              Navigator.pop(context, false);
            }),
        ]
      );
    });
  }

  void _onLocationDetailTapped() {
    Analytics().logSelect(target: "Location Directions");
    _appointment?.launchDirections();
  }

  void _launchUrl(String? url) async {
    if (StringUtils.isNotEmpty(url)) {
      if (StringUtils.isNotEmpty(url)) {
        Uri? uri = Uri.tryParse(url!);
        if ((uri != null) && (await canLaunchUrl(uri))) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  void _setLoading(bool loading) {
    setStateIfMounted(() {
      _loading = loading;
    });
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == LocationServices.notifyStatusChanged) {
      _updateCurrentLocation();
    } else if (name == Auth2UserPrefs.notifyPrivacyLevelChanged) {
      setStateIfMounted(() {});
      _updateCurrentLocation();
    } else if (name == Auth2UserPrefs.notifyFavoritesChanged) {
      setStateIfMounted(() {});
    } else if (name == FlexUI.notifyChanged) {
      setStateIfMounted(() {});
      _updateCurrentLocation();
    }
  }
}
