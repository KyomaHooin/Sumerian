;
; Calculate Mean / Standard Deviation from ArtaxExport CSV output
;

#AutoIt3Wrapper_Icon=artax.ico
#NoTrayIcon

;INCLUDE
#include <GUIConstantsEx.au3>
#include <File.au3>

;VAR

$runtime = @YEAR & @MON & @MDAY & 'T' & @HOUR & @MIN & @SEC
$mapping = @ScriptDir & '\spectra.txt'
$header = 'sep=;' & @CRLF & "ID;Num(Excl);Na;Na;Mg;Mg;Al;Al;Si;Si;P;P;K;K;Ca;Ca;Ti;Ti;Mn;Mn;Fe;Fe" & @CRLF & _
	  ';;(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd);(avg);(sd)'

;CONTROL
;already running
If UBound(ProcessList(@ScriptName)) > 2 Then Exit

;GUI
$gui = GUICreate("ArtaxCalc v 1.8", 351, 91)
$gui_path = GUICtrlCreateInput("", 6, 8, 255, 21)
$button_path = GUICtrlCreateButton("Procházet", 270, 8, 75, 21)
$gui_progress = GUICtrlCreateProgress(6, 38, 338, 16)
$gui_error = GUICtrlCreateLabel("", 8, 66, 172, 15)
$button_enum = GUICtrlCreateButton("Start", 188, 63, 75, 21)
$button_exit = GUICtrlCreateButton("Konec", 270, 63, 75, 21)

;GUI INIT
GUICtrlSetState($button_path, $GUI_FOCUS)
GUISetState(@SW_SHOW)

While 1
	$event = GUIGetMsg() ; catch event
	If $event = $button_path Then ; data path
		$export_path = FileSelectFolder("Artax/CSV Directory", @HomeDrive, Default)
		If Not @error Then
			GUICtrlSetData($gui_path, $export_path)
		EndIf
	EndIf
	If $event = $button_enum Then
		local $map
		_FileReadToArray($mapping,$map,0,';')
		If @error Then
			GUICtrlSetData($gui_error, "E: Načtení seznamu selhalo.")
		ElseIf GUICtrlRead($gui_path) == '' Then
			GUICtrlSetData($gui_error, "E: Prázdná cesta.")
		ElseIf Not FileExists(GUICtrlRead($gui_path)) Then
			GUICtrlSetData($gui_error, "E: Adresář neexistuje.")
		Else
			$filelist = _FileListToArrayRec(GUICtrlRead($gui_path), '*.csv', 1, 1, 1, 2) ; recursion, files only, sorted, fullpath..
			If UBound($filelist) < 2 Then
				GUICtrlSetData($gui_error, "E: Adresář neobsahuje data.")
			Else
				;crete id/spectra map
				for $i = 0 to UBound($map) - 1
					$map[$i][0] = StringRegExpReplace($map[$i][0],".*_(.*)","$1")
					$map[$i][1] = StringRegExpReplace($map[$i][1],"(.*)_.*","$1")
				next
				local $idmap[0][2],$line[1][2]
				;create spectra/file map
				for $i = 1 To UBound($filelist) - 1
					;get SID
					if StringRegExp($filelist[$i],".*\\tabl_\d+@.*$") = 1 then; match measuring number
						$line[0][0] = sid_by_id(StringRegExpReplace($filelist[$i],".*\\tabl_(\d+)@.*$","$1"),$map)
						$line[0][1] = $filelist[$i]
					endif
					_ArrayAdd($idmap,$line)
				next
				_ArraySort($idmap)
				;create output file
				$out = FileOpen(@ScriptDir & '\artax_calc_' & $runtime & ".csv", 258); UTF-8 no BOM overwrite
				if @error then; write header
					GUICtrlSetData($gui_error, "E: Nelze zapsat CSV soubor.")
				else;proccess CSV data
					local $raw,$data,$batch[0][10],$data[1][10]
					FileWriteLine($out, $header); CSV header
					for $i = 0 To UBound($idmap) - 1;
						_FileReadToArray($idmap[$i][1],$raw,2,';')
						if UBound($raw) = 12 then; check CSV compat
							for $j = 2 to ubound($raw) - 1; skip CSV header
								$data[0][$j-2] = StringRegExpReplace(($raw[$j])[9],',','.'); "Conc."
							next
							_ArrayAdd($batch,$data);populate batch 
						endif
						GUICtrlSetData($gui_progress, Round($i / (UBound($idmap) - 1) * 100)) ; update progress
						GUICtrlSetData($gui_error, StringRegExpReplace($idmap[$i][1], ".*\\(.*)$", "$1"))
						if ($i < ubound($idmap)-1 and $idmap[$i][0] <> $idmap[$i+1][0]) or $i = ubound($idmap)-1 then
							calc($out,$batch,$idmap[$i][0])
							local $batch[0][10]
						endif
					next
				endif
				FileClose($out)
				GUICtrlSetData($gui_progress, 0) ; clear progress
				GUICtrlSetData($gui_error, "Hotovo!")
			endif
		Endif
	EndIf
	If $event = $GUI_EVENT_CLOSE Or $event = $button_exit Then
		Exit; exit
	EndIf
WEnd

func sid_by_id($id,$map)
	$index = _ArraySearch($map,$id)
	if not @error then return $map[$index][1]
EndFunc

func calc($out,$data,$id)
	local $line[22]
	$line[0] = $id
	$line[1] = ubound($data) & '(' & ubound($data) - 2 & ')'; Num(Excl)
	;mean
	for $j = 1 to 10
		local $excl[0]; reinit exc.
		for $k = 0 to ubound($data) - 1
			_ArrayAdd($excl,number($data[$k][$j-1]))
		next
		_ArraySort($excl)
		_ArrayDelete($excl,0)
		_ArrayDelete($excl,UBound($excl) - 1)
		for $m = 0 to UBound($excl) - 1
			$line[$j*2]+=$excl[$m]
		next
		$line[$j*2] = $line[$j*2]/ubound($data); odd
	next
	;deviation
	for $j = 1 to 10
		local $excl[0]; reinit excl.
		for $k = 0 to ubound($data) - 1
			_ArrayAdd($excl,number($data[$k][$j-1]))
		next
		_ArraySort($excl)
		_ArrayDelete($excl,0)
		_ArrayDelete($excl,UBound($excl) - 1)
		for $m = 0 to UBound($excl) -1
			$line[$j*2+1]+=($excl[$m]-$line[$j*2])^2
		next
		$line[$j*2+1] = sqrt($line[$j*2+1]/ubound($data)); even
	next
	;round/format output
	for $j = 1 to 10
		$line[$j*2] = StringRegExpReplace(StringFormat("%.02f",round($line[$j*2],2)),"\.",",")
		$line[$j*2+1] = StringRegExpReplace(StringFormat("%.03f",round($line[$j*2+1],3)),"\.",",")
	next
	;write
	FileWriteLine($out,_ArrayToString($line,";"))
EndFunc

