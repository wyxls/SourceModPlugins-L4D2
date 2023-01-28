#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1.3"

#define TEST_DEBUG			0
#define TEST_DEBUG_LOG		1

#define DEFAULT_FLAGS FCVAR_NOTIFY

/*
Datamap m_iAmmo
offset to add - gun(s) - control cvar

+12: M4A1, AK74, Desert Rifle, also SG552 - ammo_assaultrifle_max
+20: both SMGs, also the MP5 - ammo_smg_max
+28: both Pump Shotguns - ammo_shotgun_max
+32: both autoshotguns - ammo_autoshotgun_max
+36: Hunting Rifle - ammo_huntingrifle_max
+40: Military Sniper, AWP, Scout - ammo_sniperrifle_max
+68: Grenade Launcher - ammo_grenadelauncher_max
*/

static const	ASSAULT_RIFLE_OFFSET_IAMMO		= 12;
static const	SMG_OFFSET_IAMMO				= 20;
static const	PUMPSHOTGUN_OFFSET_IAMMO		= 28;
static const	AUTO_SHOTGUN_OFFSET_IAMMO		= 32;
static const	HUNTING_RIFLE_OFFSET_IAMMO		= 36;
static const	MILITARY_SNIPER_OFFSET_IAMMO	= 40;
static const	GRENADE_LAUNCHER_OFFSET_IAMMO	= 68;

/*
Further info:

On a dropped or carried weapon Prop_Send "m_iClip1" contains the primary ammo amount
On dropped weapons (only!) Prop_Send "m_iExtraPrimaryAmmo" contains the reserve ammo amount 


weapon_rifle_m60_spawn is the new 'The Passing' gun, ammo is not in m_iAmmo
m60 ammo is stored in gun entity, in m_iClip1

spawn: class "weapon_rifle_m60_spawn"
gun: class "weapon_rifle_m60_spawn"
item_pickup item id: "rifle_m60"
*/

static Handle:AssaultAmmoCVAR = INVALID_HANDLE;
static Handle:SMGAmmoCVAR = INVALID_HANDLE;
static Handle:ShotgunAmmoCVAR = INVALID_HANDLE;
static Handle:AutoShotgunAmmoCVAR = INVALID_HANDLE;
static Handle:HRAmmoCVAR = INVALID_HANDLE;
static Handle:SniperRifleAmmoCVAR = INVALID_HANDLE;
static Handle:GrenadeLauncherAmmoCVAR = INVALID_HANDLE;
static Handle:M60AmmoCVAR = INVALID_HANDLE;

static Handle:GrenadeResupplyCVAR = INVALID_HANDLE;
static Handle:M60ResupplyCVAR = INVALID_HANDLE;
static Handle:GLtoM60TransformCVAR = INVALID_HANDLE;
static Handle:IncendAmmoMultiplier = INVALID_HANDLE;
static Handle:SplosiveAmmoMultiplier = INVALID_HANDLE;

static bool:buttondelay[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "L4D2 Gun Control",
	author = "AtomicStryker",
	description = " Allows Customization of some gun related game mechanics ",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1020236"
}

