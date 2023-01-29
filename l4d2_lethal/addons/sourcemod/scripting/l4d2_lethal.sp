#pragma newdecls required
#pragma semicolon 1

/*******************************************************
*
* 		L4D2: Lethal Weapon
*
* 		      Author: ztar
* 		   Edited: M249-M4A1
* http://forums.alliedmods.net/showthread.php?p=1121995
*
********************************************************
* CHANGELOG:
*
* - Added several ConVars to customize effects
*   - Enable/disable sounds
*   - Enable/disable use of extra ammo
*   - Enable/disable some effects (to be discreet)
*   - Enable/disable charging while crouched and moving
*
* - Renamed ConVars and CFG to be more uniform
* - Fixed some grammar and spelling issues
* - Removed text gauge as it was kinda annoying
* - Made it easier to change sounds (#define)
* - Updated some sounds
* - Fixed bug where Survivors would be launched away
*   and killed unless "l4d2_lw_ff" is enabled
* - Fixed bug where if you were limited to 1 lethal
*   charged shot, you fired, then the limit was
*   removed, you wouldn't be able to charge again
* - Added screen shake
*
*******************************************************/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.1.14"

/*

	Modify by Zakikun

	2.1.14
	- Added "l4d2_lw_adminonly" convar to control whether only enable lethal shoot for admin
	- Added "lethal_weapon" flag to specify which admin can use lethal shoot

	Fork by Dragokas
	
	2.1.13
	- Fixed "l4d2_lw_shootonce" can be walkaround by going to idle.

	2.1.12
	- Added "l4d2_lw_firelifetime" convar to control how many time should flame exist after sniper shooting.

	2.1.11
	- Added "l4d2_lw_useammocount" convar to set the number of ammo player spend on each lethal shoot (999 - by default).

	2.1.10
	- Converted to a new syntax and methodmaps

	2.1.9
	- Added checking for game requirements (L4d1 / L4d2).
	- Added natives Lethal_SetAllowedClient(), Lethal_SetAllowedClientsAll(), Lethal_FriendlyFire().
	- Added "sm_satellite_friendlyfire" ConVar to control FriendlyFire of indirect damage (explosion and fire).
	- Ammo / clip offsets are corrected for L4D1.
	- Now lethal sniper shoot spend all ammo.
	- Fixed exploit on infinite super sniper-shoots when your bullets are not reset if you do a fast switch on pistol just right after shoot.

	2.1.8
	- Added IsClientInGame() check to StopSound.

	2.1.7
	- Added count of proper statistics for sniper super-shoot (thanks to SilverShot)
	- Replaced deprecated FindSendPropOffs() and FindDataMapOffs()

	2.1.6
	- Added IsValidClient() check to Smash function.

	2.1.5
	- Added some fixes from Ludastar.

	2.1.4
	- Added another one check
	- Added Russian translation

	2.1.3
	- ReleaseLock[client] = 0 is moved to a bit earlier stage for Event_Infected_Hurt and Event_Player_Hurt to prevent recurse calling bug (server crash).

	2.1.2
	- Added some client checkings
	- Fixed bug when molotov is displayed but no longer available for player after super-shoot done
*/

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY
#define MOLOTOV 0
#define EXPLODE 1

/*
Datamap m_iAmmo
offset to add

+12: M4A1, AK74, Desert Rifle, also SG552 - ammo_assaultrifle_max
+20: both SMGs, also the MP5 - ammo_smg_max
+28: both Pump Shotguns - ammo_shotgun_max
+32: both autoshotguns - ammo_autoshotgun_max
+36: Hunting Rifle - ammo_huntingrifle_max
+40: Military Sniper, AWP, Scout - ammo_sniperrifle_max
+68: Grenade Launcher - ammo_grenadelauncher_max
*/
const HUNTING_RIFLE_OFFSET_IAMMO	= 36;
const MILITARY_SNIPER_OFFSET_IAMMO	= 40;

int ChargeLock[65];
int ReleaseLock[65];
int CurrentWeapon;
int ClipSize;
int ChargeEndTime[65];
Handle ClientTimer[65];
int g_sprite;
float myPos[3], trsPos[3], trsPos002[3];

/* Sound */
#define CHARGESOUND 	"ambient/spacial_loops/lights_flicker.wav"
#define CHARGEDUPSOUND	"level/startwam.wav"
#define AWPSHOT			"weapons/awp/gunfire/awp1.wav"
#define EXPLOSIONSOUND	"animation/bombing_run_01.wav"

/* Sprite */
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"

