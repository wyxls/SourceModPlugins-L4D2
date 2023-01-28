#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo =
{
	name = "L4D2 Survivor Bot Fix",
	author = "DingbatFlat",
	description = "Survivor Bot Fix. Improve Survivor Bot",
	version = "1.00",
	url = ""
}

/*
// ====================================================================================================

About:

- Main items that can be improve bots by introducing this plugin.

Help a pinning Survivor.
Attack a Common Infected.
Attack a Special Infected.
Attack a Tank.
Bash a flying Hunter and Jockey.
Shoot a tank rock.
Shoot a Witch (Contronls the attack timing when have a shotgun).
Restrict switching to the sub weapon.

And the action during incapacitated.


- Sourcemod ver 1.10 is required.



// ====================================================================================================

How to use:

Make sure "sb_fix_enabled" in the CVars is 1.


- Select the improved bot with the following CVar.

If "sb_fix_select_type" is 0, It is always enabled.

If "sb_fix_select_type" is 1, the number of people set in "sb_fix_select_number" will be randomly select.

If "sb_fix_select_type" is 2, Select the bot of the character entered in "sb_fix_select_character_name".


- For 1 and 2, bots that improve after left the safe room are selected.



// ====================================================================================================

Change Log:

1.00 (09-September-2021)
    - Initial release.



// ====================================================================================================


// It is difficult to improve the movement operation.
// This is the limit of my power and I can't add any further improvement points maybe... so arrange as you like.
*/

#define SOUND_SELECT "level/gnomeftw.wav"
#define SOUND_SWING	"ui/pickup_guitarriff10.wav"

#define BUFSIZE			(1 << 12)	// 4k

#define ZC_SMOKER       1
#define ZC_BOOMER       2
#define ZC_HUNTER       3
#define ZC_SPITTER      4
#define ZC_JOCKEY       5
#define ZC_CHARGER      6
#define ZC_TANK         8

#define MAXPLAYERS1     (MAXPLAYERS+1)
#define MAXENTITIES 2048

#define WITCH_INCAPACITATED 1
#define WITCH_KILLED 2

/****************************************************************************************************/

// ====================================================================================================
// Handle
// ====================================================================================================
new Handle:sb_fix_enabled				= INVALID_HANDLE;
new Handle:sb_fix_select_type			= INVALID_HANDLE;
new Handle:sb_fix_select_number		= INVALID_HANDLE;
new Handle:sb_fix_select_character_name	= INVALID_HANDLE;

new Handle:sb_fix_dont_switch_secondary	= INVALID_HANDLE;

new Handle:sb_fix_help_enabled			= INVALID_HANDLE;
new Handle:sb_fix_help_range			= INVALID_HANDLE;
new Handle:sb_fix_help_shove_type		= INVALID_HANDLE;
new Handle:sb_fix_help_shove_reloading	= INVALID_HANDLE;

new Handle:sb_fix_ci_enabled			= INVALID_HANDLE;
new Handle:sb_fix_ci_range				= INVALID_HANDLE;
new Handle:sb_fix_ci_melee_allow		= INVALID_HANDLE;
new Handle:sb_fix_ci_melee_range		= INVALID_HANDLE;

new Handle:sb_fix_si_enabled			= INVALID_HANDLE;
new Handle:sb_fix_si_range				= INVALID_HANDLE;
new Handle:sb_fix_si_ignore_boomer		= INVALID_HANDLE;
new Handle:sb_fix_si_ignore_boomer_range	= INVALID_HANDLE;

new Handle:sb_fix_tank_enabled			= INVALID_HANDLE;
new Handle:sb_fix_tank_range			= INVALID_HANDLE;

new Handle:sb_fix_si_tank_priority_type	= INVALID_HANDLE;

new Handle:sb_fix_bash_enabled			= INVALID_HANDLE;
new Handle:sb_fix_bash_hunter_chance	= INVALID_HANDLE;
new Handle:sb_fix_bash_hunter_range	= INVALID_HANDLE;
new Handle:sb_fix_bash_jockey_chance	= INVALID_HANDLE;
new Handle:sb_fix_bash_jockey_range		= INVALID_HANDLE;

new Handle:sb_fix_rock_enabled			= INVALID_HANDLE;
new Handle:sb_fix_rock_range			= INVALID_HANDLE;

new Handle:sb_fix_witch_enabled		= INVALID_HANDLE;
new Handle:sb_fix_witch_range			= INVALID_HANDLE;
new Handle:sb_fix_witch_range_incapacitated	= INVALID_HANDLE;
new Handle:sb_fix_witch_range_killed		= INVALID_HANDLE;
new Handle:sb_fix_witch_shotgun_control	= INVALID_HANDLE;
new Handle:sb_fix_witch_shotgun_range_max	= INVALID_HANDLE;
new Handle:sb_fix_witch_shotgun_range_min	= INVALID_HANDLE;

new Handle:sb_fix_prioritize_ownersmoker	= INVALID_HANDLE;

new Handle:sb_fix_incapacitated_enabled	= INVALID_HANDLE;

new Handle:sb_fix_debug				= INVALID_HANDLE;

// ====================================================================================================
// SendProp
// ====================================================================================================
new g_Velo = -1;
new g_ActiveWeapon = -1;
new g_iAmmoOffset = -1;

// ====================================================================================================
// Variables
// ====================================================================================================
new bool:g_hEnabled;
new c_iSelectType;
new c_iSelectNumber;

new bool:c_bDontSwitchSecondary;

new bool:c_bHelp_Enabled;
new Float:c_fHelp_Range;
new c_iHelp_ShoveType;
new bool:c_bHelp_ShoveOnlyReloading;

new bool:c_bCI_Enabled;
new Float:c_fCI_Range;
new bool:c_bCI_MeleeEnabled;
new Float:c_fCI_MeleeRange;

new bool:c_bSI_Enabled;
new Float:c_fSI_Range;
new bool:c_bSI_IgnoreBoomer;
new Float:c_fSI_IgnoreBoomerRange;

new bool:c_bTank_Enabled;
new Float:c_fTank_Range;

new c_iSITank_PriorityType;

new bool:c_bBash_Enabled;
new c_iBash_HunterChance;
new Float:c_fBash_HunterRange;
new c_iBash_JockeyChance;
new Float:c_fBash_JockeyRange;

new bool:c_bRock_Enabled;
new Float:c_fRock_Range;

new bool:c_bWitch_Enabled;
new Float:c_fWitch_Range;
new Float:c_fWitch_Range_Incapacitated;
new Float:c_fWitch_Range_Killed;
new bool:c_bWitch_Shotgun_Control;
new Float:c_fWitch_Shotgun_Range_Max;
new Float:c_fWitch_Shotgun_Range_Min;

new bool:c_bPrioritize_OwnerSmoker;

new bool:c_bIncapacitated_Enabled;

new bool:c_bDebug_Enabled;

// ====================================================================================================
// Int Array
// ====================================================================================================
new g_iWitch_Process[MAXENTITIES];

new g_Stock_NextThinkTick[MAXPLAYERS1];

// ====================================================================================================
// Bool Array
// ====================================================================================================
new bool:g_bFixTarget[MAXPLAYERS1];

new bool:g_bDanger[MAXPLAYERS1] = false;

new bool:g_bWitchActive = false;

new bool:g_bCommonWithinMelee[MAXPLAYERS1] = false;
new bool:g_bShove[MAXPLAYERS1][MAXPLAYERS1];

// ====================================================================================================
// Round
// ====================================================================================================
new bool:LeftSafeRoom = false;
new bool:TimerAlreadyWorking = false;

/****************************************************************************************************/

new bool:bLateLoad = false;

