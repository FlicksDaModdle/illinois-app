
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/CheckList.dart';
import 'package:illinois/ui/gies/CheckListPanel.dart';
import 'package:illinois/ui/home/HomePanel.dart';
import 'package:illinois/ui/home/HomeWidgets.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:illinois/service/Storage.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/ui/widgets/rounded_button.dart';
import 'package:rokwire_plugin/service/notification_service.dart';
import 'package:rokwire_plugin/utils/utils.dart';

class HomeCheckListWidget extends StatefulWidget{

  final String contentKey;
  final String? favoriteId;
  final StreamController<void>? refreshController;
  final HomeDragAndDropHost? dragAndDropHost;

  const HomeCheckListWidget({Key? key, required this.contentKey, this.favoriteId, this.refreshController, this.dragAndDropHost}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _HomeCheckListWidgetState();

}

class _HomeCheckListWidgetState extends State<HomeCheckListWidget> implements NotificationsListener{
  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [CheckList.notifyPageChanged, CheckList.notifyPageCompleted, CheckList.notifyContentChanged]);
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(visible: true, child:
    
      HomeDropTargetWidget(favoriteId: widget.favoriteId, dragAndDropHost: widget.dragAndDropHost, child:
        HomeSlantWidget(favoriteId: widget.favoriteId, dragAndDropHost: widget.dragAndDropHost,
          title: _title,
          child: _buildContent(),
          headerAxisAlignment: CrossAxisAlignment.start,
        ),
      ),

    );
  }

  Widget _buildContent() {
    if(CheckList(widget.contentKey).isLoading){
      return _buildLoadingContent();
    }
    if (!_isStarted) {
      return _buildStartContent();
    }

    if (_isEnded) {
      return _buildEndedContent();
    }

    return _buildProgressContent();
  }

  Widget _buildLoadingContent(){
    return 
        Container(
          constraints: BoxConstraints(maxHeight: 100),
          padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Styles().colors!.white,
                borderRadius: BorderRadius.circular(5)),
            child: Column(children: <Widget>[
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color?>(Styles().colors!.fillColorSecondary), ),
                ),
              ),
            ]),
    );
  }

  Widget _buildStartContent() {
    return 
        Container(padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Styles().colors!.white,
                borderRadius: BorderRadius.circular(5)),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child:
                  Semantics(
                    container: true,
                    child:Text(Localization().getStringEx(
                        'widget.gies.message.start', 'Ready to get started?'),
                      style: TextStyle(color: Styles().colors!.fillColorPrimary,
                        fontFamily: Styles().fontFamilies!.extraBold,
                        fontSize: 32,),),)),
                  ],),
                Container(height: 24,),
                RoundedButton(
                  label: Localization().getStringEx('widget.gies.button.title.begin', "Begin Checklist"),
                  backgroundColor: Styles().colors?.white!,
                  borderColor: Styles().colors?.fillColorSecondary!,
                  textColor: Styles().colors!.fillColorPrimary,
                  onTap: _onTapContinue,
                ),
                Container(height: 16,),
              ],
            ));
  }

  Widget _buildEndedContent() {
    return 
        Container(padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Styles().colors!.white,
                borderRadius: BorderRadius.circular(5)),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child:
                    Semantics(
                      container: true,
                      child:
                      Text(Localization().getStringEx(
                          'widget.gies.message.finished', 'You’ve completed the checklist.'),
                        style: TextStyle(color: Styles().colors!.fillColorPrimary,
                          fontFamily: Styles().fontFamilies!.extraBold,
                          fontSize: 32,),),)),
                ],),
                Container(height: 24,),
                RoundedButton(
                  label: Localization().getStringEx('widget.gies.button.title.review', "Review Checklist"),
                  backgroundColor: Styles().colors?.white!,
                  borderColor: Styles().colors?.fillColorSecondary!,
                  textColor: Styles().colors!.fillColorPrimary,
                  onTap: _onTapContinue,
                ),
                !CheckList(widget.contentKey).supportNotes ? Container() :
                Column(children: [
                  Container(height: 12,),
                  RoundedButton(
                    label: Localization().getStringEx('widget.gies.button.title.view_notes', "View My Notes"),
                    backgroundColor: Styles().colors?.white!,
                    borderColor: Styles().colors?.fillColorSecondary!,
                    textColor: Styles().colors!.fillColorPrimary,
                    onTap: _onTapViewNotes,
                  ),
                ],),
                Container(height: 16,),
              ],
            )
    );
  }

  Widget _buildProgressContent() {
    return 
        Container(padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Styles().colors!.white,
                borderRadius: BorderRadius.circular(5)),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child:
                    Semantics(
                      container: true,
                      child: Text(_progressText,
                        style: TextStyle(color: Styles().colors!.fillColorPrimary,
                          fontFamily: Styles().fontFamilies!.extraBold,
                          fontSize: 24,),),)),
                    ],),
                Container(height: 24,),
                RoundedButton(
                  label: Localization().getStringEx('widget.gies.button.title.continue', "Continue"),
                  backgroundColor: Styles().colors?.white!,
                  borderColor: Styles().colors?.fillColorSecondary!,
                  textColor: Styles().colors!.fillColorPrimary,
                  onTap: _onTapContinue,
                ),
                Container(height: 16,),
              ],
            )
    );
  }

  void _onTapContinue(){
    Navigator.push(context, CupertinoPageRoute(builder: (context) => CheckListPanel(contentKey: widget.contentKey,)));
  }

  void _onTapViewNotes(){
    showDialog(context: context, builder: (BuildContext context) {
        return CheckListNotesWidget(contentKey: widget.contentKey ,notes: JsonUtils.decodeList(Storage().getChecklistNotes(widget.contentKey)) ?? []);
    });
  }

  String get _progressText {
    List<String> completed = [];
    List<String> notCompleted = [];
    String completedNames = "";
    String notCompletedNames = "";
    for(int stepId in CheckList(widget.contentKey).progressSteps??[]){
      if(CheckList(widget.contentKey).isProgressStepCompleted(stepId)){
        completed.add(stepId.toString());
        completedNames+= StringUtils.isNotEmpty(completedNames)? ", " : "";
        completedNames+= stepId.toString();
      } else {
        notCompleted.add(stepId.toString());
      }
    }
    String completedText = "Step${completed.length>1 ? "s" : ""} $completedNames completed${notCompleted.length>0?"," : ""}";

    for(String stepName in notCompleted){
      notCompletedNames+= StringUtils.isNotEmpty(notCompletedNames)?
        "${notCompleted.last == stepName ? " and" : ","} " :
        "";
      notCompletedNames+= stepName.toString();
    }
    String notCompletedText = notCompletedNames.length>0? "$notCompletedNames ${notCompleted.length>1 ? "are" : "is"} incomplete." :"";
    return "$completedText $notCompletedText";
  }

  bool get _isStarted {
    return _completedStpsCount > 0;
  }

  bool get _isEnded {
    return _completedStpsCount >= _stepsCount;
  }

  int get _completedStpsCount {
    return CheckList(widget.contentKey).completedStepsCount;
  }

  int get _stepsCount {
    return CheckList(widget.contentKey).progressSteps?.length ?? 0;
  }

  String get _title {
    if(widget.contentKey == "gies"){
      return Localization().getStringEx( 'widget.checklist.gies.title', 'iDegrees New Student Checklist');// TBD localize
    } else if (widget.contentKey == "uiuc_student"){
      return Localization().getStringEx( 'widget.checklist.uiuc.title', 'New Student Checklist'); // TBD localize
    }

    return "";
  }

  @override
  void onNotification(String name, param) {
    if(name == CheckList.notifyPageChanged ||
        name == CheckList.notifyPageCompleted ||
        name ==CheckList.notifyContentChanged){
      setState(() {});
    }
  }

}