public OnPluginStart()
{
	// Requires Left 4 Dead 2
	decl String:game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead2", false))
		SetFailState("Plugin supports Left 4 Dead 2 only.");
	
	CreateConVar("l4d2_guncontrol_version", PLUGIN_VERSION, " Version of L4D2 Gun Control on this server ", DEFAULT_FLAGS|FCVAR_SPONLY|FCVAR_DONTRECORD);
	
	AssaultAmmoCVAR = CreateConVar("l4d2_guncontrol_assaultammo", "360", " How much Ammo for Assault Rifles ", DEFAULT_FLAGS);
	SMGAmmoCVAR = CreateConVar("l4d2_guncontrol_smgammo", "650", " How much Ammo for SMG gun types ", DEFAULT_FLAGS);
	ShotgunAmmoCVAR = CreateConVar("l4d2_guncontrol_shotgunammo", "56", " How much Ammo for Shotgun and Chrome Shotgun ", DEFAULT_FLAGS);
	AutoShotgunAmmoCVAR = CreateConVar("l4d2_guncontrol_autoshotgunammo", "90", " How much Ammo for Autoshottie and SPAS ", DEFAULT_FLAGS);
	HRAmmoCVAR = CreateConVar("l4d2_guncontrol_huntingrifleammo", "150", " How much Ammo for the Hunting Rifle ", DEFAULT_FLAGS);
	SniperRifleAmmoCVAR = CreateConVar("l4d2_guncontrol_sniperrifleammo", "180", " How much Ammo for the Military Sniper Rifle, AWP, and Scout ", DEFAULT_FLAGS);	
	GrenadeLauncherAmmoCVAR = CreateConVar("l4d2_guncontrol_grenadelauncherammo", "30", " How much Ammo for the Grenade Launcher ", DEFAULT_FLAGS);
	M60AmmoCVAR = CreateConVar("l4d2_guncontrol_m60ammo", "150", " How much Ammo for the M60 ", DEFAULT_FLAGS);	
	
	GrenadeResupplyCVAR = CreateConVar("l4d2_guncontrol_allowgrenadereplenish", "1", " Do you allow Players to resupply the Grenadelauncher off ammospots ", DEFAULT_FLAGS);
	M60ResupplyCVAR = CreateConVar("l4d2_guncontrol_allowm60replenish", "1", " Do you allow Players to resupply the M60 off ammospots ", DEFAULT_FLAGS);
	GLtoM60TransformCVAR = CreateConVar("l4d2_guncontrol_turnGLintoM60chance", "2", " Turns GL spawns into M60 spawns. Works as chance setting. 1 is FULL chance, 2 is half chance, 3 one third and so on ", DEFAULT_FLAGS);
	IncendAmmoMultiplier = CreateConVar("l4d2_guncontrol_incendammomulti", "3", " Multiplier for Incendiary Ammo Pickup Amount ", DEFAULT_FLAGS);
	SplosiveAmmoMultiplier = CreateConVar("l4d2_guncontrol_explosiveammomulti", "1", " Multiplier for Explosive Ammo Pickup Amount ", DEFAULT_FLAGS);
	
	HookConVarChange(AssaultAmmoCVAR, CVARChanged);
	HookConVarChange(SMGAmmoCVAR, CVARChanged);
	HookConVarChange(ShotgunAmmoCVAR, CVARChanged);
	HookConVarChange(AutoShotgunAmmoCVAR, CVARChanged);
	HookConVarChange(HRAmmoCVAR, CVARChanged);
	HookConVarChange(SniperRifleAmmoCVAR, CVARChanged);
	HookConVarChange(GrenadeLauncherAmmoCVAR, CVARChanged);
	
	HookEvent("upgrade_pack_added", Event_SpecialAmmo);
	
	RegConsoleCmd("give_ammo", Cmd_GiveAmmo, "Gives the Player you look at your current ammo clip");
	RegAdminCmd("sm_guncontroldebug", Cmd_ReadGunData, ADMFLAG_ROOT, " Reads your current weapons data ");
	
	HookEvent("item_pickup", Event_Item_Pickup);
	HookEvent("round_start", Event_Round_Start);
	
	AutoExecConfig(true, "l4d2_guncontrol");
	
	UpdateConVars();
}

public OnMapStart()
{
	UpdateConVars();
}

public CVARChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	UpdateConVars();
}

