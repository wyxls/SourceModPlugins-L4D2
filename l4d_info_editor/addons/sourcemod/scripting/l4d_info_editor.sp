/*
*	Mission and Weapons - Info Editor
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



#define PLUGIN_VERSION		"1.19"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Mission and Weapons - Info Editor
*	Author	:	SilverShot
*	Descrp	:	Modify gamemodes.txt and weapons.txt values by config instead of conflicting VPK files.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=310586
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.19 (16-Dec-2022)
	- Fixed not loading melee weapons on certain maps under certain conditions. Thanks to "Mi.Cura" for reporting.
	- Feature added: plugin can load mode specific sections that overwrite previous data loaded from the "l4d_info_editor_mission.cfg" config. Requested by "ProjectSky".
	- Feature added: plugin can load mode specific configs, e.g. "l4d_info_editor_mission.versus.cfg" or "l4d_info_editor_mission.mutation3.cfg" for "Versus" or "Bleedout" modes etc.
	- These features also apply to the "l4d_info_editor_weapons.cfg" data config.

1.18 (15-Dec-2022)
	- Fixed duplicating custom melee weapons in the mission keyvalue string. Thanks to "ProjectSky" for reporting.
	- Fixed not loading melee weapons if the "Info Editor" config is missing a "meleeweapons" key to use.

1.17 (12-Dec-2022)
	- Forgot to turn off debug printing values.

1.16 (11-Dec-2022)
	- Fixed error in command "sm_info_melee" causing it to not display everything correctly.

1.15 (11-Dec-2022)
	- L4D2: Now supports 3rd party melee weapons where the mission.txt file does not contain a "meleeweapons" key. Thanks to "Yabi" for reporting and testing.
	- L4D2: Added command "sm_info_melee" to list the maps currently allowed melee weapons and report any issues.
	- L4D2: GameData file has updated to support these changes.

1.14 (21-Oct-2022)
	- Fixed plugins not loading with the updated include file.
	- Include file updated.

1.13 (20-Oct-2022)
	- L4D2: Plugin now prevents setting over 16 melee weapons. Thanks to "gabuch2" for reporting.
	- Compiled .smx plugin is now compiled with SourceMod version 1.11.

1.12 (01-Oct-2020)
	- Fixed not properly adding both melee weapons causing potential issues.

1.11 (24-Sep-2020)
	- Compatibility update for L4D2's "The Last Stand" update.
	- Added support for the 2 new melee weapons.
	- GameData .txt file updated.

1.10 (02-Jul-2020)
	- Fixed not always loading the correct map section data in the config for the current map.
	- Fixed not adding 3rd party melee weapons on all 3rd party maps. Thanks to "Shao" for reporting.

1.9 (10-May-2020)
	- Added better error log message when gamedata file is missing.
	- Now supports setting strings to "" when using the "InfoEditor_SetString" native.
	- Various changes to tidy up code.
	- Various optimizations and fixes.

1.8 (30-Apr-2020)
	- Changed "InfoEditor_GetString" and "InfoEditor_SetString" natives to not require the mission pointer.
	- Specifying 0 when calling will make Info Editor use the last known mission pointer value.
	- A valid pointer will still be required to read weapons data.

1.7 (12-Apr-2020)
	- Fixed breaking some melee entries when adding 3rd party melee names containing similar classnames.
	- Thanks to "Marttt" for reporting.

1.6 (10-Apr-2020)
	- Added support to match multiple map names using comma separation in the data configs, as requested by "Lux".
	- Added "clip_size", "ReloadDuration", "CycleTime", "Damage", "Range" and "RangeModifier" to "l4d_info_editor_weapons.cfg" config.
	- Values shown are default from L4D2 weapon scripts.
	- Fixed not creating keys for weapons and accidentally creating them on the mission file instead.

1.5 (01-Apr-2020)
	- Changed command block to allow listen servers to operate the reload command.
	- Changed .inc file to remove args from copy paste error of "InfoEditor_ReloadData" native.

1.4 (18-Mar-2020)
	- Added native "InfoEditor_ReloadData" for external plugins to reload the mission and weapon configs.
	- Fixed crashing with "CTerrorWeaponInfo::Reload" error. Finally!

1.3 (25-Feb-2020)
	- Now dynamically generates "meleeweapons" string for any map using custom melee weapons.
	- Set the string to the default game weapons you want to include, and the custom ones will be added.
	- Mission config "l4d_info_editor_mission.cfg" updated with changes for "Helms Deep" map.

1.2 (17-Sep-2019)
	- No longer removing cheat flags from "sb_all_bot_game" command, was never deleted from testing.

1.1.1a (25-Aug-2019) re-upload
	- Added "helms_deep" section in the mission config to enable all melee weapons on that map.

1.1.1 (09-Jun-2019)
	- Added FORCE_VALUES define to force create missing keys.
	- Slightly optimized fixing single line mistake.
	- Slight code cleaning.

1.1 (01-Jun-2019)
	- Fixed reading incorrect data for map specific sections.
	- Added support to load map specific weapon and melee data.
	- Added commands to display mission and weapon changes applied to the current map.
	- Added a command to get and set keyname values from the mission info.
	- Added a command to reload the mission and weapons configs. Live changes can be made!
	- Added natives to read and write mission and weapon data from third party plugins.
	- Added test plugin to demonstrate natives and forwards for developers.
	- Gamedata .txt changed.

1.0 (10-Sep-2018)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define GAMEDATA				"l4d_info_editor"
#define CONFIG_MISSION			"data/l4d_info_editor_mission.cfg"
#define CONFIG_WEAPONS			"data/l4d_info_editor_weapons.cfg"
#define MAX_STRING_LENGTH		4096
#define MAX_STRING_MELEE		64 // Maximum string length of melee weapons
#define DEBUG_VALUES			0
#define FORCE_VALUES			1 // Force create keyvalues when not found.

bool g_bGameMode;
ConVar g_hCvarMPGameMode;
char g_sGameMode[64];
char g_sConfigMission[PLATFORM_MAX_PATH];
char g_sConfigWeapons[PLATFORM_MAX_PATH];
Handle g_hForwardOnGetMission;
Handle g_hForwardOnGetWeapons;
Handle SDK_KV_GetString;
Handle SDK_KV_SetString;
Handle SDK_KV_FindKey;
ArrayList g_alMissionData;
ArrayList g_alWeaponsData;
ArrayList g_alMeleeDefault;
ArrayList g_alMeleeCustoms;
int g_PointerMission;
bool g_bLeft4Dead2;
bool g_bLoadNewMap;
bool g_bManifest;
bool g_bHasMelee;



// ====================================================================================================
//					PLUGIN INFO / NATIVES
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Mission and Weapons - Info Editor",
	author = "SilverShot",
	description = "Modify gamemodes.txt and weapons.txt values by config instead of conflicting VPK files.",
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

	// Natives
	RegPluginLibrary("info_editor");
	CreateNative("InfoEditor_GetString",		Native_GetString);
	CreateNative("InfoEditor_SetString",		Native_SetString);
	CreateNative("InfoEditor_ReloadData",		Native_ReloadData);

	g_bManifest = late;
	if( late )
	{
		LoadManifest();
	}

	return APLRes_Success;
}

int Native_GetString(Handle plugin, int numParams)
{
	// Pointer to keyvalue for modifying
	int pThis = GetNativeCell(1);
	if( pThis == 0 ) pThis = g_PointerMission;
	if( pThis == 0 ) return 0; // Some maps maybe invalid (due to invalid gamemode).

	// Validate string
	int len;
	GetNativeStringLength(2, len);
	if( len <= 0 ) return 0;

	// Key name to get
	char key[MAX_STRING_LENGTH];
	GetNativeString(2, key, sizeof(key));

	// Get key value
	char value[MAX_STRING_LENGTH];
	SDKCall(SDK_KV_GetString, pThis, value, sizeof(value), key, "N/A");

	// Return string
	int maxlength = GetNativeCell(4);
	SetNativeString(3, value, maxlength);

	return 0;
}

int Native_SetString(Handle plugin, int numParams)
{
	// Pointer to keyvalue for modifying
	int pThis = GetNativeCell(1);
	if( pThis == 0 ) pThis = g_PointerMission;
	if( pThis == 0 ) return 0; // Some maps maybe invalid (due to invalid gamemode).

	// Validate string
	int len;
	GetNativeStringLength(2, len);
	if( len <= 0 ) return 0;
	GetNativeStringLength(3, len);

	// Key name and value to set
	char key[MAX_STRING_LENGTH];
	char[] value = new char[len+1];
	GetNativeString(2, key, sizeof(key));
	GetNativeString(3, value, len+1);

	// Create
	bool bCreate = GetNativeCell(4);
	if( bCreate && SDK_KV_FindKey != null )
	{
		char sCheck[MAX_STRING_LENGTH];
		SDKCall(SDK_KV_GetString, pThis, sCheck, sizeof(sCheck), key, "N/A");
		if( strcmp(sCheck, "N/A") == 0 )
		{
			SDKCall(SDK_KV_FindKey, pThis, key, true);
		}
	}

	// Set key value
	SDKCall(SDK_KV_SetString, pThis, key, value);

	return 0;
}



// ====================================================================================================
//					PLUGIN START / END
// ====================================================================================================
public void OnPluginStart()
{
	CreateConVar("l4d_info_editor_version", PLUGIN_VERSION, "Mission and Weapons - Info Editor plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Cvars);
	ConVarChanged_Cvars(null, "", "");

	// ====================================================================================================
	// SDKCalls
	// ====================================================================================================
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if( FileExists(sPath) == false ) SetFailState("\n==========\nMissing required file: \"%s\".\nRead installation instructions again.\n==========", sPath);

	Handle hGameData = LoadGameConfigFile(GAMEDATA);
	if( hGameData == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString") == false )
		SetFailState("Could not load the \"KeyValues::GetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	SDK_KV_GetString = EndPrepSDKCall();
	if( SDK_KV_GetString == null )
		SetFailState("Could not prep the \"KeyValues::GetString\" function.");

	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString") == false )
		SetFailState("Could not load the \"KeyValues::SetString\" gamedata signature.");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	SDK_KV_SetString = EndPrepSDKCall();
	if( SDK_KV_SetString == null )
		SetFailState("Could not prep the \"KeyValues::SetString\" function.");

	// Optional, not required.
	StartPrepSDKCall(SDKCall_Raw);
	if( PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::FindKey") == false )
	{
		LogError("Could not load the \"KeyValues::FindKey\" gamedata signature.");
	} else {
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);
		SDK_KV_FindKey = EndPrepSDKCall();
		if( SDK_KV_FindKey == null )
			LogError("Could not prep the \"KeyValues::FindKey\" function.");
	}

	// ====================================================================================================
	// Detours
	// ====================================================================================================
	Handle hDetour;

	// Mission Info
	hDetour = DHookCreateFromConf(hGameData, "CTerrorGameRules::GetMissionInfo");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorGameRules::GetMissionInfo\" signature.");
	if( !DHookEnableDetour(hDetour, true, GetMissionInfo) )
		SetFailState("Failed to detour \"CTerrorGameRules::GetMissionInfo\"");
	delete hDetour;

	// Weapon Info
	hDetour = DHookCreateFromConf(hGameData, "CTerrorWeaponInfo::Parse");
	if( !hDetour )
		SetFailState("Failed to find \"CTerrorWeaponInfo::Parse\" signature.");
	if( !DHookEnableDetour(hDetour, false, GetWeaponInfo) )
		SetFailState("Failed to detour \"CTerrorWeaponInfo::Parse\"");
	delete hDetour;

	if( g_bLeft4Dead2 )
	{
		// Melee Weapons
		hDetour = DHookCreateFromConf(hGameData, "CMeleeWeaponInfo::Parse");
		if( !hDetour )
			SetFailState("Failed to find \"CMeleeWeaponInfo::Parse\" signature.");
		if( !DHookEnableDetour(hDetour, false, GetMeleeWeaponInfo) )
			SetFailState("Failed to detour \"CMeleeWeaponInfo::Parse\"");
		delete hDetour;

		// Allow all Melee weapon types
		hDetour = DHookCreateFromConf(hGameData, "CDirectorItemManager::IsMeleeWeaponAllowedToExist");
		if( !hDetour )
			SetFailState("Failed to find \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\" signature.");
		if( !DHookEnableDetour(hDetour, true, MeleeWeaponAllowedToExist) )
			SetFailState("Failed to detour \"CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
		delete hDetour;

		// Overwrite string when "meleeweapons" keyvalue from mission.txt is empty
		hDetour = DHookCreateFromConf(hGameData, "CMeleeWeaponInfoStore::LoadScriptsFromManifest");
		if( !hDetour )
			SetFailState("Failed to find \"CMeleeWeaponInfoStore::LoadScriptsFromManifest\" signature.");
		if( !DHookEnableDetour(hDetour, false, LoadScriptsFromManifest) )
			SetFailState("Failed to detour \"CMeleeWeaponInfoStore::LoadScriptsFromManifest\"");
		delete hDetour;
	}

	delete hGameData;

	// Strip cheat flags here, because executing when required with a CheatCommand() function to strip/add the cheat flag denies with the error:
	// "Can't use cheat command weapon_reparse_server in multiplayer, unless the server has sv_cheats set to 1."
	// We'll also block clients from executing the commands to prevent any potential exploit or command spam.
	SetCommandFlags("weapon_reparse_server", GetCommandFlags("weapon_reparse_server") & ~FCVAR_CHEAT);
	AddCommandListener(CmdListenBlock, "weapon_reparse_server");
	if( g_bLeft4Dead2 )
	{
		SetCommandFlags("melee_reload_info_server", GetCommandFlags("melee_reload_info_server") & ~FCVAR_CHEAT);
		AddCommandListener(CmdListenBlock, "melee_reload_info_server");
	}

	// Forwards
	g_hForwardOnGetMission = CreateGlobalForward("OnGetMissionInfo", ET_Ignore, Param_Cell);
	g_hForwardOnGetWeapons = CreateGlobalForward("OnGetWeaponsInfo", ET_Ignore, Param_Cell, Param_String);

	// Load config
	ResetPlugin();

	// Commands
	RegAdminCmd("sm_info_mission_list",	CmdInfoMissionList,	ADMFLAG_ROOT, "Show mission config tree of modified data for this map.");
	RegAdminCmd("sm_info_weapons_list",	CmdInfoWeaponsList,	ADMFLAG_ROOT, "Show weapons config tree of modified data for this map.");
	RegAdminCmd("sm_info_mission",		CmdInfoMission,		ADMFLAG_ROOT, "Get or set the value of a mission keyname. Usage: sm_info_mission <keyname> [value].");
	RegAdminCmd("sm_info_reload",		CmdInfoReload,		ADMFLAG_ROOT, "Reloads the mission and weapons configs. Weapons info data is re-parsed allowing changes to be made live without changing level.");

	if( g_bLeft4Dead2 )
	{
		RegAdminCmd("sm_info_melee",	CmdInfoMelee,		ADMFLAG_ROOT, "Lists the maps current melee weapons allowed and report any issues.");

		// Add stock melee weapons, used to remove from manifest
		g_alMeleeDefault = new ArrayList(ByteCountToCells(MAX_STRING_MELEE));
		g_alMeleeDefault.PushString("baseball_bat");
		g_alMeleeDefault.PushString("cricket_bat");
		g_alMeleeDefault.PushString("crowbar");
		g_alMeleeDefault.PushString("electric_guitar");
		g_alMeleeDefault.PushString("fireaxe");
		g_alMeleeDefault.PushString("frying_pan");
		g_alMeleeDefault.PushString("golfclub");
		g_alMeleeDefault.PushString("katana");
		g_alMeleeDefault.PushString("knife");
		g_alMeleeDefault.PushString("machete");
		g_alMeleeDefault.PushString("tonfa");
		g_alMeleeDefault.PushString("pitchfork");
		g_alMeleeDefault.PushString("shovel");
		g_alMeleeDefault.PushString("riot_shield");
	}
}

Action CmdListenBlock(int client, const char[] command, int argc)
{
	client = IsDedicatedServer() ? client : (client > 1 ? client : 0);

	if( client )
		return Plugin_Handled;
	return Plugin_Continue;
}

public void OnMapEnd()
{
	g_bLoadNewMap = true;
}

void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	g_hCvarMPGameMode.GetString(g_sGameMode, sizeof(g_sGameMode));
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
Action CmdInfoMelee(int client, int args)
{
	char sTemp[256];

	ArrayList aTabs = new ArrayList(ByteCountToCells(MAX_STRING_MELEE));
	ArrayList aMiss = new ArrayList(ByteCountToCells(MAX_STRING_MELEE));

	// StringTable data
	int table = INVALID_STRING_TABLE;
	if( table == INVALID_STRING_TABLE )
	{
		table = FindStringTable("MeleeWeapons");
	}

	int total = GetStringTableNumStrings(table);
	int max = GetStringTableMaxStrings(table);
	for( int i = 0; i < total; i++ )
	{
		ReadStringTable(table, i, sTemp, sizeof(sTemp));

		aTabs.PushString(sTemp);

		ReplyToCommand(client, "StringTable %2d: [%s]", i + 1, sTemp);
	}

	// Mission data
	if( g_PointerMission )
	{
		int mission = 0;
		ReplyToCommand(client, " ");

		SDKCall(SDK_KV_GetString, g_PointerMission, sTemp, sizeof(sTemp), "meleeweapons", "N/A");

		if( sTemp[0] && strcmp(sTemp, "N/A") )
		{
			int last, pos;
			bool loop = true;

			while( loop )
			{
				pos = FindCharInString(sTemp[last], ';');
				if( pos != -1 )
				{
					pos += last;
					sTemp[pos] = 0;
				}
				else
				{
					loop = false;
				}

				mission++;
				aMiss.PushString(sTemp[last]);
				ReplyToCommand(client, "MissionData %2d. %s", mission, sTemp[last]);

				last = pos + 1;
			}
		}

		ReplyToCommand(client, "Total melee weapons: %d/%d", total, max);



		// Verify lengths match
		int lenMiss = aMiss.Length;
		int lenTabs = aTabs.Length;
		if( lenMiss != lenTabs )
		{
			ReplyToCommand(client, " ");
			ReplyToCommand(client, "Melee length mismatch: Mission %d != StringTable %d", lenMiss, lenTabs);
		}

		// Verify lists match
		char sTabs[MAX_STRING_MELEE];

		if( lenMiss < lenTabs )
			max = lenMiss;
		else
			max = lenTabs;

		for( int i = 0; i < max; i++ )
		{
			aMiss.GetString(i, sTemp, sizeof(sTemp));
			aTabs.GetString(i, sTabs, sizeof(sTabs));

			if( strcmp(sTemp, sTabs) )
			{
				ReplyToCommand(client, "Melee mismatch: %d Mission [%s] != StringTable [%s]", i, sTemp, sTabs);
			}
		}
	}
	else
	{
		ReplyToCommand(client, "No mission pointer");
	}

	return Plugin_Handled;
}

Action CmdInfoReload(int client, int args)
{
	ReloadData();
	ReplyToCommand(client, "[Info Editor] Reloaded configs and weapon attributes.");
	return Plugin_Handled;
}

int Native_ReloadData(Handle plugin, int numParams)
{
	ReloadData();
	return 0;
}

void ReloadData()
{
	// Weapons Info is re-parsed via command in this function.
	ResetPlugin();

	if( g_PointerMission )
		SetMissionData();
}

Action CmdInfoMission(int client, int args)
{
	if( g_PointerMission == 0 )
	{
		ReplyToCommand(client, "[Info] Error: no mission pointer. invalid game mode for this map?");
		return Plugin_Handled;
	}

	if( args == 1 )
	{
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];
		GetCmdArg(1, key, sizeof(key));

		SDKCall(SDK_KV_GetString, g_PointerMission, value, sizeof(value), key, "N/A");
		ReplyToCommand(client, "[Info] Key \"%s\" = \"%s\"", key, value);
	}

	else if( args == 2 )
	{
		char key[MAX_STRING_LENGTH];
		char value[MAX_STRING_LENGTH];
		char check[MAX_STRING_LENGTH];
		GetCmdArg(1, key, sizeof(key));
		GetCmdArg(2, value, sizeof(value));

		// Check value
		SDKCall(SDK_KV_GetString, g_PointerMission, check, sizeof(check), key, "N/A");

		// Create if not found.
		bool existed = true;
		if( SDK_KV_FindKey != null && strcmp(check, "N/A") == 0 )
		{
			SDKCall(SDK_KV_FindKey, g_PointerMission, key, true);
			existed = false;
		}

		SDKCall(SDK_KV_SetString, g_PointerMission, key, value);

		if( existed )
			ReplyToCommand(client, "[Info] Set \"%s\" to \"%s\"", key, value);
		else
			ReplyToCommand(client, "[Info] Created \"%s\" set \"%s\"", key, value);
	}

	else
	{
		ReplyToCommand(client, "Usage: sm_info_mission <keyname> [value]");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

Action CmdInfoMissionList(int client, int args)
{
	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== MISSION INFO DATA =====");
	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, " ");
	ReplyToCommand(client, "Config: %s", g_sConfigMission);
	ReplyToCommand(client, " ");

	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	int length = g_alMissionData.Length;

	for( int i = 0; i < length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		ReplyToCommand(client, "%s %s", key, value);
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}

Action CmdInfoWeaponsList(int client, int args)
{
	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, "===== WEAPONS INFO DATA =====");
	ReplyToCommand(client, "=============================");
	ReplyToCommand(client, " ");
	ReplyToCommand(client, "Config: %s", g_sConfigWeapons);
	ReplyToCommand(client, " ");

	ArrayList aHand;
	int size;
	int length = g_alWeaponsData.Length;
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	for( int x = 0; x < length; x++ )
	{
		// Weapon classname
		aHand = g_alWeaponsData.Get(x);
		aHand.GetString(0, check, sizeof(check));

		ReplyToCommand(client, check);

		// Weapon keys and values
		size = aHand.Length;
		for( int i = 1; i < size; i+=2 )
		{
			aHand.GetString(i, key, sizeof(key));
			aHand.GetString(i+1, value, sizeof(value));
			ReplyToCommand(client, "... %s %s", key, value);
		}

		ReplyToCommand(client, "");
	}

	ReplyToCommand(client, "=============================");
	return Plugin_Handled;
}



// ====================================================================================================
//					DETOURS
// ====================================================================================================
MRESReturn GetMissionInfo(DHookReturn hReturn, DHookParam hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Pointer
	int pThis = DHookGetReturn(hReturn);
	g_PointerMission = pThis;
	if( pThis == 0 ) return MRES_Ignored; // Some maps the mission file does not load (most likely due to gamemode not being supported).

	SetMissionData();

	// Forward
	Call_StartForward(g_hForwardOnGetMission);
	Call_PushCell(pThis);
	Call_Finish();

	return MRES_Ignored;
}

void SetMissionData()
{
	// Mission Info has no command, but we can manually set changes with ease.
	static char key[MAX_STRING_LENGTH];
	static char value[MAX_STRING_LENGTH];
	static char extra[MAX_STRING_LENGTH];
	static char check[MAX_STRING_LENGTH];
	static char defs[MAX_STRING_LENGTH];
	static char temp[MAX_STRING_MELEE];

	// Loop through Info Editor config
	bool write;
	int last;
	int pos;
	extra[0] = 0;
	check[0] = 0;

	for( int i = 0; i < g_alMissionData.Length; i += 2 )
	{
		g_alMissionData.GetString(i, key, sizeof(key));
		g_alMissionData.GetString(i + 1, value, sizeof(value));

		SDKCall(SDK_KV_GetString, g_PointerMission, defs, sizeof(defs), key, "N/A");

		// Dynamic Melee Weapons:
		if( g_bLeft4Dead2 && strcmp(key, "meleeweapons") == 0 )
		{
			g_bHasMelee = true;
			write = false;

			// Add manifest entries for custom melee weapons when the mission file does not supply the "meleeweapons" string
			// Ignore these default melee weapons
			if( g_alMeleeCustoms )
			{
				int total = g_alMeleeCustoms.Length;

				// Loop through manifest melee weapon scripts
				for( int x = 0; x < total; x++ )
				{
					g_alMeleeCustoms.GetString(x, temp, sizeof(temp));

					// Only add unknown melee weapons
					if( g_alMeleeDefault.FindString(temp) == -1 && StrContains(check, temp) == -1 )
					{
						StrCat(check, sizeof(check), temp);
						StrCat(check, sizeof(check), ";");
					}
				}

				// Remove trailing ";"
				pos = strlen(check);
				if( pos )
				{
					check[pos - 1] = 0;
				}

				// Manifest has custom entries
				if( check[0] )
				{
					// If the maps "meleeweapons" string is empty, set them from the manifest
					if( strcmp(defs, "N/A") == 0  )
					{
						write = true;
						strcopy(defs, sizeof(defs), check);
					}
				}
				// If the manifest has been read
				else if( g_bManifest )
				{
					// If the maps "meleeweapons" string is empty, set them from the data config
					if( strcmp(defs, "N/A") == 0  )
					{
						write = true;
						strcopy(defs, sizeof(defs), value);
					}
				}
			}

			// "meleeweapons" string is not empty
			if( strcmp(defs, "N/A") )
			{
				// Replace game default melee weapons
				FormatEx(check, sizeof(check), ";%s;", defs);
				ReplaceStringEx(check, sizeof(check), ";baseball_bat;", ";");
				ReplaceStringEx(check, sizeof(check), ";cricket_bat;", ";");
				ReplaceStringEx(check, sizeof(check), ";crowbar;", ";");
				ReplaceStringEx(check, sizeof(check), ";electric_guitar;", ";");
				ReplaceStringEx(check, sizeof(check), ";fireaxe;", ";");
				ReplaceStringEx(check, sizeof(check), ";frying_pan;", ";");
				ReplaceStringEx(check, sizeof(check), ";golfclub;", ";");
				ReplaceStringEx(check, sizeof(check), ";katana;", ";");
				ReplaceStringEx(check, sizeof(check), ";knife;", ";");
				ReplaceStringEx(check, sizeof(check), ";machete;", ";");
				ReplaceStringEx(check, sizeof(check), ";tonfa;", ";");
				ReplaceStringEx(check, sizeof(check), ";pitchfork;", ";");
				ReplaceStringEx(check, sizeof(check), ";shovel;", ";");
				ReplaceStringEx(check, sizeof(check), ";riot_shield;", ";");

				// Prevent duplicate entries
				pos = 1;
				while( (last = SplitString(check[pos], ";", temp, sizeof(temp))) != -1 )
				{
					if( StrContains(value, temp) == -1 && StrContains(extra, temp) == -1 )
					{
						Format(extra, sizeof(extra), "%s;%s", extra, temp);
					}

					pos += last;
				}
				
				if( extra[0] )
				{
					Format(value, sizeof(value), "%s;%s", extra[1], value);
				}

				// Prevent setting over 16 melee weapons
				pos = 0;
				for( int x = 0; x < 16; x++ )
				{
					last = FindCharInString(value[pos], ';');
					if( last == -1 ) break;

					pos += last + 1;

					if( x == 15 )
					{
						value[pos] = 0;
						break;
					}
				}

				// Remove trailing ;
				pos = strlen(value);
				if( pos > 0 )
				{
					if( value[pos - 1] == ';' ) value[pos - 1] = 0;
				}
			}
			else
			{
				strcopy(value, sizeof(value), defs);
			}
		}

		// Overwrite different values
		if( write || strcmp(defs, value) )
		{
			#if DEBUG_VALUES || FORCE_VALUES
			if( strcmp(defs, "N/A") == 0 )
			{
				#if FORCE_VALUES
					if( SDK_KV_FindKey != null )
					{
						SDKCall(SDK_KV_FindKey, g_PointerMission, key, true);
						#if DEBUG_VALUES
							PrintToServer("MissionInfo: Attempted to create \"%s\"", key);
						#endif
					}
				#endif

				#if DEBUG_VALUES
					PrintToServer("MissionInfo: \"%s\" not found.", key);
				#endif
			} else {
				#if DEBUG_VALUES
					PrintToServer("MissionInfo: Set \"%s\" to \"%s\". Was \"%s\"", key, value, defs);
				#endif
			}
			#endif

			SDKCall(SDK_KV_SetString, g_PointerMission, key, value);
		}
	}
}

MRESReturn MeleeWeaponAllowedToExist(DHookReturn hReturn, DHookParam hParams)
{
	hReturn.Value = true;
	return MRES_Override;
}

MRESReturn LoadScriptsFromManifest(DHookReturn hReturn, DHookParam hParams)
{
	g_bManifest = true;

	if( g_bHasMelee )
	{
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

MRESReturn GetMeleeWeaponInfo(DHookReturn hReturn, DHookParam hParams)
{
	WeaponInfoFunction(1, hParams);
	return MRES_Ignored;
}

MRESReturn GetWeaponInfo(DHookReturn hReturn, DHookParam hParams)
{
	WeaponInfoFunction(0, hParams);
	return MRES_Ignored;
}

void WeaponInfoFunction(int funk, Handle hParams)
{
	// Load new map data
	if( g_bLoadNewMap ) ResetPlugin();

	// Pointer
	int pThis = DHookGetParam(hParams, 1 + funk);

	// Weapon name
	char class[64];
	DHookGetParamString(hParams, 2 - funk, class, sizeof(class));

	// Set data
	ArrayList aHand;
	char key[MAX_STRING_LENGTH];
	char value[MAX_STRING_LENGTH];
	char check[MAX_STRING_LENGTH];

	// Loop editor_weapons classnames
	for( int x = 0; x < g_alWeaponsData.Length; x++ )
	{
		aHand = g_alWeaponsData.Get(x);
		aHand.GetString(0, key, sizeof(key));

		// Matches weapon from detour
		if( strcmp(class, key) == 0 )
		{
			// Loop editor_weapons properties
			for( int i = 1; i < aHand.Length; i += 2 )
			{
				aHand.GetString(i, key, sizeof(key));
				aHand.GetString(i + 1, value, sizeof(value));

				SDKCall(SDK_KV_GetString, pThis, check, sizeof(check), key, "N/A");

				if( strcmp(check, value) )
				{
					#if DEBUG_VALUES || FORCE_VALUES
					if( strcmp(check, "N/A") == 0 )
					{
						#if FORCE_VALUES
							if( SDK_KV_FindKey != null )
							{
								SDKCall(SDK_KV_FindKey, pThis, key, true);
								#if DEBUG_VALUES
									PrintToServer("WeaponInfo: Attempted to create \"%s\"", key);
								#endif
							}
						#endif

						#if DEBUG_VALUES
							PrintToServer("WeaponInfo: \"%s/%s\" not found.", class, key);
						#endif
					} else {
						#if DEBUG_VALUES
							PrintToServer("WeaponInfo: Set \"%s/%s\" to \"%s\". Was \"%s\"", class, key, value, check);
						#endif
					}
					#endif

					SDKCall(SDK_KV_SetString, pThis, key, value);
				}
			}
		}
	}

	// Forward
	Call_StartForward(g_hForwardOnGetWeapons);
	Call_PushCell(pThis);
	Call_PushString(class);
	Call_Finish();
}



// ====================================================================================================
//					LOAD CONFIG
// ====================================================================================================
bool g_bAllowSection;
int g_iSectionMission; // 0 = weapons cfg. 1 = mission cfg.
int g_iSectionLevel;
int g_iValueIndex;

void ResetPlugin()
{
	char sMap[PLATFORM_MAX_PATH];
	GetCurrentMap(sMap, sizeof(sMap));

	if( g_bLoadNewMap )
	{
		g_bLoadNewMap = false;
		g_bManifest = false;
		g_bHasMelee = false;

		// Load custom melee weapons list
		LoadManifest();
	}

	// Clear strings
	if( g_alMissionData != null )
	{
		g_alMissionData.Clear();
		delete g_alMissionData;
	}

	// Delete handles
	if( g_alWeaponsData != null )
	{
		ArrayList aHand;
		int size = g_alWeaponsData.Length;

		for( int i = 0; i < size; i++ )
		{
			aHand = g_alWeaponsData.Get(i);
			delete aHand;
		}

		g_alWeaponsData.Clear();
		delete g_alWeaponsData;
	}

	// Load again
	LoadConfig();

	RequestFrame(OnStart);
}

void OnStart()
{
	// Reparse weapon and melee configs each map
	ServerCommand("weapon_reparse_server; %s", g_bLeft4Dead2 ? "melee_reload_info_server" : "");
}

void LoadManifest()
{
	if( g_bLeft4Dead2 )
	{
		delete g_alMeleeCustoms;
		g_alMeleeCustoms = new ArrayList(ByteCountToCells(MAX_STRING_MELEE));

		File hFile = OpenFile("scripts/melee/melee_manifest.txt", "r", true);
		if( hFile )
		{
			char sLine[256];
			int start;
			int last;

			while( !IsEndOfFile(hFile) && ReadFileLine(hFile, sLine, sizeof(sLine)) )
			{
				start = StrContains(sLine, "scripts/melee/", false);
				if( start != -1 )
				{
					last = StrContains(sLine[start + 14], ".txt", false);
					sLine[start + 14 + last] = 0;
					g_alMeleeCustoms.PushString(sLine[start + 14]);
				}
			}

			delete hFile;
		}
	}
}

void LoadConfig()
{
	g_alMissionData = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
	g_alWeaponsData = new ArrayList();
	int pos;



	// ==========
	// Mission config
	// ==========
	g_iSectionMission = 1;
	BuildPath(Path_SM, g_sConfigMission, sizeof(g_sConfigMission), CONFIG_MISSION);
	pos = StrContains(g_sConfigMission, ".cfg");

	if( pos != -1 )
	{
		g_sConfigMission[pos] = 0;
		Format(g_sConfigMission, sizeof(g_sConfigMission), "%s.%s.cfg", g_sConfigMission, g_sGameMode);
	}

	// Check for gamemode config
	if( FileExists(g_sConfigMission) )
	{
		ParseConfigFile(g_sConfigMission);
	}
	else
	{
		// Load normal config
		BuildPath(Path_SM, g_sConfigMission, sizeof(g_sConfigMission), CONFIG_MISSION);
		if( FileExists(g_sConfigMission) )
		{
			g_bGameMode = false;
			ParseConfigFile(g_sConfigMission);

			g_bGameMode = true;
			ParseConfigFile(g_sConfigMission);

			g_bGameMode = false;
		}
	}



	// ==========
	// Weapons config
	// ==========
	g_iSectionMission = 0;

	BuildPath(Path_SM, g_sConfigWeapons, sizeof(g_sConfigWeapons), CONFIG_WEAPONS);
	pos = StrContains(g_sConfigWeapons, ".cfg");
	if( pos != -1 )
	{
		g_sConfigWeapons[pos] = 0;
		Format(g_sConfigWeapons, sizeof(g_sConfigWeapons), "%s.%s.cfg", g_sConfigWeapons, g_sGameMode);
	}

	// Check for gamemode config
	if( FileExists(g_sConfigWeapons) )
	{
		ParseConfigFile(g_sConfigWeapons);
	}
	else
	{
		// Load normal config
		BuildPath(Path_SM, g_sConfigWeapons, sizeof(g_sConfigWeapons), CONFIG_WEAPONS);
		if( FileExists(g_sConfigWeapons) )
		{
			g_bGameMode = false;
			ParseConfigFile(g_sConfigWeapons);

			g_bGameMode = true;
			ParseConfigFile(g_sConfigWeapons);

			g_bGameMode = false;
		}
	}
}

void ParseConfigFile(const char[] file)
{
	// Load parser and set hook functions
	SMCParser parser = new SMCParser();
	SMC_SetReaders(parser, Config_NewSection, Config_KeyValue, Config_EndSection);
	parser.OnEnd = Config_End;

	// Log errors detected in config
	char error[128];
	int line, col;
	SMCError result = parser.ParseFile(file, line, col);

	if( result != SMCError_Okay )
	{
		if( parser.GetErrorString(result, error, sizeof(error)) )
		{
			SetFailState("%s on line %d, col %d of %s [%d]", error, line, col, file, result);
		}
		else
		{
			SetFailState("Unable to load config. Bad format? Check for missing { } etc.");
		}
	}

	delete parser;
	// return (result == SMCError_Okay);
}

SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	g_iSectionLevel++;

	if( g_iSectionLevel == 2 )
	{
		g_bAllowSection = false;

		if( strcmp(section, "all") == 0 )
		{
			g_bAllowSection = true;
		} else {
			if( g_bGameMode )
			{
				if( strcmp(section, g_sGameMode) == 0 )
				{
					g_bAllowSection = true;
				}
			}
			else
			{
				char sMap[PLATFORM_MAX_PATH];
				GetCurrentMap(sMap, sizeof(sMap));

				if( StrContains(section, ",") != -1 )
				{
					int index, last;
					int len = strlen(section) + 2;
					char[] newSection = new char [len];
					StrCat(newSection, len, section);
					StrCat(newSection, len, ",");

					while( (index = StrContains(newSection[last], ",")) != -1 )
					{
						newSection[last + index] = 0;
						if( StrContains(sMap, newSection[last], false) != -1 )
						{
							g_bAllowSection = true;
							break;
						}
						newSection[last + index] = ',';
						last += index + 1;
					}
				}
				else if( StrContains(sMap, section, false) != -1 )
				{
					g_bAllowSection = true;
				}
			}
		}
	}

	if( g_bAllowSection && g_iSectionMission == 0 && g_iSectionLevel == 3 )
	{
		int lens = g_alWeaponsData.Length;

		bool pushData = true;
		ArrayList aHand;
		char value[64];

		g_iValueIndex = 1;

		// Loop through sections
		for( int x = 0; x < lens; x++ )
		{
			aHand = g_alWeaponsData.Get(x);
			aHand.GetString(0, value, sizeof(value));

			// Already exists
			if( strcmp(value, section) == 0 )
			{
				pushData = false;
				break;
			}

			g_iValueIndex++;
		}

		// Doesn't exist, push into weapons array
		if( pushData )
		{
			aHand = new ArrayList(ByteCountToCells(MAX_STRING_LENGTH));
			aHand.PushString(section);
			g_alWeaponsData.Push(aHand);
		}
	}

	return SMCParse_Continue;
}

SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	// 2 = Mission
	// 3 = Weapons
	if( g_bAllowSection )
	{
		if( (g_iSectionMission && g_iSectionLevel == 2) || g_iSectionLevel == 3 )
		{
			ArrayList aHand;

			// Mission Data
			if( g_iSectionMission )
			{
				aHand = g_alMissionData;

				// Remove duplicates (map specific overriding 'all' section)
				int index = aHand.FindString(key);
				if( index != -1 )
				{
					aHand.Erase(index);
					aHand.Erase(index);
				}

				aHand.PushString(key);
				aHand.PushString(value);

			// Weapon Data
			} else {
				aHand = g_alWeaponsData.Get(g_iValueIndex - 1);

				int index = aHand.FindString(key);
				if( index == -1 )
				{
					aHand.PushString(key);
					aHand.PushString(value);
				} else {
					aHand.SetString(index + 1, value);
				}
			}
		}
	}
	return SMCParse_Continue;
}

SMCResult Config_EndSection(Handle parser)
{
	g_iSectionLevel--;
	return SMCParse_Continue;
}

void Config_End(Handle parser, bool halted, bool failed)
{
	if( failed )
		SetFailState("Error: Cannot load the Info Editor config.");
}