public APLRes:AskPluginLoad2(Handle:plugin, bool:late, String:error[], errMax)
{
	bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	// Notes:
	// If "~_enabled" of the group is not set to 1, other Cvars in that group will not work.
	// If the plugin is too heavy, Try disable searching for "Entities" other than Client. (CI, Witch and tank rock)
	
	// ---------------------------------
	sb_fix_enabled				= CreateConVar("sb_fix_enabled", "1", "Enable the plugin. <0: Disable, 1: Enable>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// ---------------------------------
	sb_fix_select_type				= CreateConVar("sb_fix_select_type", "0", "Which survivor bots to improved. <0: All, 1: Randomly select X people when left the safe area, 2: Enter the character name of the survivor bot to improve in \"sb_fix_select_character_name\">", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	sb_fix_select_number			= CreateConVar("sb_fix_select_number", "1", "If \"sb_fix_select_type\" is 1, Enter the number of survivor bots. <0 ~ 4>", FCVAR_NOTIFY, true, 0.0);
	sb_fix_select_character_name	= CreateConVar("sb_fix_select_character_name", "", "If \"sb_fix_select_type\" is 4, Enter the character name to improved. Separate with spaces. Example: \"nick francis bill\"", FCVAR_NOTIFY); // "coach ellis rochelle nick louis francis zoey bill"
	// ---------------------------------
	sb_fix_dont_switch_secondary	= CreateConVar("sb_fix_dont_switch_secondary", "1", "Disallow switching to the secondary weapon until the primary weapon is out of ammo. <0:No, 1:Yes | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// ---------------------------------
	sb_fix_help_enabled			= CreateConVar("sb_fix_help_enabled", "1", "Help a pinning survivor. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_help_range				= CreateConVar("sb_fix_help_range", "1200", "Range to shoot/search a pinning survivor. <1 ~ 3000 | def: 1200>", FCVAR_NOTIFY, true, 1.0, true, 3000.0);
	sb_fix_help_shove_type			= CreateConVar("sb_fix_help_shove_type", "2", "Whether to help by shove. <0: Not help by shove, 1: Smoker only, 2: Smoker and Jockey, 3: Smoker, Jockey and Hunter | def: 2>", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	sb_fix_help_shove_reloading		= CreateConVar("sb_fix_help_shove_reloading", "0", "If \"sb_fix_help_shove_type\" is 2 or more, it is shove only while reloading. <0: No, 1: Yes | def: 0>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// ---------------------------------
	sb_fix_ci_enabled				= CreateConVar("sb_fix_ci_enabled", "1", "Deal with Common Infecteds. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_ci_range				= CreateConVar("sb_fix_ci_range", "500", "Range to shoot/search a Common Infected. <1 ~ 2000 | def: 500>", FCVAR_NOTIFY, true, 1.0, true, 2000.0);
	sb_fix_ci_melee_allow			= CreateConVar("sb_fix_ci_melee_allow", "1", "Allow to deal with the melee weapon. <0: Disable 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_ci_melee_range			= CreateConVar("sb_fix_ci_melee_range", "160", "If \"sb_fix_ci_melee_allow\" is enabled, range to deal with the melee weapon. <1 ~ 500 | def: 160>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	// ---------------------------------
	sb_fix_si_enabled				= CreateConVar("sb_fix_si_enabled", "1", "Deal with Special Infecteds. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_si_range				= CreateConVar("sb_fix_si_range", "500", "Range to shoot/search a Special Infected. <1 ~ 3000 | def: 500>", FCVAR_NOTIFY, true, 1.0, true, 3000.0);
	sb_fix_si_ignore_boomer		= CreateConVar("sb_fix_si_ignore_boomer", "1", "Ignore a Boomer near Survivors (and shove a Boomer). <0: No, 1: Yes | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_si_ignore_boomer_range	= CreateConVar("sb_fix_si_ignore_boomer_range", "200", "Range to ignore a Boomer. <1 ~ 900 | def: 200>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	// ---------------------------------
	sb_fix_tank_enabled			= CreateConVar("sb_fix_tank_enabled", "1", "Deal with Tanks. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_tank_range				= CreateConVar("sb_fix_tank_range", "1200", "Range to shoot/search a Tank. <1 ~ 3000 | def: 1200>", FCVAR_NOTIFY, true, 1.0, true, 3000.0);
	// ---------------------------------
	sb_fix_si_tank_priority_type		= CreateConVar("sb_fix_si_tank_priority_type", "0", "When a Special Infected and a Tank is together within the specified range, which to prioritize. <0: Nearest, 1: Special Infected, 2: Tank | def: 0>", FCVAR_NOTIFY, true, 0.0, true, 2.0);
	// ---------------------------------
	sb_fix_bash_enabled			= CreateConVar("sb_fix_bash_enabled", "1", "Bash a flying Hunter or Jockey. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_bash_hunter_chance		= CreateConVar("sb_fix_bash_hunter_chance", "100", "Chance of bash a flying Hunter. (Even 100 doesn't can perfectly shove). <1 ~ 100 | def: 100>", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	sb_fix_bash_hunter_range		= CreateConVar("sb_fix_bash_hunter_range", "145", "Range to bash/search a flying Hunter. <1 ~ 500 | def: 145>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	sb_fix_bash_jockey_chance		= CreateConVar("sb_fix_bash_jockey_chance", "100", "Chance of bash a flying Jockey. (Even 100 doesn't can perfectly shove). <1 ~ 100 | def: 100>", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	sb_fix_bash_jockey_range		= CreateConVar("sb_fix_bash_jockey_range", "125", "Range to bash/search a flying Jockey. <1 ~ 500 | def: 125>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	// ---------------------------------
	sb_fix_rock_enabled			= CreateConVar("sb_fix_rock_enabled", "1", "Shoot a tank rock. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_rock_range				= CreateConVar("sb_fix_rock_range", "700", "Range to shoot/search a tank rock. <1 ~ 2000 | def: 700>", FCVAR_NOTIFY, true, 1.0, true, 2000.0);
	// ---------------------------------
	sb_fix_witch_enabled			= CreateConVar("sb_fix_witch_enabled", "1", "Shoot a rage Witch. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_witch_range				= CreateConVar("sb_fix_witch_range", "1500", "Range to shoot/search a rage Witch. <1 ~ 2000 | def: 1500>", FCVAR_NOTIFY, true, 1.0, true, 2000.0);
	sb_fix_witch_range_incapacitated	= CreateConVar("sb_fix_witch_range_incapacitated", "1000", "Range to shoot/search a Witch that incapacitated a survivor. <0 ~ 2000 | def: 1000>", FCVAR_NOTIFY, true, 0.0, true, 2000.0);
	sb_fix_witch_range_killed		= CreateConVar("sb_fix_witch_range_killed", "0", "Range to shoot/search a Witch that killed a survivor. <0 ~ 2000 | def: 0>", FCVAR_NOTIFY, true, 0.0, true, 2000.0);
	sb_fix_witch_shotgun_control	= CreateConVar("sb_fix_witch_shotgun_control", "1", "[Witch] If have the shotgun, controls the attack timing. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	sb_fix_witch_shotgun_range_max	= CreateConVar("sb_fix_witch_shotgun_range_max", "300", "If a Witch is within distance of the values, stop the attack. <1 ~ 1000 | def: 300>", FCVAR_NOTIFY, true, 1.0, true, 1000.0);
	sb_fix_witch_shotgun_range_min	= CreateConVar("sb_fix_witch_shotgun_range_min", "70", "If a Witch is at distance of the values or more, stop the attack. <1 ~ 500 | def: 70>", FCVAR_NOTIFY, true, 1.0, true, 500.0);
	// ---------------------------------
	sb_fix_prioritize_ownersmoker	= CreateConVar("sb_fix_prioritize_ownersmoker", "1", "Priority given to dealt a Smoker that is try to pinning self. <0: No, 1: Yes | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// ---------------------------------
	sb_fix_incapacitated_enabled		= CreateConVar("sb_fix_incapacitated_enabled", "1", "Enable Incapacitated Cmd. <0: Disable, 1: Enable | def: 1>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	// ---------------------------------
	sb_fix_debug					= CreateConVar("sb_fix_debug", "0", "[For debug] Print the action status. <0:Disable, 1:Enable>", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	
	HookConVarChange(sb_fix_help_enabled, SBHelp_ChangeConvar);
	HookConVarChange(sb_fix_help_range, SBHelp_ChangeConvar);
	HookConVarChange(sb_fix_help_shove_type, SBHelp_ChangeConvar);
	HookConVarChange(sb_fix_help_shove_reloading, SBHelp_ChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_ci_enabled, SBCI_ChangeConvar);
	HookConVarChange(sb_fix_ci_range, SBCI_ChangeConvar);
	HookConVarChange(sb_fix_ci_melee_allow, SBCI_ChangeConvar);
	HookConVarChange(sb_fix_ci_melee_range, SBCI_ChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_si_enabled, SBSI_ChangeConvar);
	HookConVarChange(sb_fix_si_range, SBSI_ChangeConvar);
	HookConVarChange(sb_fix_si_ignore_boomer, SBSI_ChangeConvar);
	HookConVarChange(sb_fix_si_ignore_boomer_range, SBSI_ChangeConvar)
	// ---------------------------------
	HookConVarChange(sb_fix_tank_enabled, SBTank_ChangeConvar);
	HookConVarChange(sb_fix_tank_range, SBTank_ChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_si_tank_priority_type, SBTank_ChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_bash_enabled, SBBash_ChangeConvar);
	HookConVarChange(sb_fix_bash_hunter_chance, SBBash_ChangeConvar);
	HookConVarChange(sb_fix_bash_hunter_range, SBBash_ChangeConvar);
	HookConVarChange(sb_fix_bash_jockey_chance, SBBash_ChangeConvar);
	HookConVarChange(sb_fix_bash_jockey_range, SBBash_ChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_rock_enabled, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_rock_range, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_enabled, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_range, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_range_incapacitated, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_range_killed, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_shotgun_control, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_shotgun_range_max, SBEnt_ChangeConvar);
	HookConVarChange(sb_fix_witch_shotgun_range_min, SBEnt_ChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_enabled, SBConfigChangeConvar);
	HookConVarChange(sb_fix_select_type, SBConfigChangeConvar);
	HookConVarChange(sb_fix_select_number, SBConfigChangeConvar);
	HookConVarChange(sb_fix_dont_switch_secondary, SBConfigChangeConvar);
	HookConVarChange(sb_fix_prioritize_ownersmoker, SBConfigChangeConvar);
	HookConVarChange(sb_fix_incapacitated_enabled, SBConfigChangeConvar);
	HookConVarChange(sb_fix_debug, SBConfigChangeConvar);
	// ---------------------------------
	HookConVarChange(sb_fix_select_type, SBSelectChangeConvar);
	HookConVarChange(sb_fix_select_number, SBSelectChangeConvar);
	HookConVarChange(sb_fix_select_character_name, SBSelectChangeConvar);
	
	if (bLateLoad) {
		for (new x = 1; x <= MaxClients; x++) {
			if (x > 0 && x <= MaxClients && IsClientInGame(x)) {
				SDKHook(x, SDKHook_WeaponSwitch, WeaponSwitch);
			}
		}
	}
	
	AutoExecConfig(false, "l4d2_sb_fix");
	
	PrefetchSound(SOUND_SELECT);
	PrecacheSound(SOUND_SELECT);
	PrefetchSound(SOUND_SWING);
	PrecacheSound(SOUND_SWING);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("bot_player_replace", Event_BotAndPlayerReplace, EventHookMode_Pre); // SelectImprovedTarget
	
	HookEvent("player_incapacitated", Event_PlayerIncapacitated); // Witch Event
	HookEvent("player_death", Event_PlayerDeath); // Witch Event
	
	HookEvent("witch_harasser_set", Event_WitchRage);
	
	g_Velo = FindSendPropInfo("CBasePlayer", "m_vecVelocity[0]");
	g_ActiveWeapon = FindSendPropInfo("CBasePlayer", "m_hActiveWeapon");
	g_iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	CreateTimer(3.0, Timer_ShoveChance, _, TIMER_REPEAT);
	
	InitTimers(); // Safe Room Check
}

public OnMapStart()
{
	input_Help();
	input_CI();
	input_SI();
	input_Tank();
	input_Bash();
	input_Entity();
	inputConfig();
}

public OnAllPluginsLoaded()
{
	input_Help();
	input_CI();
	input_SI();
	input_Tank();
	input_Bash();
	input_Entity();
	inputConfig();
}

public SBHelp_ChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[])	{ input_Help(); }
public SBCI_ChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[])	{ input_CI(); }
public SBSI_ChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[])	{ input_SI(); }
public SBTank_ChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[])	{ input_Tank(); }
public SBBash_ChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[])	{ input_Bash(); }
public SBEnt_ChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[])	{ input_Entity(); }

public SBConfigChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[]) { inputConfig(); }

public SBSelectChangeConvar(Handle:convar, const String:oldValue[], const String:newValue[]) { SelectImprovedTarget(); }

input_Help()
{
	c_bHelp_Enabled = GetConVarBool(sb_fix_help_enabled);
	c_fHelp_Range = GetConVarInt(sb_fix_help_range) * 1.0;
	c_iHelp_ShoveType = GetConVarInt(sb_fix_help_shove_type);
	c_bHelp_ShoveOnlyReloading = GetConVarBool(sb_fix_help_shove_reloading);
}
input_CI()
{
	c_bCI_Enabled = GetConVarBool(sb_fix_ci_enabled);
	c_fCI_Range = GetConVarInt(sb_fix_ci_range) * 1.0;
	c_bCI_MeleeEnabled = GetConVarBool(sb_fix_ci_melee_allow);
	c_fCI_MeleeRange = GetConVarInt(sb_fix_ci_melee_range) * 1.0;
}
input_SI()
{
	c_bSI_Enabled = GetConVarBool(sb_fix_si_enabled);
	c_fSI_Range = GetConVarInt(sb_fix_si_range) * 1.0;
	c_bSI_IgnoreBoomer = GetConVarBool(sb_fix_si_ignore_boomer);
	c_fSI_IgnoreBoomerRange = GetConVarInt(sb_fix_si_ignore_boomer_range) * 1.0;
}
input_Tank()
{
	c_bTank_Enabled = GetConVarBool(sb_fix_tank_enabled);
	c_fTank_Range = GetConVarInt(sb_fix_tank_range) * 1.0;
	
	c_iSITank_PriorityType = GetConVarInt(sb_fix_si_tank_priority_type);
}
input_Bash()
{
	c_bBash_Enabled = GetConVarBool(sb_fix_bash_enabled);
	c_iBash_HunterChance = GetConVarInt(sb_fix_bash_hunter_chance);
	c_fBash_HunterRange = GetConVarInt(sb_fix_bash_hunter_range) * 1.0;
	c_iBash_JockeyChance = GetConVarInt(sb_fix_bash_jockey_chance);
	c_fBash_JockeyRange = GetConVarInt(sb_fix_bash_jockey_range) * 1.0;
}
input_Entity()
{
	c_bRock_Enabled = GetConVarBool(sb_fix_rock_enabled);
	c_fRock_Range = GetConVarInt(sb_fix_rock_range) * 1.0;
	
	c_bWitch_Enabled = GetConVarBool(sb_fix_witch_enabled);
	c_fWitch_Range = GetConVarInt(sb_fix_witch_range) * 1.0;
	c_fWitch_Range_Incapacitated = GetConVarInt(sb_fix_witch_range_incapacitated) * 1.0;
	c_fWitch_Range_Killed = GetConVarInt(sb_fix_witch_range_killed) * 1.0;
	c_bWitch_Shotgun_Control = GetConVarBool(sb_fix_witch_shotgun_control);
	c_fWitch_Shotgun_Range_Max = GetConVarInt(sb_fix_witch_shotgun_range_max) * 1.0;
	c_fWitch_Shotgun_Range_Min = GetConVarInt(sb_fix_witch_shotgun_range_min) * 1.0;
}

inputConfig()
{
	g_hEnabled = GetConVarBool(sb_fix_enabled);
	c_iSelectType = GetConVarInt(sb_fix_select_type);
	c_iSelectNumber = GetConVarInt(sb_fix_select_number);
	
	c_bDontSwitchSecondary = GetConVarBool(sb_fix_dont_switch_secondary);
	
	c_bPrioritize_OwnerSmoker = GetConVarBool(sb_fix_prioritize_ownersmoker);
	
	c_bIncapacitated_Enabled = GetConVarBool(sb_fix_incapacitated_enabled);
	
	c_bDebug_Enabled = GetConVarBool(sb_fix_debug);
}


/****************************************************************************************************/


/* ================================================================================================
*=
*=		Round / Start Ready / Select Improved Targets
*=
================================================================================================ */
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new x = 1; x <= MAXPLAYERS; x++) g_bFixTarget[x] = false; // RESET
	
	LeftSafeRoom = false;
	
	
	if (!TimerAlreadyWorking) {
		CreateTimer(1.0, Timer_PlayerLeftCheck);
		TimerAlreadyWorking = true;
	}
	
	InitTimers();
}

public Action:Event_BotAndPlayerReplace(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!LeftSafeRoom) return;
	
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	if (g_bFixTarget[bot]) {
		SelectImprovedTarget();
	}
}

InitTimers()
{
	if (LeftSafeRoom)
		SelectImprovedTarget();
	else if (!TimerAlreadyWorking)
	{
		TimerAlreadyWorking = true;
		CreateTimer(1.0, Timer_PlayerLeftCheck);
	}
}

public Action:Timer_PlayerLeftCheck(Handle:Timer)
{
	if (LeftStartArea())
	{
		if (!LeftSafeRoom) {
			LeftSafeRoom = true;
			SelectImprovedTarget();
			// PrintToChatAll("[sb_fix] Survivors left the safe area.");
		}
		
		TimerAlreadyWorking = false;
	}
	else
	{
		CreateTimer(1.0, Timer_PlayerLeftCheck);
	}
	return Plugin_Continue; 
}

bool:LeftStartArea()
{
	new ent = -1, maxents = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		new offset = FindSendPropInfo("CTerrorPlayerResource", "m_hasAnySurvivorLeftSafeArea");
		if (offset > 0)
		{
			if (GetEntData(ent, offset))
			{
				if (GetEntData(ent, offset) == 1) return true;
			}
		}
	}
	return false;
}

SelectImprovedTarget()
{
	// PrintToChatAll("type %i, leftsaferoom %b", c_iSelectType, LeftSafeRoom);
	
	if (!g_hEnabled || !LeftSafeRoom) return; // Select targets when left the safe area.
	
	EmitSoundToAll(SOUND_SELECT, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5); // Selected Sound
	
	decl String:bufferChat[512];
	decl String:bufferHintText[512];
	Format(bufferChat, 512, "\x05[sb_fix] \x01Improved targets:");
	Format(bufferHintText, 512, "[sb_fix] Improved targets:");
	
	if (c_iSelectType == 0) {
		//PrintToChatAll("\x04Type0 - ALL bots");
		Format(bufferChat, 512, "%s\x04\nType0 - ALL bots", bufferChat);
		Format(bufferHintText, 512, "%s\nType0 - ALL bots", bufferHintText);
	}
	else if (c_iSelectType == 1) {
		//PrintToChatAll("\x04Type1 - %d bot%s", c_iSelectNumber, (c_iSelectNumber == 1) ? "" : "s");
		Format(bufferChat, 512, "%s\x04\nType1 - %d bot%s", bufferChat, c_iSelectNumber, (c_iSelectNumber == 1) ? "" : "s");
		Format(bufferHintText, 512, "%s\nType1 - %d bot%s", bufferHintText, c_iSelectNumber, (c_iSelectNumber == 1) ? "" : "s");
		
		new count;
		for (new x = 1; x <= MaxClients; x++) {
			if (isSurvivorBot(x)) {
				g_bFixTarget[x] = true;
				count++
				//PrintToChatAll("\x04(%d/%d)\x05. %N", count, c_iSelectNumber, x);
				Format(bufferChat, 512, "%s\x04\n(%d/%d)\x05. %N", bufferChat, count, c_iSelectNumber, x);
				Format(bufferHintText, 512, "%s%s(%d/%d). %N", bufferHintText, (count == 1) ? "\n" : ", ", count, c_iSelectNumber, x);
			}
			
			if (count >= c_iSelectNumber) { break; }
		}
	}
	else if (c_iSelectType == 2)
	{
		decl String:sSelectName[256];
		GetConVarString(sb_fix_select_character_name, sSelectName, sizeof(sSelectName));
		
		//PrintToChatAll("\x04Type2 - \"%s\"", sSelectName);
		Format(bufferChat, 512, "%s\x04\nType2 - \"%s\"", bufferChat, sSelectName);
		Format(bufferHintText, 512, "%s\nType2 - \"%s\"", bufferHintText, sSelectName);
		
		new count;
		for (new x = 1; x <= MaxClients; x++) {
			if (isSurvivorBot(x)) {
				new String:sName[128];
				GetClientName(x, sName, sizeof(sName));
				
				if (StrContains(sSelectName, sName, false) != -1) {
					g_bFixTarget[x] = true;
					count++;
					//PrintToChatAll("\x04%d\x05. %N", count, x);
					Format(bufferChat, 512, "%s\x04\n%d\x05. %N", bufferChat, count, x);
					Format(bufferHintText, 512, "%s%s%d. %N", bufferHintText, (count == 1) ? "\n" : ", ", count, x);
				} else {
					g_bFixTarget[x] = false;
				}
			}
			
		}
	}
	
	PrintToChatAll(bufferChat);
	PrintHintTextToAll(bufferHintText);
}

public Action:Timer_ShoveChance(Handle:Timer)
{
	// ----------------------- Bash Chance -----------------------
	if (c_iBash_HunterChance < 100 || c_iBash_JockeyChance < 100) {
		for (new sb = 1; sb <= MaxClients; sb++) {
			if (isSurvivorBot(sb) && IsPlayerAlive(sb)) {
				for (new x = 1; x <= MaxClients; x++) {
					if (isInfected(x) && IsPlayerAlive(x)) {
						new zombieClass = getZombieClass(x);
						if (zombieClass == ZC_HUNTER) {
							if (GetRandomInt(0, 100) <= c_iBash_HunterChance) g_bShove[sb][x] = true;
							else g_bShove[sb][x] = false;
							
							// PrintToChatAll("%N's Shove to %N: %b", sb, x, g_bShove[sb][x]);
						}
						else if (zombieClass == ZC_JOCKEY) {
							if (GetRandomInt(0, 100) <= c_iBash_JockeyChance) g_bShove[sb][x] = true;
							else g_bShove[sb][x] = false;
							
							// PrintToChatAll("%N's Shove to %N: %b", sb, x, g_bShove[sb][x]);
						}
					}
				}
			}
		}
	}
}


/****************************************************************************************************/


/* Client key input processing
 *
 * buttons: Entered keys (enum‚Íinclude/entity_prop_stock.incŽQÆ)

 * angles:
 *      [0]: pitch(UP-DOWN) -89~+89
 *      [1]: yaw(360) -180~+180
 */
 
 /*
 *		OnPlayerRunCmd is Runs 30 times per second. (every 0.03333... seconds)
 */
public Action:OnPlayerRunCmd(client, &buttons, &impulse,
	Float:vel[3], Float:angles[3], &weapon)
{
	if (g_hEnabled) {
		if (isSurvivorBot(client) && IsPlayerAlive(client)) {
			if ((c_iSelectType == 0) || (c_iSelectType >= 1 && g_bFixTarget[client])) {
				new Action:ret = Plugin_Continue;
				ret = onSBRunCmd(client, buttons, vel, angles);
				if (c_bIncapacitated_Enabled) ret = onSBRunCmd_Incapacitated(client, buttons, vel, angles);
				ret = onSBSlotActionCmd(client, buttons, vel, angles);
				
				return ret;
			}
		}
	}
	return Plugin_Continue;
}


/****************************************************************************************************/


/* ================================================================================================
*=
*=		Weapon Switch
*=
================================================================================================ */
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponSwitch, WeaponSwitch);
}
public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_WeaponSwitch, WeaponSwitch);
}
public Action:WeaponSwitch(client, weapon)
{
	if (!g_hEnabled) return Plugin_Continue;
	if (!isSurvivor(client) || !IsFakeClient(client) || !IsValidEntity(weapon)) return Plugin_Continue;
	if (isIncapacitated(client) || GetPlayerWeaponSlot(client, 0) == -1) return Plugin_Continue;
	
	new String:classname[128];
	GetEntityClassname(weapon, classname, sizeof(classname));
	
	if (isHaveItem(classname, "weapon_melee")
		|| isHaveItem(classname, "weapon_pistol") // Includes Magnum ("weapon_pistol_magnum")
		|| isHaveItem(classname, "weapon_dual_pistol"))
	{
		if (c_bDontSwitchSecondary) {
			new slot0 = GetPlayerWeaponSlot(client, 0);
			new clip, extra_ammo;
			clip = GetEntProp(slot0, Prop_Send, "m_iClip1");
			extra_ammo = PrimaryExtraAmmoCheck(client, slot0); // check
			
			//PrintToChatAll("[%N's] clip: %d, extra_ammo: %d", client, clip, extra_ammo);
			
			//if (!g_bCommonWithinMelee[client] && (clip != 0 || extra_ammo != 0)) PrintToChatAll("switch Stoped");
			
			if (clip == 0 && extra_ammo == 0) {
				PrintToChatAll("\x05[sb_fix] \x04%N\x01 ammo is now zero.", client);
			}
			
			if (!g_bCommonWithinMelee[client] && (clip != 0 || extra_ammo != 0)) return Plugin_Handled;
		}
	}
	else if (StrContains(classname, "first_aid_kit", false) > -1
		|| StrContains(classname, "defibrillator", false) > -1)
	{
		if (g_bDanger[client]) return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

stock Action:onSBSlotActionCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (!isIncapacitated(client) && GetPlayerWeaponSlot(client, 0) > -1) {
		new weapon = GetEntDataEnt2(client, g_ActiveWeapon);
		
		if (weapon <= 0) return Plugin_Continue;
		
		new String:classname[128];
		GetEntityClassname(weapon, classname, sizeof(classname));
		
		if (StrContains(classname, "weapon_melee", false) > -1
			|| StrContains(classname, "weapon_pistol", false) > -1
			|| StrContains(classname, "weapon_dual_pistol", false) > -1
			|| StrContains(classname, "weapon_pistol_magnum", false) > -1)
		{
			if (!g_bCommonWithinMelee[client]) {
				new String:main_weapon[128];
				GetEntityClassname(GetPlayerWeaponSlot(client, 0), main_weapon, sizeof(main_weapon));
				FakeClientCommand(client, "use %s", main_weapon);
			}
		} else if (StrContains(classname, "first_aid_kit", false) > -1
			|| StrContains(classname, "defibrillator", false) > -1)
		{
			if (g_bDanger[client]) {
				new String:main_weapon[128];
				GetEntityClassname(GetPlayerWeaponSlot(client, 0), main_weapon, sizeof(main_weapon));
				FakeClientCommand(client, "use %s", main_weapon);
			}
		}
	}
	return Plugin_Continue;
}


/****************************************************************************************************/


/* ================================================================================================
*=
*=		SB Run Cmd
*=
================================================================================================ */
stock Action:onSBRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (!isIncapacitated(client)
		&& GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		// Find a nearest visible Special Infected
		new new_target = -1;
		new Float:min_dist = 100000.0;
		new Float:self_pos[3], Float:target_pos[3];
		
		if ((c_bSI_Enabled || c_bTank_Enabled) && !NeedsTeammateHelp_ExceptSmoker(client)) {
			GetClientAbsOrigin(client, self_pos);
			for (new x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& !isIncapacitated(x)
					&& isVisibleTo(client, x))
				{
					new Float:dist;
					
					GetClientAbsOrigin(x, target_pos);
					dist = GetVectorDistance(self_pos, target_pos);
					
					new zombieClass = getZombieClass(x);
					if ((c_bSI_Enabled && zombieClass != ZC_TANK && dist <= c_fSI_Range)
						|| (c_bTank_Enabled && zombieClass == ZC_TANK && dist <= c_fTank_Range))
					{
						if ((c_iSITank_PriorityType == 1 && zombieClass != ZC_TANK)
							|| (c_iSITank_PriorityType == 2 && zombieClass == ZC_TANK)) {
							if (dist < min_dist) {
								min_dist = dist;
								new_target = x;
								continue;
							}
						}
						
						if (dist < min_dist) {
							min_dist = dist;
							new_target = x;
						}
					}
					
				}
			}
		}
		
		new aCap_Survivor = -1;
		new Float:min_dist_CapSur = 100000.0;
		new Float:target_pos_CapSur[3];
		
		new aCap_Infected = -1;
		new Float:min_dist_CapInf = 100000.0;
		new Float:target_pos_CapInf[3];
		
		if (c_bHelp_Enabled && !NeedsTeammateHelp_ExceptSmoker(client)) {
			// Find a Survivor who are pinned
			for (new x = 1; x <= MaxClients; ++x) {
				if (isSurvivor(x)
					&& NeedsTeammateHelp(x)
					&& (x != client)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					new Float:dist;
					
					GetClientAbsOrigin(x, target_pos_CapSur);
					dist = GetVectorDistance(self_pos, target_pos_CapSur);
					if (dist < c_fHelp_Range) {
						if (dist < min_dist_CapSur) {
							min_dist_CapSur = dist;
							aCap_Survivor = x;
						}
					}
				}
			}
			
			// Find a Special Infected who are pinning
			for (new x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& CappingSuvivor(x)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					new Float:dist;
					
					GetClientAbsOrigin(x, target_pos_CapInf);
					dist = GetVectorDistance(self_pos, target_pos_CapInf);
					if (dist < c_fHelp_Range) {
						if (dist < min_dist_CapInf) {
							min_dist_CapInf = dist;
							aCap_Infected = x;
						}
					}
				}
			}
		}
		
		/*
		// Find aCapSmoker
		new aCapSmoker = -1;
		new Float:min_dist_CapSmo = 100000.0;
		new Float:target_pos_CapSmo[3];
		
		for (new x = 1; x <= MaxClients; ++x) {
			if (isSpecialInfectedBot(x)
				&& IsPlayerAlive(x)
				&& HasValidEnt(x, "m_tongueVictim")
				&& isVisibleTo(client, x))
			{
				new Float:dist;
				
				GetClientAbsOrigin(x, target_pos_CapSmo);
				dist = GetVectorDistance(self_pos, target_pos_CapSmo);
				if (dist < 700.0) {
					if (dist < min_dist_CapSmo) {
						min_dist_CapSmo = dist;
						aCapSmoker = x;
					}
				}
			}
		}
		*/
		
		// Find a Smoker who is tongued self
		new aCapSmoker = -1;
		
		if (c_bPrioritize_OwnerSmoker) {
			new Float:min_dist_CapSmo = 100000.0;
			new Float:target_pos_CapSmo[3];
			
			for (new x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& HasValidEnt(x, "m_tongueVictim"))
				{
					if (GetEntPropEnt(x, Prop_Send, "m_tongueVictim") == client) {
						new Float:dist;
						
						GetClientAbsOrigin(x, target_pos_CapSmo);
						dist = GetVectorDistance(self_pos, target_pos_CapSmo);
						if (dist < 750.0) {
							if (dist < min_dist_CapSmo) {
								min_dist_CapSmo = dist;
								aCapSmoker = x;
							}
						}
					}
				}
			}
		}
		
		// Find a flying Hunter and Jockey
		new aHunterJockey = -1;
		new Float:hunjoc_pos[3];
		new Float:min_dist_HunJoc = 100000.0;
		
		if (c_bBash_Enabled && !NeedsTeammateHelp_ExceptSmoker(client)) {
			for (new x = 1; x <= MaxClients; ++x) {
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& !isStagger(x)
					&& isVisibleTo(client, x))
				{
					if (getZombieClass(x) == ZC_HUNTER) {
						if (c_iBash_HunterChance == 100 || (c_iBash_HunterChance < 100 && g_bShove[client][x])) {
							new Float:hunterVelocity[3];
							GetEntDataVector(x, g_Velo, hunterVelocity);
							if ((GetClientButtons(x) & IN_DUCK) && hunterVelocity[2] != 0.0) {
								GetClientAbsOrigin(x, hunjoc_pos);
							
								new Float:hundist;
								hundist = GetVectorDistance(self_pos, hunjoc_pos);
								
								if (hundist < c_fBash_HunterRange) { // 145.0 best
									if (hundist < min_dist_HunJoc) {
										min_dist_HunJoc = hundist;
										aHunterJockey = x;
									}
								}
							}
						}
					}
					else if (getZombieClass(x) == ZC_JOCKEY) {
						if (c_iBash_JockeyChance == 100 || (c_iBash_JockeyChance < 100 && g_bShove[client][x])) {
							new Float:jockeyVelocity[3];
							GetEntDataVector(x, g_Velo, jockeyVelocity);
							if (jockeyVelocity[2] != 0.0) {
								GetClientAbsOrigin(x, hunjoc_pos);
								
								new Float:jocdist;
								jocdist = GetVectorDistance(self_pos, hunjoc_pos);
								
								if (jocdist < c_fBash_JockeyRange) { // 125.0 best
									if (jocdist < min_dist_HunJoc) {
										min_dist_HunJoc = jocdist;
										aHunterJockey = x;
									}
								}
							}
						}
					}
				}
			}
		}
		
		// Find a Common Infected
		//new iMaxEntities = GetMaxEntities();
		new aCommonInfected = -1;
		new iCI_MeleeCount = 0;
		new Float:min_dist_CI = 100000.0;
		new Float:ci_pos[3];
		
		if (c_bCI_Enabled && !NeedsTeammateHelp(client)) {
			for (new iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity) {
				if (IsCommonInfected(iEntity)
					&& GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0
					&& isVisibleToEntity(iEntity, client))
				{
					new Float:dist;
					GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", ci_pos);
					dist = GetVectorDistance(self_pos, ci_pos);
					
					if (dist < c_fCI_Range) {
						new iSeq = GetEntProp(iEntity, Prop_Send, "m_nSequence", 2);
						// Stagger			122, 123, 126, 127, 128, 133, 134
						// Down Stagger		128, 129, 130, 131
						// Object Climb (Very Low)	182, 183, 184, 185
						// Object Climb (Low)	190, 191, 192, 193, 194, 195, 196, 197, 198, 199
						// Object Climb (High)	206, 207, 208, 209, 210, 211, 218, 219, 220, 221, 222, 223
						
						if ((iSeq <= 121) || (iSeq >= 135 && iSeq <= 189) || (iSeq >= 200 && iSeq <= 205) || (iSeq >= 224)) {
							if (dist < min_dist_CI) {
								min_dist_CI = dist;
								aCommonInfected = iEntity;
							}
						}
					}
					
					if (dist <= c_fCI_MeleeRange) { // ‚æ‚ë‚¯‚Ä‚Ä‚à MeleeCount ‚É‚Í“ü‚ê‚é
						iCI_MeleeCount += 1;
					}
					
				}
			}
		}
		
		// Fina a rage Witch
		new aWitch = -1;
		new Float:min_dist_Witch = 100000.0;
		new Float:witch_pos[3];
		if (g_bWitchActive && c_bWitch_Enabled && !NeedsTeammateHelp(client)) {
			for (new iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity)
			{
				if (IsWitch(iEntity)
					&& GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0
					&& IsWitchRage(iEntity)
					&& isVisibleToEntity(iEntity, client))
				{
					new Float:witch_dist;
					GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", witch_pos);
					witch_dist = GetVectorDistance(self_pos, witch_pos);
					
					if ((g_iWitch_Process[iEntity] == 0 && witch_dist < c_fWitch_Range)
						|| (g_iWitch_Process[iEntity] == WITCH_INCAPACITATED && witch_dist < c_fWitch_Range_Incapacitated)
						|| (g_iWitch_Process[iEntity] == WITCH_KILLED && witch_dist < c_fWitch_Range_Killed)) {
						if (witch_dist < min_dist_Witch) {
							min_dist_Witch = witch_dist;
							aWitch = iEntity;
						}
					}
				}
			}
		}
		
		// Find a tank rock
		new aTankRock = -1;
		new Float:rock_min_dist = 100000.0;
		new Float:rock_pos[3];
		if (c_bRock_Enabled && !NeedsTeammateHelp(client)) {
			for (new iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity)
			{
				if (IsTankRock(iEntity)
					&& isVisibleToEntity(iEntity, client))
				{
					new Float:rock_dist;
					GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", rock_pos);
					rock_dist = GetVectorDistance(self_pos, rock_pos);
					
					if (rock_dist < c_fRock_Range) {
						if (rock_dist < rock_min_dist) {
							rock_min_dist = rock_dist;
							aTankRock = iEntity;
						}
					}
				}
			}
		}
		
		
		
		/* -------------------------------------------------------------------------------------------------------------------------------------------------------------- 
		*****************************
		*		Get The Weapon		*
		*****************************
		--------------------------------------------------------------------------------------------------------------------------------------------------------------- */
		
		new weapon = GetEntDataEnt2(client, g_ActiveWeapon);
		
		new String:AW_Classname[256];
		if (weapon > MAXPLAYERS) GetEntityClassname(weapon, AW_Classname, sizeof(AW_Classname)); // Exception reported: Entity -1 (-1) is invalid
		
		new String:main_weapon[128];
		new slot0 = GetPlayerWeaponSlot(client, 0);
		if (slot0 > -1) {			
			GetEntityClassname(slot0, main_weapon, sizeof(main_weapon));
		}
		
		/* -------------------------------------------------------------------------------------------------------------------------------------------------------------- 
		**********************
		*		Action		 *
		**********************
		--------------------------------------------------------------------------------------------------------------------------------------------------------------- */
		
		/* ====================================================================================================
		*
		*  Other Adjustment
		*
		==================================================================================================== */ 
		if (g_bDanger[client]) { // If have the medkit even though it is dangerous, switch to the main weapon
			if (isHaveItem(AW_Classname, "first_aid_kit")) {
				if (main_weapon[1] != 0) {
					FakeClientCommand(client, "use %s", main_weapon);
				} else {
					new String:sub_weapon[128];
					new slot1 = GetPlayerWeaponSlot(client, 1);
					if (slot1 > -1) {			
						GetEntityClassname(slot1, sub_weapon, sizeof(sub_weapon)); // SubWeapon
					}
					
					FakeClientCommand(client, "use %s", main_weapon);
				}
			}
		}
		
		if (g_bCommonWithinMelee[client]) {
			if (aCommonInfected < 1) g_bCommonWithinMelee[client] = false;
			if (aCommonInfected > 0) {
				new Float:c_pos[3], Float:common_e_pos[3];
				
				GetClientAbsOrigin(client, c_pos);
				GetEntPropVector(aCommonInfected, Prop_Data, "m_vecOrigin", common_e_pos);
				
				new Float:aimdist = GetVectorDistance(c_pos, common_e_pos);
				
				if (aimdist > c_fCI_MeleeRange) g_bCommonWithinMelee[client] = false;
			}
		}
		
		
		
		/* ====================================================================================================
		*
		*   —Dæ“xA : Bash | flying Hunter, Jockey
		*
		==================================================================================================== */ 
		if (aHunterJockey > 0) {
			if (!g_bDanger[client]) g_bDanger[client] = true;
			
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			GetClientAbsOrigin(aHunterJockey, e_pos);
			e_pos[2] += -10.0;
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			buttons |= IN_ATTACK2;
			if (c_bDebug_Enabled) {
				PrintToChatAll("\x01[%.2f] \x05%N \x01shoved: \x04flying %N (%d)", GetGameTime(), client, aHunterJockey, aHunterJockey);
				EmitSoundToAll(SOUND_SWING, client);
			}
			return Plugin_Changed;
		}
		
		
		/* ====================================================================================================
		*
		*   —Dæ“xB : Self Smoker | aCapSmoker
		*
		==================================================================================================== */ 
		if (aCapSmoker > 0) { // Shoot even if client invisible the smoker
			if (!g_bDanger[client]) g_bDanger[client] = true;
			
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			GetEntPropVector(aCapSmoker, Prop_Data, "m_vecOrigin", e_pos);
			e_pos[2] += 5.0;
			
			//PrintToChatAll("c_pos[0] %.1f  |  [1] %.1f  |  [2] %.1f", c_pos[0], c_pos[1], c_pos[2]);
			//PrintToChatAll("e_pos[0] %.1f  |  [1] %.1f  |  [2] %.1f", e_pos[0], e_pos[1], e_pos[2]);
			
			// GetClientEyePosition(client, c_pos);
			// GetClientEyePosition(aCapSmoker, e_pos);
			// e_pos[2] += -10.0;
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N \x01Cap Smoker: \x04%N (%d)", GetGameTime(), client, aCapSmoker, aCapSmoker);

			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
			new Float:aimdist = GetVectorDistance(c_pos, e_pos);
			
			if (aimdist < 100.0) buttons |= IN_ATTACK2;
			else {
				buttons &= ~IN_ATTACK2;
				buttons |= IN_DUCK;
			}

			if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
			else buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
		
		
		/* ====================================================================================================
		*
		*  —Dæ“xC : Help | aCap_Infected, aCap_Survivor
		*
		==================================================================================================== */ 
		if (aCap_Survivor > 0) { // Pass if the client and target are "visible" to each other. so aCap Smoker doesn't pass
			if (!g_bDanger[client]) g_bDanger[client] = true;
			
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetClientEyePosition(aCap_Survivor, e_pos);
			
			if (HasValidEnt(aCap_Survivor, "m_pounceAttacker")) e_pos[2] += 5.0;
			else if (aCapSmoker > 0) { // ˆø‚Á’£‚Á‚Ä‚¢‚éSmoker
				GetClientEyePosition(aCapSmoker, e_pos);
				e_pos[2] += -10.0;
			}
			
			new Float:aimdist = GetVectorDistance(c_pos, e_pos);
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N \x01Cap Survivor: \x04%N (%d)", GetGameTime(), client, aCap_Survivor, aCap_Survivor);
			
			/****************************************************************************************************/
			
			// If any of the following are active, Switch to the main weapon 
			if (isHaveItem(AW_Classname, "first_aid_kit")
				|| isHaveItem(AW_Classname, "defibrillator")
				|| HasValidEnt(client, "m_reviveTarget")) {
				UseItem(client, main_weapon);
			}
			
			// If the melee weapon is active and the dist from the target is 110 or more, switch to the main weapon
			if (isHaveItem(AW_Classname, "weapon_melee") && aimdist > 110.0) {
				if (g_bCommonWithinMelee[client]) g_bCommonWithinMelee[client] = false;
				UseItem(client, main_weapon);
			}
			
			/****************************************************************************************************/
			
			if ((!isHaveItem(AW_Classname, "weapon_melee")) || (isHaveItem(AW_Classname, "weapon_melee") && aimdist < 110.0)) {
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
		
				if (((c_iHelp_ShoveType >= 1 && HasValidEnt(aCap_Survivor, "m_tongueOwner") && aimdist < 110.0)
						|| (c_iHelp_ShoveType >= 2 && HasValidEnt(aCap_Survivor, "m_jockeyAttacker") && aimdist < 100.0)
						|| (c_iHelp_ShoveType >= 3 && HasValidEnt(aCap_Survivor, "m_pounceAttacker") && aimdist < 100.0)))
				{
					if ((!c_bHelp_ShoveOnlyReloading) || (c_bHelp_ShoveOnlyReloading && isReloading(client)))
						buttons |= IN_ATTACK2; // ‰£‚è
				}
				
				if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
				else buttons |= IN_ATTACK;
				
				return Plugin_Changed;
			}
		} 
		else if (aCap_Infected > 0 && aCap_Survivor < 1) {
			if (!g_bDanger[client]) g_bDanger[client] = true;
			
			new zombieClass = getZombieClass(aCap_Infected);
			
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientEyePosition(client, c_pos);
			
			if (aCapSmoker > 0) { // Prioritize aCapSmoker
				GetClientEyePosition(aCapSmoker, e_pos);
				e_pos[2] += -10.0;
			} else {
				GetClientEyePosition(aCap_Infected, e_pos);
				
				if (zombieClass == ZC_SMOKER || zombieClass == ZC_CHARGER) e_pos[2] += -9.0;
				else if (zombieClass == ZC_HUNTER) e_pos[2] += -14.0;
			}
			
			new Float:aimdist = GetVectorDistance(c_pos, e_pos);
			
			if (zombieClass == ZC_CHARGER && aimdist < 300.0) e_pos[2] += 10.0;
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N \x01Cap Infected: \x04%N (%d)", GetGameTime(), client, aCap_Infected, aCap_Infected);
			
			/****************************************************************************************************/
			
			// If any of the following are active, Switch to the main weapon 
			if (isHaveItem(AW_Classname, "first_aid_kit")
				|| isHaveItem(AW_Classname, "defibrillator")
				|| HasValidEnt(client, "m_reviveTarget"))
			{
				UseItem(client, main_weapon);
			}
			
			// If the melee weapon is active and the dist from the target is 110 or more, switch to the main weapon
			if (isHaveItem(AW_Classname, "weapon_melee") && aimdist > 110.0)
			{
				if (g_bCommonWithinMelee[client]) g_bCommonWithinMelee[client] = false;
				UseItem(client, main_weapon);
			}
			
			/****************************************************************************************************/
			
			if ((!isHaveItem(AW_Classname, "weapon_melee")) || (isHaveItem(AW_Classname, "weapon_melee") && aimdist < 110.0)) {
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				
				if (aimdist < 100.0
					&& ((c_iHelp_ShoveType >= 1 && zombieClass == ZC_SMOKER)
						|| (c_iHelp_ShoveType >= 2 && zombieClass == ZC_JOCKEY)
						|| (c_iHelp_ShoveType >= 3 && zombieClass == ZC_HUNTER)))
				{
					if ((!c_bHelp_ShoveOnlyReloading) || (c_bHelp_ShoveOnlyReloading && isReloading(client)))
						buttons |= IN_ATTACK2; // Shove
				}
				
				if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
				else buttons |= IN_ATTACK;
				
				return Plugin_Changed;
			}
		}
		
		
		
		/* ====================================================================================================
		*
		*   —Dæ“xD : Tank Rock, Witch
		*
		==================================================================================================== */ 
		if (aTankRock > 1 && !HasValidEnt(client, "m_reviveTarget")) {
			new Float:c_pos[3], Float:rock_e_pos[3];
			new Float:lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			GetEntPropVector(aTankRock, Prop_Data, "m_vecAbsOrigin", rock_e_pos);
			rock_e_pos[2] += -50.0;
			
			MakeVectorFromPoints(c_pos, rock_e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) {
				// PrintToChatAll("\x01rock : \x01[0] - \x04%.2f \x01, [1] - \x04%.2f \x01, [2] - \x04%.2f", rock_e_pos[0], rock_e_pos[1], rock_e_pos[2]);
				// PrintToChatAll("\x01client(%N) : \x01[0] - \x04%.2f \x01, [1] - \x04%.2f \x01, [2] - \x04%.2f", client, c_pos[0], c_pos[1], c_pos[2]);
				// PrintToChatAll("---");
			}
			
			new Float:aimdist = GetVectorDistance(c_pos, rock_e_pos);
			
			if (aimdist > 40.0 && !isHaveItem(AW_Classname, "weapon_melee")) { //‹ßÚ‚ðŽ‚Á‚Ä‚¢‚È‚¢ê‡
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				
				if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
				else buttons |= IN_ATTACK;
			}
			
			return Plugin_Changed;
		}
		
		if (aWitch > 1) {
			new Float:c_pos[3], Float:witch_e_pos[3];
			new Float:lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetEntPropVector(aWitch, Prop_Data, "m_vecAbsOrigin", witch_e_pos);
			witch_e_pos[2] += 40.0;
			
			MakeVectorFromPoints(c_pos, witch_e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N \x01Witch: \x05(%d)", GetGameTime(), client, aWitch);
			
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
			new Float:aimdist = GetVectorDistance(c_pos, witch_e_pos);
			
			if (c_bWitch_Shotgun_Control && isHaveItem(AW_Classname, "shotgun")) {
				if (aimdist < 150.0) buttons |= IN_DUCK;
				
				if (aimdist < c_fWitch_Shotgun_Range_Min || aimdist > c_fWitch_Shotgun_Range_Max) { // 70 ~ 300
					if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
					else buttons |= IN_ATTACK;
					//PrintToChatAll("\x05%N %.2f", client, aimdist);
				} else {
					buttons &= ~IN_ATTACK;
					//PrintToChatAll("\x04%N Attack Stop %.2f", client, aimdist);
				}
				return Plugin_Changed;
			}
			
			if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
			else buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
		
		
		
		/* ====================================================================================================
		*
		*   —Dæ“xE : Common Infected
		*
		==================================================================================================== */ 
		if (aCommonInfected > 0) {
			if (!HasValidEnt(client, "m_reviveTarget") && StrContains(AW_Classname, "first_aid_kit", false) == -1) {
				// Even if aCommonInfected dies and disappears, the Entity may not disappear for a while.(Bot keeps shooting the place)B Even with InValidEntity(), true appears...
				// When the entity disappears, m_nNextThinkTick will not advance, so skip that if NextThinkTick has the same value as before.
				
				new iNextThinkTick = GetEntProp(aCommonInfected, Prop_Data, "m_nNextThinkTick");
				
				if (g_Stock_NextThinkTick[client] != iNextThinkTick) // If visible aCommonInfected
				{
					new Float:c_pos[3], Float:common_e_pos[3];
					new Float:lookat[3];
					
					GetClientEyePosition(client, c_pos);
					GetEntPropVector(aCommonInfected, Prop_Data, "m_vecOrigin", common_e_pos);
					
					//new Float:height_difference = (c_pos[2] - common_e_pos[2]) - 60.0;
					
					common_e_pos[2] += 40.0;
					
					new Float:aimdist = GetVectorDistance(c_pos, common_e_pos);
					
					//common_e_pos[2] += (25.0 + (aimdist * 0.05) - (height_difference * 0.1));
					
					// GetClientAbsOrigin(client, c_pos);
					// GetEntPropVector(aCommonInfected, Prop_Data, "m_vecOrigin", common_e_pos);
					// common_e_pos[2] += -30.0;
					
					new iSeq = GetEntProp(aCommonInfected, Prop_Send, "m_nSequence", 2);
					// Stagger			122, 123, 126, 127, 128, 133, 134
					// Down Stagger		128, 129, 130, 131
					// Object Climb (Very Low)	182, 183, 184, 185
					// Object Climb (Low)	190, 191, 192, 193, 194, 195, 196, 197, 198, 199
					// Object Climb (High)	206, 207, 208, 209, 210, 211, 218, 219, 220, 221, 222, 223
					if (iSeq >= 182 && iSeq <= 189) common_e_pos[2] += -10.0;
					
					MakeVectorFromPoints(c_pos, common_e_pos, lookat);
					GetVectorAngles(lookat, angles);
					
					/****************************************************************************************************/
					
					g_Stock_NextThinkTick[client] = iNextThinkTick; // Set the current m_nNextThinkTick
					
					if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N\x01 Commons: \x04(%d)\x01  |  Dist: \x04%.1f\x01  |  Melee Count: \x04%d", GetGameTime(), client, aCommonInfected, aimdist, iCI_MeleeCount);
					
					// iCI_MeleeCount is from ci_melee_range
					if (c_bCI_MeleeEnabled
						&& aimdist <= c_fCI_MeleeRange
						&& iCI_MeleeCount > 2) {
						g_bCommonWithinMelee[client] = true;
						
						new String:sub_weapon[128];
						new slot1 = GetPlayerWeaponSlot(client, 1);
						if (slot1 > -1) {			
							GetEntityClassname(slot1, sub_weapon, sizeof(sub_weapon)); // SubWeapon
						}
						
						if (isHaveItem(sub_weapon, "weapon_melee")) {
							if (!isHaveItem(AW_Classname, "weapon_melee")) {
								FakeClientCommand(client, "use %s", sub_weapon);
							}
						}
					}
					
					if (new_target > 0) {
						if (aimdist <= 90.0) TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
					} else {
						if (isHaveItem(AW_Classname, "weapon_melee")) {
							if (aimdist <= 90.0) TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
						} else {
							TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
						}
					}
					
					if (new_target < 1 || (new_target > 0 && aimdist <= 90.0)) { // If new_target and common at the same time, prioritize to new_target. Attack only when within 90.0 dist.
						if (isHaveItem(AW_Classname, "weapon_melee")) {
							if (GetRandomInt(0, 6) == 0) {
								if (aimdist <= 50.0) buttons |= IN_ATTACK2;
								else if (aimdist > 50.0 && aimdist <= 90.0) buttons |= IN_ATTACK;
							} else {
								if (aimdist <= 90.0) buttons |= IN_ATTACK; // 90.0
							}
							
							// if (GetRandomInt(0, 6) == 0) {
							// 	if (aimdist < 50.0) {
							// 		buttons |= IN_ATTACK2;
							// 	}
							// } else {
							// 	if (aimdist < 90.0) buttons |= IN_ATTACK;
							// }
						} else {
							if (aimdist > 60.0) {
								if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
								else buttons |= IN_ATTACK;
							} else {
								if (GetRandomInt(0, 8) == 0) {
									if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
									else buttons |= IN_ATTACK;
								} else {
									buttons |= IN_ATTACK2;
								}
								
								if (isReloading(client)) {
									if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK2;
									else buttons |= IN_ATTACK2;
								}
							}
						}
						return Plugin_Changed;
					}
				}
				else // Skip if aCommonInfected is not visible
				{
					// PrintToChatAll("stock %i  |  next %i", g_Stock_NextThinkTick[client], iNextThinkTick);
				}
			}
		}
		
		
		
		/* ====================================================================================================
		*
		*   —Dæ“xF : Special Infected and Tank (new_target)
		*
		==================================================================================================== */ 
		if (new_target > 0) {
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientAbsOrigin(client, c_pos);
			
			new zombieClass = getZombieClass(new_target);
			
			if (aCapSmoker > 0) { // Prioritize aCapSmoker
				GetClientAbsOrigin(aCapSmoker, e_pos);
				e_pos[2] += -10.0;
			} else {
				GetClientAbsOrigin(new_target, e_pos);
				if (zombieClass == ZC_HUNTER
					&& (GetClientButtons(new_target) & IN_DUCK)) {
					if (GetVectorDistance(c_pos, e_pos) > 250.0) e_pos[2] += -30.0;
					else e_pos[2] += -35.0;
				} else if (zombieClass == ZC_JOCKEY) {
					e_pos[2] += -30.0;
				} else {
					e_pos[2] += -10.0;
				}
			}
			
			if (zombieClass == ZC_TANK && aTankRock > 0) return Plugin_Continue; // If the Tank and tank rock are visible at the same time, prioritize the tank rock
			
			new Float:aimdist = GetVectorDistance(c_pos, e_pos);
			
			if (aimdist < 200.0) {if (!g_bDanger[client]) g_bDanger[client] = true;}
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			/****************************************************************************************************/
			
			if(isHaveItem(AW_Classname, "first_aid_kit")
				|| isHaveItem(AW_Classname, "defibrillator")
				|| HasValidEnt(client, "m_reviveTarget")) {
				if (aimdist > 250.0) return Plugin_Continue;
				else { UseItem(client, main_weapon); }
			}
			
			if (isHaveItem(AW_Classname, "weapon_shotgun_chrome")
				|| isHaveItem(AW_Classname, "weapon_shotgun_spas")
				|| isHaveItem(AW_Classname, "weapon_pumpshotgun")
				|| isHaveItem(AW_Classname, "weapon_autoshotgun")) {
				if (aimdist > 1000.0) return Plugin_Continue;
			}
			
			if (isHaveItem(AW_Classname, "weapon_melee") && aCommonInfected < 1) {
				if (aimdist > 100.0) UseItem(client, main_weapon);
			}
			
			/****************************************************************************************************/
			
			new bool:isTargetBoomer = false; // Is new_target Boomer
			new bool:isBoomer_Shoot_OK = false;
			
			if (c_bSI_IgnoreBoomer && zombieClass == ZC_BOOMER) {
				new Float:voS_pos[3];
				for (new s = 1; s <= MaxClients; ++s) {
					if (isSurvivor(s)
						&& IsPlayerAlive(s))
					{
						new Float:fVomit = GetEntPropFloat(s, Prop_Send, "m_vomitStart");
						if (GetGameTime() - fVomit > 10.0) { // Survivors without vomit
							GetClientAbsOrigin(s, voS_pos);
							
							new Float:dist = GetVectorDistance(voS_pos, e_pos); // Distance between the Survivor without vomit and the Boomer
							if (dist >= c_fSI_IgnoreBoomerRange) { isBoomer_Shoot_OK = true; } // If the survivor without vomit is farther than dist "c_fSI_IgnoreBoomerRange (def: 200)"
							else { isBoomer_Shoot_OK = false; break; } // If False appears even once, break
						}
					}
				}
				isTargetBoomer = true;
			}
			
			if ((zombieClass == ZC_JOCKEY && g_bShove[client][new_target])
				|| zombieClass == ZC_SMOKER
				|| (isTargetBoomer && !isBoomer_Shoot_OK))
			{
				if (aimdist < 90.0 && !isStagger(new_target)) {
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
					buttons |= IN_ATTACK2;
					if (c_bDebug_Enabled) {
						PrintToChatAll("\x01[%.2f] \x05%N\x01 new_target shoved: \x04%N (%d)", GetGameTime(), client, new_target, new_target);
						EmitSoundToAll(SOUND_SWING, client);
					}
					return Plugin_Changed;
				}
			}
			
			if (!isHaveItem(AW_Classname, "weapon_melee")
				|| (aimdist < 100.0 && isHaveItem(AW_Classname, "weapon_melee")))
			{
				if (c_bDebug_Enabled) {
					if (!isTargetBoomer) PrintToChatAll("\x01[%.2f] \x05%N\x01 new_target: \x04%N (%d)", GetGameTime(), client, new_target, new_target);
					else PrintToChatAll("\x01[%.2f] \x05%N\x01 new_target: \x04%N (%d) (Shoot: %s)", GetGameTime(), client, new_target, new_target, (isBoomer_Shoot_OK) ? "OK" : "NO");
				}
			
				if (!isTargetBoomer || (isTargetBoomer && isBoomer_Shoot_OK)) {
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
					
					if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
					else buttons |= IN_ATTACK;
				}
				
				return Plugin_Changed;
			}
		}
		
		// if there is no danger, false
		if (g_bDanger[client]) g_bDanger[client] = false;
	}
	
	return Plugin_Continue;
}



/* ================================================================================================
*=
*= 		Incapacitated Run Cmd
*=
================================================================================================ */
stock Action:onSBRunCmd_Incapacitated(client, &buttons, Float:vel[3], Float:angles[3])
{
	if (isIncapacitated(client)) {
		new aCapper = -1;
		new Float:min_dist_Cap = 100000.0;
		new Float:self_pos[3], Float:target_pos[3];
		
		GetClientEyePosition(client, self_pos);
		if (!NeedsTeammateHelp(client)) {
			for (new x = 1; x <= MaxClients; ++x) {
				// S‘©‚³‚ê‚Ä‚¢‚é¶‘¶ŽÒ‚ð’T‚·
				if (isSurvivor(x)
					&& NeedsTeammateHelp(x)
					&& (x != client)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					GetClientAbsOrigin(x, target_pos);
					new Float:dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist_Cap) {
						min_dist_Cap = dist;
						aCapper = x;
					}
				}
				
				// S‘©‚µ‚Ä‚¢‚é“ÁŽêŠ´õŽÒ‚ð’T‚·
				if (isInfected(x)
					&& CappingSuvivor(x)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					GetClientAbsOrigin(x, target_pos);
					new Float:dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist_Cap) {
						min_dist_Cap = dist;
						aCapper = x;
					}
				}
			}
		}
		
		if (aCapper > 0) {
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetClientEyePosition(aCapper, e_pos);
			
			e_pos[2] += -15.0;		
			
			if ((isSurvivor(aCapper) && HasValidEnt(aCapper, "m_pounceAttacker"))) {
				e_pos[2] += 18.0;
				// Raise angles if near
			}
			if ((isInfected(aCapper) && getZombieClass(aCapper) == ZC_HUNTER)) {
				e_pos[2] += -15.0;
			}
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) {
				if (isSurvivor(aCapper)) PrintToChatAll("\x01[%.2f] \x05%N \x01Cap Survivor Incapacitated: \x04%N", GetGameTime(), client, aCapper);
				else PrintToChatAll("\x01[%.2f] \x05%N \x01Cap Infected Incapacitated: \x04%N", GetGameTime(), client, aCapper);
			}
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
			if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
			else buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
		
		
		new new_target = -1;
		new aCommonInfected = -1;
		if (aCapper < 1 && !NeedsTeammateHelp(client)) {
			new Float:min_dist = 100000.0;
			new Float:ci_pos[3];
			
			for (new x = 1; x <= MaxClients; ++x){
				if (isInfected(x)
					&& IsPlayerAlive(x)
					&& (isVisibleTo(client, x) || isVisibleTo(x, client)))
				{
					GetClientAbsOrigin(x, target_pos);
					new Float:dist = GetVectorDistance(self_pos, target_pos);
					if (dist < min_dist) {
						min_dist = dist;
						new_target = x;
						aCommonInfected = -1;
					}
				}
			}
			
			if (c_bCI_Enabled) {
				for (new iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity) {
					if (IsCommonInfected(iEntity)
						&& GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0
						&& isVisibleToEntity(iEntity, client))
					{
						GetEntPropVector(iEntity, Prop_Data, "m_vecAbsOrigin", ci_pos);
						new Float:dist = GetVectorDistance(self_pos, ci_pos);
						
						if (dist < min_dist) {
							min_dist = dist;
							aCommonInfected = iEntity;
							new_target = -1;
						}
					}
				}
			}
		}
		
		if (aCommonInfected > 0) {
			new Float:c_pos[3], Float:common_e_pos[3];
			new Float:lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetEntPropVector(aCommonInfected, Prop_Data, "m_vecOrigin", common_e_pos);
			common_e_pos[2] += 35.0;
			
			MakeVectorFromPoints(c_pos, common_e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			new Float:aimdist = GetVectorDistance(c_pos, common_e_pos);
			
			/****************************************************************************************************/
			
			if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N\x01 Commons Incapacitated Dist: %.1f", GetGameTime(), client, aimdist);
			
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
			if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
			else buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
		
		if (new_target > 0) {
			new Float:c_pos[3], Float:e_pos[3];
			new Float:lookat[3];
			
			GetClientEyePosition(client, c_pos);
			GetClientEyePosition(new_target, e_pos);
			
			e_pos[2] += -15.0
			
			new zombieClass = getZombieClass(new_target);
			if (zombieClass == ZC_JOCKEY) {
				e_pos[2] += -30.0;
			} else if (zombieClass == ZC_HUNTER) {
				if ((GetClientButtons(new_target) & IN_DUCK) || HasValidEnt(new_target, "m_pounceVictim")) e_pos[2] += -25.0;
			}
			
			MakeVectorFromPoints(c_pos, e_pos, lookat);
			GetVectorAngles(lookat, angles);
			
			if (c_bDebug_Enabled) PrintToChatAll("\x01[%.2f] \x05%N \x01new target Incapacitated: \x04%N", GetGameTime(), client, new_target);
			
			TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			
			if (GetRandomInt(0, 4) == 0) buttons &= ~IN_ATTACK;
			else buttons |= IN_ATTACK;
			
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}


/* ================================================================================================
*=
*=		Events
*=
================================================================================================ */
public Action:Event_PlayerIncapacitated(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_hEnabled) return Plugin_Handled;
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attackerentid = GetEventInt(event, "attackerentid");
	
	// new type = GetEventInt(event, "type");
	// PrintToChatAll("\x04PlayerIncapacitated");
	// PrintToChatAll("type %i", type);
	
	if (isSurvivor(victim) && IsWitch(attackerentid))
	{
		g_iWitch_Process[attackerentid] = WITCH_INCAPACITATED;
		
		// PrintToChatAll("attackerentid %i attacked %N", attackerentid, victim);
		// new health = GetEventInt(event, "health");
		// new dmg_health = GetEventInt(event, "dmg_health");
		// PrintToChatAll("health: %i, damage: %i", health, dmg_health);
	}
	
	return Plugin_Handled;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (!g_hEnabled) return Plugin_Handled;
	
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attackerentid = GetEventInt(event, "attackerentid");
	
	// new type = GetEventInt(event, "type");
	// PrintToChatAll("\x04PlayerDeath");
	// PrintToChatAll("type %i", type);
	
	if (isSurvivor(victim) && IsWitch(attackerentid))
	{
		g_iWitch_Process[attackerentid] = WITCH_KILLED;
		
		// PrintToChatAll("attackerentid %i attacked %N", attackerentid, victim);
		// new health = GetEventInt(event, "health");
		// new dmg_health = GetEventInt(event, "dmg_health");
		// PrintToChatAll("health: %i, damage: %i", health, dmg_health);
	}
	
	// Witch Damage type: 4
	// Witch Incapacitated type: 32772
	
	return Plugin_Handled;
}

public Action:Event_WitchRage(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (isSurvivor(attacker)) {
		// CallBotstoWitch(attacker);
		g_bWitchActive = true;
	}	
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrContains(classname, "witch", false) > -1)
	{
		g_iWitch_Process[entity] = 0;
	}
}

public OnEntityDestroyed(entity)
{
	new String:classname[32];
	GetEntityClassname(entity, classname, sizeof(classname));
	
	if (StrEqual(classname, "witch", false)) {
		if (g_bWitchActive) {
			new iWitch_Count = 0;
			for (new iEntity = MaxClients+1; iEntity <= MAXENTITIES; ++iEntity)
			{
				if (IsWitch(iEntity) && GetEntProp(iEntity, Prop_Data, "m_iHealth") > 0 && IsWitchRage(iEntity))
				{
					iWitch_Count++;
				}
				
				//PrintToChatAll("witch count %d", iWitch_Count);
				
				if (iWitch_Count == 0) {g_bWitchActive = false;}
			}
		}
	}
}


/* ================================================================================================
*=
*=		Stock any
*=
================================================================================================ */
stock ScriptCommand(client, const String:command[], const String:arguments[], any:...)
{
	new String:vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 4);
	
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags^FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, vscript);
	SetCommandFlags(command, flags | FCVAR_CHEAT);
}

