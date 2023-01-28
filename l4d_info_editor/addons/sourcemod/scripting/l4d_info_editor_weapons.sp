/*
*	Info Editor - Test Weapons
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



#define PLUGIN_VERSION		"1.2"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Info Editor - Test Weapons
*	Author	:	SilverShot
*	Descrp	:	Testing.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=310586
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (20-Oct-2022)
	- Changes to fix warnings when compiling on SourceMod 1.11.

1.1 (10-May-2020)
	- Various changes to tidy up code.

1.0 (23-Aug-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d_info_editor>

#define MAX_STRING_LENGTH		4096



// ====================================================================================================
//					PLUGIN INFO / LOAD
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Info Editor - Test Weapons",
	author = "SilverShot",
	description = "Testing.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=310586"
}

public void OnAllPluginsLoaded()
{
	if( LibraryExists("info_editor") == false )
	{
		SetFailState("Info Editor Test cannot start 'l4d_info_editor.smx' plugin not loaded.");
	}
}

public void OnPluginStart()
{
	RegAdminCmd("sm_info_weapon",	CmdInfoWeapon, ADMFLAG_ROOT, "Get or set a weapon keyname value. Usage: sm_info_weapon <weapon classname> <keyname> [value]");
	RegAdminCmd("sm_iw",			CmdInfoWeaponTest, ADMFLAG_ROOT, "Tests: sm_info_weapon weapon_rifle clip_size");
}

bool g_bDone;
char g_sClass[MAX_STRING_LENGTH];
char g_sKey[MAX_STRING_LENGTH];
char g_sSet[MAX_STRING_LENGTH];

Action CmdInfoWeaponTest(int client, int args)
{
	ServerCommand("sm_info_weapon weapon_rifle clip_size");
	// ServerCommand("sm_info_weapon weapon_rifle clip_size 25"); // Set value of 25.

	return Plugin_Handled;
}

Action CmdInfoWeapon(int client, int args)
{
	if( args < 2 )
	{
		ReplyToCommand(client, "Usage: sm_info_weapon <weapon classname> <key>");
		return Plugin_Handled;
	}

	GetCmdArg(1, g_sClass, sizeof(g_sClass));
	GetCmdArg(2, g_sKey, sizeof(g_sKey));

	if( args == 3 )
		GetCmdArg(3, g_sSet, sizeof(g_sSet));
	else
		g_sSet[0] = '\x0';

	g_bDone = false;
	ServerCommand("sm_info_reload");

	return Plugin_Handled;
}

public void OnGetWeaponsInfo(int pThis, const char[] classname)
{
	if( !g_bDone )
	{
		if( strcmp(classname, g_sClass) == 0 )
		{
			if( strlen(g_sSet) > 0 )
			{
				InfoEditor_SetString(pThis, g_sKey, g_sSet);
				PrintToServer("Info_Weapon: Set: %s/%s == %s", g_sClass, g_sKey, g_sSet);
			}

			char sResult[MAX_STRING_LENGTH];
			InfoEditor_GetString(pThis, g_sKey, sResult, sizeof(sResult));
			PrintToServer("Info_Weapon: %s/%s == %s", g_sClass, g_sKey, sResult);

			g_bDone = true;
		}
	}
}