UpdateConVars()
{
	SetConVarInt(FindConVar("ammo_assaultrifle_max"), GetConVarInt(AssaultAmmoCVAR));
	SetConVarInt(FindConVar("ammo_smg_max"), GetConVarInt(SMGAmmoCVAR));
	SetConVarInt(FindConVar("ammo_shotgun_max"), GetConVarInt(ShotgunAmmoCVAR));
	SetConVarInt(FindConVar("ammo_autoshotgun_max"), GetConVarInt(AutoShotgunAmmoCVAR));
	SetConVarInt(FindConVar("ammo_huntingrifle_max"), GetConVarInt(HRAmmoCVAR));
	SetConVarInt(FindConVar("ammo_sniperrifle_max"), GetConVarInt(SniperRifleAmmoCVAR));
	SetConVarInt(FindConVar("ammo_grenadelauncher_max"), GetConVarInt(GrenadeLauncherAmmoCVAR));
}

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Handle:UnlockGunsPlugin = FindConVar("l4d2_WeaponUnlock");
	if (UnlockGunsPlugin == INVALID_HANDLE) return;

	decl String:version[12];
	GetConVarString(UnlockGunsPlugin, version, sizeof(version));
	
	new unlockversion = ParseVersionNumber(version);
	new neededversion = ParseVersionNumber("0.8.2");
	if (unlockversion < neededversion) return;
	
	DebugPrintToAll("Unlock Plugin found, requirements for M60 exchange met, moving on");

	CreateTimer(10.0, ReplaceGLWithM60Delayed);
	if (!IsModelPrecached("models/w_models/weapons/w_m60.mdl")) PrecacheModel("models/w_models/weapons/w_m60.mdl");
	if (!IsModelPrecached("models/v_models/v_m60.mdl")) PrecacheModel("models/v_models/v_m60.mdl");
}

stock ParseVersionNumber(const String:versionText[])
{
	new String:versionNumbers[4][4];
	ExplodeString(versionText, /* split */ ".", versionNumbers, .maxStrings = 4, .maxStringLength = 4);
	
	new version = 0;
	new shift = 24;
	for(new i = 0; i < sizeof(versionNumbers); i++)
	{
		version = version | (StringToInt(versionNumbers[i]) << shift);
		
		shift -= 8;
	}
	
	return version;
}

public Action:ReplaceGLWithM60Delayed(Handle:timer)
{
	ReplaceGrenadeLauncherWithM60(GetConVarInt(GLtoM60TransformCVAR));
}

ReplaceGrenadeLauncherWithM60(chance)
{
	if (chance == 0) return;

	new ent = -1;
	new prev = 0;
	new replacement;
	decl Float:origin[3];
	decl Float:angles[3];
	while ((ent = FindEntityByClassname(ent, "weapon_grenade_launcher_spawn")) != -1)
	{
		if (prev)
		{
			if (GetRandomInt(1, chance) == 1)
			{
				GetEntPropVector(prev, Prop_Send, "m_vecOrigin", origin);
				GetEntPropVector(prev, Prop_Send, "m_angRotation", angles);
				
				replacement = CreateEntityByName("weapon_rifle_m60");
				DispatchSpawn(replacement);
				DebugPrintToAll("Replacing weapon_grenade_launcher_spawn %i with weapon_rifle_m60 %i", prev, replacement);
				if (!IsValidEdict(replacement)) return;
				
				TeleportEntity(replacement, origin, angles, NULL_VECTOR);
				SetEntProp(replacement, Prop_Data, "m_iClip1", GetConVarInt(M60AmmoCVAR), 1);
				DebugPrintToAll("Teleported weapon_rifle_m60 %i into position, removing weapon_grenade_launcher_spawn now", replacement);
				
				if (IsValidEdict(prev)) RemoveEdict(prev);
			}
		}
		prev = ent;
	}
	if (prev)
	{
		if (GetRandomInt(1, chance) == 1)
		{
			GetEntPropVector(prev, Prop_Send, "m_vecOrigin", origin);
			GetEntPropVector(prev, Prop_Send, "m_angRotation", angles);
			
			replacement = CreateEntityByName("weapon_rifle_m60");
			DispatchSpawn(replacement);
			DebugPrintToAll("Replacing weapon_grenade_launcher_spawn %i with weapon_rifle_m60 %i", prev, replacement);
			if (!IsValidEdict(replacement)) return;
			
			TeleportEntity(replacement, origin, angles, NULL_VECTOR);
			SetEntProp(replacement, Prop_Data, "m_iClip1", GetConVarInt(M60AmmoCVAR), 1);
			DebugPrintToAll("Teleported weapon_rifle_m60 %i into position, removing weapon_grenade_launcher_spawn now", replacement);
			
			if (IsValidEdict(prev)) RemoveEdict(prev);
		}
	}
}