stock L4D2_RunScript(const String:sCode[], any:...)
{
	static iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic)) {
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			SetFailState("Could not create 'logic_script'");
		
		DispatchSpawn(iScriptLogic);
	}
	
	static String:sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
	
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
}


/*
*
*   Bool
*
*/
stock bool:NeedsTeammateHelp(client)
{
	if (HasValidEnt(client, "m_tongueOwner")
	|| HasValidEnt(client, "m_pounceAttacker")
	|| HasValidEnt(client, "m_jockeyAttacker")
	|| HasValidEnt(client, "m_carryAttacker")
	|| HasValidEnt(client, "m_pummelAttacker"))
	{
		return true;
	}
	
	return false;
}

stock bool:NeedsTeammateHelp_ExceptSmoker(client)
{
	if (HasValidEnt(client, "m_pounceAttacker")
	|| HasValidEnt(client, "m_jockeyAttacker")
	|| HasValidEnt(client, "m_carryAttacker")
	|| HasValidEnt(client, "m_pummelAttacker"))
	{
		return true;
	}
	
	return false;
}

stock bool:CappingSuvivor(client)
{
	if (HasValidEnt(client, "m_tongueVictim")
	|| HasValidEnt(client, "m_pounceVictim")
	|| HasValidEnt(client, "m_jockeyVictim")
	|| HasValidEnt(client, "m_carryVictim")
	|| HasValidEnt(client, "m_pummelVictim"))
	{
		return true;
	}
	
	return false;
}

