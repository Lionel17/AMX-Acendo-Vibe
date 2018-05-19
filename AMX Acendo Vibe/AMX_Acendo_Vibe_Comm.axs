MODULE_NAME='AMX_Acendo_Vibe_Comm' (dev vdvDevice, dev dvDevice)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/04/2006  AT: 11:33:16        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)

include 'SNAPI'

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

char CRLF[] = 			{$0D,$0A}
char CR[] =			{$0D}
char Space[] =			{$20}
char Esc[] = 			{$1B}

char Set[] =			'Set'
char Get[] =			'Get'

integer Max_PollTime =		65 // request status max every 60 sec

integer TL_ID_HeartBeat =	1
integer TL_ID_CountDown =	2
integer TL_ID_Volume =		3

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile integer nDebug = 	0
volatile integer nReinit = 	0

volatile long CountDown =	35 // Default value

volatile long PollTime =		30000 // default value
volatile char BaudRate[] =	'115200' // Default value

volatile long TL_Array_HeartBeat[1] = {30000} // default
volatile long TL_Array_CountDown[Max_PollTime] = {1000}
volatile long TL_Array_Volume[] = 	{250}

volatile char VibeBuffer[500]

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function fnDebug (char cMess[])
{
    if(nDebug == true)
    {
	send_string 0, "'Acendo Vibe [',itoa(dvDevice.number),':',itoa(dvDevice.port),':',itoa(dvDevice.system),'] ::: ',cMess"
    }
}

define_function fnCommunicationSetup ()
{
    local_var char cCmd[DUET_MAX_CMD_LEN]
    local_var char cHeader[DUET_MAX_HDR_LEN]
    local_var char cParameter[DUET_MAX_PARAM_LEN]
    
    local_var integer Vol
    cCmd = data.text
    cHeader = DuetParseCmdHeader(cCmd)
    cParameter = DuetParseCmdParam(cCmd)
    switch(cHeader)
    {
	case 'PROPERTY':
	{
	    switch(cParameter)
	    {
		case 'Poll_Time': PollTime = atoi(cCmd)
		case 'Baud_Rate': BaudRate = (cCmd)
	    }
	}
	case 'PASSTHRU': fnSendString (cParameter)
	case 'VOL_LVL': 
	{
	    Vol = atoi(cParameter)
	    Vol = Vol*100/255
	    fnSendString("Set,Space,'/audio/volume',Space,itoa(Vol)")
	}
	case 'RING_LED_COLOR': fnSendString("Set,Space,'ringleds/color',Space,cParameter,':',DuetParseCmdParam(cCmd),':',cCmd")
	case 'INPUT':fnSendString("Set,Space,'/audio/source',Space,lower_string(cParameter)")
	case 'REINIT': nReinit = true
    }
    if(nReinit == true && dvDevice.number != false)
    {
	if(PollTime > 60000)
	{
	    PollTime = 60000
	    TL_Array_HeartBeat[1] = PollTime
	    CountDown = PollTime/1000+5
	}
	else if(PollTime < 10000)
	{
	    PollTime = 10000
	    TL_Array_HeartBeat[1] = PollTime
	    CountDown = PollTime/1000+5
	}
	else
	{
	    TL_Array_HeartBeat[1] = PollTime
	    CountDown = PollTime/1000+5
	}
	send_command dvDevice, "'SET BAUD ',BaudRate,',N,8,1'"
	fnSendString("Get,Space,'/system/model'")
	wait 2
	fnSendString("Get,Space,'/system/version'")
	wait 4
	fnSendString("Get,Space,'/system/name'")
	wait 6
	fnSendString("Get,Space,'/camera/state'")
	wait 8
	fnSendString("Get,Space,'/usbup/status'")
	wait 10
	fnSendString("Get,Space,'/audio/volume'")
	wait 12
	fnSendString("Get,Space,'/audio/state'")
	wait 14
	fnSendString("Get,Space,'/video/status'")
	wait 16
	fnSendString("Get,Space,'/audio/source'")
	if(timeline_active(TL_ID_HeartBeat))
	timeline_kill(TL_ID_HeartBeat)
	timeline_create(TL_ID_HeartBeat,TL_Array_HeartBeat,1,timeline_absolute,timeline_repeat)
	nReinit = false
    }
}