public Action:Event_Item_Pickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client)) return;
	
	decl String:itemname[128];
	GetEventString(event, "item", itemname, sizeof(itemname));
	//PrintToChat(client, "You picked up: %s", itemname);
	if (!StrEqual(itemname, "rifle_m60", false)) return;
	
	new targetgun = GetPlayerWeaponSlot(client, 0);
	if (!IsValidEdict(targetgun)) return;
	SetEntProp(targetgun, Prop_Data, "m_iClip1", GetConVarInt(M60AmmoCVAR), 1);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_USE && !buttondelay[client])
	{
		CreateTimer(2.0, ResetDelay, client); //add a button delay to prevent multiple firings
		
		new gun = GetClientAimTarget(client, false); //get the entity player is looking at
		if (gun < 32) return Plugin_Continue; //below 32 is a player or null, invalid
		if (!IsValidEdict(gun)) return Plugin_Continue; //lets check for validity anyhow
		
		decl String:ent_name[64];
		GetEdictClassname(gun, ent_name, sizeof(ent_name)); //get the entities name
		
		new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
		if (!IsValidEdict(oldgun)) return Plugin_Continue; //check for validity
		
		decl String:currentgunname[64];
		GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
		
		// later added grenade launcher remunition code, where "gun" actually is an ammopile.
		if (StrEqual(ent_name, "weapon_ammo_spawn", false) && StrEqual(currentgunname, "weapon_grenade_launcher", false) && GetConVarBool(GrenadeResupplyCVAR))
		{
			new iAmmoOffset = FindDataMapInfo(client, "m_iAmmo");
			SetEntData(client, iAmmoOffset + GRENADE_LAUNCHER_OFFSET_IAMMO, GetConVarInt(GrenadeLauncherAmmoCVAR));
			PrintHintText(client, "你补充了榴弹枪子弹!");
		}
		
		// later added m60 remunition code, where "gun" actually is an ammopile.
		if (StrEqual(ent_name, "weapon_ammo_spawn", false) && StrEqual(currentgunname, "weapon_rifle_m60", false) && GetConVarBool(M60ResupplyCVAR))
		{
			SetEntProp(oldgun, Prop_Data, "m_iClip1", GetConVarInt(M60AmmoCVAR), 1);
			PrintHintText(client, "你补充了M60子弹!");
		}
		
		if (!StrEqual(ent_name, currentgunname)) return Plugin_Continue; //if entity and primary weapon dont have the same name theyre incompatible
		
		new iAmmoOffset = FindDataMapInfo(client, "m_iAmmo"); //get the iAmmo Offset
		decl offsettoadd, maxammo;
		
		if (StrEqual(ent_name, "weapon_rifle", false) || StrEqual(ent_name, "weapon_rifle_ak47", false) || StrEqual(ent_name, "weapon_rifle_desert", false) || StrEqual(ent_name, "weapon_rifle_sg552", false))
		{ //case: Assault rifles
			offsettoadd = ASSAULT_RIFLE_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(AssaultAmmoCVAR); //get max ammo as set
		}
		else if (StrEqual(ent_name, "weapon_smg", false) || StrEqual(ent_name, "weapon_smg_silenced", false) || StrEqual(ent_name, "weapon_smg_mp5", false))
		{ //case: SMGS
			offsettoadd = SMG_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(SMGAmmoCVAR); //get max ammo as set
		}		
		else if (StrEqual(ent_name, "weapon_pumpshotgun", false) || StrEqual(ent_name, "weapon_shotgun_chrome", false))
		{ //case: Pump Shotguns
			offsettoadd = PUMPSHOTGUN_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(ShotgunAmmoCVAR); //get max ammo as set
		}
		else if (StrEqual(ent_name, "weapon_autoshotgun", false) || StrEqual(ent_name, "weapon_shotgun_spas", false))
		{ //case: Auto Shotguns
			offsettoadd = AUTO_SHOTGUN_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(AutoShotgunAmmoCVAR); //get max ammo as set
		}
		else if (StrEqual(ent_name, "weapon_hunting_rifle", false))
		{ //case: Hunting Rifle
			offsettoadd = HUNTING_RIFLE_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(HRAmmoCVAR); //get max ammo as set
		}
		else if (StrEqual(ent_name, "weapon_sniper_military", false) || StrEqual(ent_name, "weapon_sniper_awp", false) || StrEqual(ent_name, "weapon_sniper_scout", false))
		{ //case: Military Sniper Rifle or CSS Snipers
			offsettoadd = MILITARY_SNIPER_OFFSET_IAMMO; //gun type specific offset
			maxammo = GetConVarInt(SniperRifleAmmoCVAR); //get max ammo as set
		}
		else
		{ //case: no gun this plugin recognizes
			return Plugin_Continue;
		}
		
		new currentammo = GetEntData(client, (iAmmoOffset + offsettoadd)); //get current ammo
		
		if (currentammo >= maxammo) return Plugin_Continue; //if youre full, do nothing
		
		new foundgunammo = GetEntProp(gun, Prop_Send, "m_iExtraPrimaryAmmo", 4); //get the lying around guns contained ammo
		if (!foundgunammo) //if its zero
		{
			PrintHintText(client, "那把枪已经空弹"); //the gun is empty, bug out
			return Plugin_Continue;
		}
		
		if ((currentammo + foundgunammo) <= maxammo) //if contained ammo is less than youd need to be full
		{
			SetEntData(client, (iAmmoOffset + offsettoadd), (currentammo + foundgunammo), 4, true); //add bullets to your supply
			SetEntProp(gun, Prop_Send, "m_iExtraPrimaryAmmo",0 ,4); //empty the gun
			PrintHintText(client, "你从那把枪上搜寻到了 %i 发子弹", foundgunammo); //imform the client
		}
		else //if contained ammo exceeds your needs
		{
			new neededammo = (maxammo - currentammo); //find out how much exactly you need
			SetEntData(client, (iAmmoOffset + offsettoadd), maxammo, 4, true); //fill you up
			SetEntProp(gun, Prop_Send, "m_iExtraPrimaryAmmo",(foundgunammo - neededammo) ,4); //take needed ammo from gun
			PrintHintText(client, "你从那把枪上搜寻到了 %i 发子弹", neededammo); //inform the client
		}
	}
	
	return Plugin_Continue;
}