stock bool:HasValidEnt(client, const String:entprop[])
{
	new ent = GetEntPropEnt(client, Prop_Send, entprop);
	
	return (ent > 0
		&& IsClientInGame(ent));
}

stock bool:IsWitchRage(id) {
	if (GetEntPropFloat(id, Prop_Send, "m_rage") >= 1.0) return true;
	return false;
}

stock bool:IsCommonInfected(iEntity)
{
	if (iEntity && IsValidEntity(iEntity))
	{
		new String:strClassName[64];
		GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
		
		if (StrContains(strClassName, "infected", false) > -1)
			return true;
	}
	return false;
}

stock bool:IsWitch(iEntity)
{
	if (iEntity && IsValidEntity(iEntity))
	{
		decl String:strClassName[64];
		GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
		if (StrEqual(strClassName, "witch"))
			return true;
	}
	return false;
}

stock bool:IsTankRock(iEntity)
{
	if (iEntity && IsValidEntity(iEntity))
	{
		decl String:strClassName[64];
		GetEntityClassname(iEntity, strClassName, sizeof(strClassName));
		if (StrEqual(strClassName, "tank_rock"))
			return true;
	}
	return false;
}

stock bool:isGhost(i)
{
	return bool:GetEntProp(i, Prop_Send, "m_isGhost");
}

