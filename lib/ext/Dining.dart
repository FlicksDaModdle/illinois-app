import 'dart:ui';

import 'package:illinois/model/Dining.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:rokwire_plugin/service/styles.dart';

extension DiningExt on Dining {
  
  Map<String, dynamic>? get analyticsAttributes => {
        Analytics.LogAttributeDiningId:   exploreId,
        Analytics.LogAttributeDiningName: exploreTitle,
        Analytics.LogAttributeLocation : location?.analyticsValue,
  };

  Color? get uiColor => Styles().colors?.diningColor;

}