ConVar l4d2_lw_lethalweapon;
ConVar l4d2_lw_lethaldamage;
ConVar l4d2_lw_lethalforce;
ConVar l4d2_lw_chargetime;
ConVar l4d2_lw_shootonce;
ConVar l4d2_lw_ff;
ConVar l4d2_lw_scout;
ConVar l4d2_lw_awp;
ConVar l4d2_lw_huntingrifle;
ConVar l4d2_lw_g3sg1;
ConVar l4d2_lw_flash;
ConVar l4d2_lw_chargingsound;
ConVar l4d2_lw_chargedsound;
ConVar l4d2_lw_moveandcharge;
ConVar l4d2_lw_chargeparticle;
ConVar l4d2_lw_useammo;
ConVar l4d2_lw_useammocount;
ConVar l4d2_lw_shake;
ConVar l4d2_lw_shake_intensity;
ConVar l4d2_lw_shake_shooteronly;
ConVar l4d2_lw_laseroffset;
ConVar l4d2_lw_friendlyfire;
ConVar l4d2_lw_firelifetime;
ConVar l4d2_lw_adminonly;
ConVar hConVar_FireLifetime;

bool g_bDamageAlly = true;
bool g_bHooked[MAXPLAYERS+1];
bool g_bBlockBlastDamage = false;
bool g_bBlockFireDamage = false;
bool g_bLeft4Dead2 = false;

int g_iOnlyAllowedClient = 0;
int g_iCurWeapon[MAXPLAYERS+1];
int g_iFireLifetime = 15;
int g_iAmmoOffset;


public Plugin myinfo = 
{
	name = "Lethal weapon",
	author = "ztar (Fork by Dragokas, modify by Zakikun)",
	description = "Sniper rifles super shoot",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=121711"
}

/******************************************************
*	Natives
*******************************************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead && test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 and Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	g_bLeft4Dead2 = (test == Engine_Left4Dead2);

	CreateNative("Lethal_SetAllowedClient", NATIVE_Lethal_SetAllowedClient);
	CreateNative("Lethal_SetAllowedClientsAll", NATIVE_Lethal_SetAllowedClientsAll);
	CreateNative("Lethal_FriendlyFire", NATIVE_Lethal_FriendlyFire);
	RegPluginLibrary("lethal_helpers");
	return APLRes_Success;
}

public int NATIVE_Lethal_SetAllowedClient(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");
	
	g_iOnlyAllowedClient = GetNativeCell(1);
	return 0;
}

public int NATIVE_Lethal_SetAllowedClientsAll(Handle plugin, int numParams)
{
	g_iOnlyAllowedClient = 0;
	return 0;
}

public int NATIVE_Lethal_FriendlyFire(Handle plugin, int numParams)
{
	if(numParams < 1)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid numParams");

	g_bDamageAlly = view_as<bool>(GetNativeCell(1));
	return 0;
}

bool UseAllowed(int client)
{
	if (g_iOnlyAllowedClient == client)
		return true;
	
	if (g_iOnlyAllowedClient != 0)
		return false;
	
	if (!HasAccess(client) && l4d2_lw_adminonly.IntValue)
		return false;

	return true; // g_iOnlyAllowedClient == 0 => allow for @all
}

/******************************************************
*	When plugin started
*******************************************************/

