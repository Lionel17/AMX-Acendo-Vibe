MODULE_NAME='AMX_Acendo_Vibe_UI' (dev vdvDevice,dev dvDevice[])
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

integer TL_ID_UI_Feedback =	1

integer lvlCmdRGB[3] =		{11,12,13}
integer btnCmdInputs[] = 	{501,502,503,504,505} // Bluetooth, HDMI, Optical, Aux & USB
integer btnFdbStates[3] =	{601,602,603} // HDMI, USB, Cam


char InputLabel[5][10] =
{
    'BLUETOOTH',
    'HDMI',
    'OPTICAL',
    'AUX',
    'USB'
}
(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

struct _Acendo
{
    integer Comm
    char Model[15]
    char Name[30]
    char Firmware[50]
    integer Volume
    integer AudioMute
    integer MicMute
    integer USBConnected
    integer HDMIInputConnected
    integer CamState
    char Input[15]
    integer RGB[3]
    char InternalOccupancySensor[10]
    char ExternalOccupancySensor[10]
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

integer Volume // Levl value on the panel
integer RGB[3]

long TL_Array_UI_Feedback[] =	{200}

_Acendo Acendo

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

(***********************************************************)
// Fonction pour afficher du texte dans le panel
// Param = dvDevice (Panel sur lequel on affiche le texte)
// Param = nAddress (le numÃ©ro du champs texte)
// Param = nState l'Ã©tat du bouton dans le lequel afficher le texte, 0 all, 1 On, 2 Off
// Param = cText (Le texte Ã  afficher dans le champs)
(***********************************************************)
define_function fnSendTextToAllPanel (dev dvDevice[], integer nAddress, char cText[])
{
    send_command dvDevice, "'^TXT-',itoa(nAddress),',0,',cText"
}

define_function fnOnlinePanel ()
{
    send_level dvDevice,VOL_LVL,Acendo.Volume
    fnSendTextToAllPanel(dvDevice,1,Acendo.Model)
    fnSendTextToAllPanel(dvDevice,2,Acendo.Name)
    send_level dvDevice,lvlCmdRGB[1],Acendo.RGB[1]
    send_level dvDevice,lvlCmdRGB[2],Acendo.RGB[2]
    send_level dvDevice,lvlCmdRGB[3],Acendo.RGB[3]
}


define_function fnFeedbackAcendo ()
{
    stack_var char cCmd[DUET_MAX_CMD_LEN]
    stack_var char Header[DUET_MAX_HDR_LEN]
    stack_var char Parameter[DUET_MAX_PARAM_LEN]

    cCmd = data.text
    Header = DuetParseCmdHeader(cCmd)
    Parameter = DuetParseCmdParam(cCmd)
    
    switch(upper_string(Header))
    {
	case 'INPUT': Acendo.Input = Parameter
	case 'HDMI_INPUT':
	{
	    switch(upper_string(Parameter))
	    {
		case 'NONE': Acendo.HDMIInputConnected = false
		case 'CONNECTED': Acendo.HDMIInputConnected = true
	    }
	}
	case 'USB_INPUT':
	{
	    switch(upper_string(Parameter))
	    {
		case 'DISCONNECTED': Acendo.USBConnected = false
		case 'CONNECTED': Acendo.USBConnected = true
	    }
	}
	case 'CAMERA_STATE':
	{
	    switch(upper_string(Parameter))
	    {
		case 'IDLE': Acendo.CamState = false
		case 'STREAMING': Acendo.CamState = true
	    }
	}
	case 'MODEL': 
	{
	    Acendo.Model = Parameter
	    fnSendTextToAllPanel(dvDevice,1,Acendo.Model)
	}
	case 'NAME': 
	{
	    Acendo.Name = Parameter
	    fnSendTextToAllPanel(dvDevice,2,Acendo.Name)
	}
	case 'FWVERSION': Acendo.Firmware = Parameter
	case 'RING_LED_COLOR':
	{
	    Acendo.RGB[1] = atoi(Parameter)
	    Acendo.RGB[2] = atoi(DuetParseCmdParam(cCmd))
	    Acendo.RGB[3] = atoi(DuetParseCmdParam(cCmd))
	    send_level dvDevice,lvlCmdRGB[1],Acendo.RGB[1]
	    send_level dvDevice,lvlCmdRGB[2],Acendo.RGB[2]
	    send_level dvDevice,lvlCmdRGB[3],Acendo.RGB[3]
	}
	case 'INTERNAL_OCCUPANCY_SENSOR': Acendo.InternalOccupancySensor = Parameter
	case 'EXTERNAL_OCCUPANCY_SENSOR': Acendo.ExternalOccupancySensor = Parameter
    }
}
(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START

//DEFINE_CONNECT_LEVEL(vdvDevice,1,dvDevice[1],2)

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvDevice]
{
    online: fnOnlinePanel ()
}

data_event[vdvDevice]
{
    online: timeline_create(TL_ID_UI_Feedback,TL_Array_UI_Feedback,1,timeline_absolute,timeline_repeat)
    string: fnFeedbackAcendo ()
}

channel_event[vdvDevice,0]
{
    on:
    {
	switch(channel.channel)
	{
	    case DEVICE_COMMUNICATING: Acendo.Comm = true
	    case VOL_MUTE_FB: Acendo.AudioMute = true
	    case ACONF_PRIVACY_FB: Acendo.MicMute = true
	}
    }
    off:
    {
	switch(channel.channel)
	{
	    case DEVICE_COMMUNICATING: Acendo.Comm = false
	    case VOL_MUTE_FB: Acendo.AudioMute = false
	    case ACONF_PRIVACY_FB: Acendo.MicMute = false
	}
    }
}

level_event[vdvDevice,VOL_LVL]
{
    Acendo.Volume = level.value
    send_level dvDevice,VOL_LVL,Acendo.Volume
}

button_event[dvDevice,0]
{
    push:
    {
	to[button.input]
	switch(button.input.channel)
	{
	    case VOL_UP: to[vdvDevice,VOL_UP]
	    case VOL_DN: to[vdvDevice,VOL_DN]
	    case VOL_MUTE: pulse[vdvDevice,VOL_MUTE]
	    case VOL_MUTE_ON: pulse[vdvDevice,VOL_MUTE_ON]
	    case ACONF_PRIVACY: pulse[vdvDevice,ACONF_PRIVACY]
	}
    }
}

button_event[dvDevice,btnCmdInputs]
{
    push:
    {
	to[button.input]
	send_command vdvDevice,"'INPUT-',InputLabel[get_last(btnCmdInputs)]"
    }
}

level_event[dvDevice,lvlCmdRGB]
{
    local_var integer nLev
    nLev = get_last(lvlCmdRGB)
    RGB[nLev] = level.value
}

level_event[dvDevice,VOL_LVL]
{
    Volume = level.value
}

button_event[dvDevice,lvlCmdRGB]
{
    push:send_command vdvDevice,"'RING_LED_COLOR-',itoa(RGB[1]),',',itoa(RGB[2]),',',itoa(RGB[3])"
    hold[2,repeat]:send_command vdvDevice,"'RING_LED_COLOR-',itoa(RGB[1]),',',itoa(RGB[2]),',',itoa(RGB[3])"
    release: send_command vdvDevice,"'RING_LED_COLOR-',itoa(RGB[1]),',',itoa(RGB[2]),',',itoa(RGB[3])"
}

button_event[dvDevice,301] // Volume
{
    push:send_command vdvDevice,"'VOL_LVL-',itoa(Volume)"
    hold[2.5,repeat]:send_command vdvDevice,"'VOL_LVL-',itoa(Volume)"
    release: send_command vdvDevice,"'VOL_LVL-',itoa(Volume)"
}

timeline_event[TL_ID_UI_Feedback]
{
    [dvDevice,VOL_MUTE] = Acendo.AudioMute == true && Acendo.Comm == true
    [dvDevice,ACONF_PRIVACY] = Acendo.MicMute == true && Acendo.Comm == true
    [dvDevice,btnCmdInputs[1]] = Acendo.Input == 'BLUETOOTH' && Acendo.Comm == true
    [dvDevice,btnCmdInputs[2]] = Acendo.Input == 'HDMI' && Acendo.Comm == true
    [dvDevice,btnCmdInputs[3]] = Acendo.Input == 'OPTICAL' && Acendo.Comm == true
    [dvDevice,btnCmdInputs[4]] = Acendo.Input == 'AUX' && Acendo.Comm == true
    [dvDevice,btnCmdInputs[5]] = Acendo.Input == 'USB' && Acendo.Comm == true
    [dvDevice,btnFdbStates[1]] = Acendo.HDMIInputConnected == true && Acendo.Comm == true
    [dvDevice,btnFdbStates[2]] = Acendo.USBConnected == true && Acendo.Comm == true
    [dvDevice,btnFdbStates[3]] = Acendo.CamState == true && Acendo.Comm == true
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