public Action:ResetDelay(Handle:timer, any:client)
{
	buttondelay[client] = false;
}

public Action:Cmd_GiveAmmo(client, args)
{
	if (!client) client=1;
	new target = GetClientAimTarget(client, true); //get the player our client is looking at
	if (!target || !IsClientInGame(target)) return Plugin_Handled; //invalid
	
	new targetgun = GetPlayerWeaponSlot(target, 0); //get the players primary weapon
	if (!IsValidEdict(targetgun)) return Plugin_Handled; //check for validity
	
	decl String:targetgunname[64];
	GetEdictClassname(targetgun, targetgunname, sizeof(targetgunname));
	
	new oldgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
	if (!IsValidEdict(oldgun)) return Plugin_Handled; //check for validity
	
	decl String:currentgunname[64];
	GetEdictClassname(oldgun, currentgunname, sizeof(currentgunname)); //get the primary weapon name
	
	if (!StrEqual(targetgunname, currentgunname))
	{
		PrintToChat(client, "\x04[Guncontrol] \x03只有你拿着\x05相同武器\x03才能把子弹送给\x05%N", target);
		return Plugin_Handled; //if targets and your weapon dont have the same name theyre incompatible
	}
	
	if (GetEntProp(oldgun, Prop_Send, "m_iClip1", 1)<2) 
	{
		PrintToChat(client, "\x04[Guncontrol] \x03你的枪需要有一盒弹匣才能把送给\x05%N", target);
		return Plugin_Handled;
	}
	
	new iAmmoOffset = FindDataMapInfo(target, "m_iAmmo"); //get the iAmmo Offset
	decl offsettoadd, maxammo;
	
	if (StrEqual(currentgunname, "weapon_rifle", false) || StrEqual(currentgunname, "weapon_rifle_ak47", false) || StrEqual(currentgunname, "weapon_rifle_desert", false) || StrEqual(currentgunname, "weapon_rifle_sg552", false))
	{ //case: Assault rifles
		offsettoadd = ASSAULT_RIFLE_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(AssaultAmmoCVAR); //get max ammo as set
	}
	else if (StrEqual(currentgunname, "weapon_smg", false) || StrEqual(currentgunname, "weapon_smg_silenced", false) || StrEqual(currentgunname, "weapon_smg_mp5", false))
	{ //case: SMGS
		offsettoadd = SMG_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(SMGAmmoCVAR); //get max ammo as set
	}		
	else if (StrEqual(currentgunname, "weapon_pumpshotgun", false) || StrEqual(currentgunname, "weapon_shotgun_chrome", false))
	{ //case: Pump Shotguns
		offsettoadd = PUMPSHOTGUN_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(ShotgunAmmoCVAR); //get max ammo as set
	}
	else if (StrEqual(currentgunname, "weapon_autoshotgun", false) || StrEqual(currentgunname, "weapon_shotgun_spas", false))
	{ //case: Auto Shotguns
		offsettoadd = AUTO_SHOTGUN_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(AutoShotgunAmmoCVAR); //get max ammo as set
	}
	else if (StrEqual(currentgunname, "weapon_hunting_rifle", false))
	{ //case: Hunting Rifle
		offsettoadd = HUNTING_RIFLE_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(HRAmmoCVAR); //get max ammo as set
	}
	else if (StrEqual(currentgunname, "weapon_sniper_military", false) || StrEqual(currentgunname, "weapon_sniper_awp", false) || StrEqual(currentgunname, "weapon_sniper_scout", false))
	{ //case: Military Sniper Rifle or CSS Snipers
		offsettoadd = MILITARY_SNIPER_OFFSET_IAMMO; //gun type specific offset
		maxammo = GetConVarInt(SniperRifleAmmoCVAR); //get max ammo as set
	}
	else
	{ //case: no gun this plugin recognizes
		PrintToChat(client, "\x04[Guncontrol] \x03等等, 这是什么枪?");
		return Plugin_Handled;
	}
	
	new currentammo = GetEntData(target, (iAmmoOffset + offsettoadd)); //get targets current ammo
	
	if (currentammo >= maxammo) //if hes full, do nothing
	{
		PrintToChat(client, "\x04[Guncontrol] \x03那家伙的子弹是满的");
		return Plugin_Handled;
	}
	
	new donateammo = GetEntProp(oldgun, Prop_Send, "m_iClip1", 1)-1; //you give your current gun clip minus the bullet thats in the barrel
	
	if ((currentammo + donateammo) <= maxammo) //if clips ammo is less than hed need to be full
	{
		SetEntData(target, (iAmmoOffset + offsettoadd), (currentammo + donateammo), 4, true); //add bullets to his supply
		SetEntProp(oldgun, Prop_Send, "m_iClip1",1 ,1); //empty your gun
		PrintToChat(client, "\x04[Guncontrol] \x03你把 \x05%i \x03发子弹送给\x05%N", donateammo, target);
	}
	else //if given ammo exceeds his needs
	{
		new neededammo = (maxammo - currentammo); //find out how much exactly he needs
		SetEntData(target, (iAmmoOffset + offsettoadd), maxammo, 4, true); //fill him up
		SetEntProp(oldgun, Prop_Send, "m_iClip1",(donateammo - neededammo) ,1); //take needed ammo from your clip
		PrintToChat(client, "\x04[Guncontrol] \x03你把 \x05%i \x03发子弹送给\x05%N", neededammo, target);
	}	
	return Plugin_Handled;
}