public void OnPluginStart()
{
	LoadTranslations("Lethal_AR.phrases");

	// ConVars
	l4d2_lw_lethalweapon	= CreateConVar("l4d2_lw_lethalweapon","1", "Enable Lethal Weapon (0:OFF 1:ON 2:SIMPLE)", CVAR_FLAGS);
	l4d2_lw_lethaldamage	= CreateConVar("l4d2_lw_lethaldamage","3000.0", "Lethal Weapon base damage", CVAR_FLAGS);
	l4d2_lw_lethalforce		= CreateConVar("l4d2_lw_lethalforce","500.0", "Lethal Weapon force", CVAR_FLAGS);
	l4d2_lw_chargetime		= CreateConVar("l4d2_lw_chargetime","7", "Lethal Weapon charge time", CVAR_FLAGS);
	l4d2_lw_shootonce		= CreateConVar("l4d2_lw_shootonce","0", "Survivor can use Lethal Weapon once per round", CVAR_FLAGS);
	l4d2_lw_ff				= CreateConVar("l4d2_lw_ff","0", "Lethal Weapon can deal direct damage to other survivors (0:OFF 1:ON)", CVAR_FLAGS);
	l4d2_lw_friendlyfire	= CreateConVar("l4d2_lw_friendlyfire", "1", "Enable friendly fire - indirect damage, like explosion and fire (0:OFF 1:ON)", FCVAR_NOTIFY);
	l4d2_lw_scout			= CreateConVar("l4d2_lw_scout","1", "Enable Lethal Weapon for Scout", CVAR_FLAGS);
	l4d2_lw_awp				= CreateConVar("l4d2_lw_awp","1", "Enable Lethal Weapon for AWP", CVAR_FLAGS);
	l4d2_lw_huntingrifle	= CreateConVar("l4d2_lw_huntingrifle","1", "Enable Lethal Weapon for Hunting Rifle", CVAR_FLAGS);
	l4d2_lw_g3sg1			= CreateConVar("l4d2_lw_g3sg1","1", "Enable Lethal Weapon for G3SG1", CVAR_FLAGS);
	l4d2_lw_laseroffset		= CreateConVar("l4d2_lw_laseroffset", "36", "Tracker offeset", FCVAR_NOTIFY);
	
	// Additional ConVars
	l4d2_lw_flash				= CreateConVar("l4d2_lw_flash", "1", "Enable screen flash");
	l4d2_lw_chargingsound		= CreateConVar("l4d2_lw_chargingsound", "1", "Enable charging sound");
	l4d2_lw_chargedsound		= CreateConVar("l4d2_lw_chargedsound", "1", "Enable charged up sound");
	l4d2_lw_moveandcharge		= CreateConVar("l4d2_lw_moveandcharge", "1", "Enable charging while crouched and moving");
	l4d2_lw_chargeparticle		= CreateConVar("l4d2_lw_chargeparticle", "1", "Enable showing electric particles when charged");
	l4d2_lw_useammo				= CreateConVar("l4d2_lw_useammo", "1", "Enable and require use of addtional ammunition");
	l4d2_lw_useammocount		= CreateConVar("l4d2_lw_useammo_count", "999", "Number of ammo to use on each lethal shoot");
	l4d2_lw_shake				= CreateConVar("l4d2_lw_shake", "1", "Enable screen shake during explosion");
	l4d2_lw_shake_intensity		= CreateConVar("l4d2_lw_shake_intensity", "50.0", "Intensity of screen shake");
	l4d2_lw_shake_shooteronly	= CreateConVar("l4d2_lw_shake_shooteronly", "0", "Only the shooter experiences screen shake");
	l4d2_lw_firelifetime		= CreateConVar("l4d2_lw_firelifetime", "1", "How many time (in sec.) should flame exist after sniper shooting");
	l4d2_lw_adminonly			= CreateConVar("l4d2_lw_adminonly", "0", "Admin only (0:OFF 1:ON)");
	
	hConVar_FireLifetime = FindConVar("inferno_flame_lifetime");
	
	g_iAmmoOffset = FindSendPropInfo("CTerrorPlayer", "m_iAmmo");
	
	// Hooks
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("weapon_fire", Event_Weapon_Fire);
	HookEvent("bullet_impact", Event_Bullet_Impact);
	HookEvent("player_incapacitated", Event_Player_Incap, EventHookMode_Pre);
	HookEvent("player_hurt", Event_Player_Hurt, EventHookMode_Pre);
	HookEvent("player_death", Event_Player_Hurt, EventHookMode_Pre);
	HookEvent("infected_death", Event_Infected_Hurt, EventHookMode_Pre);
	HookEvent("infected_hurt", Event_Infected_Hurt, EventHookMode_Pre);
	HookEvent("round_start", Event_Round_Start, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_Round_End, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", Event_Round_End, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_Round_End, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_Round_End, EventHookMode_Pre);
	HookEvent("player_bot_replace", 	Event_PlayerBotReplace);
	HookEvent("bot_player_replace", 	Event_BotReplacePlayer);
	
	// Weapon stuff
	CurrentWeapon	= FindSendPropInfo ("CTerrorPlayer", "m_hActiveWeapon");
	ClipSize	= FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	
	//InitCharge();
	
	AutoExecConfig(true, "l4d2_lethal_weapon");

	l4d2_lw_friendlyfire.AddChangeHook(ConVarChanged_Cvars);
	hConVar_FireLifetime.AddChangeHook(ConVarChanged_Cvars);
	
	GetCvars();
}

public void ConVarChanged_Cvars(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_bDamageAlly = l4d2_lw_friendlyfire.BoolValue;
	g_iFireLifetime = hConVar_FireLifetime.IntValue;
}

public void OnMapStart()
{
	InitPrecache();

	for (int i = 1; i <= MaxClients; i++)
	{
		ChargeEndTime[i] = 0;
		ReleaseLock[i] = 0;
		ChargeLock[i] = 0;
		ClientTimer[i] = INVALID_HANDLE;
	}
}

public Action Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) // player has replaced by bot
{
	int iBot = GetClientOfUserId(event.GetInt("bot"));
	int client = GetClientOfUserId(event.GetInt("player"));
	
	ChargeLock[iBot] = ChargeLock[client];
	ChargeLock[client] = 0;
	return Plugin_Handled;
}

