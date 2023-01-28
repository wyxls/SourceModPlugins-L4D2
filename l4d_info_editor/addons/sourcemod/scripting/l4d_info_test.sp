/*
*	Info Editor - Test Plugin
*	Copyright (C) 2022 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION		"1.3"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Info Editor - Test Plugin
*	Author	:	SilverShot
*	Descrp	:	Testing.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=310586
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.3 (11-Dec-2022)
	- Increased string size.

1.2 (20-Oct-2022)
	- Small changes for a better example.

1.1 (10-May-2020)
	- Various changes to tidy up code.

1.0 (01-Jun-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d_info_editor>

bool g_bLeft4Dead2;



// ====================================================================================================
//					PLUGIN INFO / LOAD
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Info Editor - Test Plugin",
	author = "SilverShot",
	description = "Testing.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=310586"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if( LibraryExists("info_editor") == false )
	{
		SetFailState("Info Editor Test cannot start 'l4d_info_editor.smx' plugin not loaded.");
	}
}

public void OnGetMissionInfo(int pThis)
{
	RequestFrame(OnMission, pThis);
}

void OnMission(int pThis)
{
	// Example
	static char temp[256];

	if( g_bLeft4Dead2 )
	{
		// Get and show original value
		InfoEditor_GetString(pThis, "meleeweapons", temp, sizeof(temp));
		// Check the retrieved value is different to SetString value.
		if( strcmp(temp, "knife") )
		{
			PrintToServer("[INFO EDITOR TEST] >>> meleeweapons original == (%d) [%s]", pThis, temp);
			// Setting a new value
			InfoEditor_SetString(pThis, "meleeweapons", "knife");
			// Retrieve set value to show it's changed
			InfoEditor_GetString(pThis, "meleeweapons", temp, sizeof(temp));
			PrintToServer("[INFO EDITOR TEST] >>> meleeweapons modified == (%d) [%s]", pThis, temp);
		}
	}

	// Lets create another custom keyvalue which doesn't exist
	InfoEditor_GetString(pThis, "my_keyname", temp, sizeof(temp));
	// Check the retrieved value is different to SetString value.
	if( strcmp(temp, "testing") )
	{
		PrintToServer("[INFO EDITOR TEST] >>> my_keyname original == (%d) [%s]", pThis, temp);
		// True to create, for whatever reason, demonstration
		InfoEditor_SetString(pThis, "my_keyname", "testing", true);
		InfoEditor_GetString(pThis, "my_keyname", temp, sizeof(temp));
		PrintToServer("[INFO EDITOR TEST] >>> my_keyname modified == (%d) [%s]", pThis, temp);
	}
}

public void OnGetWeaponsInfo(int pThis, const char[] classname)
{
	// Match classname to the weapon we want to change
	if( strcmp(classname, "weapon_pistol") == 0 )
	{
		// We'll retrieve and print out the value
		char temp[64];
		InfoEditor_GetString(pThis, "clip_size", temp, sizeof(temp));
		PrintToServer("[INFO EDITOR TEST] >>> weapon_pistol/clip_size original == (%d) [%s]", pThis, temp);

		// We'll test the value and modify if we want
		if( StringToInt(temp) < 30 )
		{
			// Modify value
			InfoEditor_SetString(pThis, "clip_size", "50");

			// Test to show it's changed
			InfoEditor_GetString(pThis, "clip_size", temp, sizeof(temp));
			PrintToServer("TEST >>> weapon_pistol/clip_size modified == (%d) [%s]", pThis, temp);
		}
	}
}