; ======================================
; == FM Radio                         ==
; ==                                  ==
; == Minimalistic GUI for fmtools     ==
; == Author: Sergey Avdeev            ==
; == E-Mail: thesoultaker48@gmail.com ==
; == URL: http://tst48.wordpress.com  ==
; ==                                  ==
; == Think correctly. Debian.         ==
; ======================================


; For icons
UsePNGImageDecoder()

; Check the fmtools package and turn on fm radio
If Not RunProgram("fm", "on", "", #PB_Program_Hide)
  MessageRequester("Error", "Package "+Chr(34)+"fmtools"+Chr(34)+" is not installed.")
  End
EndIf

; Stations storage
Structure station
  name.s
  frequency.f
EndStructure
Global NewList Stations.station()

; Create application deirectory
If (FileSize(GetHomeDirectory()+".fmradio") <> -2)
  CreateDirectory(GetHomeDirectory()+".fmradio")
EndIf

; Load stations from file
If ReadFile(0, GetHomeDirectory()+".fmradio/stations.list")
  While (Eof(0) = 0)
    station$ = Trim(ReadString(0))
    If (Len(station$) > 0)
      AddElement(Stations())
      Stations()\frequency = ValF(StringField(station$, 1, ";"))
      Stations()\name = StringField(station$, 2, ";")
    EndIf
  Wend
  CloseFile(0)
EndIf

; Default values
Global CurrentStation.i = 0
Global CurrentFrequency.f = 97.75
Global CurrentVolume.i = 100
Global CurrentDevice.s = "/dev/radio0"
Global AutoScanRunning.l = #False
Global FoundStations.i = 0
Global FoundSkipped.i = 0

; Custom events
Enumeration #PB_Event_FirstCustomValue
  #Event_AutoScan
  #Event_AutoScan_Started
  #Event_AutoScan_Stopped
  #Event_AutoScan_Progress
EndEnumeration

; Load settings from file
If OpenPreferences(GetHomeDirectory()+".fmradio/fmradio.conf", #PB_Preference_GroupSeparator)
  PreferenceGroup("main")
  CurrentStation = ReadPreferenceInteger("station", CurrentStation)
  CurrentFrequency = ReadPreferenceFloat("frequency", CurrentFrequency)
  CurrentVolume = ReadPreferenceInteger("volume", CurrentVolume)
  CurrentDevice = ReadPreferenceString("device", CurrentDevice)
  ClosePreferences()
ElseIf CreatePreferences(GetHomeDirectory()+".fmradio/fmradio.conf", #PB_Preference_GroupSeparator)
  PreferenceGroup("main")
  WritePreferenceInteger("station", CurrentStation)
  WritePreferenceFloat("frequency", CurrentFrequency)
  WritePreferenceInteger("volume", CurrentVolume)
  WritePreferenceString("device", CurrentDevice)
  ClosePreferences()
EndIf

; Interface
OpenWindow(0, #PB_Ignore, #PB_Ignore, 455, 150, "FM Radio", #PB_Window_ScreenCentered|#PB_Window_MinimizeGadget)
gtk_window_set_icon_(WindowID(0), ImageID(CatchImage(#PB_Any, ?MainIcon)))
ContainerGadget(0, 5, 5, 150, 50, #PB_Container_Flat)
TextGadget(1, 0, 8, 145, 30, "", #PB_Text_Center)
CloseGadgetList()
LoadFont(1, "Arial", 19, #PB_Font_Bold)
SetGadgetFont(1, FontID(1))
TextGadget(2, 160, 10, 290, 25, "Stations:", #PB_Text_Center)
ComboBoxGadget(3, 160, 29, 200, 25) : GadgetToolTip(3, "Current station")
ButtonImageGadget(13, 365, 29, 25, 25, ImageID(CatchImage(#PB_Any, ?DeleteStaionIcon))) : GadgetToolTip(13, "Delete station")
ButtonImageGadget(14, 395, 29, 25, 25, ImageID(CatchImage(#PB_Any, ?EditStaionIcon))) : GadgetToolTip(14, "Edit station")
ButtonImageGadget(15, 425, 29, 25, 25, ImageID(CatchImage(#PB_Any, ?AddStaionIcon))) : GadgetToolTip(15, "Add station")
TrackBarGadget(4, 5, 65, 445, 30, 0, 410, #PB_TrackBar_Ticks) : GadgetToolTip(4, "Change frequency")
ImageGadget(16, 5, 85, 445, 10, ImageID(CatchImage(#PB_Any, ?TrackBarTics))) ; 440x10
ButtonImageGadget(5, 10, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?PreviousIcon))) : GadgetToolTip(5, "Previous station")
ButtonImageGadget(6, 65, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?BackwardIcon))) : GadgetToolTip(6, "0.05 MHz backward")
ButtonImageGadget(7, 120, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?ForwardIcon))) : GadgetToolTip(7, "0.05 MHz forward")
ButtonImageGadget(8, 175, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?NextIcon))) : GadgetToolTip(8, "Next station")
ButtonImageGadget(9, 230, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?VolumeFullIcon)), #PB_Button_Toggle) : GadgetToolTip(9, "Volume level")
ButtonImageGadget(10, 285, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?AutoSearchIcon))) : GadgetToolTip(10, "Automatic scanning")
ButtonImageGadget(11, 340, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?SettingsIcon))) : GadgetToolTip(11, "Settings")
ButtonImageGadget(12, 395, 105, 50, 35, ImageID(CatchImage(#PB_Any, ?AboutIcon))) : GadgetToolTip(12, "About FM Radio")

SetActiveGadget(4)

; Update station list
Procedure updateStationsList()
  ClearGadgetItems(3)
  AddGadgetItem(3, -1, "Manual")
  ResetList(Stations())
  While NextElement(Stations())
    AddGadgetItem(3, -1, Stations()\name+" ("+StrF(Stations()\frequency, 2)+" MHz)")
  Wend
  SetGadgetState(3, 0)
EndProcedure

; Get current frequency
Procedure.f getFrequency()
  ProcedureReturn CurrentFrequency
EndProcedure

; Set frequency
Procedure.b setFrequency(freq.f)
  If (freq>=87.5) And (freq<=108)
    ; Display
    SetGadgetText(1, StrF(freq, 2)+" MHz")
    If AutoScanRunning
      SetWindowTitle(0, "FM Radio - "+StrF(freq, 2)+" MHz (scanning)")
    Else
      SetWindowTitle(0, "FM Radio - "+StrF(freq, 2)+" MHz")
    EndIf
    ; Control
    SetGadgetState(4, (freq-87.5)*(GetGadgetAttribute(4, #PB_TrackBar_Maximum)/(108-87.5)))
    GadgetToolTip(4, "Change frequency ("+StrF(freq, 2)+" MHz)")
    ; Radio
    If Not AutoScanRunning
      RunProgram("fm", StrF(freq, 2), "", #PB_Program_Hide)
    EndIf
    ; Global
    CurrentFrequency = freq
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; Get the current station
Procedure.i getStation()
  ProcedureReturn CurrentStation
EndProcedure

; Set station
Procedure setStation(id.i)
  If (id >= 0) And (id <= ListSize(Stations()))
    result.b = #True
    If (id > 0)
      SelectElement(Stations(), id-1)
      result = setFrequency(Stations()\frequency)
    EndIf
    SetGadgetState(3, id)
    CurrentStation = id
    ProcedureReturn result
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; Previous station
Procedure previousStation()
  If (CountGadgetItems(3) > 1)
    If (getStation() > 1)
      ProcedureReturn setStation(getStation()-1)
    Else
      ProcedureReturn setStation(CountGadgetItems(3)-1)
    EndIf
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; Next station
Procedure.b nextStation()
  If (CountGadgetItems(3) > 1)
    If (getStation() < CountGadgetItems(3)-1)
      ProcedureReturn setStation(getStation()+1)
    Else
      ProcedureReturn setStation(1)
    EndIf
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; Get volume level
Procedure.i getVolume()
  ProcedureReturn CurrentVolume
EndProcedure

; Set the volume level
Procedure.b setVolume(vol.i)
  If (vol>=0) And (vol<=100)
    If (vol=0)
      GadgetToolTip(9, "Volume level (mute)")
      SetGadgetAttribute(9, #PB_Button_Image, ImageID(CatchImage(#PB_Any, ?VolumeMuteIcon)))
    Else
      GadgetToolTip(9, "Volume level ("+Str(vol)+"%)")
      SetGadgetAttribute(9, #PB_Button_Image, ImageID(CatchImage(#PB_Any, ?VolumeFullIcon)))
    EndIf
    fmvol.l = RunProgram("fm", "on "+Str(vol), "", #PB_Program_Hide|#PB_Program_Open|#PB_Program_Read)
    While ProgramRunning(fmvol)
      If AvailableProgramOutput(fmvol)
        output$ = Trim(ReadProgramString(fmvol))
        If (FindString(output$, "not support volume control", 1, #PB_String_NoCase) > 0)
          CurrentVolume = -1
          ProcedureReturn #False
        EndIf
      EndIf
    Wend
    CurrentVolume = vol
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; Get device
Procedure.s getDevice()
  ProcedureReturn CurrentDevice
EndProcedure

; Set the device
Procedure.b setDevice(device.s)
  If (FileSize(device) >= 0)
    fmdev.l = RunProgram("fm", "-d "+device+" on", "", #PB_Program_Hide|#PB_Program_Open|#PB_Program_Error)
    While ProgramRunning(fmdev)
      error$ = Trim(ReadProgramError(fmdev))
      If Len(error$)>0
        ProcedureReturn #False
      EndIf
    Wend
    CurrentDevice = device
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

; Automatic channel scan
Procedure runAutoScan(*null)
  FoundStations = 0
  FoundSkipped = 0
  AutoScanRunning = #True
  PostEvent(#Event_AutoScan, 0, #Null, #Event_AutoScan_Started)
  fmscan.l = RunProgram("fmscan", "", "", #PB_Program_Hide|#PB_Program_Open|#PB_Program_Read)
  AutoScanRunning = fmscan
  While ProgramRunning(fmscan)
    outputBytes.i = AvailableProgramOutput(fmscan)
    If outputBytes
      ; read output to buffer
      *outputBuffer = AllocateMemory(outputBytes)
      ReadProgramData(fmscan, *outputBuffer, outputBytes)
      outputString$ = PeekS(*outputBuffer, outputBytes, #PB_Ascii)
      FreeMemory(*outputBuffer)
      ; prepare string
      outputString$ = Trim(outputString$)
      outputString$ = Trim(outputString$, #LF$)
      outputString$ = Trim(outputString$, #CR$)
      ; progress
      If CreateRegularExpression(0, "^([0-9]{2,3})\.([0-9]{2}):$", #PB_RegularExpression_NoCase|#PB_RegularExpression_AnyNewLine|#PB_RegularExpression_MultiLine)
        If MatchRegularExpression(0, outputString$)
          PostEvent(#Event_AutoScan, 0, #Null, #Event_AutoScan_Progress, @outputString$)
        EndIf
        FreeRegularExpression(0)
      EndIf
      ; found stations
      If CreateRegularExpression(0, "^([0-9]{2,3})\.([0-9]{2}): ([0-9]+)\.([0-9]+)%$", #PB_RegularExpression_NoCase|#PB_RegularExpression_AnyNewLine|#PB_RegularExpression_MultiLine)
        If MatchRegularExpression(0, outputString$)
          SaveStationToList.b = #True
          FoundStations = FoundStations + 1
          frequency.f = ValF(StringField(outputString$, 1, ":"))
          ResetList(Stations())
          While NextElement(Stations())
            If (Stations()\frequency = frequency)
              SaveStationToList = #False
            EndIf
          Wend
          If SaveStationToList
            AddElement(Stations())
            Stations()\frequency = frequency
            Stations()\name = "Station "+Str(FoundStations)
          Else
            FoundSkipped = FoundSkipped + 1
          EndIf
        EndIf
        FreeRegularExpression(0)
      EndIf
    EndIf
  Wend
  PostEvent(#Event_AutoScan, 0, #Null, #Event_AutoScan_Stopped)
EndProcedure

; Stop automatic scanning
Procedure stopAutoScan()
  KillProgram(AutoScanRunning)
  AutoScanRunning = #False
EndProcedure

; Set the Default parameters
setDevice(getDevice())
If Not setVolume(getVolume())
  DisableGadget(9, #True)
  GadgetToolTip(9, "Radio does not support volume control")
EndIf
setFrequency(getFrequency())
updateStationsList()
setStation(getStation())

; The main loop interface
Exit.b = #False
Repeat
  Event = WaitWindowEvent(100)
  Select Event
    Case #PB_Event_Gadget ; Gadgets event
      Select EventGadget()
        Case 3: ; ComboBox
          setStation(GetGadgetState(3))
        Case 4: ; TrackBar
          setStation(0)
          setFrequency(GetGadgetState(4)/(GetGadgetAttribute(4, #PB_TrackBar_Maximum)/(108-87.5))+87.5)
        Case 6: ; 0.05 MHz backward
          setFrequency(getFrequency()-0.05)
        Case 7: ; 0.05 MHz forward
          setFrequency(getFrequency()+0.05)
        Case 5: ; Previous station
          previousStation()
        Case 8: ; Next station
          nextStation()
        Case 9: ; Volume
          If (Not IsWindow(1))
            OpenWindow(1, WindowX(0)+231, WindowY(0)+161, 51, 115, "VOL", #PB_Window_Tool|#PB_Window_BorderLess, WindowID(0))
            ContainerGadget(102, 0, 0, WindowWidth(1), WindowHeight(1), #PB_Container_Flat)
            ContainerGadget(101, 15, 10, 16, 95, #PB_Container_BorderLess) ; hack for hide ticks (bug fixed in PB 5.41)
            TrackBarGadget(100, 0, 0, 16, 90, 0, 100, #PB_TrackBar_Vertical) : SetGadgetState(100, getVolume())
            CloseGadgetList()
            ;TrackBarGadget(100, 5, 5, 40, 90, 0, 100, #PB_TrackBar_Vertical) : SetGadgetState(100, getVolume())
            CloseGadgetList()
          Else
            CloseWindow(1)
            SetGadgetState(9, #False)
          EndIf
        Case 10: ; Automatic scanning
          If Not AutoScanRunning
            CreateThread(@runAutoScan(), #NUL)
          Else
            stopAutoScan()
          EndIf
        Case 11: ; Settings
          DisableWindow(0, #True)
          OpenWindow(4, #PB_Ignore, #PB_Ignore, 200, 80, "Settings", #PB_Window_WindowCentered, WindowID(0))
          TextGadget(400, 5, 15, 50, 25, "Device:") : StringGadget(401, 60, 10, 135, 25, getDevice())
          ButtonGadget(402, 10, 45, 85, 25, "Cancel") : ButtonGadget(403, 105, 45, 85, 25, "Save")
        Case 12: ; About FM Radio
          MessageRequester("About ", "FM Radio v"+#Program_Major_Version+"."+#Program_Minor_Version+" (build "+#PB_Editor_BuildCount+")"+#LF$+#LF$+"Minimalistic GUI for fmtools"+#LF$+#LF$+"Author: Sergey Avdeev"+#LF$+"E-Mail: thesoultaker48@gmail.com"+#LF$+"URL: http://tst48.wordpress.com"+#LF$+#LF$+"Think correctly. Debian.")
        Case 13: ; Delete station
          If (GetGadgetState(3) > 0)
            If (MessageRequester("Question", "Are you sure you want to delete the station "+GetGadgetText(3)+"?", #PB_MessageRequester_YesNo) = #PB_MessageRequester_Yes)
              DeleteElement(Stations())
              updateStationsList()
              setStation(0)
            EndIf
          Else
            MessageRequester("Message", "Please, select a station from the list!")
          EndIf
        Case 14: ; Edit station
          If (GetGadgetState(3) > 0)
            DisableWindow(0, #True)
            OpenWindow(2, #PB_Ignore, #PB_Ignore, 185, 110, "Edit station", #PB_Window_WindowCentered, WindowID(0))
            TextGadget(200, 5, 15, 70, 25, "Name:") : StringGadget(201, 80, 10, 100, 25, Stations()\name)
            TextGadget(202, 5, 45, 70, 25, "Frequency:") : StringGadget(203, 80, 40, 100, 25, StrF(Stations()\frequency, 2))
            ButtonGadget(204, 10, 75, 75, 25, "Cancel") : ButtonGadget(205, 100, 75, 75, 25, "Save")
            SetActiveGadget(205)
          Else
            MessageRequester("Message", "Please, select a station from the list!")
          EndIf
        Case 15: ; Add station
          DisableWindow(0, #True)
          OpenWindow(3, #PB_Ignore, #PB_Ignore, 185, 110, "Add station", #PB_Window_WindowCentered, WindowID(0))
          TextGadget(300, 5, 15, 70, 25, "Name:") : StringGadget(301, 80, 10, 100, 25, "")
          TextGadget(302, 5, 45, 70, 25, "Frequency:") : StringGadget(303, 80, 40, 100, 25, StrF(getFrequency(), 2))
          ButtonGadget(304, 10, 75, 75, 25, "Cancel") : ButtonGadget(305, 100, 75, 75, 25, "Save")
          SetActiveGadget(305)
        Case 100: ; Volume level
          setVolume(GetGadgetState(100))
        Case 204: ; Edit station: Cancel
          CloseWindow(2)
          DisableWindow(0, #False)
        Case 205: ; Edit station: Save
          name$ = Trim(GetGadgetText(201))
          If (Len(name$) > 0)
            frequency.f = ValF(GetGadgetText(203))
            If (frequency >= 87.5) And (frequency <= 108)
              Stations()\name = name$
              Stations()\frequency = frequency
              CloseWindow(2)
              DisableWindow(0, #False)
              updateStationsList()
              setStation(getStation())
            Else
              MessageRequester("Message", "Please, enter a station's frequency (range 87.5 to 108)!")
            EndIf
          Else
            MessageRequester("Message", "Please, enter the name of the station!")
          EndIf
        Case 304: ; Add station: Cancel
          CloseWindow(3)
          DisableWindow(0, #False)
        Case 305: ; Add station: Save
          name$ = Trim(GetGadgetText(301))
          If (Len(name$) > 0)
            frequency.f = ValF(GetGadgetText(303))
            If (frequency >= 87.5) And (frequency <= 108)
              LastElement(Stations())
              AddElement(Stations())
              Stations()\name = name$
              Stations()\frequency = frequency
              CloseWindow(3)
              DisableWindow(0, #False)
              updateStationsList()
              setStation(ListSize(Stations()))
            Else
              MessageRequester("Message", "Please, enter a station's frequency (range 87.5 to 108)!")
            EndIf
          Else
            MessageRequester("Message", "Please, enter the name of the station!")
          EndIf
        Case 402: ; Settings: Cancel
          CloseWindow(4)
          DisableWindow(0, #False)
        Case 403: ; Settings: Save
          device$ = Trim(GetGadgetText(401))
          If Len(device$)>0
            If setDevice(device$)
              CloseWindow(4)
              DisableWindow(0, #False)
            Else
              MessageRequester("Message", "The device is not available! Try again (for example /dev/radio0).")
            EndIf
          Else
            MessageRequester("Message", "Please, enter the address of the device (for example /dev/radio0)!")
          EndIf
      EndSelect
    Case #Event_AutoScan ; AutoScan event
      Select EventType()
        Case #Event_AutoScan_Started
          ; Freeze interface
          DisableGadget(3, #True)
          DisableGadget(4, #True)
          DisableGadget(5, #True)
          DisableGadget(6, #True)
          DisableGadget(7, #True)
          DisableGadget(8, #True)
          If (getVolume() <> -1) : DisableGadget(9, #True) : EndIf
          SetGadgetAttribute(10, #PB_Button_Image, ImageID(CatchImage(#PB_Any, ?StopSearchIcon)))
          DisableGadget(11, #True)
          DisableGadget(12, #True)
          DisableGadget(13, #True)
          DisableGadget(14, #True)
          DisableGadget(15, #True)
          ; Reset Station and Frequency
          setStation(0)
          setFrequency(87.5)
        Case #Event_AutoScan_Stopped
          If (AutoScanRunning <> #False)
            AutoScanRunning = #False
            setFrequency(108)
          Else
            setFrequency(getFrequency())
          EndIf
          MessageRequester("Message", "Scan complete!"+#LF$+#LF$+"Found: "+Str(FoundStations)+#LF$+"Saved: "+Str(FoundStations-FoundSkipped)+#LF$+"Skipped: "+Str(FoundSkipped)+#LF$+#LF$+"Click OK to continue.")
          updateStationsList()
          ; Unfreeze interface
          DisableGadget(3, #False)
          DisableGadget(4, #False)
          DisableGadget(5, #False)
          DisableGadget(6, #False)
          DisableGadget(7, #False)
          DisableGadget(8, #False)
          If (getVolume() <> -1) : DisableGadget(9, #False) : EndIf
          SetGadgetAttribute(10, #PB_Button_Image, ImageID(CatchImage(#PB_Any, ?AutoSearchIcon)))
          DisableGadget(11, #False)
          DisableGadget(12, #False)
          DisableGadget(13, #False)
          DisableGadget(14, #False)
          DisableGadget(15, #False)
        Case #Event_AutoScan_Progress
          setFrequency(ValF(PeekS(EventData())))
      EndSelect
    Case #PB_Event_DeactivateWindow ; Window lost focus
      Select EventWindow()
        Case 1: ; Volume window
          ; Check cursor position
          WindowMouseX.i = WindowMouseX(0)
          WindowMouseY.i = WindowMouseY(0)
          WindowGadgetX.i = GadgetX(9, #PB_Gadget_WindowCoordinate)
          WindowGadgetY.i = GadgetY(9, #PB_Gadget_WindowCoordinate)
          GadgetWidth.i = GadgetWidth(9, #PB_Gadget_ActualSize)
          GadgetHeight.i = GadgetHeight(9, #PB_Gadget_ActualSize)
          ; Cursor outside of the button (fucking crutch)
          If (Not (((WindowMouseX >= WindowGadgetX) And (WindowMouseX <= (WindowGadgetX + GadgetWidth))) And ((WindowMouseY >= WindowGadgetY) And (WindowMouseY <= (WindowGadgetY + GadgetHeight)))))
            CloseWindow(1)
            SetGadgetState(9, #False)
          EndIf
        Case 2: ; Edit station window
          SetActiveWindow(2)
        Case 3: ; Add station window
          SetActiveWindow(3)
        Case 4: ; Settings window
          SetActiveWindow(4)
      EndSelect
    Case #PB_Event_CloseWindow ; Window closed
      Select EventWindow()
        Case 0: ; Main window
          Exit = #True
        Case 2: ; Edit station window
          CloseWindow(2)
          DisableWindow(0, #False)
        Case 3: ; Add station window
          CloseWindow(3)
          DisableWindow(0, #False)
        Case 4: ; Settings window
          CloseWindow(4)
          DisableWindow(0, #False)
      EndSelect
  EndSelect
Until Exit = #True ; When main window closed

; Turn off the radio
RunProgram("fm", "off", "", #PB_Program_Hide)

; Write stations to file
If OpenFile(0, GetHomeDirectory()+".fmradio/stations.list")
  TruncateFile(0)
  ResetList(Stations())
  While NextElement(Stations())
    frequency$ = ReplaceString(StrF(Stations()\frequency, 2), ";", #NULL$)
    name$ = ReplaceString(Stations()\name, ";", #NULL$)
    WriteStringN(0, frequency$+";"+name$)
  Wend
  CloseFile(0)
EndIf

; Save settings to file
If OpenPreferences(GetHomeDirectory()+".fmradio/fmradio.conf", #PB_Preference_GroupSeparator)
  PreferenceGroup("main")
  WritePreferenceInteger("station", getStation())
  WritePreferenceFloat("frequency", getFrequency())
  If (getVolume() < 0)
    WritePreferenceInteger("volume", 100)
  Else
    WritePreferenceInteger("volume", getVolume())
  EndIf
  WritePreferenceString("device", getDevice())
  ClosePreferences()
EndIf

End

; Resources
DataSection
  MainIcon:
  IncludeBinary "resources/fmradio.png"
  DeleteStaionIcon:
  IncludeBinary "resources/delete_station.png"
  EditStaionIcon:
  IncludeBinary "resources/edit_station.png"
  AddStaionIcon:
  IncludeBinary "resources/add_station.png"
  PreviousIcon:
  IncludeBinary "resources/previous.png"
  NextIcon:
  IncludeBinary "resources/next.png"
  BackwardIcon:
  IncludeBinary "resources/backward.png"
  ForwardIcon:
  IncludeBinary "resources/forward.png"
  VolumeFullIcon:
  IncludeBinary "resources/volume_full.png"
  VolumeMuteIcon:
  IncludeBinary "resources/volume_mute.png"
  AutoSearchIcon:
  IncludeBinary "resources/auto_search.png"
  StopSearchIcon:
  IncludeBinary "resources/stop_search.png"
  SettingsIcon:
  IncludeBinary "resources/settings.png"
  AboutIcon:
  IncludeBinary "resources/about.png"
  TrackBarTics:
  IncludeBinary "resources/tics.png"
EndDataSection
; IDE Options = PureBasic 5.31 (Linux - x86)
; CursorPosition = 363
; FirstLine = 360
; Folding = ---
; EnableUnicode
; EnableThread
; EnableXP
; Executable = package/usr/bin/fmradio
; EnableBuildCount = 4
; Constant = #Program_Major_Version = 1
; Constant = #Program_Minor_Version = 0