public Action Event_BotReplacePlayer(Event event, char[] name, bool dontBroadcast) // bot is replaced by player
{
	int iBot = GetClientOfUserId(event.GetInt("bot"));
	int client = GetClientOfUserId(event.GetInt("player"));
	
	ChargeLock[client] = ChargeLock[iBot];
	ChargeLock[iBot] = 0;
	return Plugin_Handled;
}

/*
void InitCharge()
{
	// Initalize charge parameter
	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		ChargeEndTime[i] = 0;
		ReleaseLock[i] = 0;
		ChargeLock[i] = 0;
		ClientTimer[i] = INVALID_HANDLE;
	}
	for (i = 1; i <= MaxClients; i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2 && !IsFakeClient(i))
				ClientTimer[i] = CreateTimer(0.5, ChargeTimer, i, TIMER_REPEAT);
		}
	}
}
*/

void InitPrecache()
{
	/* Precache models */
	PrecacheModel("models/props_junk/propanecanister001a.mdl", true);
	PrecacheModel("models/props_junk/gascan001a.mdl", true);
	
	/* Precache sounds */
	PrecacheSound(CHARGESOUND, true);
	PrecacheSound(CHARGEDUPSOUND, true);
	PrecacheSound(AWPSHOT, true);
	PrecacheSound(EXPLOSIONSOUND, true);
	
	/* Precache particles */
	PrecacheParticle("gas_explosion_main");
	PrecacheParticle("electrical_arc_01_cp0");
	PrecacheParticle("electrical_arc_01_system");
	
	g_sprite = PrecacheModel(SPRITE_BEAM);
}

public void OnClientPutInServer(int client)
{
	if (GetClientTeam(client) != 3)
		Set_SDKHook(client);
}

public Action Event_Round_Start(Event event, const char[] name, bool dontBroadcast)
{
	g_bBlockBlastDamage = false;
	g_bBlockFireDamage = false;
	return Plugin_Handled;
}

public Action Event_Round_End(Event event, char[] event_name, bool dontBroadcast)
{
	/* Timer end */
	for (int i = 1; i <= MaxClients; i++)
	{
		if (ClientTimer[i] != INVALID_HANDLE)
		{
			delete ClientTimer[i];
			ClientTimer[i] = INVALID_HANDLE;
		}
		if (IsValidEntity(i) && IsClientInGame(i))
		{
			ChargeEndTime[i] = 0;
			ReleaseLock[i] = 0;
			ChargeLock[i] = 0;
		}
		g_bHooked[i] = false;
	}
	return Plugin_Handled;
}

void Set_SDKHook(int client)
{
	if (!g_bHooked[client])
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		g_bHooked[client] = true;
	}
}

/*
void Remove_SDKHook(int client)
{
	if (g_bHooked[client]) 
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		g_bHooked[client] = false;
	}
}
*/

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (g_bBlockBlastDamage || g_bBlockFireDamage)
	{
		if (inflictor == attacker && attacker > MaxClients) // not impersonated entity
		{
			// DMG_BLAST
			// DMG_BURN | DMG_PREVENT_PHYSICS_FORCE
			// DMG_DIRECT | DMG_PREVENT_PHYSICS_FORCE

			if ((g_bBlockBlastDamage && damagetype == DMG_BLAST) || (g_bBlockFireDamage && (damagetype & (DMG_BURN | DMG_DIRECT) != 0)))
			{
				if (victim > 0 && victim <= MaxClients && GetClientTeam(victim) == 2)
				{
					return Plugin_Handled; // block friendly fire on propanetank blast or fire
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action Event_Player_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	/* Timer start */
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client > 0 && client <= MaxClients)
	{
		if (IsValidEntity(client) && IsClientInGame(client))
		{
			if (GetClientTeam(client) == 2)
			{
				if (ClientTimer[client] != INVALID_HANDLE)
					delete ClientTimer[client];
				ChargeLock[client] = 0;
				ClientTimer[client] = CreateTimer(0.5, ChargeTimer, client, TIMER_REPEAT);
			}
		}
	}
	return Plugin_Handled;
}

public Action Event_Player_Incap(Event event, const char[] name, bool dontBroadcast)
{
	/* Reset client condition */
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client != 0)
	{
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = RoundToCeil(GetGameTime()) + l4d2_lw_chargetime.IntValue;
	}
	return Plugin_Handled;
}

public Action Event_Bullet_Impact(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (client != 0 && ReleaseLock[client])
	{
		float TargetPosition[3];
		
		TargetPosition[0] = event.GetFloat("x");
		TargetPosition[1] = event.GetFloat("y");
		TargetPosition[2] = event.GetFloat("z");
		
		/* Explode effect */
		ExplodeMain(TargetPosition);
	}
	return Plugin_Continue;
}

public Action Event_Infected_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));

	if (client != 0 && ReleaseLock[client])
	{
		/* Reset Lethal Weapon lock */
		ReleaseLock[client] = 0;

		int health = event.GetInt("health");
		int damage = l4d2_lw_lethaldamage.IntValue;

		float TargetPosition[3];
		int target = GetClientAimTarget(client, false);
		if (target < 0)
		{
			return Plugin_Continue;
		}

		GetEntityAbsOrigin(target, TargetPosition);
		
		/* Smash target */
		if (l4d2_lw_lethalweapon.IntValue != 2)
			Smash(client, target, l4d2_lw_lethalforce.FloatValue, 1.5, 2.0);
		
		if ((health - damage) < 0)
			damage = health;

		/* Deal lethal damage */
//		SetEntProp(target, Prop_Data, "m_iHealth", health - damage);
		DamageEntity(client, target, damage);

//		health = GetEntProp(target, Prop_Data, "m_iHealth");

		/* Explode effect */
		EmitSoundToAll(EXPLOSIONSOUND, target);
		ExplodeMain(TargetPosition);
	}
	return Plugin_Continue;
}