define_function fnCreateCountDown ()
{
    local_var integer i
    for(i=1;i<=CountDown;i++)
    {
	TL_Array_CountDown[i] = i*1000
    }
    timeline_create(TL_ID_CountDown,TL_Array_CountDown,CountDown,timeline_absolute,timeline_once)
}

define_function fnSendString (char cCmd[50])
{
    send_string dvDevice,"cCmd,CRLF"
    //fnDebug("cCmd,CRLF")
}

define_function fnFeedbackFromDevice ()
{
    local_var char cData[DUET_MAX_CMD_LEN]
    local_var char Header[DUET_MAX_HDR_LEN]
    local_var char Parameter[DUET_MAX_PARAM_LEN]
    local_var char Value[DUET_MAX_PARAM_LEN]
    local_var char RGB[3][4]
    
    //VibeBuffer = "VibeBuffer,Data.text"
    
    while(find_string(VibeBuffer,CRLF,1))
    {
	fnDebug ("'Sent to AMX ::: ',VibeBuffer")
	if(timeline_active(TL_ID_CountDown))
	timeline_kill(TL_ID_CountDown)
	on[vdvDevice,DEVICE_COMMUNICATING]
	on[vdvDevice,POWER_FB]
	cData = remove_string(VibeBuffer,CRLF,1)
	set_length_string(cData,length_string(cData)-2)
	if(find_string(cData,Space,1))
	{
	    Header = remove_string(cData,Space,1)
	    set_length_string(Header,length_string(Header)-1)
	    if(find_string(cData,Space,1))
	    {
		Parameter = remove_string(cData,Space,1)
		set_length_string(Parameter,length_string(Parameter)-1)
		Value = cData
	    }
	    else
	    {
		Parameter = cData
	    }
	    switch(lower_string(Header))
	    {
		case 'event':
		{
		    switch(lower_string(Parameter))
		    {
			case 'spkr_mute': on[vdvDevice,VOL_MUTE_FB]
			case 'spkr_unmute': off[vdvDevice,VOL_MUTE_FB]
			case 'vol_change': send_level vdvDevice, VOL_LVL,(atoi(Value))*255/100
			case 'src_change_audio': 
			{
			    switch(lower_string(Value))
			    {
				case 'usb': send_string vdvDevice,'INPUT-USB'
				case 'optical': send_string vdvDevice,'INPUT-OPTICAL'
				case 'bt': send_string vdvDevice,'INPUT-BLUETOOTH'
				case 'hdmi': send_string vdvDevice,'INPUT-HDMI'
				case 'aux': send_string vdvDevice,'INPUT-AUX'
			    }
			}
			case 'mic_mute':on[vdvDevice,ACONF_PRIVACY_FB]
			case 'mic_unmute':off[vdvDevice,ACONF_PRIVACY_FB]
			case 'usb_dis': send_string vdvDevice,'USB_INPUT-DISCONNECTED'
			case 'usb_conn': send_string vdvDevice,'USB_INPUT-CONNECTED'
			case 'bt_dis': send_string vdvDevice,'BLUETOOTH_INPUT-DISCONNECTED'
			case 'bt_conn': send_string vdvDevice,'BLUETOOTH_INPUT-CONNECTED'
			case 'bt_remote_conn': send_string vdvDevice,'BLUETOOTH_REMOTE-CONNECTED'
			case 'bt_remote_dis': send_string vdvDevice,'BLUETOOTH_REMOTE-DISCONNECTED'
			case 'bt_inactive': send_string vdvDevice,'BLUETOOTH-INACTIVE'
			case 'bt_oor': send_string vdvDevice,'BLUETOOTH-OUT_OF_RANGE'
			case 'vacancy_det': send_string vdvdevice,'OCCUPANCY-NO'
		    }
		}
		case '@set':
		{
		    switch(lower_string(Parameter))
		    {
			case '/audio/volume': 
			{
			    if(Value <> '-' && Value <> '+')
			    {
				send_level vdvDevice, VOL_LVL,(atoi(Value))*255/100
			    }
			}
			case '/video/status': send_string vdvDevice,"'HDMI_INPUT-',upper_string(Value)"
			case '/audio/source':
			{
			    switch(lower_string (Value))
			    {
				case 'usb': send_string vdvDevice,'INPUT-USB'
				case 'optical': send_string vdvDevice,'INPUT-OPTICAL'
				case 'bluetooth': send_string vdvDevice,'INPUT-BLUETOOTH'
				case 'hdmi': send_string vdvDevice,'INPUT-HDMI'
				case 'aux': send_string vdvDevice,'INPUT-AUX'
			    }
			}
			case '/audio/state':
			{
			    switch(lower_string(Value))
			    {
				case 'normal': Off[vdvDevice,VOL_MUTE_FB]
				case 'muted': On[vdvDevice,VOL_MUTE_FB]
			    }
			}
			case '/audmic/state':
			{
			    switch(lower_string(Value))
			    {
				case 'normal': Off[vdvDevice,ACONF_PRIVACY_ON]
				case 'muted': On[vdvDevice,ACONF_PRIVACY_ON]
			    }
			}
			case 'ringleds/color': 
			{
			    RGB[1] = remove_string(Value,':',1)
			    set_length_string(RGB[1],length_string(RGB[1])-1)
			    RGB[2] = remove_string(Value,':',1)
			    set_length_string(RGB[2],length_string(RGB[2])-1)
			    RGB[3] = Value
			    send_string vdvDevice,"'RING_LED_COLOR-',RGB[1],',',RGB[2],',',RGB[3]"
			}
		    }
		}
		case '@get':
		{
		    switch(lower_string(Parameter))
		    {
			case '/audio/volume': send_level vdvDevice, VOL_LVL,(atoi(Value))*255/100
			case '/video/status': send_string vdvDevice,"'HDMI_INPUT-',upper_string(Value)"
			case '/audio/state':
			{
			    switch(lower_string(Value))
			    {
				case 'normal': off[vdvDevice,VOL_MUTE_FB]
				case 'muted': on[vdvDevice,VOL_MUTE_FB]
			    }
			}
			case '/system/model': send_string vdvDevice,"'MODEL-',upper_string(Value)"
			case '/system/version': 
			{
			    send_string vdvDevice,"'FWVERSION-',upper_string(Value)"
			    on[vdvDevice,DATA_INITIALIZED]
			}
			case '/system/name': send_string vdvDevice,"'NAME-',upper_string(Value)"
			case '/usbup/status': send_string vdvDevice,"'USB_INPUT-',upper_string(Value)"
			case '/audio/source':
			{
			    switch(lower_string (Value))
			    {
				case 'usb': send_string vdvDevice,'INPUT-USB'
				case 'optical': send_string vdvDevice,'INPUT-OPTICAL'
				case 'bluetooth': send_string vdvDevice,'INPUT-BLUETOOTH'
				case 'hdmi': send_string vdvDevice,'INPUT-HDMI'
				case 'aux': send_string vdvDevice,'INPUT-AUX'
			    }
			}
			case '/camera/state': send_string vdvDevice,"'CAMERA_STATE-',upper_string(Value)"
			case '/occupancy/internal/state': send_string vdvDevice,"'INTERNAL_OCCUPANCY_SENSOR-',upper_string(Value)"
			case '/occupancy/external/state': send_string vdvDevice,"'EXTERNAL_OCCUPANCY_SENSOR-',upper_string(Value)"
			case '/audmic/state':
			{
			    switch(lower_string(Value))
			    {
				case 'normal': off[vdvDevice,ACONF_PRIVACY_ON]
				case 'muted': on[vdvDevice,ACONF_PRIVACY_ON]
			    }
			}
		    }
		}
	    }
	}
	fnCreateCountDown()
	//clear_buffer VibeBuffer
    }
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

create_buffer dvDevice,VibeBuffer

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[vdvDevice]
{
    command: fnCommunicationSetup ()
}

data_event[dvDevice]
{
    online: 
    {
	send_command dvDevice, "'SET BAUD 115200,N,8,1'"
	fnSendString("Get,Space,'/system/model'")
	wait 2
	fnSendString("Get,Space,'/system/version'")
	wait 4
	fnSendString("Get,Space,'/system/name'")
	wait 6
	fnSendString("Get,Space,'/camera/state'")
	wait 8
	fnSendString("Get,Space,'/usbup/status'")
	wait 10
	fnSendString("Get,Space,'/audio/volume'")
	wait 12
	fnSendString("Get,Space,'/audio/state'")
	wait 14
	fnSendString("Get,Space,'/video/status'")
	wait 16
	fnSendString("Get,Space,'/audio/source'")
	if(!timeline_active(TL_ID_HeartBeat))
	timeline_create(TL_ID_HeartBeat,TL_Array_HeartBeat,1,timeline_absolute,timeline_repeat)
    }
    string: fnFeedbackFromDevice ()
}

channel_event[vdvDevice,0]
{
    on:
    {
	switch(channel.channel)
	{
	    case VOL_UP: 
	    {
		fnSendString("Set,Space,'/audio/volume +'")
		if(!timeline_active(TL_ID_Volume))
		timeline_create(TL_ID_Volume,TL_Array_Volume,1,timeline_absolute,timeline_repeat)
	    }
	    case VOL_DN: 
	    {
		fnSendString("Set,Space,'/audio/volume -'")
		if(!timeline_active(TL_ID_Volume))
		timeline_create(TL_ID_Volume,TL_Array_Volume,1,timeline_absolute,timeline_repeat)
	    }
	    case VOL_MUTE:
	    {
		if([vdvDevice,VOL_MUTE_FB])
		{
		    fnSendString("Set,Space,'/audio/state',Space,'normal'")
		}
		else
		{
		    fnSendString("Set,Space,'/audio/state',Space,'muted'")
		}
	    }
	    case VOL_MUTE_FB: fnSendString("Set,Space,'/audio/state',Space,'muted'")
	    case ACONF_PRIVACY: 
	    {
		if([vdvDevice,ACONF_PRIVACY_ON])
		{
		    fnSendString("Set,Space,'/audmic/state',Space,'normal'")
		}
		else
		{
		    fnSendString("Set,Space,'/audmic/state',Space,'muted'")
		}
	    }
	}
    }
    off:
    {
	switch(channel.channel)
	{
	    case VOL_UP: 
	    {
		if(timeline_active(TL_ID_Volume) && ![vdvDevice,VOL_DN])
		timeline_kill(TL_ID_Volume)
	    }
	    case VOL_DN: 
	    {
		if(timeline_active(TL_ID_Volume) && ![vdvDevice,VOL_UP])
		timeline_kill(TL_ID_Volume)
	    }
	}
    }
}

timeline_event[TL_ID_HeartBeat]
{
    fnSendString("Get,Space,'/camera/state'")
    wait 2
    fnSendString("Get,Space,'/usbup/status'")
    wait 4
    fnSendString("Get,Space,'/video/status'")
    wait 6
    fnSendString("get,Space,'/occupancy/internal/state'")
    wait 8
    fnSendString("get,Space,'/occupancy/external/state'")
}

timeline_event[TL_ID_CountDown]
{
    fnDebug ("'CountDown: ',itoa((CountDown)-Timeline.sequence)")
    if(timeline.sequence == CountDown)
    {
	off[vdvDevice,POWER_FB]
	off[vdvDevice,DEVICE_COMMUNICATING]
	off[vdvDevice,DATA_INITIALIZED]
	off[vdvDevice,VOL_MUTE_FB]
	off[vdvDevice,ACONF_PRIVACY_FB]
    }
}

timeline_event[TL_ID_Volume]
{
    if([vdvDevice,VOL_UP])
    {
	fnSendString("Set,Space,'/audio/volume +'")
    }
    else if([vdvDevice,VOL_DN])
    {
	fnSendString("Set,Space,'/audio/volume -'")
    }
}

(*****************************************************************)
(*                                                               *)
(*                      !!!! WARNING !!!!                        *)
(*                                                               *)
(* Due to differences in the underlying architecture of the      *)
(* X-Series masters, changing variables in the DEFINE_PROGRAM    *)
(* section of code can negatively impact program performance.    *)
(*                                                               *)
(* See “Differences in DEFINE_PROGRAM Program Execution” section *)
(* of the NX-Series Controllers WebConsole & Programming Guide   *)
(* for additional and alternate coding methodologies.            *)
(*****************************************************************)

DEFINE_PROGRAM

(*****************************************************************)
(*                       END OF PROGRAM                          *)
(*                                                               *)
(*         !!!  DO NOT PUT ANY CODE BELOW THIS COMMENT  !!!      *)
(*                                                               *)
(*****************************************************************)