stock bool:isSpecialInfectedBot(i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3;
}

stock bool:isSurvivorBot(i)
{
	return isSurvivor(i) && IsFakeClient(i);
}

stock bool:isInfected(i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 3 && !isGhost(i);
}

stock bool:isSurvivor(i)
{
	return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}

stock any:getZombieClass(client)
{
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

stock bool:isIncapacitated(client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1;
}

stock bool:isReloading(client)
{
	new slot0 = GetPlayerWeaponSlot(client, 0);
	if (slot0 > -1) {
		return GetEntProp(slot0, Prop_Data, "m_bInReload") > 0;
	}
	return false;
}

stock bool:isStagger(client) // Client Only
{
	new Float:staggerPos[3];
	GetEntPropVector(client, Prop_Send, "m_staggerStart", staggerPos);
	
	if (staggerPos[0] != 0.0 && staggerPos[1] != 0.0 && staggerPos[2] != 0.0) return true;
	
	return false;
}

stock bool:isJockeyLeaping(client)
{
	new Float:jockeyVelocity[3];
	GetEntDataVector(client, g_Velo, jockeyVelocity);
	if (jockeyVelocity[2] != 0.0) return true;
	return false;
}

stock bool:isHaveItem(const String:FItem[], const String:SItem[])
{
	if (StrContains(FItem, SItem, false) > -1) return true;
	
	return false;
}

stock UseItem(client, const String:FItem[])
{
	FakeClientCommand(client, "use %s", FItem);
}

stock any:PrimaryExtraAmmoCheck(client, weapon_index)
{
	// Offset:
	// 12: Rifle ALL (Other than M60)
	// 20: SMG ALL
	// 28: Chrome, Pump
	// 32: SPAS, Auto
	// 36: Hunting
	// 40: Sniper
	// 68: Granade Launcher
	// NONE: Rifle M60 is only Clip1
	new offset;
	
	decl String:sWeaponName[256];
	GetEdictClassname(weapon_index, sWeaponName, sizeof(sWeaponName));
	if (isHaveItem(sWeaponName, "weapon_rifle")) offset = 12;
	else if (isHaveItem(sWeaponName, "weapon_smg")) offset = 20;
	else if (isHaveItem(sWeaponName, "weapon_shotgun_chrome") || isHaveItem(sWeaponName, "weapon_pumpshotgun")) offset = 28;
	else if (isHaveItem(sWeaponName, "weapon_shotgun_spas") || isHaveItem(sWeaponName, "weapon_autoshotgun")) offset = 32;
	else if (isHaveItem(sWeaponName, "weapon_hunting_")) offset = 36;
	else if (isHaveItem(sWeaponName, "weapon_sniper")) offset = 40;
	else if (isHaveItem(sWeaponName, "weapon_grenade_launcher")) offset = 68;
	
	new extra_ammo = GetEntData(client, (g_iAmmoOffset + offset));
	//PrintToChatAll("%N Gun Name: %s, Offset: %i, ExtraAmmo: %i:", client, sWeaponName, offset, extra_ammo);
	
	return extra_ammo;
}

/* -------------------------------------------------------------------------------------------------------------------------------------------------------------- 

--------------------------------------------------------------------------------------------------------------------------------------------------------------------- */

public bool:traceFilter(entity, mask, any:self)
{
	return entity != self;
}

public bool:TraceRayDontHitPlayers(entity, mask)
{
	// Check if the beam hit a player and tell it to keep tracing if it did
	return (entity <= 0 || entity > MaxClients);
}

// Determine if the head of the target can be seen from the client
stock bool:isVisibleTo(client, target)
{
	new bool:ret = false;
	new Float:aim_angles[3];
	new Float:self_pos[3];
	
	GetClientEyePosition(client, self_pos);
	computeAimAngles(client, target, aim_angles);
	
	new Handle:trace = TR_TraceRayFilterEx(self_pos, aim_angles, MASK_VISIBLE, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) {
		new hit = TR_GetEntityIndex(trace);
		if (hit == target) {
			ret = true;
		}
	}
	CloseHandle(trace);
	return ret;
}

/* Determine if the head of the entity can be seen from the client */
stock bool:isVisibleToEntity(target, client)
{
	new bool:ret = false;
	new Float:aim_angles[3];
	new Float:self_pos[3], Float:target_pos[3];
	new Float:lookat[3];
	
	GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);
	GetClientEyePosition(client, self_pos);
	
	MakeVectorFromPoints(target_pos, self_pos, lookat);
	GetVectorAngles(lookat, aim_angles);
	
	new Handle:trace = TR_TraceRayFilterEx(target_pos, aim_angles, MASK_VISIBLE, RayType_Infinite, traceFilter, target);
	if (TR_DidHit(trace)) {
		new hit = TR_GetEntityIndex(trace);
		if (hit == client) {
			ret = true;
		}
	}
	CloseHandle(trace);
	return ret;
}

/* From the client to the target's head, whether it is blocked by mesh */
stock bool:isInterruptTo(client, target)
{
	new bool:ret = false;
	new Float:aim_angles[3];
	new Float:self_pos[3];
	
	GetClientEyePosition(client, self_pos);
	computeAimAngles(client, target, aim_angles);
	new Handle:trace = TR_TraceRayFilterEx(self_pos, aim_angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace)) {
		new hit = TR_GetEntityIndex(trace);
		if (hit == target) {
			ret = true;
		}
	}
	CloseHandle(trace);
	return ret;
}

// Calculate the angles from client to target
stock computeAimAngles(client, target, Float:angles[3], type = 1)
{
	new Float:target_pos[3];
	new Float:self_pos[3];
	new Float:lookat[3];
	
	GetClientEyePosition(client, self_pos);
	switch (type) {
		case 1: { // Eye (Default)
			GetClientEyePosition(target, target_pos);
		}
		case 2: { // Body
			GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);
		}
		case 3: { // Chest
			GetClientAbsOrigin(target, target_pos);
			target_pos[2] += 45.0;
		}
	}
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
}