void DamageEntity(int client, int target, int damage)
{
	char sTemp[16];
	int entity = CreateEntityByName("point_hurt");
	FormatEx(sTemp, sizeof(sTemp), "ext%d%d", EntIndexToEntRef(entity), client);
	DispatchKeyValue(target, "targetname", sTemp);
	DispatchKeyValue(entity, "DamageTarget", sTemp);
	DispatchKeyValue(entity, "DamageType", "8");
	IntToString(damage, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "Damage", sTemp);
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Hurt", client);
	RemoveEdict(entity);
}

public Action Event_Player_Hurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));
	int target = GetClientOfUserId(event.GetInt("userid"));
	int dtype = event.GetInt("type");
	
	if (client != 0 && target != 0 && ReleaseLock[client] && dtype != 268435464)
	{
		/* Reset Lethal Weapon lock */
		ReleaseLock[client] = 0;

		int health = event.GetInt("health");
		int damage = l4d2_lw_lethaldamage.IntValue;
		
//		decl Float:AttackPosition[3];
		float TargetPosition[3];
//		GetClientAbsOrigin(client, AttackPosition);
		GetClientAbsOrigin(target, TargetPosition);
		
		/* Explode effect */
		EmitSoundToAll(EXPLOSIONSOUND, target);
		ExplodeMain(TargetPosition);
		
		/* Smash target */
		if (l4d2_lw_lethalweapon.IntValue != 2)
			Smash(client, target, l4d2_lw_lethalforce.FloatValue, 1.5, 2.0);
		
		if ((health - damage) < 0)
			damage = health;

		/* Deal lethal damage */
		if ((GetClientTeam(client) != GetClientTeam(target)) || l4d2_lw_ff.IntValue) {
//			SetEntProp(target, Prop_Data, "m_iHealth", health - damage);
			DamageEntity(client, target, damage);
		}
	}
	return Plugin_Continue;
}

public Action Event_Weapon_Fire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + l4d2_lw_chargetime.IntValue;
	
	if (client != 0 && ReleaseLock[client])
	{
		if (!g_bDamageAlly)
		{
			g_bBlockBlastDamage = true;
			g_bBlockFireDamage = true;
			CreateTimer(0.5, Timer_AllowBlastDamage, _, TIMER_FLAG_NO_MAPCHANGE);
			CreateTimer(float(g_iFireLifetime) + 1.0, Timer_AllowFireDamage, _, TIMER_FLAG_NO_MAPCHANGE);
		}

		g_iCurWeapon[client] = GetEntDataEnt2(client, CurrentWeapon);

		/* Flash screen */
		if (l4d2_lw_flash.IntValue)
		{
			ScreenFade(client, 200, 200, 255, 255, 100, 1);
		}

		if (l4d2_lw_shake.IntValue)
		{
			ScreenShake(client);
		}
		
		/* Laser effect */
		GetTracePosition(client);
		CreateLaserEffect(client, 0, 0, 200, 230, 2.0, 1.00);
		
		/* Emit sound */
		EmitSoundToAll(
			AWPSHOT, client,
			SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL,
			125, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

		/* Reset client condition */
		CreateTimer(0.2, ReleaseTimer, client);
		if (l4d2_lw_shootonce.IntValue)
		{
			ChargeLock[client] = 1;
			//PrintHintText(client, "Lethal Weapon can only be fired once per round");
		}
		else
		{
			// Enable shooting more than once per round again
			ChargeLock[client] = 0;
		}
	}
	return Plugin_Handled;
}

