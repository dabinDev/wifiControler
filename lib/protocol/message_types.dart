class MessageTypes {
  MessageTypes._();

  // Connection & Auth
  static const String regReq = 'REG_REQ';
  static const String regAck = 'REG_ACK';
  static const String heartbeat = 'HEARTBEAT';
  static const String disconnect = 'DISCONNECT';

  // Telemetry
  static const String statusSync = 'STATUS_SYNC';

  // Live Streaming
  static const String cmdRtcStart = 'CMD_RTC_START';
  static const String rtcOffer = 'RTC_OFFER';
  static const String rtcAnswer = 'RTC_ANSWER';
  static const String rtcIceCandidate = 'RTC_ICE_CANDIDATE';
  static const String cmdRtcStop = 'CMD_RTC_STOP';

  // Capture Control
  static const String cmdRecordStart = 'CMD_RECORD_START';
  static const String cmdRecordStop = 'CMD_RECORD_STOP';
  static const String cmdAudioStart = 'CMD_AUDIO_START';
  static const String cmdAudioStop = 'CMD_AUDIO_STOP';
  static const String eventRecordStarted = 'EVENT_RECORD_STARTED';
  static const String cmdTakePhoto = 'CMD_TAKE_PHOTO';
  static const String eventPhotoTaken = 'EVENT_PHOTO_TAKEN';

  // File & Cloud
  static const String cmdFileUpload = 'CMD_FILE_UPLOAD';
  static const String eventUploadProgress = 'EVENT_UPLOAD_PROGRESS';
  static const String eventUploadSuccess = 'EVENT_UPLOAD_SUCCESS';
  static const String eventUploadFailed = 'EVENT_UPLOAD_FAILED';
  static const String cmdUploadCancel = 'CMD_UPLOAD_CANCEL';

  // Hardware Remote
  static const String cmdCamSwitch = 'CMD_CAM_SWITCH';
  static const String cmdZoomSet = 'CMD_ZOOM_SET';
  static const String cmdTorchSet = 'CMD_TORCH_SET';
  static const String cmdFocusSet = 'CMD_FOCUS_SET';

  // Alerts & Failures
  static const String notifyPhoneCallIncoming = 'NOTIFY_PHONE_CALL_INCOMING';
  static const String notifyPhoneCallEnded = 'NOTIFY_PHONE_CALL_ENDED';
  static const String notifyLowBattery = 'NOTIFY_LOW_BATTERY';
  static const String notifyStorageFull = 'NOTIFY_STORAGE_FULL';
  static const String notifyOverheat = 'NOTIFY_OVERHEAT';
  static const String eventError = 'EVENT_ERROR';

  // Maintenance
  static const String cmdCleanFiles = 'CMD_CLEAN_FILES';
  static const String cmdAppRestart = 'CMD_APP_RESTART';
  static const String cmdLogQuery = 'CMD_LOG_QUERY';

  // Web only
  static const String webClientJoin = 'WEB_CLIENT_JOIN';
  static const String webClientLeave = 'WEB_CLIENT_LEAVE';

  // Existing local flow
  static const String discover = 'DISCOVER';
  static const String hello = 'HELLO';
  static const String ack = 'ACK';
  static const String status = 'STATUS';
  static const String cmd = 'CMD';

  static const List<String> controllerQuickCommands = <String>[
    cmdRecordStart,
    cmdRecordStop,
    cmdTakePhoto,
    cmdFileUpload,
    cmdUploadCancel,
    cmdRtcStart,
    cmdRtcStop,
    cmdCamSwitch,
    cmdZoomSet,
    cmdTorchSet,
    cmdFocusSet,
    cmdCleanFiles,
    cmdAppRestart,
    cmdLogQuery,
  ];

  static const List<String> controlledAutoMessages = <String>[
    regReq,
    heartbeat,
    statusSync,
    eventRecordStarted,
    eventPhotoTaken,
    eventUploadProgress,
    eventUploadSuccess,
    eventUploadFailed,
    notifyPhoneCallIncoming,
    notifyPhoneCallEnded,
    notifyLowBattery,
    notifyStorageFull,
    notifyOverheat,
    eventError,
  ];
}
