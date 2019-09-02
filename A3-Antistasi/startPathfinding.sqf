params ["_startPos" , "_endPos", "_ignored"];

private _deltaTime = time;


_startNav = [_startPos] call findNearestNavPoint;
_endNav = [_endPos] call findNearestNavPoint;

hint format ["Start %1 at %2\nEnd %3 at %4", _startNav, str _startPos, _endNav, str _endPos];

allMarker = [];
createNavMarker = compile preprocessFileLineNumbers "NavGridTools\createNavMarker.sqf";


if(!(_startNav isEqualType 1 && _endNav isEqualType 1)) exitWith {hint "Improve the search!"};


//Start A* here
_openList = [];
_closedList = [];

_targetNavPos = [_startNav] call getNavPos;
_startNavPos = [_endNav] call getNavPos;

["mil_triangle", _targetNavPos, "ColorBlue"] call createNavMarker;
["mil_triangle", _startNavPos, "ColorBlue"] call createNavMarker;

private _lastNav = -1;

//Search for end to start, due to nature of script
_openList pushBack [_endNav, 0, [_startNavPos, _targetNavPos] call calculateH, "End"];


while {(!(_lastNav isEqualType [])) && {count _openList > 0}} do
{
    //Select node with lowest score
    _next = objNull;
    if((count _openList) == 1) then
    {
      _next = _openList deleteAt 0;
    }
    else
    {
      //private _debug = "List is";
      private _nextValue = 0;
      {
        _xValue = ((_x select 1) + (_x select 2));
        //_debug = format ["%1\n%2 Value %3", _debug ,str _x, _xValue];

        if((!(_next isEqualType [])) || {_xValue < _nextValue}) then
        {
          _next = _x;
          _nextValue = _xValue;
        };
      } forEach _openList;
      //_debug = format ["%1\nSelected was %2 value %3", _debug, str _next, ((_next select 1) + (_next select 2))];
      //hint _debug;
      //sleep 5;

      _openList = _openList - [_next];
    };

    //Close node
    _closedList pushBack _next;


    //Gather next nodes
    _nextNodes = [_next select 0] call getNavConnections;
    _nextPos = [_next select 0] call getNavPos;

    ["mil_dot", _nextPos, "ColorRed"] call createNavMarker;

    {
        _conNav = _x;
        _conName = _conNav select 0;

        //Found the end
        if(_conName == _startNav) exitWith {_lastNav = _next};

        _conPos = [_conName] call getNavPos;

        //Not in closed list
        if((_closedList findIf {(_x select 0) == _conName}) == -1) then
        {
          _openListIndex = _openList findIf {(_x select 0) == _conName};

          //Not in open list
          if(_openListIndex == -1) then
          {
            _h = [_conPos, _targetNavPos] call calculateH;
            _openList pushBack [_conName, ((_next select 1) + (_nextPos distance _conPos)), _h, (_next select 0)];
            ["mil_dot", _conPos, "ColorGreen"] call createNavMarker;
          }
          else
          {
            //In open list
            _conData = _openList deleteAt _openListIndex;
            //Is it a shorter way to this node?
            if((_conData select 1) > ((_next select 1) + (_nodePos distance _conPos))) then
            {
              _conData set [1, ((_next select 1) + (_nextPos distance _conPos))];
              _conData set [3, (_next select 0)];
            };
            _openList pushBack _conData;
          };
        };
    } forEach _nextNodes;

    //deleteMarker _marker;
    //sleep 0.5;
};

private _wayPoints = [];
if(_lastNav isEqualType []) then
{
  //Way found, reverting way through path
  _wayPoints = [_startPos, _targetNavPos];
  while {_lastNav isEqualType []} do
  {
    _wayPoints pushBack ([_lastNav select 0] call getNavPos);
    _lastNavIndex = _lastNav select 3;
    if(_lastNavIndex isEqualType 1) then
    {
      _closedListIndex = _closedList findIf {(_x select 0) == _lastNavIndex};
      _lastNav = _closedList select _closedListIndex;
    }
    else
    {
      _lastNav = -1;
    };
  };
  _wayPoints pushBack _endPos;
  _deltaTime = time - _deltaTime;
  hint format ["Successful finished pathfinding in %1 seconds", _deltaTime];
}
else
{
  _deltaTime = time - _deltaTime;
  hint format ["Could not find a way, search took %1 seconds", _deltaTime];
};

_wayPoints;