public Action Timer_AllowBlastDamage(Handle timer)
{
	g_bBlockBlastDamage = false;
	return Plugin_Handled;
}
public Action Timer_AllowFireDamage(Handle timer)
{
	g_bBlockFireDamage = false;
	return Plugin_Handled;
}

public Action ReleaseTimer(Handle timer, any client)
{
	/* Set ammo after using */
	if (l4d2_lw_useammo.IntValue)
	{
		
		char weapon[32];
		GetClientWeapon(client, weapon, 32);
		int iAmmoSpend = GetConVarInt(l4d2_lw_useammocount);
		int iAmmoLeft, iAmmoOffsetToAdd;
		int iAmmoClip = GetEntProp(g_iCurWeapon[client], Prop_Send, "m_iClip1", 0);

		if (g_bLeft4Dead2)
		{
			/* Check weapon class and set Offset to add */
			if (StrEqual(weapon, "weapon_hunting_rifle"))
			{
				iAmmoOffsetToAdd = HUNTING_RIFLE_OFFSET_IAMMO;
			}
			else if (StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp") || StrEqual(weapon, "weapon_sniper_scout"))
					{
						iAmmoOffsetToAdd = MILITARY_SNIPER_OFFSET_IAMMO;
					}

		}
		else
		{
			iAmmoOffsetToAdd = 8;
		}

		/* Set how much ammo should set */
		iAmmoLeft = GetEntData(client, g_iAmmoOffset + iAmmoOffsetToAdd);

		iAmmoLeft -= iAmmoSpend;
		if (iAmmoLeft < 0) iAmmoLeft = 0;

		/* Modify reserve ammunition */
		SetEntData(client, g_iAmmoOffset + iAmmoOffsetToAdd, iAmmoLeft);

		/* Set clip size */
		if ((g_iCurWeapon[client]) != 0)
		{
			if (IsValidEntity(g_iCurWeapon[client]))
			{
				SetEntProp(g_iCurWeapon[client], Prop_Send, "m_iClip1", iAmmoClip + 1);
			}
		}
	}
	
	/* Reset flags */
	ReleaseLock[client] = 0;
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_lw_chargetime);
	return Plugin_Handled;
}

