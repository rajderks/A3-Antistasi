//Mission: Logistic supplies
if (!isServer and hasInterface) exitWith{};
private ["_markerX","_difficultX","_leave","_contactX","_groupContact","_tsk","_posHQ","_citiesX","_city","_radiusX","_positionX","_posHouse","_nameDest","_timeLimit","_dateLimit","_dateLimitNum","_pos","_truckX","_countX", "_emptybox"];

_debugMode = 2;

[format ["LOG_Supplies.sqf: Running script with taskTerminateLogBox %1", missionNamespace getVariable ["taskTerminateLogBox", false]], _debugMode] call A3A_fnc_debug;

try {
	_markerX = _this select 0;
	_difficultX = if (random 10 < tierWar) then {true} else {false};
	_leave = false;
	_contactX = objNull;
	_groupContact = grpNull;
	_tsk = "";
	_positionX = getMarkerPos _markerX;

	_timeLimit = if (_difficultX) then {30} else {60};
	if (hasIFA) then {_timeLimit = _timeLimit * 2};
	_dateLimit = [date select 0, date select 1, date select 2, date select 3, (date select 4) + _timeLimit];
	_dateLimitNum = dateToNumber _dateLimit;
	_dateLimit = numberToDate [date select 0, _dateLimitNum];//converts datenumber back to date array so that time formats correctly
	_displayTime = [_dateLimit] call A3A_fnc_dateToTimeString;//Converts the time portion of the date array to a string for clarity in hints

	_nameDest = [_markerX] call A3A_fnc_localizar;
	_taskDescription = format ["%1 population is in need of supplies. We may improve our relationship with that city if we are the ones who provide them. I reserved a transport truck with supplies near our HQ. Drive the transport truck to %1 city center. Hold it there for 2 minutes and it's done. Do this before %2.",_nameDest,_displayTime];

	[[teamPlayer,civilian],"LOG",[_taskDescription,"City Supplies",_markerX],_positionX,false,0,true,"Heal",true] call BIS_fnc_taskCreate;
	missionsX pushBack ["LOG","CREATED"]; publicVariable "missionsX";
	_pos = (getMarkerPos respawnTeamPlayer) findEmptyPosition [1,50,"C_Van_01_box_F"];

	//Creating the box
	_truckX = "Land_PaperBox_01_open_boxes_F" createVehicle _pos;
	_truckX allowDamage false;
	_truckX call jn_fnc_logistics_addAction;
	_truckX addAction ["Delivery infos",
		{
			_text = format ["Deliver this box to %1, unload it to start distributing to people",(_this select 0) getVariable "destinationX"]; //This need a rework
			_text remoteExecCall ["hint",_this select 2];	//This need a rework
		},
		nil,
		0,
		false,
		true,
		"",
		"(isPlayer _this) and (_this == _this getVariable ['owner',objNull])"
	];
	[_truckX] call A3A_fnc_AIVEHinit;
	//{_x reveal _truckX} forEach (allPlayers - (entities "HeadlessClient_F"));
	_truckX setVariable ["destinationX",_nameDest,true];

	[_truckX,"Supply Box"] spawn A3A_fnc_inmuneConvoy;
	[format ["LOG_Supplies.sqf: waiting for cargo to be unloaded at the target or taskTerminateLogBox: %1 == true", missionNamespace getVariable ["taskTerminateLogBox", false]], _debugMode] call A3A_fnc_debug;
	
	waitUntil {
		sleep 1;
		(missionNamespace getVariable ["taskTerminateLogBox", false]) or
		(
			(dateToNumber date > _dateLimitNum) or ((_truckX distance _positionX < 40) and (isNull attachedTo _truckX)) or (isNull _truckX)
		)
	};
	
	[format ["LOG_Supplies.sqf: loaded cargo or taskTerminateLogBox%1 == true", missionNamespace getVariable ["taskTerminateLogBox", false]], _debugMode] call A3A_fnc_debug;	
	if !(missionNamespace getVariable ["taskTerminateLogBox", false]) then {
		_bonus = if (_difficultX) then {2} else {1};
		// Fail if time elapsed or box is destroyed
		if ((dateToNumber date > _dateLimitNum) or (isNull _truckX)) then
			{
				["LOG",[_taskDescription,"City Supplies",_markerX],_positionX,"FAILED","Heal"] call A3A_fnc_taskUpdate;
				[5*_bonus,-5*_bonus,_positionX] remoteExec ["A3A_fnc_citySupportChange",2];
				[-10*_bonus,theBoss] call A3A_fnc_playerScoreAdd;
			}
		// Normal path
		else
			{
				["LOG_Supplies.sqf: unloaded cargo", _debugMode] call A3A_fnc_debug;
				_countX = 120*_bonus;
				// Spawn/hook up patrol
				[[_positionX,Occupants,"",false],"A3A_fnc_patrolCA"] remoteExec ["A3A_fnc_scheduler",2];
				// Show bad guys supplies are being deployed
				["TaskFailed", ["", format ["%2 deploying supplies in %1",_nameDest,nameTeamPlayer]]] remoteExec ["BIS_fnc_showNotification",Occupants];
				{_friendX = _x;
					if (captive _friendX) then
						{
						[_friendX,false] remoteExec ["setCaptive",0,_friendX];
						_friendX setCaptive false;
					};
					{
					if ((side _x == Occupants) and (_x distance _positionX < distanceSPWN)) then
						{
							if (_x distance _positionX < 300) then {_x doMove _positionX} else {_x reveal [_friendX,4]};
						};
					if ((side _x == civilian) and (_x distance _positionX < 300) and (vehicle _x == _x)) then {_x doMove position _truckX};
					} forEach allUnits;
				} forEach ([300,0,_truckX,teamPlayer] call A3A_fnc_distanceUnits);
				
				["LOG_Supplies.sqf: entering distance loop", _debugMode] call A3A_fnc_debug;
				while {
					(_countX > 0)/* or (_truckX distance _positionX < 40)*/ and (dateToNumber date < _dateLimitNum) and !(isNull _truckX)
					} do
					// Cargo unloaded loop
					{
						// Countdown loop
						while {(_countX > 0) and (_truckX distance _positionX < 40) and ({[_x] call A3A_fnc_canFight} count ([80,0,_truckX,teamPlayer] call A3A_fnc_distanceUnits) == count ([80,0,_truckX,teamPlayer] call A3A_fnc_distanceUnits)) and ({(side _x == Occupants) and (_x distance _truckX < 50)} count allUnits == 0) and (dateToNumber date < _dateLimitNum) and (isNull attachedTo _truckX)} do
							{
								if (missionNamespace getVariable ["taskTerminateLogBox", false]) exitWith {};
								_formatX = format ["%1", _countX];
								{if (isPlayer _x) then {[petros,"countdown",_formatX] remoteExec ["A3A_fnc_commsMP",_x]}} forEach ([80,0,_truckX,teamPlayer] call A3A_fnc_distanceUnits);
								sleep 1;
								_countX = _countX - 1;
							};
						// If cancelled, break out
						if (missionNamespace getVariable ["taskTerminateLogBox", false]) exitWith {};
							
						// reset if-statement and loop
						if (_countX > 0) then
							{
							_countX = 120*_bonus;//120
							if (((_truckX distance _positionX > 40) or (not([80,1,_truckX,teamPlayer] call A3A_fnc_distanceUnits)) or ({(side _x == Occupants) and (_x distance _truckX < 50)} count allUnits != 0)) and (alive _truckX)) then {{[petros,"hint","Don't get the truck far from the city center, and stay close to it, and clean all BLUFOR presence in the surroundings or count will restart"] remoteExec ["A3A_fnc_commsMP",_x]} forEach ([100,0,_truckX,teamPlayer] call A3A_fnc_distanceUnits)};
								waitUntil {
									["LOG_Supplies.sqf: resetting distance waitUntil", _debugMode] call A3A_fnc_debug; 
									if (missionNamespace getVariable ["taskTerminateLogBox", false]) exitWith { true };
									((_truckX distance _positionX < 40) and ([80,1,_truckX,teamPlayer] call A3A_fnc_distanceUnits) and ({(side _x == Occupants) and (_x distance _truckX < 50)} count allUnits == 0)) or (dateToNumber date > _dateLimitNum) or (isNull _truckX)
									sleep 1; 
								};
							};
						if (_countX < 1) exitWith {};
					};
				// Mission state changed. Cleanup after!
				[format ["LOG_Supplies.sqf: task finished with taskTerminateLogBox %1", missionNamespace getVariable ["taskTerminateLogBox", false]], _debugMode] call A3A_fnc_debug;
				if !(missionNamespace getVariable ["taskTerminateLogBox", false]) then {		
					if ((dateToNumber date < _dateLimitNum) and !(isNull _truckX)) then
						{
							[petros,"hint","Supplies Delivered"] remoteExec ["A3A_fnc_commsMP",[teamPlayer,civilian]];
							["LOG",[_taskDescription,"City Supplies",_markerX],_positionX,"SUCCEEDED","Heal"] call A3A_fnc_taskUpdate;
							{if (_x distance _positionX < 500) then {[10*_bonus,_x] call A3A_fnc_playerScoreAdd}} forEach (allPlayers - (entities "HeadlessClient_F"));
							[5*_bonus,theBoss] call A3A_fnc_playerScoreAdd;
							if (!isMultiplayer) then {_bonus = _bonus + ((20-skillFIA)*0.1)};
							[-1*(20-skillFIA),15*_bonus,_markerX] remoteExec ["A3A_fnc_citySupportChange",2];
							[-3,0] remoteExec ["A3A_fnc_prestige",2];
						}
					else
						{
							["LOG",[_taskDescription,"City Supplies",_markerX],_positionX,"FAILED","Heal"] call A3A_fnc_taskUpdate;
							[5*_bonus,-5*_bonus,_positionX] remoteExec ["A3A_fnc_citySupportChange",2];
							[-10*_bonus,theBoss] call A3A_fnc_playerScoreAdd;
						};
				} else {
					["LOG",[_taskDescription,"City Supplies",_marcador],_posicion,"CANCELLED","Heal"] call A3A_fnc_taskUpdate;
				};
			};
		if !(isNil "_truckX") then {
				_ecpos = getpos _truckX;
				deleteVehicle _truckX;
				_emptybox = "Land_PaperBox_01_open_empty_F" createVehicle _ecpos;
		};
	} else {
		[format ["LOG_Supplies.sqf: taskTerminateLogBox %1: skipped code after loading cargo waitUntil", taskTerminateLogBox], _debugMode] call A3A_fnc_debug;
	};

	[format ["LOG_Supplies.sqf: destroying task with taskTerminateLogBox %1", taskTerminateLogBox], _debugMode] call A3A_fnc_debug;
	if (["LOG"] call BIS_fnc_taskExists) then {
		[0, "LOG"] spawn A3A_fnc_deleteTask; // Timeout was 1200
	};
	waitUntil {
		sleep 1; 
		(missionNamespace getVariable ["taskTerminateLogBox", false]) or
		((not([distanceSPWN,1,_truckX,teamPlayer] call A3A_fnc_distanceUnits)) or (_truckX distance (getMarkerPos respawnTeamPlayer) < 60))
	};

	if !(isNil "_truckX") then {
		deleteVehicle _truckX;
	};
	if !(isNil "_emptybox") then {
		deleteVehicle _emptybox;
	};
	[format ["LOG_Supplies.sqf: setting taskTerminateLogBox %1 to false", missionNamespace getVariable ["taskTerminateLogBox", false]], _debugMode] call A3A_fnc_debug;
	missionNamespace setVariable ["taskTerminateLogBox", false, true];

} catch {
	[format ["LOG_Supplies.sqf:  <%1>", _exception], _debugMode] call A3A_fnc_debug;
	missionNamespace setVariable ["taskTerminateLogBox", false, true];
};