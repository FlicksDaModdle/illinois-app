import 'package:flutter/material.dart';
import 'package:illinois/ui/settings/SettingsWidgets.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:rokwire_plugin/model/auth2.dart';
import 'package:rokwire_plugin/service/auth2.dart';
import 'package:rokwire_plugin/service/localization.dart';
import 'package:rokwire_plugin/service/styles.dart';
import 'package:rokwire_plugin/utils/utils.dart';

class SettingsLinkedEmailPanel extends StatefulWidget{
  //TBD Localization
  //TBD decide do we want to load it in the panel init phase 
  final Auth2Type? linkedEmail;

  const SettingsLinkedEmailPanel({Key? key, this.linkedEmail}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SettingsLinkedEmailState();
}

class _SettingsLinkedEmailState extends State<SettingsLinkedEmailPanel>{
  bool _isLoading = false; //TBD show progress

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: HeaderBar(title: Localization().getStringEx("panel.settings.linked.email.label.title", "Alternate Email"),),
        body: Column(children: <Widget>[
          Expanded(child:
            SingleChildScrollView(scrollDirection: Axis.vertical, child:
              Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(children:[
                  Row(children: [ Expanded(child:
                    Text(Localization().getStringEx("panel.settings.linked.email.label.description",
                        "You may sign in using your email as an alternate way to sign in. Some features of the Illinois App will not be available unless you login with your NetID."),
                      style: TextStyle(fontFamily: Styles().fontFamilies?.regular, fontSize: 18, color: Styles().colors!.fillColorPrimary),
                    )
                  )],),
                  Container(height: 48),
                  LinkAccountContentWidget(linkedAccount: _linkedEmail, onTapDisconnect: _onTapDisconnect,)
    ]))))])
    );
  }

  void _onTapDisconnect(Auth2Type account){
    setState(() {
      _isLoading = true;
    });

    if(account.email != null)
    Auth2().unlinkAccountAuthType(Auth2LoginType.email, account.email!).then((bool? result) {
      if (mounted) {
        setState(() { _isLoading = false; });
        if (result != null) {
          if (!result) {
            setErrorMsg(Localization().getStringEx("panel.settings.linked.email.label.failed", "Failed to disconnect email"));
            return;
          }

          Navigator.of(context).pop();
        } else {
          setErrorMsg(Localization().getStringEx("panel.settings.linked.email.label.failed", "Failed to disconnect email"));
        }
      }
    });
  }

  void setErrorMsg(String msg){
    AppToast.show(msg);
  }

  //TBD decide do we want to load it in the panel init phase 
  Auth2Type get _linkedEmail{
    return widget.linkedEmail ?? mocData; //TODO remove moc data
  }

  Auth2Type get mocData{
    return Auth2Type(id: "1234", identifier: "test@todo.com", code: "5678");
  }
}