public Action ChargeTimer(Handle timer, any client)
{
	// Make sure we remove the lock if this ConVar is later disabled
	if (l4d2_lw_shootonce.IntValue < 1)
	{
		ChargeLock[client] = 0;
	}

	if (IsClientInGame(client))
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);

	if (!l4d2_lw_lethalweapon.IntValue || ChargeLock[client])
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsValidEntity(client))
	{
		ClientTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	/* Get data */
	int gt = RoundToCeil(GetGameTime());
	int ct = l4d2_lw_chargetime.IntValue;
	int buttons = GetClientButtons(client);
	int WeaponClass = GetEntDataEnt2(client, CurrentWeapon);
	char weapon[32];
	GetClientWeapon(client, weapon, 32);
	int iAmmoSpend = GetConVarInt(l4d2_lw_useammocount);
	int iAmmoLeft, iAmmoOffsetToAdd;

	if (g_bLeft4Dead2)
	{
	/* Check weapon class and set Offset to add */
	if (StrEqual(weapon, "weapon_hunting_rifle"))
		{
				iAmmoOffsetToAdd = HUNTING_RIFLE_OFFSET_IAMMO;
		}
		else if (StrEqual(weapon, "weapon_sniper_military") || StrEqual(weapon, "weapon_sniper_awp") || StrEqual(weapon, "weapon_sniper_scout"))
				{
					iAmmoOffsetToAdd = MILITARY_SNIPER_OFFSET_IAMMO;
				}

	}
	else
	{
		iAmmoOffsetToAdd = 8;
	}

	/* Check how much ammunition left in the weapon */
	iAmmoLeft = GetEntData(client, g_iAmmoOffset + iAmmoOffsetToAdd);

	/* Check if "l4d2_lw_useammocount" > iAmmoLeft , reset it */
	if (iAmmoLeft < iAmmoSpend)
		iAmmoSpend = iAmmoLeft;

	/* These weapons allow you to start charging */
	/* Now allowed: Hunting Rifle, G3SG1, Scout, AWP */
	if (!(StrEqual(weapon, "weapon_sniper_military") && l4d2_lw_g3sg1.IntValue) &&
		!(StrEqual(weapon, "weapon_sniper_awp") && l4d2_lw_awp.IntValue) &&
		!(StrEqual(weapon, "weapon_sniper_scout") && l4d2_lw_scout.IntValue) &&
		!(StrEqual(weapon, "weapon_hunting_rifle") && l4d2_lw_huntingrifle.IntValue))
	{
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
		return Plugin_Continue;
	}
	
	if (!UseAllowed(client))
	{
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
		return Plugin_Continue;
	}

	// Base case to be overridden, just in case someone messes with the ConVar
	int inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
	
        if (l4d2_lw_moveandcharge.IntValue < 1)
        {
		/* Ducked, not moving, not attacking, not incapacitated */
		inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_FORWARD) &&
					!(buttons & IN_MOVERIGHT) &&
					!(buttons & IN_MOVELEFT) &&
					!(buttons & IN_BACK) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
        }
        else
        {
		/* Ducked, moving, not attacking, not incapacitated */
		inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
        }
	
	/* If in charging, display charge bar */
	if (inCharge && GetEntData(WeaponClass, ClipSize) && iAmmoLeft>=iAmmoSpend && iAmmoLeft != 0)
	{
		if (ChargeEndTime[client] < gt)
		{
			/* Charge end, ready to fire */
			PrintCenterText(client, "☠☠☠☠☠☠ %t ☠☠☠☠☠☠", "SHOOT"); // СТРЕЛЯЙ
			if (ReleaseLock[client] != 1)
			{
				float pos[3];
				GetClientAbsOrigin(client, pos);
				if (l4d2_lw_chargedsound.IntValue)
				{
					EmitSoundToAll(CHARGEDUPSOUND, client);
				}
				if (l4d2_lw_chargeparticle.IntValue)
				{
					ShowParticle(pos, "electrical_arc_01_system", 5.0);
				}
			}
			ReleaseLock[client] = 1;
		}
		else
		{
			/* Not charged yet. Display charge gauge */
			int i, j;
			char ChargeBar[50];
			char Gauge1[2] = "|";
			char Gauge2[2] = " ";
			float GaugeNum = (float(ct) - (float(ChargeEndTime[client] - gt))) * (100.0/float(ct))/2.0;
			ReleaseLock[client] = 0;
			if(GaugeNum > 50.0)
				GaugeNum = 50.0;
			
			for(i=0; i<GaugeNum; i++)
				ChargeBar[i] = Gauge1[0];
			for(j=i; j<50; j++)
				ChargeBar[j] = Gauge2[0];
			if (GaugeNum >= 15)
			{
				/* Gauge meter is 30% or more */
				float pos[3];
				GetClientAbsOrigin(client, pos);
				pos[2] += 45;
				if (l4d2_lw_chargeparticle.IntValue)
				{
					ShowParticle(pos, "electrical_arc_01_cp0", 5.0);
				}
				if (l4d2_lw_chargingsound.IntValue)
				{
					EmitSoundToAll(CHARGESOUND, client);
				}
			}
			/* Display gauge */
			PrintCenterText(client, "★★★ %t ★★★\n0%% %s %3.0f%%", "Charging...", ChargeBar, GaugeNum*2); // Заряжается...
		}
	}
	else
	{
		/* Not matching condition */
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
	}
	return Plugin_Continue;
}

public void ExplodeMain(float pos[3])
{
	hConVar_FireLifetime.SetInt(l4d2_lw_firelifetime.IntValue, true, false);

	/* Main effect when hit */
	if (l4d2_lw_chargeparticle.IntValue)
	{
		ShowParticle(pos, "electrical_arc_01_system", l4d2_lw_firelifetime.FloatValue);
	}
	LittleFlower(pos, EXPLODE);
	
	if (l4d2_lw_lethalweapon.IntValue == 1)
	{
		ShowParticle(pos, "gas_explosion_main", l4d2_lw_firelifetime.FloatValue);
		LittleFlower(pos, MOLOTOV);
	}
	CreateTimer(l4d2_lw_firelifetime.FloatValue + 0.5, Timer_RestoreLifeTime);
}

public Action Timer_RestoreLifeTime(Handle timer)
{
	hConVar_FireLifetime.RestoreDefault(true, false);
	return Plugin_Handled;
}

public void ShowParticle(float pos[3], char[] particlename, float time)
{
	/* Show particle effect you like */
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(particle) || IsValidEdict(particle))
	{
		char sBuffer[32];
		sBuffer[0] = 0;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
//		CreateTimer(time, DeleteParticles, particle);
		Format(sBuffer, sizeof(sBuffer), "OnUser1 !self:Kill::%f:-1", time);
		SetVariantString(sBuffer);
		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");
	}  
}

public void PrecacheParticle(char[] particlename)
{
	/* Precache particle */
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEntity(particle) || IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
//		CreateTimer(0.01, DeleteParticles, particle);
		SetVariantString("OnUser1 !self:Kill::0.01:-1");
		AcceptEntityInput(particle, "AddOutput");
		AcceptEntityInput(particle, "FireUser1");
	}  
}

