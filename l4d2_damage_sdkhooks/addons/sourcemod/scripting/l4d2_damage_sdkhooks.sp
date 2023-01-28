#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_VERSION							"1.0.9"

#define TEST_DEBUG								0
#define TEST_DEBUG_LOG						 	0

#define				MAX_MODDED_WEAPONS			64
#define				CLASS_STRINGLENGHT			32

#define 		ZOMBIECLASS_SMOKER				1
#define 		ZOMBIECLASS_BOOMER				2
#define 		ZOMBIECLASS_HUNTER				3
#define 		ZOMBIECLASS_SPITTER				4
#define 		ZOMBIECLASS_JOCKEY				5
#define 		ZOMBIECLASS_CHARGER 			6
#define 		ZOMBIECLASS_TANK 				8

static const	L4D2_TEAM_INFECTED			=  3;

static const Float:DAMAGE_MOD_NONE			= 1.0;

static const String:ENTPROP_MELEE_STRING[]	= "m_strMapSetScriptName";
static const String:CLASSNAME_INFECTED[]  	= "infected";
static const String:CLASSNAME_MELEE_WPN[] 	= "weapon_melee";
static const String:CLASSNAME_WITCH[]	 	= "witch";

/*
static const String:ENTPROP_OWNER_ENT[]	  	= "m_hOwnerEntity";
static const String:ENTPROP_ZOMBIE_CLASS[]= "m_zombieClass";
static const String:CLASSNAME_PLAYER[]	  = "player";
static const String:CLASSNAME_SMOKER[]	  = "smoker";
static const String:CLASSNAME_BOOMER[]	  = "boomer";
static const String:CLASSNAME_HUNTER[]	  = "hunter";
static const String:CLASSNAME_SPITTER[]	  = "spitter";
static const String:CLASSNAME_JOCKEY[]	  = "jockey";
static const String:CLASSNAME_CHARGER[]	  = "charger";
static const String:CLASSNAME_TANK[]	  = "tank";
*/


static String:damageModConfigFile[PLATFORM_MAX_PATH]	= "";
static Handle:keyValueHolder							= INVALID_HANDLE;
static Handle:weaponIndexTrie							= INVALID_HANDLE;

enum weaponModData
{
	Float:damageModifierFriendly,
	Float:damageModifierEnemy
}

static damageModArray[MAX_MODDED_WEAPONS][weaponModData];


public Plugin:myinfo =
{
	name = "L4D2 Damage Mod SDKHooks",
	author = "AtomicStryker",
	description = "Modify damage",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1184761"
};