public Action:Event_SpecialAmmo(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	new upgradeid = GetEventInt(event, "upgradeid");
	decl String:class[256];
	GetEdictClassname(upgradeid, class, sizeof(class));
	//PrintToChatAll("Upgrade caught, entity = %i, entclass: %s", upgradeid, class);
	
	if (StrEqual(class, "upgrade_laser_sight"))
		return;
	
	new ammo = GetSpecialAmmoInPlayerGun(client);
	new newammo;
	
	if (StrEqual(class, "upgrade_ammo_incendiary"))	
		newammo = ammo * GetConVarInt(IncendAmmoMultiplier);
	else if (StrEqual(class, "upgrade_ammo_explosive"))	
		newammo = ammo * GetConVarInt(SplosiveAmmoMultiplier);
	
	if (newammo > 1)
		SetSpecialAmmoInPlayerGun(client, newammo);
	else return;

	PrintToChat(client, "\x04[Guncontrol] \x03你获得 \x05%i \x03盒特殊弹药!", newammo/ammo);
}

stock GetSpecialAmmoInPlayerGun(client) //returns the amount of special rounds in your gun
{
	if (!client) client = 1;
	new gunent = GetPlayerWeaponSlot(client, 0);
	if (IsValidEdict(gunent))
		return GetEntProp(gunent, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", 1);
	else return 0;
}

stock SetSpecialAmmoInPlayerGun(client, amount)
{
	if (!client) client = 1;
	new gunent = GetPlayerWeaponSlot(client, 0);
	if (IsValidEdict(gunent))
		SetEntProp(gunent, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", amount, 1);
}

public Action:Cmd_ReadGunData(client, args)
{
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "Can only use this command ingame");
		return Plugin_Handled;
	}
	
	new targetgun = GetPlayerWeaponSlot(client, 0); //get the players primary weapon
	if (!IsValidEdict(targetgun)) return Plugin_Handled; //check for validity
	
	decl String:name[256];
	GetEdictClassname(targetgun, name, sizeof(name));
	PrintToChat(client, "Gun Class: %s", name);
	
	new iAmmoOffset = FindDataMapInfo(client, "m_iAmmo"); //get the iAmmo Offset
	PrintToChat(client, "m_iAmmo Offset: %i", iAmmoOffset);
	
	for (new offset = 0; offset <= 128 ; offset += 4)
	{
		PrintToChat(client, "Offset %i Value: %i", offset, GetEntData(client, (iAmmoOffset + offset)));
	}
	
	PrintToChat(client, "m_iClip1 Value in gun: %i", GetEntProp(targetgun, Prop_Data, "m_iClip1", 1));
	PrintToChat(client, "m_iExtraPrimaryAmmo Value in gun: %i", GetEntProp(targetgun, Prop_Data, "m_iExtraPrimaryAmmo", 4));
	return Plugin_Handled;
}

stock DebugPrintToAll(const String:format[], any:...)
{
	#if (TEST_DEBUG || TEST_DEBUG_LOG)
	decl String:buffer[256];
	
	VFormat(buffer, sizeof(buffer), format, 2);
	
	#if TEST_DEBUG
	PrintToChatAll("[GUNCONTROL] %s", buffer);
	PrintToConsole(0, "[GUNCONTROL] %s", buffer);
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