/*
public Action:DeleteParticles(Handle:timer, any:particle)
{
    if (IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
            		RemoveEdict(particle);
	}
}
*/

public void LittleFlower(float pos[3], int type)
{
	/* Cause fire(type=0) or explosion(type=1) */
	int entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		pos[2] += 10.0;
		if (type == 0)
			/* fire */
			DispatchKeyValue(entity, "model", "models/props_junk/gascan001a.mdl");
		else
			/* explode */
			DispatchKeyValue(entity, "model", "models/props_junk/propanecanister001a.mdl");
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "break");
	}
}

public Action GetEntityAbsOrigin(int entity, float origin[3])
{
	/* Get target posision */
	float mins[3], maxs[3];
	GetEntPropVector(entity,Prop_Send,"m_vecOrigin",origin);
	GetEntPropVector(entity,Prop_Send,"m_vecMins",mins);
	GetEntPropVector(entity,Prop_Send,"m_vecMaxs",maxs);
	
	origin[0] += (mins[0] + maxs[0]) * 0.5;
	origin[1] += (mins[1] + maxs[1]) * 0.5;
	origin[2] += (mins[2] + maxs[2]) * 0.5;
	return Plugin_Handled;
}

void Smash(int client, int target, float power, float powHor, float powVec)
{
	/* Smash target */
	// Check so that we don't "smash" other Survivors (only if "l4d2_lw_ff" is 0)
	if (!IsValidClient(client) || !IsValidClient(target))
		return;

	if (l4d2_lw_ff.IntValue || GetClientTeam(target) != 2)
	{
		float HeadingVector[3], AimVector[3];
		GetClientEyeAngles(client, HeadingVector);
	
		AimVector[0] = Cosine(DegToRad(HeadingVector[1])) * (power * powHor);
		AimVector[1] = Sine(DegToRad(HeadingVector[1])) * (power * powHor);
	
		float current[3];
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", current);
	
		float resulting[3];
		resulting[0] = current[0] + AimVector[0];
		resulting[1] = current[1] + AimVector[1];
		resulting[2] = power * powVec;
	
		TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, resulting);
	}
}

bool IsValidClient(int client) 
{
    return ((1 <= client <= MaxClients) && IsClientInGame(client));
}

public void ScreenFade(int target, int red, int green, int blue, int alpha, int duration, int type)
{
	Handle msg = StartMessageOne("Fade", target);
	if (msg == INVALID_HANDLE)
		return;
	BfWriteShort(msg, 500);
	BfWriteShort(msg, duration);
	if (type == 0)
	{
		BfWriteShort(msg, (0x0002 | 0x0008));
	}
	else
	{
		BfWriteShort(msg, (0x0001 | 0x0010));
	}
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public void ScreenShake(int target)
{
	Handle msg;
	if (l4d2_lw_shake_shooteronly.IntValue)
	{
		msg = StartMessageAll("Shake");
	}
	else
	{
		msg = StartMessageOne("Shake", target);
	}
	if (msg == INVALID_HANDLE)
		return;
	BfWriteByte(msg, 0);
 	BfWriteFloat(msg, l4d2_lw_shake_intensity.FloatValue);
 	BfWriteFloat(msg, 10.0);
 	BfWriteFloat(msg, 3.0);
	EndMessage();
}

public void GetTracePosition(int client)
{
	float myAng[3];
	GetClientEyePosition(client, myPos);
	GetClientEyeAngles(client, myAng);
	Handle trace = TR_TraceRayFilterEx(myPos, myAng, CONTENTS_SOLID|CONTENTS_MOVEABLE, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
		TR_GetEndPosition(trsPos, trace);
	delete trace;
	for(int i = 0; i < 3; i++)
		trsPos002[i] = trsPos[i];
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
	return entity > MaxClients || !entity;
}

public void CreateLaserEffect(int client, int colRed, int colGre, int colBlu, int alpha, float width, float duration)
{
	float tmpVec[3];
	SubtractVectors(myPos, trsPos, tmpVec);
	NormalizeVector(tmpVec, tmpVec);
	ScaleVector(tmpVec, l4d2_lw_laseroffset.FloatValue);
	SubtractVectors(myPos, tmpVec, trsPos);
	
	int color[4];
	color[0] = colRed; 
	color[1] = colGre;
	color[2] = colBlu;
	color[3] = alpha;
	TE_SetupBeamPoints(myPos, trsPos002, g_sprite, 0, 0, 0, duration, width, width, 1, 0.0, color, 0);
	TE_SendToAll();
}

bool HasAccess(int client)
{
	/* check player whether have access flag */
	if (CheckCommandAccess(client, "lethal_weapon", 0, true))
	{
		return true;
	}
	else
	{
		return false;
	}
}