public OnPluginStart()
{
	decl String:game_name[CLASS_STRINGLENGHT];
	GetGameFolderName(game_name, sizeof(game_name));
	if (StrContains(game_name, "left4dead", false) < 0)
	{
		SetFailState("Plugin supports L4D2 only.");
	}

	CreateConVar("l4d2_damage_mod_version", PLUGIN_VERSION, "L4D2 Damage Mod Version", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	
	RegAdminCmd("sm_reloaddamagemod", cmd_ReloadData, ADMFLAG_CHEATS, "Reload the setting file for live changes");
}

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public OnEntityCreated(entity, const String:classname[])
{
	if (StrEqual(classname, CLASSNAME_INFECTED, false) || StrEqual(classname, CLASSNAME_WITCH, false))
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public OnMapStart()
{
	ReloadKeyValues();
}

public Action:cmd_ReloadData(client, args)
{
	ReloadKeyValues();
	ReplyToCommand(client, "L4D2 Damage Mod config file re-loaded");
	return Plugin_Handled;
}

static ReloadKeyValues()
{
	if (weaponIndexTrie != INVALID_HANDLE)
	{
		CloseHandle(weaponIndexTrie);
	}
	weaponIndexTrie = CreateTrie();

	BuildPath(Path_SM, damageModConfigFile, sizeof(damageModConfigFile), "configs/l4d2damagemod.cfg");
	if(!FileExists(damageModConfigFile)) 
	{
		SetFailState("l4d2damagemod.cfg cannot be read ... FATAL ERROR!");
	}
	
	if (keyValueHolder != INVALID_HANDLE)
	{
		CloseHandle(keyValueHolder);
	}
	keyValueHolder = CreateKeyValues("l4d2damagemod");
	FileToKeyValues(keyValueHolder, damageModConfigFile);
	KvRewind(keyValueHolder);
	
	if (KvGotoFirstSubKey(keyValueHolder))
	{
		new i = 0;
		decl String:buffer[CLASS_STRINGLENGHT], Float:value;
		do
		{
			KvGetString(keyValueHolder, "weapon_class", buffer, sizeof(buffer), "1.0");
			SetTrieValue(weaponIndexTrie, buffer, i);
			DebugPrintToAll("Dataset %i, weapon_class %s read and saved", i, buffer);
			
			KvGetString(keyValueHolder, "modifier_friendly", buffer, sizeof(buffer), "1.0");
			value = StringToFloat(buffer);
			damageModArray[i][damageModifierFriendly] = value;
			DebugPrintToAll("Dataset %i, modifier_friendly %f read and saved", i, value);
			
			KvGetString(keyValueHolder, "modifier_enemy", buffer, sizeof(buffer), "1.0");
			value = StringToFloat(buffer);
			damageModArray[i][damageModifierEnemy] = value;
			DebugPrintToAll("Dataset %i, modifier_enemy %f read and saved", i, value);
			
			i++;
		}
		while (KvGotoNextKey(keyValueHolder));
	}
	else
	{
		SetFailState("l4d2damagemod.cfg cannnot be parsed ... No subkeys found!");
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	DebugPrintToAll("attacker %i, inflictor %i dealt [%f] damage to victim %i", attacker, inflictor, damage, victim);

	if (!inflictor
	|| !attacker
	|| !victim
	|| !IsValidEdict(victim)
	|| !IsValidEdict(inflictor))
	{
		return Plugin_Continue;
	}
	
	decl String:classname[CLASS_STRINGLENGHT];
	new bool:bHumanAttacker = false;
	
	if (attacker > 0
	&& attacker <= MaxClients
	&& IsClientInGame(attacker))
	{
		bHumanAttacker = true;	// case: player entity attacks
		
		if (attacker == inflictor) // case: attack with an equipped weapon (guns, claws)
		{
			GetClientWeapon(inflictor, classname, sizeof(classname));
			
			//new weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
			//GetEdictClassname(weapon, "classname", sizeof(classname));
		}
		else
		{
			GetEdictClassname(inflictor, classname, sizeof(classname)); // tank special case?
		}
	}
	
	else // case: other entity inflicts damage (eg throwable, ability)
	{
		GetEdictClassname(inflictor, classname, sizeof(classname));
		
		/*
		if (StrEqual(classname, CLASSNAME_PLAYER)) // subcase Special Infected attack
		{
			switch (GetEntProp(attacker, Prop_Send, ENTPROP_ZOMBIE_CLASS))
			{
				case ZOMBIECLASS_SMOKER: 	Format(classname, sizeof(classname), CLASSNAME_SMOKER);
				case ZOMBIECLASS_BOOMER: 	Format(classname, sizeof(classname), CLASSNAME_BOOMER);
				case ZOMBIECLASS_HUNTER: 	Format(classname, sizeof(classname), CLASSNAME_HUNTER);
				case ZOMBIECLASS_SPITTER: 	Format(classname, sizeof(classname), CLASSNAME_SPITTER);
				case ZOMBIECLASS_JOCKEY: 	Format(classname, sizeof(classname), CLASSNAME_JOCKEY);
				case ZOMBIECLASS_CHARGER: 	Format(classname, sizeof(classname), CLASSNAME_CHARGER);
				case ZOMBIECLASS_TANK: 		Format(classname, sizeof(classname), CLASSNAME_TANK);
			}
		}
		*/
	}
	
	if (StrEqual(classname, CLASSNAME_MELEE_WPN)) // subcase melee weapons
	{
		GetEntPropString(GetPlayerWeaponSlot(attacker, 1), Prop_Data, ENTPROP_MELEE_STRING, classname, sizeof(classname));
	}
	
	DebugPrintToAll("configurable class name: %s", classname);
	
	new i;
	if (!GetTrieValue(weaponIndexTrie, classname, i)) return Plugin_Continue;
	
	new teamattacker, teamvictim, Float:damagemod;
	
	new bool:bHumanVictim = (victim <= MaxClients && IsClientInGame(victim));
	
	if (bHumanAttacker) // case: attacker human player
	{
		teamattacker = GetClientTeam(attacker);
		
		if (bHumanVictim) // case: victim also human player
		{
			teamvictim = GetClientTeam(victim);
			if (teamattacker == teamvictim)
			{
				damagemod = damageModArray[i][damageModifierFriendly];
			}
			else
			{
				damagemod = damageModArray[i][damageModifierEnemy];
			}
		}
		else // case: victim is witch or common or some other entity, we'll assume an adversary
		{
			if (teamattacker == L4D2_TEAM_INFECTED)
			{
				damagemod = damageModArray[i][damageModifierFriendly];
			}
			else
			{
				damagemod = damageModArray[i][damageModifierEnemy];
			}
		}
	}
	else if (bHumanVictim) // case: attacker witch or common, victim human player
	{

		teamvictim = GetClientTeam(victim);
		if (teamvictim == L4D2_TEAM_INFECTED)
		{
			damagemod = damageModArray[i][damageModifierFriendly];
		}
		else
		{
			damagemod = damageModArray[i][damageModifierEnemy];
		}
	}
	else return Plugin_Continue; // entity-to-entity damage is unhandled
	
	if (FloatCompare(damagemod, DAMAGE_MOD_NONE) != 0)
	{
		damage = damage * damagemod;
		DebugPrintToAll("Damage modded by [%f] to [%f]", damagemod, damage);
	}
	
	return Plugin_Changed;
}

stock DebugPrintToAll(const String:format[], any:...)
{
	#if TEST_DEBUG	|| TEST_DEBUG_LOG
	decl String:buffer[192];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	#if TEST_DEBUG
	PrintToChatAll("[DAMAGE] %s", buffer);
	PrintToConsole(0, "[DAMAGE] %s", buffer);
	#endif
	
	LogMessage("%s", buffer);
	#else
	//suppress "format" never used warning
	if(format[0])
		return;
	else
		return;
	#endif
}