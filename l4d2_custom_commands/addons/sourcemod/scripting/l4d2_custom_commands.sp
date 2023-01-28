/***********************************************************************************************
*          NAVIGATION (Search For: Do not allow caps)
*
* -EVENTS - Events.
* 
* -COMMANDS - For commands code
*	-Vomit Player
*	-Incap Player
*	-Change Speed Player
*	-Set Health Player
*	-Change Color Player
* 
* -MENU RELATED - For menus code
*	-Show Categories
*	-Display menus
* 	-Sub Menus Needed
*	-Do Action
* 
* -FUNCTIONS - For functions code (They do every action)
*
************************************************************************************************/

//Include data
#pragma semicolon 2
#include <sourcemod>
#include <sdktools>
#include <sdktools_functions>
#include <adminmenu>

//Definitions needed for plugin functionality
#define GETVERSION "1.0.9"
#define DEBUG 0
#define DESIRED_FLAGS ADMFLAG_UNBAN

#define ARRAY_SIZE 5000

//Colors
#define RED "189 9 13 255"
#define BLUE "34 22 173 255"
#define GREEN "34 120 24 255"
#define YELLOW "231 220 24 255"
#define BLACK "0 0 0 255"
#define WHITE "255 255 255 255"
#define TRANSPARENT "255 255 255 0"
#define HALFTRANSPARENT "255 255 255 180"

//Sounds
#define EXPLOSION_SOUND "ambient/explosions/explode_1.wav"
#define EXPLOSION_SOUND2 "ambient/explosions/explode_2.wav"
#define EXPLOSION_SOUND3 "ambient/explosions/explode_3.wav"
#define EXPLOSION_DEBRIS "animation/van_inside_debris.wav"

//Particles
#define FIRE_PARTICLE "gas_explosion_ground_fire"
#define EXPLOSION_PARTICLE "FluidExplosion_fps"
#define EXPLOSION_PARTICLE2 "weapon_grenade_explosion"
#define EXPLOSION_PARTICLE3 "explosion_huge_b"
#define BURN_IGNITE_PARTICLE "fire_small_01"
#define BLEED_PARTICLE "blood_chainsaw_constant_tp"

/*
 *Offsets, Handles, Bools, Floats, Integers, Strings, Vecs and everything needed for the commands
 */
 
//Strings

//Integers
/* Refers to the last selected userid by the admin client index. Doesn't matter if the admins leaves and another using the same index gets in
 * because if this admin uses the same menu item, the last userid will be reset.
 */
new g_iCurrentUserId[MAXPLAYERS+1] = 0; 
new g_iLastGrabbedEntity[ARRAY_SIZE+1] = -1;

//Bools
new bool:g_bVehicleReady = false;
new bool:g_bStrike = false;
new bool:g_bGnomeRain = false;
new bool:g_bHasGod[MAXPLAYERS+1] = false;
new bool:g_bGrab[MAXPLAYERS+1] = false;
new bool:g_bGrabbed[ARRAY_SIZE+1] = false;
//Floats

//Handles
new Handle:g_hGameConf = INVALID_HANDLE;
new Handle:sdkVomitInfected = INVALID_HANDLE;
new Handle:sdkVomitSurvivor = INVALID_HANDLE;
new Handle:sdkCallPushPlayer = INVALID_HANDLE;
new Handle:sdkDetonateAcid = INVALID_HANDLE;
new Handle:sdkAdrenaline = INVALID_HANDLE;
new Handle:sdkSetBuffer = INVALID_HANDLE;
new Handle:sdkRevive = INVALID_HANDLE;

//Offsets
static g_flLagMovement = 0;

//Vectors

//CVARS
new Handle:g_cvarRadius = INVALID_HANDLE;
new Handle:g_cvarPower = INVALID_HANDLE;
new Handle:g_cvarDuration = INVALID_HANDLE;
new Handle:g_cvarRainDur = INVALID_HANDLE;
new Handle:g_cvarRainRadius = INVALID_HANDLE;
new Handle:g_cvarLog = INVALID_HANDLE;
new Handle:g_cvarAddType = INVALID_HANDLE;

//Plugin Info
public Plugin:myinfo = 
{
	name = "[L4D2] Custom admin commands",
	author = "honorcode23",
	description = "Allow admins to use new administrative or fun commands",
	version = GETVERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=133475"
}

public OnPluginStart()
{
	//Left 4 dead 2 only
	decl String:sGame[256];
	GetGameFolderName(sGame, sizeof(sGame));
	if (!StrEqual(sGame, "left4dead2", false))
	{
		SetFailState("[L4D2] Custom Commands supports Left 4 dead 2 only!");
	}
	
	//Cvars
	CreateConVar("l4d2_custom_commands_version", GETVERSION, "Version of Custom Admin Commands Plugin", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvarRadius = CreateConVar("l4d2_custom_commands_explosion_radius", "350", "Radius for the Create Explosion's command explosion");
	g_cvarPower = CreateConVar("l4d2_custom_commands_explosion_power", "350", "Power of the Create Explosion's command explosion");
	g_cvarDuration = CreateConVar("l4d2_custom_commands_explosion_duration", "15", "Duration of the Create Explosion's command explosion fire trace");
	g_cvarRainDur = CreateConVar("l4d2_custom_commands_rain_duration", "10", "Time out for the gnome's rain");
	g_cvarRainRadius = CreateConVar("l4d2_custom_commands_rain_radius", "300", "Maximum radius of the gnome rain. Will also affect the air strike radius");
	g_cvarLog = CreateConVar("l4d2_custom_commands_log", "1", "Log admin actions when they use a command? [1: Yes 0: No]");
	g_cvarAddType = CreateConVar("l4d2_custom_commands_menutype", "1", "How should the commands be added to the menu? 0: Create new category 1: Add to default categories");
	AutoExecConfig(true, "l4d2_custom_commands");
	//Commands
	RegAdminCmd("sm_vomitplayer", CmdVomitPlayer, DESIRED_FLAGS, "Vomits the desired player");
	RegAdminCmd("sm_incapplayer", CmdIncapPlayer, DESIRED_FLAGS, "Incapacitates a survivor or tank");
	RegAdminCmd("sm_speedplayer", CmdSpeedPlayer, DESIRED_FLAGS, "Set a player's speed");
	RegAdminCmd("sm_sethpplayer", CmdSetHpPlayer, DESIRED_FLAGS, "Set a player's health");
	RegAdminCmd("sm_colorplayer", CmdColorPlayer, DESIRED_FLAGS, "Set a player's model color");
	RegAdminCmd("sm_setexplosion", CmdSetExplosion, DESIRED_FLAGS, "Creates an explosion on your feet or where you are looking at");
	RegAdminCmd("sm_sizeplayer", CmdSizePlayer, DESIRED_FLAGS, "Resize a player's model (Most likely, their pants)");
	RegAdminCmd("sm_norescue", CmdNoRescue, DESIRED_FLAGS, "Forces the rescue vehicle to leave");
	RegAdminCmd("sm_changehp", CmdChangeHp, DESIRED_FLAGS, "Will switch a player's health between temporal or permanent");
	RegAdminCmd("sm_airstrike", CmdAirstrike, DESIRED_FLAGS, "Will set an airstrike attack in the player's face");
	RegAdminCmd("sm_gnomerain", CmdGnomeRain, DESIRED_FLAGS, "Will rain gnomes within your position");
	RegAdminCmd("sm_gnomewipe", CmdGnomeWipe, DESIRED_FLAGS, "Will delete all the gnomes in the map");
	RegAdminCmd("sm_godmode", CmdGodMode, DESIRED_FLAGS, "Will activate or deactivate godmode from player");
	RegAdminCmd("sm_colortarget", CmdColorTarget, DESIRED_FLAGS, "Will color the aiming target entity");
	RegAdminCmd("sm_sizetarget", CmdSizeTarget, DESIRED_FLAGS, "Will size the aiming target entity");
	RegAdminCmd("sm_shakeplayer", CmdShakePlayer, DESIRED_FLAGS, "Will shake a player screen during the desired amount of time");
	RegAdminCmd("sm_charge", CmdCharge, DESIRED_FLAGS, "Will launch a survivor far away");
	RegAdminCmd("sm_weaponrain", CmdWeaponRain, DESIRED_FLAGS, "Will rain the specified weapon");
	RegAdminCmd("sm_cmdplayer", CmdConsolePlayer, DESIRED_FLAGS, "Will control a player's console");
	RegAdminCmd("sm_bleedplayer", CmdBleedPlayer, DESIRED_FLAGS, "Will force a player to bleed");
	RegAdminCmd("sm_hinttext", CmdHintText, DESIRED_FLAGS, "Prints an instructor hint to all players");
	RegAdminCmd("sm_cheat", CmdCheat, DESIRED_FLAGS, "Bypass any command and executes it. Rule: [command] [argument] EX: z_spawn tank");
	RegAdminCmd("sm_wipeentity", CmdWipeEntity, DESIRED_FLAGS, "Wipe all entities with the given name");
	RegAdminCmd("sm_setmodel", CmdSetModel, DESIRED_FLAGS, "Sets a player's model relavite to the models folder");
	RegAdminCmd("sm_setmodelentity", CmdSetModelEntity, DESIRED_FLAGS, "Sets all entities model that match the given classname");
	RegAdminCmd("sm_createparticle", CmdCreateParticle, DESIRED_FLAGS, "Creates a particle with the option to parent it");
	RegAdminCmd("sm_ignite", CmdIgnite, DESIRED_FLAGS, "Ignites a survivor player");
	RegAdminCmd("sm_teleport", CmdTeleport, DESIRED_FLAGS, "Teleports a player to your cursor position");
	RegAdminCmd("sm_teleportent", CmdTeleportEnt, DESIRED_FLAGS, "Teleports all entities with the given classname to your cursor position");
	RegAdminCmd("sm_rcheat", CmdCheatRcon, DESIRED_FLAGS, "Bypass any command and executes it on the server console");
	RegAdminCmd("sm_scanmodel", CmdScanModel, DESIRED_FLAGS, "Scans the model of an entity, if possible");
	RegAdminCmd("sm_grabentity", CmdGrabEntity, DESIRED_FLAGS, "Grabs any entity, if possible");
	RegAdminCmd("sm_acidspill", CmdAcidSpill, DESIRED_FLAGS, "Spawns a spitter's acid spill on your the desired player");
	RegAdminCmd("sm_adren", CmdAdren, DESIRED_FLAGS, "Gives a player the adrenaline effect");
	RegAdminCmd("sm_temphp", CmdTempHp, DESIRED_FLAGS, "Sets a player temporary health into the desired value");
	RegAdminCmd("sm_revive", CmdRevive, DESIRED_FLAGS, "Revives an incapacitated player");
	RegAdminCmd("sm_oldmovie", CmdOldMovie, DESIRED_FLAGS, "Sets a player into black and white");
	RegAdminCmd("sm_panic", CmdPanic, DESIRED_FLAGS, "Forces a panic event");
	
	//Development
	RegAdminCmd("sm_entityinfo", CmdEntityInfo, DESIRED_FLAGS, "Returns the aiming entity classname");
	RegAdminCmd("sm_ccrefresh", CmdCCRefresh, DESIRED_FLAGS, "Refreshes the menu items");
	RegAdminCmd("sm_cchelp", CmdHelp, DESIRED_FLAGS, "Prints the entire list of commands");
	
	//Events
	HookEvent("round_end", OnRoundEnd);
	HookEvent("finale_vehicle_ready", OnVehicleReady);
	
	//Translations
	LoadTranslations("common.phrases");
	
	//SDKCalls
	g_hGameConf = LoadGameConfigFile("l4d2_custom_commands");
	if(g_hGameConf == INVALID_HANDLE)
	{
		SetFailState("Couldn't find the offsets and signatures file. Please, check that it is installed correctly.");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_OnHitByVomitJar");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkVomitInfected = EndPrepSDKCall();
	if(sdkVomitInfected == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CTerrorPlayer_OnHitByVomitJar\" PLEASE UPDATE GAMEDATA");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallPushPlayer = EndPrepSDKCall();
	if(sdkCallPushPlayer == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CTerrorPlayer_Fling\" PLEASE UPDATE GAMEDATA");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkVomitSurvivor = EndPrepSDKCall();
	if(sdkVomitSurvivor == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CTerrorPlayer_OnVomitedUpon\" PLEASE UPDATE GAMEDATA");
	}
	
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CSpitterProjectile_Detonate");
	sdkDetonateAcid = EndPrepSDKCall();
	if(sdkDetonateAcid == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CSpitterProjectile_Detonate\" PLEASE UPDATE GAMEDATA");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_OnAdrenalineUsed");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkAdrenaline = EndPrepSDKCall();
	if(sdkAdrenaline == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CTerrorPlayer_OnAdrenalineUsed\" PLEASE UPDATE GAMEDATA");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_SetHealthBuffer");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkSetBuffer = EndPrepSDKCall();
	if(sdkSetBuffer == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CTerrorPlayer_SetHealthBuffer\" PLEASE UPDATE GAMEDATA");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(g_hGameConf, SDKConf_Signature, "CTerrorPlayer_OnRevived");
	sdkRevive = EndPrepSDKCall();
	if(sdkRevive == INVALID_HANDLE)
	{
		PrintToServer("BROKEN SIGNATURE \"CTerrorPlayer_OnRevived\" PLEASE UPDATE GAMEDATA");
	}
	
	new Handle:topmenu = GetAdminTopMenu();
	if (LibraryExists("adminmenu") && (topmenu != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public OnMapStart()
{
	PrecacheSound(EXPLOSION_SOUND);
	
	PrecacheModel("sprites/muzzleflash4.vmt");
	
	PrefetchSound(EXPLOSION_SOUND);
	
	PrecacheParticle(FIRE_PARTICLE);
	PrecacheParticle(EXPLOSION_PARTICLE);
	PrecacheParticle(EXPLOSION_PARTICLE2);
	PrecacheParticle(EXPLOSION_PARTICLE3);
	PrecacheParticle(BURN_IGNITE_PARTICLE);
	//Get the offset
	g_flLagMovement = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
}

public OnMapEnd()
{
	g_bVehicleReady = false;
	for(new i=1; i<=MaxClients; i++)
	{
		g_bHasGod[i] = false;
		g_bGrab[i] = false;
	}
	
	for(new i = MaxClients+1; i < ARRAY_SIZE; i++)
	{
		g_iLastGrabbedEntity[i] = -1;
		g_bGrabbed[i] = false;
	}
}

public Action:CmdCCRefresh(client, args)
{
	PrintToChat(client, "\x04[SM] \x03正在刷新管理员菜单");
	new Handle:topmenu = GetAdminTopMenu();
	
	//Add to default sourcemod categories
	if(GetConVarBool(g_cvarAddType))
	{
		new TopMenuObject:players_commands = FindTopMenuCategory(topmenu, ADMINMENU_PLAYERCOMMANDS);
		new TopMenuObject:server_commands = FindTopMenuCategory(topmenu, ADMINMENU_SERVERCOMMANDS);
		
		// now we add the function ...
		if (players_commands != INVALID_TOPMENUOBJECT)
		{
			AddToTopMenu (topmenu, "l4d2vomitplayer", TopMenuObject_Item, MenuItem_VomitPlayer, players_commands, "l4d2vomitplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2incapplayer", TopMenuObject_Item, MenuItem_IncapPlayer, players_commands, "l4d2incapplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2speedplayer", TopMenuObject_Item, MenuItem_SpeedPlayer, players_commands, "l4d2speedplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2sethpplayer", TopMenuObject_Item, MenuItem_SetHpPlayer, players_commands, "l4d2sethpplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2colorplayer", TopMenuObject_Item, MenuItem_ColorPlayer, players_commands, "l4d2colorplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2sizeplayer", TopMenuObject_Item, MenuItem_ScalePlayer, players_commands, "l4d2sizeplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2shakeplayer", TopMenuObject_Item, MenuItem_ShakePlayer, players_commands, "l4d2shakeplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2chargeplayer", TopMenuObject_Item, MenuItem_Charge, players_commands, "l4d2chargeplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2teleplayer", TopMenuObject_Item, MenuItem_TeleportPlayer, players_commands, "l4d2teleplayer", DESIRED_FLAGS);
			
			AddToTopMenu (topmenu, "l4d2bleedplayer", TopMenuObject_Item, MenuItem_BleedPlayer, players_commands, "l4d2bleedplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2airstrike", TopMenuObject_Item, MenuItem_Airstrike, players_commands, "l4d2airstrike", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2changehp", TopMenuObject_Item, MenuItem_ChangeHp, players_commands, "l4d2changehp", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2godmode", TopMenuObject_Item, MenuItem_GodMode, players_commands, "l4d2godmode", DESIRED_FLAGS);
		}
		else
		{
			PrintToChat(client, "\x04[SM] \x03玩家指令目录无效!");
			return Plugin_Handled;
		}
		
		if(server_commands != INVALID_TOPMENUOBJECT)
		{
			AddToTopMenu (topmenu, "l4d2createexplosion", TopMenuObject_Item, MenuItem_CreateExplosion, server_commands, "l4d2createexplosion", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2norescue", TopMenuObject_Item, MenuItem_NoRescue, server_commands, "l4d2norescue", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2gnomerain", TopMenuObject_Item, MenuItem_GnomeRain, server_commands, "l4d2gnomerain", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2gnomewipe", TopMenuObject_Item, MenuItem_GnomeWipe, server_commands, "l4d2gnomewipe", DESIRED_FLAGS);
		}
		else
		{
			PrintToChat(client, "\x04[SM] \x03服务器指令目录无效!");
			return Plugin_Handled;
		}
		PrintToChat(client, "\x04[SM] \x03成功刷新管理员菜单");
	}
	
	//Create Custom category
	else
	{
		new TopMenuObject:menu_category_customcmds = AddToTopMenu(topmenu, "sm_cccategory", TopMenuObject_Category, Category_Handler, INVALID_TOPMENUOBJECT);
		AddToTopMenu(topmenu, "sm_ccplayer", TopMenuObject_Item, AdminMenu_Player, menu_category_customcmds, "sm_ccplayer", DESIRED_FLAGS);
		AddToTopMenu(topmenu, "sm_ccgeneral", TopMenuObject_Item, AdminMenu_General, menu_category_customcmds, "sm_ccgeneral", DESIRED_FLAGS);
		AddToTopMenu(topmenu, "sm_ccserver", TopMenuObject_Item, AdminMenu_Server, menu_category_customcmds, "sm_ccserver", DESIRED_FLAGS);
	}
	return Plugin_Handled;
}

public Action:CmdHelp(client, args)
{
	PrintToChat(client, "\x03********************** Custom Commands List **********************");
	PrintToChat(client, "- \"sm_vomitplayer\": Vomits the desired player (Usage: sm_vomitplayer <#userid|name>) | Example: !vomitplayer @me");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_incapplayer\": Incapacitates a survivor or tank (Usage: sm_incapplayer <#userid|name> | Example: !incapplayer @me)");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_speedplayer\": Set a player's speed (Usage: sm_speedplayer <#userid|name> <value>) | Example: !speedplayer @me 1.5");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_sethpplayer\": Set a player's health (Usage: sm_sethpplayer <#userid|name> <amount>) | Example: !sethpplayer @me 50");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_colorplayer\": Set a player's model color (Usage: sm_colorplayer <#userid|name> <R G B A>) | Example: !colorplayer @me \"24 34 38 0\"");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_setexplosion\": Creates an explosion on your feet or where you are looking at (Usage: sm_setexplosion <position |cursor>) | Example: !setexplosion position");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_sizeplayer\": Resize a player's model scale (Usage: sm_sizeplayer <#userid|name> <value>) | Example: !sizeplayer @me 0.1");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_norescue\": Forces the rescue vehicle to leave | Example: !norescue");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_changehp\": Will switch a player's health between temporal or permanent (Usage: sm_changehp <#userid|name> <perm|temp>) | Example: !changehp @me perm");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_airstrike\": Will send an airstrike attack to the target (Usage: sm_airstrike <#userid|name>) | Example: !airstrike @me");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_gnomerain\": Will rain gnomes within your position | Example: !gnomerain");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_gnomewipe\": Will delete all the gnomes in the map | Example: !gnomewipe");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_godmode\": Will activate or deactivate godmode from player (Usage: sm_godmode <#userid|name>) | Example: !godmode @me");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_colortarget\": Will change the color of the aiming target entity (Usage: sm_colortarget <R G B A>) | Example: !colortarget \"43 55 255 179\"");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_sizetarget\": Will re-size the aiming target entity (Usage: sm_sizetarget <value>) | Example: !sizetarget 5.0");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_shakeplayer\": Will shake a player screen during the desired amount of time (Usage: sm_shake <#userid|name> <duration>) | Example: !shakeplayer @me 5");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_charge\": Will launch a survivor far away (Usage: sm_charge <#userid|name>) | Example: !charge Coach");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_weaponrain\": Will rain the specified weapon (Usage: sm_weaponrain <weapon name>) | Example: !weaponrain adrenaline");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_cmdplayer\": Will control a player's console (Usage: sm_cmdplayer <#userid|name> <command>) | Example: !cmdplayer PlayerName \"+forward\"");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_bleedplayer\": Will force a player to bleed (Usage: sm_bleedplayer <#userid|name> <duration>) | Example: !bleedplayer @me 7");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_hinttext\": Prints an instructor hint to all players (Usage: sm_hinttext <hint>) | Example: !hinttext \"This is a hint text message\"");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_cheat\": Bypass any command and executes it (Usage: sm_cheat <command> <arguments>*) | Example: !cheat z_spawn \"tank auto\"");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_wipeentity\": Wipe all entities with the given classname (Usage: !wipeentity <classname>) | Example: !wipeentity infected");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_setmodel\": Sets a player's model relative to the models folder (Usage: sm_setmodel <#userid|name> <model>) | Example: !setmodel @me models/props_interiors/table_bedside.mdl");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_setmodelentity\": Sets all entities model that match the given classname (Usage: sm_setmodelentity <classname> <model>) | Example: !setmodelentity infected models/props_interiors/table_bedside.mdl");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_createparticle\": Creates a particle with the option to parent it (Usage: sm_createparticle <#userid|name> <particle> <parent: yes|no> <duration> Example: !createparticle @me ParticleName no 5");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_ignite\": Ignites a survivor player (Usage: sm_ignite <#userid|name> <duration>) | Example: !ignite @me 4");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_teleport\": Teleports a player to your cursor position (Usage: sm_teleport <#userid|name>) | Example: !teleport Coach");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_teleportent\": Teleports all entities with the given classname to your cursor position (Usage: sm_teleportent <classname>) | Example: !teleportent weapon_adrenaline");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_rcheat\": Bypass any command and executes it on the server console (Usage: sm_rcheat <command>) | Example: !rcheat director_stop");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_scanmodel\": Scans the model of an aiming entity, if possible | Example: !scanmodel");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_grabentity\": Grabs an aiming entity, if possible | Example: !grabentity");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_acidspill\": Spawns a spitter's acid spill on your the desired player (Usage: sm_acidspill <#userid|name>) | Example: !acidspill @me");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_adren\": Gives a player the adrenaline effect (Usage: sm_adren <#userid|name>) | Example: !adren Nick");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_temphp\": Sets a player temporary health into the desired value (Usage: sm_temphp <#userid|name> <amount>) | Example: !temphp Rochelle 50");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_revive\": Revives an incapacitated player (Usage: sm_revive <#userid|name>) | Example: !revive Coach");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_oldmovie\": Sets a player into black and white (Usage: sm_oldmovie <#userid|name>) | Example: !oldmovie @me");
	PrintToChat(client, " ");
	PrintToChat(client, "- \"sm_panic\": Forces a panic event, ignoring the director | Example: !panic");
	PrintToChat(client, " ");
	PrintToChat(client, " ");
	PrintToChat(client, "\x04*: Optional argument");
	PrintToChat(client, "\x04[SM] \x03打开控制台查看命令列表");
	return Plugin_Handled;
}

//**********************************EVENTS*******************************************
public OnVehicleReady(Handle:event, String:event_name[], bool:dontBroadcast)
{
	g_bVehicleReady = true;
}

public OnRoundEnd(Handle:event, String:event_name[], bool:dontBroadcast)
{
	for(new i=1; i<=MaxClients; i++)
	{
		g_bHasGod[i] = false;
	}
	g_bVehicleReady = false;
}

//*********************************COMMANDS*******************************************
public Action:CmdVomitPlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_vomitplayer <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		VomitPlayer(target_list[i], client);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Vomit Player' command on '%s'", name, arg);
	return Plugin_Handled;
}

public Action:CmdIncapPlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_incapplayer <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		IncapPlayer(target_list[i], client);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Incap Player' command on '%s'", name, arg);
	return Plugin_Handled;
}

public Action:CmdSpeedPlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_speedplayer <#userid|name> [value]");
		return Plugin_Handled;
	}
	decl String:arg1[65], String:arg2[65], Float:speed;
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	speed = StringToFloat(arg2);
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		ChangeSpeed(target_list[i], client, speed);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Speed Player' command on '%s' with value <%f>", name, arg1, speed);
	return Plugin_Handled;
}

public Action:CmdSetHpPlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_sethpplayer <#userid|name> [amount]");
		return Plugin_Handled;
	}
	decl String:arg1[65], String:arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new health = StringToInt(arg2);
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		SetHealth(target_list[i], client, health);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Set Heealth' command on '%s' with value <%i>", name, arg1, health);
	return Plugin_Handled;
}

public Action:CmdColorPlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_colorplayer <#userid|name> [R G B A]");
	}
	decl String:arg1[65], String:arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		ChangeColor(target_list[i], client, arg2);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Speed Player' command on '%s' with value '%s'", name, arg1, arg2);
	return Plugin_Handled;
}

public Action:CmdColorTarget(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_colortarget [R G B A]");
	}
	new target = GetClientAimTarget(client, false);
	if(!IsValidEntity(target) || !IsValidEdict(target))
	{
		PrintToChat(client, "\x04[SM] \x03无效Entity或未瞄准Entity");
	}
	decl String:arg[256];
	GetCmdArg(1, arg, sizeof(arg));
	DispatchKeyValue(target, "rendercolor", arg);
	DispatchKeyValue(target, "color", arg);
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Colot Target' command", name);
	return Plugin_Handled;
}

public Action:CmdSizeTarget(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_sizetarget [scale]");
	}
	new target = GetClientAimTarget(client, false);
	if(!IsValidEntity(target) || !IsValidEdict(target))
	{
		PrintToChat(client, "\x04[SM] \x03无效Entity或未瞄准Entity");
	}
	decl String:arg[256];
	GetCmdArg(1, arg, sizeof(arg));
	new Float:scale = StringToFloat(arg);
	SetEntPropFloat(target, Prop_Send, "m_flModelScale", scale);
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Size Target' command", name);
	return Plugin_Handled;
}

public Action:CmdSetExplosion(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1 || args > 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_setexplosion [position | cursor]");
		return Plugin_Handled;
	}
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	if(StrContains(arg, "position", false) != -1)
	{
		decl Float:pos[3];
		GetClientAbsOrigin(client, pos);
		CreateExplosion(pos);
		decl String:name[256];
		GetClientName(client, name, sizeof(name));
		LogCommand("'%s' used the 'Set Explosion' command", name);
		return Plugin_Handled;
	}
	else if(StrContains(arg, "cursor", false) != -1)
	{
		decl Float:VecOrigin[3], Float:VecAngles[3];
		GetClientAbsOrigin(client, VecOrigin);
		GetClientEyeAngles(client, VecAngles);
		TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, client);
		if(TR_DidHit(INVALID_HANDLE))
		{
			TR_GetEndPosition(VecOrigin);
		}
		else
		{
			PrintToChat(client, "Vector out of world geometry. Exploding on origin instead");
		}
		CreateExplosion(VecOrigin);
		decl String:name[256];
		GetClientName(client, name, sizeof(name));
		LogCommand("'%s' used the 'Set Explosion' command", name);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03指定爆炸位置");
		return Plugin_Handled;
	}
}

public Action:CmdSizePlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_sizeplayer <#userid|name> [value]");
	}
	decl String:arg1[65], String:arg2[65], Float:scale;
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	scale = StringToFloat(arg2);
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		ChangeScale(target_list[i], client, scale);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Scale Player' command on '%s' with value <%f>", name, arg1, scale);
	return Plugin_Handled;
}

public Action:CmdNoRescue(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(g_bVehicleReady)
	{
		decl String:map[32];
		GetCurrentMap(map, sizeof(map));
		if(StrEqual(map, "c1m4_atrium"))
		{
			CheatCommand(client, "ent_fire", "relay_car_escape trigger");
			CheatCommand(client, "ent_fire", "car_camera enable");
			EndGame();
		}
		else if(StrEqual(map, "c2m5_concert"))
		{
			CheatCommand(client, "ent_fire", "stadium_exit_left_chopper_prop setanimation exit2");
			CheatCommand(client, "ent_fire", "stadium_exit_left_outro_camera enable");
			EndGame();
		}
		else if(StrEqual(map, "c3m4_plantation"))
		{
			CheatCommand(client, "ent_fire", "camera_outro setparentattachment attachment_cam");
			CheatCommand(client, "ent_fire", "escape_boat_prop setanimation c3m4_outro_boat");
			CheatCommand(client, "ent_fire", "camera_outro enable");
			EndGame();
		}
		else if(StrEqual(map, "c4m5_milltown_escape"))
		{
			CheatCommand(client, "ent_fire", "model_boat setanimation c4m5_outro_boat");
			CheatCommand(client, "ent_fire", "camera_outro setparent model_boat");
			CheatCommand(client, "ent_fire", "camera_outro setparentattachment attachment_cam");
			EndGame();
		}
		else if(StrEqual(map, "c5m5_bridge"))
		{
			CheatCommand(client, "ent_fire", "heli_rescue setanimation 4lift");
			CheatCommand(client, "ent_fire", "camera_outro enable");
			EndGame();
		}
		else if(StrEqual(map, "c6m3_port"))
		{
			CheatCommand(client, "ent_fire", "outro_camera_1 setparentattachment Attachment_1");
			CheatCommand(client, "ent_fire", "car_dynamic Disable");
			CheatCommand(client, "ent_fire", "car_outro_dynamic enable");
			CheatCommand(client, "ent_fire", "ghostanim_outro enable");
			CheatCommand(client, "ent_fire", "ghostanim_outro setanimation c6m3_outro");
			CheatCommand(client, "ent_fire", "car_outro_dynamic setanimation c6m3_outro_charger");
			CheatCommand(client, "ent_fire", "outro_camera_1 enable");
			CheatCommand(client, "ent_fire", "c6m3_escape_music playsound");
			EndGame();
		}
		else
		{
			PrintToChat(client, "\x04[SM] \x03该地图没有救援车辆或不支持该功能!");
		}
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03请等待救援车辆准备好!");
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%N' used the 'No Rescue' command", client);
	return Plugin_Handled;
}

public Action:CmdAirstrike(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_airstrike <#userid|name>");
		return Plugin_Handled;
	}
	
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		Airstrike(target_list[i]);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Airstrike' command on '%s'", name, arg);
	return Plugin_Handled;
}

public Action:CmdOldMovie(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_oldmovie <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		BlackAndWhite(target_list[i], client);
	}
	return Plugin_Handled;
}

public Action:CmdChangeHp(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_changehp <#userid|name> [perm | temp]");
		return Plugin_Handled;
	}
	decl String:arg1[65], String:arg2[65];
	new type = 0;
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	if(StrEqual(arg2, "perm"))
	{
		type = 1;
	}
	else if(StrEqual(arg2, "temp"))
	{
		type = 2;
	}
	if(type <= 0 || type > 2)
	{
		PrintToChat(client, "\x04[SM] \x03指定你想要的HP类型");
		return Plugin_Handled;
	}
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		SwitchHealth(target_list[i], client, type);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Change Health Type' command on '%s' with value <%s>", name, arg1, arg2);
	return Plugin_Handled;
}

public Action:CmdGnomeRain(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Gnome Rain' command");
	StartGnomeRain(client);
	return Plugin_Handled;
}

public Action:CmdGnomeWipe(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	decl String:classname[256];
	new count = 0;
	for(new i=MaxClients; i<=GetMaxEntities(); i++)
	{
		if(!IsValidEntity(i) || !IsValidEdict(i))
		{
			continue;
		}
		GetEdictClassname(i, classname, sizeof(classname));
		if(StrEqual(classname, "weapon_gnome"))
		{
			RemoveEdict(i);
			count++;
		}
	}
	PrintToChat(client, "\x04[SM] \x03成功清除 \x05%i \x03个矮人玩具", count);
	count = 0;
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%N' used the 'Gnome Wipe' command", client);
	return Plugin_Handled;
}

public Action:CmdGodMode(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_godmode <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		GodMode(target_list[i], client);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'God Mode' command on '%s'", name, arg);
	return Plugin_Handled;
}

public Action:CmdCharge(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_charge <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		Charge(target_list[i], client);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Charge' command on '%s'", name, arg);
	return Plugin_Handled;
}

public Action:CmdShakePlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_shake <#userid|name> [duration]");
		return Plugin_Handled;
	}
	decl String:arg1[65], String:arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	new Float:duration = StringToFloat(arg2);
	
	for (new i = 0; i < target_count; i++)
	{
		Shake(target_list[i], client, duration);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Shake' command on '%s' with value <%f>", name, arg1, duration);
	return Plugin_Handled;
}

public Action:CmdConsolePlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_cmdplayer <#userid|name> [command]");
		return Plugin_Handled;
	}
	decl String:arg1[65], String:arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		ClientCommand(target_list[i], arg2);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Client Console' command on '%s' with value <%s>", name, arg1, arg2);
	return Plugin_Handled;
}

public Action:CmdWeaponRain(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_weaponrain [weapon type] [Example: !weaponrain adrenaline]");
		return Plugin_Handled;
	}
	decl String:arg1[65];
	GetCmdArgString(arg1, sizeof(arg1));
	if(IsValidWeapon(arg1))
	{
		WeaponRain(arg1, client);
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03错误的类型");
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Weapon Rain' command", name);
	return Plugin_Handled;
}

public Action:CmdBleedPlayer(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_bleedplayer <#userid|name> [duration]");
		return Plugin_Handled;
	}
	
	decl String:arg1[65], String:arg2[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	new Float:duration = StringToFloat(arg2);
	
	for (new i = 0; i < target_count; i++)
	{
		Bleed(target_list[i], client, duration);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Bleed' command on '%s' with value <%f>", name, arg1, duration);
	return Plugin_Handled;
}

public Action:CmdHintText(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	decl String:arg2[65];
	GetCmdArgString(arg2, sizeof(arg2));
	InstructorHint(arg2);
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Hint Text' command with value <%s>", name, arg2);
	return Plugin_Handled;
}

public Action:CmdCheat(client, args)
{
	decl String:command[256], String:buffer2[256];
	GetCmdArg(1, command, sizeof(command));
	GetCmdArg(2, buffer2, sizeof(buffer2));
	if(args < 1)
	{
		if(client == 0)
		{
		}
		else
		{
			PrintToChat(client, "\x04[SM] \x03Usage: sm_cheat <command>");
		}
		return Plugin_Handled;
	}
	
	if(client == 0)
	{
		new cmdflags = GetCommandFlags(command);
		SetCommandFlags(command, cmdflags & ~FCVAR_CHEAT);
		ServerCommand("%s", buffer2);
		SetCommandFlags(command, cmdflags);
		LogCommand("'Console' used the 'Cheat' command with value <%s>", buffer2);
	}
	else
	{
		CheatCommand(client, command, buffer2);
		LogCommand("'%N' used the 'Cheat' command with value <%s>", client, buffer2);
	}	
	return Plugin_Handled;
}

public Action:CmdWipeEntity(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	decl String:arg[256], String:class[64];
	GetCmdArgString(arg, sizeof(arg));
	new count = 0;
	for(new i=MaxClients+1; i<=GetMaxEntities(); i++)
	{
		if(i > 0 && IsValidEntity(i) && IsValidEdict(i))
		{
			GetEdictClassname(i, class, sizeof(class));
			if(StrEqual(class, arg))
			{
				AcceptEntityInput(i, "Kill");
				count++;
			}
		}
	}
	PrintToChat(client, "\x04[SM] \x03成功删除 \x05%i \x03个 \x05<%s>", count, arg);
	count = 0;
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Wipe Entity' command for classname <%s>", name, arg);
	return Plugin_Handled;
}

public Action:CmdSetModel(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_setmodel <#userid|name> [model]");
		PrintToChat(client, "Example: !setmodel @me models/props_interiors/table_bedside.mdl ");
		return Plugin_Handled;
	}
	decl String:arg1[256], String:arg2[256];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	PrecacheModel(arg2);
	for (new i = 0; i < target_count; i++)
	{
		SetEntityModel(target_list[i], arg2);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Set Model' command on '%s' with value <%s>", name, arg1, arg2);
	return Plugin_Handled;
}

public Action:CmdSetModelEntity(client, args)
{
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_setmodelentity <classname> [model]");
		PrintToChat(client, "Example: !setmodelentity infected models/props_interiors/table_bedside.mdl");
		return Plugin_Handled;
	}
	decl String:arg1[256], String:arg2[256], String:class[64];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	PrecacheModel(arg2);
	new count = 0;
	for(new i=MaxClients+1; i<=GetMaxEntities(); i++)
	{
		if(i > 0 && IsValidEntity(i) && IsValidEdict(i))
		{
			GetEdictClassname(i, class, sizeof(class));
			if(StrEqual(class, arg1))
			{
				SetEntityModel(i, arg2);
				count++;
			}
		}
	}
	PrintToChat(client, "\x04[SM] \x03 成功将 \x05%s \x03模型设置到 \x05%i \x03个 \x05<%s>", arg2, count, arg1);
	count = 0;
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Set Model Entity' command on classname <%s>", name, arg2);
	return Plugin_Handled;
}

public Action:CmdCreateParticle(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 4)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_createparticle <#userid|name> [particle] [parent: yes|no] [duration]");
		PrintToChat(client, "Example: !createparticle @me no 5 (Teleports the particle to my position, but don't parent it and stop the effect in 5 seconds)");
		return Plugin_Handled;
	}
	decl String:arg1[256], String:arg2[256], String:arg3[256], String:arg4[256];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	GetCmdArg(4, arg4, sizeof(arg4));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	new bool:parent = false;
	if(StrEqual(arg3, "yes"))
	{
		parent = false;
	}
	else if(StrEqual(arg3, "no"))
	{
		parent = true;
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03No parent option given. As default it won't be parented");
	}
	new Float:duration = StringToFloat(arg4);
	for (new i = 0; i < target_count; i++)
	{
		CreateParticle(target_list[i], arg2, parent, duration);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Create Particle' command on '%s' with value <%s> <%s> <%f>", name, arg1, arg2, arg3, duration);
	return Plugin_Handled;
}

public Action:CmdIgnite(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_ignite <#userid|name> [duration]");
		return Plugin_Handled;
	}
	decl String:arg1[256], String:arg2[256];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	new Float:duration = StringToFloat(arg2);
	for (new i=0; i < target_count; i++)
	{
		IgnitePlayer(target_list[i], duration);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Ignite Player' command on '%s' with value <%f>", name, arg1, duration);
	return Plugin_Handled;
}

public Action:CmdTeleport(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_teleport <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[256];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	GetCmdArgString(arg, sizeof(arg));
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	decl Float:VecOrigin[3], Float:VecAngles[3];
	GetClientAbsOrigin(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(VecOrigin);
	}
	else
	{
		PrintToChat(client, "Vector out of world geometry. Teleporting on origin instead");
	}
	for (new i=0; i < target_count; i++)
	{
		TeleportEntity(target_list[i], VecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Teleport' command on '%s'", name, arg);
	return Plugin_Handled;
}

public Action:CmdTeleportEnt(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_teleportent <classname>");
		return Plugin_Handled;
	}
	decl String:arg1[256], String:class[128];
	GetCmdArg(1, arg1, sizeof(arg1));
	new count = 0;
	decl Float:VecOrigin[3], Float:VecAngles[3];
	GetClientAbsOrigin(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(VecOrigin);
	}
	else
	{
		PrintToChat(client, "Vector out of world geometry. Teleporting on origin instead");
	}
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsValidEntity(i))
		{
			GetEdictClassname(i, class, sizeof(class));
			if(StrEqual(class, arg1))
			{
				TeleportEntity(i, VecOrigin, NULL_VECTOR, NULL_VECTOR);
				count++;
			}
		}
	}
	PrintToChat(client, "\x04[SM] \x03成功传送 \x05'%i' \x03个 \x05<%s>", count, arg1);
	decl String:name[256];
	GetClientName(client, name, sizeof(name));
	LogCommand("'%s' used the 'Teleport Entity' command on '%i' entities with classname <%s>", name, count, arg1);
	return Plugin_Handled;
}

public Action:CmdCheatRcon(client, args)
{
	decl String:buffer[256], String:buffer2[256];
	GetCmdArg(1, buffer, sizeof(buffer));
	GetCmdArgString(buffer2, sizeof(buffer2));
	if(args < 1)
	{
		if(client == 0)
		{
		}
		else
		{
			PrintToChat(client, "\x04[SM] \x03Usage: sm_rcheat <command>");
		}
		return Plugin_Handled;
	}
	
	if(client == 0)
	{
		new cmdflags = GetCommandFlags(buffer);
		SetCommandFlags(buffer, cmdflags & ~FCVAR_CHEAT);
		ServerCommand("%s", buffer2);
		SetCommandFlags(buffer, cmdflags);
		LogCommand("'Console' used the 'RCON Cheat' command with value <%s> <%s>", buffer, buffer2);
	}
	else
	{
		new cmdflags = GetCommandFlags(buffer);
		SetCommandFlags(buffer, cmdflags & ~FCVAR_CHEAT);
		ServerCommand("%s", buffer2);
		SetCommandFlags(buffer, cmdflags);
		LogCommand("'N' used the 'RCON Cheat' command with value <%s> <%s>", client, buffer, buffer2);
	}	
	return Plugin_Handled;
}

public Action:CmdScanModel(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	new entity = GetLookingEntity(client);
	if(entity <= 0
	|| !IsValidEntity(entity))
	{
		PrintToChat(client, "\x04[SM] \x03找不到有效目标!");
		return Plugin_Handled;
	}
	else
	{
		decl String:model[256], String:classname[64];
		GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));
		GetEdictClassname(entity, classname, sizeof(classname));
		PrintToChat(client, "\x04[SM] The model of the entity <%s>(%d) is \"%s\"", classname, entity, model);
	}
	LogCommand("%N used the 'Scan Model' command", client);
	return Plugin_Handled;
}

public Action:CmdGrabEntity(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(!g_bGrab[client])
	{
		GrabLookingEntity(client);
	}
	else
	{
		ReleaseLookingEntity(client);
	}
	LogCommand("%N used the 'Grab' command", client);
	return Plugin_Handled;
}

public Action:CmdAcidSpill(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_acidspill <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[256];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	GetCmdArgString(arg, sizeof(arg));
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for(new i=0; i < target_count; i++)
	{
		CreateAcidSpill(target_list[i], client);
	}
	return Plugin_Handled;
}

public Action:CmdAdren(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_adren <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[256];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	GetCmdArgString(arg, sizeof(arg));
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for(new i=0; i < target_count; i++)
	{
		SetAdrenalineEffect(target_list[i], client);
	}
	return Plugin_Handled;
}

public Action:CmdTempHp(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 2)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_temphp <#userid|name> <amount>");
		return Plugin_Handled;
	}
	decl String:arg1[256], String:arg2[256];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	GetCmdArg(1, arg1, sizeof(arg1));
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, arg2, sizeof(arg2));
	new Float:amount = StringToFloat(arg2);
	if(amount > 65000.0)
	{
		PrintToChat(client, "\x04[SM] \x03数字 \x05<%f> \x03太大了 (最大: 65000)", amount);
		return Plugin_Handled;
	}
	else if(amount < 0.0)
	{
		PrintToChat(client, "\x04[SM] \x03数字 \x05<%f> \x03太小了 (最小: 0)", amount);
		return Plugin_Handled;
	}
	for(new i=0; i < target_count; i++)
	{
		SetTempHealth(target_list[i], amount);
	}
	return Plugin_Handled;
}

public Action:CmdRevive(client, args)
{
	if(!client)
	{
		LogCommand("A command was executed from the server console, but is not permitted");
		return Plugin_Handled;
	}
	if(args < 1)
	{
		PrintToChat(client, "\x04[SM] \x03Usage: sm_revive <#userid|name>");
		return Plugin_Handled;
	}
	decl String:arg[256];
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	GetCmdArgString(arg, sizeof(arg));
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	for(new i=0; i < target_count; i++)
	{
		RevivePlayer(target_list[i], client);
	}
	return Plugin_Handled;
}

public Action:CmdPanic(client, args)
{
	if(!client)
	{
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03正在创建尸潮...");
	}
	PanicEvent();
	return Plugin_Handled;
}

//******************************MENU RELATED****************************************

public OnAdminMenuReady(Handle:topmenu)
{
	if(topmenu == INVALID_HANDLE) 
	{
		LogError("[WARNING!] The topmenu handle was invalid! Unable to add items to the menu");
		return;
	}
	//Add to default sourcemod categories
	if(GetConVarBool(g_cvarAddType))
	{
		new TopMenuObject:players_commands = FindTopMenuCategory(topmenu, ADMINMENU_PLAYERCOMMANDS);
		new TopMenuObject:server_commands = FindTopMenuCategory(topmenu, ADMINMENU_SERVERCOMMANDS);
		
		// now we add the function ...
		if (players_commands != INVALID_TOPMENUOBJECT)
		{
			AddToTopMenu (topmenu, "l4d2vomitplayer", TopMenuObject_Item, MenuItem_VomitPlayer, players_commands, "l4d2vomitplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2incapplayer", TopMenuObject_Item, MenuItem_IncapPlayer, players_commands, "l4d2incapplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2speedplayer", TopMenuObject_Item, MenuItem_SpeedPlayer, players_commands, "l4d2speedplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2sethpplayer", TopMenuObject_Item, MenuItem_SetHpPlayer, players_commands, "l4d2sethpplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2colorplayer", TopMenuObject_Item, MenuItem_ColorPlayer, players_commands, "l4d2colorplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2sizeplayer", TopMenuObject_Item, MenuItem_ScalePlayer, players_commands, "l4d2sizeplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2shakeplayer", TopMenuObject_Item, MenuItem_ShakePlayer, players_commands, "l4d2shakeplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2chargeplayer", TopMenuObject_Item, MenuItem_Charge, players_commands, "l4d2chargeplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2teleplayer", TopMenuObject_Item, MenuItem_TeleportPlayer, players_commands, "l4d2teleplayer", DESIRED_FLAGS);
			
			AddToTopMenu (topmenu, "l4d2bleedplayer", TopMenuObject_Item, MenuItem_BleedPlayer, players_commands, "l4d2bleedplayer", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2airstrike", TopMenuObject_Item, MenuItem_Airstrike, players_commands, "l4d2airstrike", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2changehp", TopMenuObject_Item, MenuItem_ChangeHp, players_commands, "l4d2changehp", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2godmode", TopMenuObject_Item, MenuItem_GodMode, players_commands, "l4d2godmode", DESIRED_FLAGS);
		}
		else
		{
			LogError("Player commands category is invalid!");
		}
		
		if(server_commands != INVALID_TOPMENUOBJECT)
		{
			AddToTopMenu (topmenu, "l4d2createexplosion", TopMenuObject_Item, MenuItem_CreateExplosion, server_commands, "l4d2createexplosion", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2norescue", TopMenuObject_Item, MenuItem_NoRescue, server_commands, "l4d2norescue", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2gnomerain", TopMenuObject_Item, MenuItem_GnomeRain, server_commands, "l4d2gnomerain", DESIRED_FLAGS);
			AddToTopMenu (topmenu, "l4d2gnomewipe", TopMenuObject_Item, MenuItem_GnomeWipe, server_commands, "l4d2gnomewipe", DESIRED_FLAGS);
		}
		else
		{
			LogError("Server commands category is invalid!");
		}
	}
	
	//Create Custom category
	else
	{
		new TopMenuObject:menu_category_customcmds = AddToTopMenu(topmenu, "sm_cccategory", TopMenuObject_Category, Category_Handler, INVALID_TOPMENUOBJECT);
		AddToTopMenu(topmenu, "sm_ccplayer", TopMenuObject_Item, AdminMenu_Player, menu_category_customcmds, "sm_ccplayer", DESIRED_FLAGS);
		AddToTopMenu(topmenu, "sm_ccgeneral", TopMenuObject_Item, AdminMenu_General, menu_category_customcmds, "sm_ccgeneral", DESIRED_FLAGS);
		AddToTopMenu(topmenu, "sm_ccserver", TopMenuObject_Item, AdminMenu_Server, menu_category_customcmds, "sm_ccserver", DESIRED_FLAGS);
	}
}

//Admin Category Name
public Category_Handler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayTitle)
	{
		Format(buffer, maxlength, "Custom Commands");
	}
	else if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "Custom Commands");
	}
}

public AdminMenu_Player(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "玩家指令");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildPlayerMenu(param);
	}
}

public AdminMenu_General(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "General Commands");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildGeneralMenu(param);
	}
}

public AdminMenu_Server(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "服务器指令");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		BuildServerMenu(param);
	}
}

stock BuildPlayerMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_PlayerMenu);
	SetMenuTitle(menu, "玩家指令");
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "l4d2chargeplayer", "击飞玩家");
	AddMenuItem(menu, "l4d2incapplayer", "使玩家倒地");
	AddMenuItem(menu, "l4d2speedplayer", "设置玩家速度");
	AddMenuItem(menu, "l4d2sethpplayer", "设置玩家血量");
	AddMenuItem(menu, "l4d2colorplayer", "设置玩家角色颜色");
	AddMenuItem(menu, "l4d2sizeplayer", "设置玩家角色模型大小");
	AddMenuItem(menu, "l4d2shakeplayer", "摇晃玩家");
	AddMenuItem(menu, "l4d2teleplayer", "传送玩家");
	AddMenuItem(menu, "l4d2bleedplayer", "防止玩家Rush");
	AddMenuItem(menu, "l4d2airstrike", "召唤空袭");
	AddMenuItem(menu, "l4d2changehp", "更改血量类型");
	AddMenuItem(menu, "l4d2godmode", "上帝模式");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

stock BuildGeneralMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_GeneralMenu);
	SetMenuTitle(menu, "玩家指令");
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "l4d2createexplosion", "召唤爆炸");
	AddMenuItem(menu, "l4d2norescue", "强制救援车辆离开");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

stock BuildServerMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_ServerMenu);
	SetMenuTitle(menu, "玩家指令");
	SetMenuExitBackButton(menu, true);
	AddMenuItem(menu, "l4d2gnomerain", "矮人玩具雨");
	AddMenuItem(menu, "l4d2gnomewipe", "清除所有矮人玩具");
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_PlayerMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				DisplayChargePlayerMenu(param1);
			}
			case 1:
			{
				DisplayIncapPlayerMenu(param1);
			}
			case 2:
			{
				DisplaySpeedPlayerMenu(param1);
			}
			case 3:
			{
				DisplaySetHpPlayerMenu(param1);
			}
			case 4:
			{
				DisplayColorPlayerMenu(param1);
			}
			case 5:
			{
				DisplayScalePlayerMenu(param1);
			}
			case 6:
			{
				DisplayShakePlayerMenu(param1);
			}
			case 7:
			{
				DisplayTeleportPlayerMenu(param1);
			}
			case 8:
			{
				DisplayBleedPlayerMenu(param1);
			}
			case 9:
			{
				DisplayAirstrikeMenu(param1);
			}
			case 10:
			{
				DisplayChangeHpMenu(param1);
			}
			case 11:
			{
				DisplayGodModeMenu(param1);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public MenuHandler_GeneralMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				DisplayCreateExplosionMenu(param1);
			}
			case 1:
			{
				if(g_bVehicleReady)
				{
					decl String:map[32];
					GetCurrentMap(map, sizeof(map));
					if(StrEqual(map, "c1m4_atrium"))
					{
						CheatCommand(param1, "ent_fire", "relay_car_escape trigger");
						CheatCommand(param1, "ent_fire", "car_camera enable");
						EndGame();
					}
					else if(StrEqual(map, "c2m5_concert"))
					{
						CheatCommand(param1, "ent_fire", "stadium_exit_left_chopper_prop setanimation exit2");
						CheatCommand(param1, "ent_fire", "stadium_exit_left_outro_camera enable");
						EndGame();
					}
					else if(StrEqual(map, "c3m4_plantation"))
					{
						CheatCommand(param1, "ent_fire", "camera_outro setparentattachment attachment_cam");
						CheatCommand(param1, "ent_fire", "escape_boat_prop setanimation c3m4_outro_boat");
						CheatCommand(param1, "ent_fire", "camera_outro enable");
						EndGame();
					}
					else if(StrEqual(map, "c4m5_milltown_escape"))
					{
						CheatCommand(param1, "ent_fire", "model_boat setanimation c4m5_outro_boat");
						CheatCommand(param1, "ent_fire", "camera_outro setparent model_boat");
						CheatCommand(param1, "ent_fire", "camera_outro setparentattachment attachment_cam");
						EndGame();
					}
					else if(StrEqual(map, "c5m5_bridge"))
					{
						CheatCommand(param1, "ent_fire", "heli_rescue setanimation 4lift");
						CheatCommand(param1, "ent_fire", "camera_outro enable");
						EndGame();
					}
					else if(StrEqual(map, "c6m3_port"))
					{
						CheatCommand(param1, "ent_fire", "outro_camera_1 setparentattachment Attachment_1");
						CheatCommand(param1, "ent_fire", "car_dynamic Disable");
						CheatCommand(param1, "ent_fire", "car_outro_dynamic enable");
						CheatCommand(param1, "ent_fire", "ghostanim_outro enable");
						CheatCommand(param1, "ent_fire", "ghostanim_outro setanimation c6m3_outro");
						CheatCommand(param1, "ent_fire", "car_outro_dynamic setanimation c6m3_outro_charger");
						CheatCommand(param1, "ent_fire", "outro_camera_1 enable");
						CheatCommand(param1, "ent_fire", "c6m3_escape_music playsound");
						EndGame();
					}
					else
					{
						PrintToChat(param1, "[SM] 该地图没有救援车辆或不支持该功能!");
					}
				}
				else
				{
					PrintToChat(param1, "[SM] 请等待救援车辆!");
				}
				decl String:name[256];
				GetClientName(param1, name, sizeof(name));
				LogCommand("%N used the 'No Rescue' command", param1);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public MenuHandler_ServerMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				StartGnomeRain(param1);
				PrintHintTextToAll("下矮人玩具雨啦!");
			}
			case 1:
			{
				decl String:classname[256];
				new count = 0;
				for(new i=MaxClients; i<=GetMaxEntities(); i++)
				{
					if(!IsValidEntity(i) || !IsValidEdict(i))
					{
						continue;
					}
					GetEdictClassname(i, classname, sizeof(classname));
					if(StrEqual(classname, "weapon_gnome"))
					{
						RemoveEdict(i);
						count++;
					}
				}
				PrintToChat(param1, "[SM] Succesfully wiped %i gnomes", count);
				count = 0;
				decl String:name[256];
				GetClientName(param1, name, sizeof(name));
				LogCommand("%N used the 'Gnome Wipe' command", param1);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//---------------------------------Show Categories--------------------------------------------
public MenuItem_Charge(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "击飞玩家", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayChargePlayerMenu(param);
	}
}

public MenuItem_VomitPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "呕吐玩家", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayVomitPlayerMenu(param);
	}
}

public MenuItem_TeleportPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "传送玩家", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayTeleportPlayerMenu(param);
	}
}

public MenuItem_GodMode(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "上帝模式", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayGodModeMenu(param);
	}
}

public MenuItem_IncapPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "使玩家倒地", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayIncapPlayerMenu(param);
	}
}

public MenuItem_SpeedPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "设置玩家速度", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplaySpeedPlayerMenu(param);
	}
}

public MenuItem_SetHpPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "设置玩家血量", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplaySetHpPlayerMenu(param);
	}
}

public MenuItem_ColorPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "设置玩家颜色", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayColorPlayerMenu(param);
	}
}

public MenuItem_CreateExplosion(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "创造爆炸", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayCreateExplosionMenu(param);
	}
}

public MenuItem_ScalePlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "设置玩家角色模型大小", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayScalePlayerMenu(param);
	}
}

public MenuItem_ShakePlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "摇晃玩家", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayShakePlayerMenu(param);
	}
}

public MenuItem_NoRescue(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "强制救援车离开", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		if(g_bVehicleReady)
		{
			decl String:map[32];
			GetCurrentMap(map, sizeof(map));
			if(StrEqual(map, "c1m4_atrium"))
			{
				CheatCommand(param, "ent_fire", "relay_car_escape trigger");
				CheatCommand(param, "ent_fire", "car_camera enable");
				EndGame();
			}
			else if(StrEqual(map, "c2m5_concert"))
			{
				CheatCommand(param, "ent_fire", "stadium_exit_left_chopper_prop setanimation exit2");
				CheatCommand(param, "ent_fire", "stadium_exit_left_outro_camera enable");
				EndGame();
			}
			else if(StrEqual(map, "c3m4_plantation"))
			{
				CheatCommand(param, "ent_fire", "camera_outro setparentattachment attachment_cam");
				CheatCommand(param, "ent_fire", "escape_boat_prop setanimation c3m4_outro_boat");
				CheatCommand(param, "ent_fire", "camera_outro enable");
				EndGame();
			}
			else if(StrEqual(map, "c4m5_milltown_escape"))
			{
				CheatCommand(param, "ent_fire", "model_boat setanimation c4m5_outro_boat");
				CheatCommand(param, "ent_fire", "camera_outro setparent model_boat");
				CheatCommand(param, "ent_fire", "camera_outro setparentattachment attachment_cam");
				EndGame();
			}
			else if(StrEqual(map, "c5m5_bridge"))
			{
				CheatCommand(param, "ent_fire", "heli_rescue setanimation 4lift");
				CheatCommand(param, "ent_fire", "camera_outro enable");
				EndGame();
			}
			else if(StrEqual(map, "c6m3_port"))
			{
				CheatCommand(param, "ent_fire", "outro_camera_1 setparentattachment Attachment_1");
				CheatCommand(param, "ent_fire", "car_dynamic Disable");
				CheatCommand(param, "ent_fire", "car_outro_dynamic enable");
				CheatCommand(param, "ent_fire", "ghostanim_outro enable");
				CheatCommand(param, "ent_fire", "ghostanim_outro setanimation c6m3_outro");
				CheatCommand(param, "ent_fire", "car_outro_dynamic setanimation c6m3_outro_charger");
				CheatCommand(param, "ent_fire", "outro_camera_1 enable");
				CheatCommand(param, "ent_fire", "c6m3_escape_music playsound");
				EndGame();
			}
			else
			{
				PrintToChat(param, "\x04[SM] \x03该地图没有救援车辆或不支持该功能!");
			}
		}
		else
		{
			PrintToChat(param, "\x04[SM] \x03该地图没有救援车辆或不支持该功能!");
		}
		decl String:name[256];
		GetClientName(param, name, sizeof(name));
		LogCommand("%N used the 'No Rescue' command", param);
	}
}

public MenuItem_BleedPlayer(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "防止玩家Rush", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayBleedPlayerMenu(param);
	}
}

public MenuItem_Airstrike(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "召唤空袭", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayAirstrikeMenu(param);
	}
}

public MenuItem_GnomeRain(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "矮人玩具雨", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		StartGnomeRain(param);
		PrintHintTextToAll("下矮人玩具雨啦!");
	}
}

public MenuItem_GnomeWipe(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "清除所有矮人玩具", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		decl String:classname[256];
		new count = 0;
		for(new i=MaxClients; i<=GetMaxEntities(); i++)
		{
			if(!IsValidEntity(i) || !IsValidEdict(i))
			{
				continue;
			}
			GetEdictClassname(i, classname, sizeof(classname));
			if(StrEqual(classname, "weapon_gnome"))
			{
				RemoveEdict(i);
				count++;
			}
		}
		PrintToChat(param, "\x04[SM] \x03成功清除 \x05%i \x03个矮人玩具", count);
		count = 0;
		decl String:name[256];
		GetClientName(param, name, sizeof(name));
		LogCommand("%N used the 'Gnome Wipe' command", param);
	}
}

public MenuItem_ChangeHp(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "更改血量类型", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		DisplayChangeHpMenu(param);
	}
}

/*public MenuItem_WipeBody(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "清理尸体", "", param);
	}
	if(action == TopMenuAction_SelectOption)
	{
		decl String:classname[256];
		new count = 0;
		for(new i=MaxClients; i<=GetMaxEntities(); i++)
		{
			if(!IsValidEntity(i) || !IsValidEdict(i))
			{
				continue;
			}
			GetEdictClassname(i, classname, sizeof(classname));
			if(StrEqual(classname, "prop_ragdoll"))
			{
				RemoveEdict(i);
				count++;
			}
		}
		PrintToChat(param, "\x04[SM] \x03成功清除 \x05%i \x03个尸体", count);
		count = 0;
	}
}
*/
//---------------------------------Display menus---------------------------------------
DisplayVomitPlayerMenu(client)
{
	new Handle:menu2 = CreateMenu(MenuHandler_VomitPlayer);
	SetMenuTitle(menu2, "选择玩家:");
	SetMenuExitBackButton(menu2, true);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

DisplayTeleportPlayerMenu(client)
{
	new Handle:menu2 = CreateMenu(MenuHandler_TeleportPlayer);
	SetMenuTitle(menu2, "选择玩家:");
	SetMenuExitBackButton(menu2, true);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

DisplayChargePlayerMenu(client)
{
	new Handle:menu2 = CreateMenu(MenuHandler_ChargePlayer);
	SetMenuTitle(menu2, "选择玩家:");
	SetMenuExitBackButton(menu2, true);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

DisplayGodModeMenu(client)
{
	new Handle:menu2 = CreateMenu(MenuHandler_GodMode);
	SetMenuTitle(menu2, "选择玩家:");
	SetMenuExitBackButton(menu2, true);
	AddTargetsToMenu2(menu2, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu2, client, MENU_TIME_FOREVER);
}

DisplayIncapPlayerMenu(client)
{
	new Handle:menu3 = CreateMenu(MenuHandler_IncapPlayer);
	SetMenuTitle(menu3, "选择玩家:");
	SetMenuExitBackButton(menu3, true);
	AddTargetsToMenu2(menu3, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu3, client, MENU_TIME_FOREVER);
}

DisplaySpeedPlayerMenu(client)
{
	new Handle:menu4 = CreateMenu(MenuSubHandler_SpeedPlayer);
	SetMenuTitle(menu4, "选择玩家:");
	SetMenuExitBackButton(menu4, true);
	AddTargetsToMenu2(menu4, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu4, client, MENU_TIME_FOREVER);
}

DisplaySetHpPlayerMenu(client)
{
	new Handle:menu5 = CreateMenu(MenuSubHandler_SetHpPlayer);
	SetMenuTitle(menu5, "选择玩家:");
	SetMenuExitBackButton(menu5, true);
	AddTargetsToMenu2(menu5, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu5, client, MENU_TIME_FOREVER);
}

DisplayChangeHpMenu(client)
{
	new Handle:menu5 = CreateMenu(MenuSubHandler_ChangeHp);
	SetMenuTitle(menu5, "选择玩家:");
	SetMenuExitBackButton(menu5, true);
	AddTargetsToMenu2(menu5, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu5, client, MENU_TIME_FOREVER);
}

DisplayColorPlayerMenu(client)
{
	new Handle:menu6 = CreateMenu(MenuSubHandler_ColorPlayer);
	SetMenuTitle(menu6, "选择玩家:");
	SetMenuExitBackButton(menu6, true);
	AddTargetsToMenu2(menu6, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu6, client, MENU_TIME_FOREVER);
}

DisplayCreateExplosionMenu(client)
{
	new Handle:menu7 = CreateMenu(MenuHandler_CreateExplosion);
	SetMenuTitle(menu7, "选择位置:");
	SetMenuExitBackButton(menu7, true);
	AddMenuItem(menu7, "onpos", "人物位置");
	AddMenuItem(menu7, "onang", "准星位置");
	DisplayMenu(menu7, client, MENU_TIME_FOREVER);
}

DisplayScalePlayerMenu(client)
{
	new Handle:menu8 = CreateMenu(MenuSubHandler_ScalePlayer);
	SetMenuTitle(menu8, "选择玩家:");
	SetMenuExitBackButton(menu8, true);
	AddTargetsToMenu2(menu8, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu8, client, MENU_TIME_FOREVER);
}

DisplayShakePlayerMenu(client)
{
	new Handle:menu8 = CreateMenu(MenuSubHandler_ShakePlayer);
	SetMenuTitle(menu8, "选择玩家:");
	SetMenuExitBackButton(menu8, true);
	AddTargetsToMenu2(menu8, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu8, client, MENU_TIME_FOREVER);
}

DisplayBleedPlayerMenu(client)
{
	new Handle:menu10 = CreateMenu(MenuHandler_BleedPlayer);
	SetMenuTitle(menu10, "选择玩家:");
	SetMenuExitBackButton(menu10, true);
	AddTargetsToMenu2(menu10, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu10, client, MENU_TIME_FOREVER);
}

DisplayAirstrikeMenu(client)
{
	new Handle:menu11 = CreateMenu(MenuHandler_Airstrike);
	SetMenuTitle(menu11, "选择玩家:");
	SetMenuExitBackButton(menu11, true);
	AddTargetsToMenu2(menu11, client, COMMAND_FILTER_CONNECTED);
	DisplayMenu(menu11, client, MENU_TIME_FOREVER);
}

//-------------------------------Sub Menus Needed-----------------------------
public MenuSubHandler_SpeedPlayer(Handle:menu4, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu4);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu4, param2, info, sizeof(info));
		g_iCurrentUserId[param1] = StringToInt(info);
		DisplaySpeedValueMenu(param1);
	}
}

public MenuSubHandler_SetHpPlayer(Handle:menu5, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu5);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu5, param2, info, sizeof(info));
		g_iCurrentUserId[param1] = StringToInt(info);
		DisplaySetHpValueMenu(param1);
	}
}

public MenuSubHandler_ChangeHp(Handle:menu5, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu5);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu5, param2, info, sizeof(info));
		g_iCurrentUserId[param1] = StringToInt(info);
		DisplayChangeHpStyleMenu(param1);
	}
}

public MenuSubHandler_ColorPlayer(Handle:menu6, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu6);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu6, param2, info, sizeof(info));
		g_iCurrentUserId[param1] = StringToInt(info);
		DisplayColorValueMenu(param1);
	}
}

public MenuSubHandler_ScalePlayer(Handle:menu8, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu8);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu8, param2, info, sizeof(info));
		g_iCurrentUserId[param1] = StringToInt(info);
		DisplayScaleValueMenu(param1);
	}
}

public MenuSubHandler_ShakePlayer(Handle:menu8, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu8);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu8, param2, info, sizeof(info));
		g_iCurrentUserId[param1] = StringToInt(info);
		DisplayShakeValueMenu(param1);
	}
}

DisplaySpeedValueMenu(client)
{
	new Handle:menu2a = CreateMenu(MenuHandler_SpeedPlayer);
	SetMenuTitle(menu2a, "新速度:");
	SetMenuExitBackButton(menu2a, true);
	AddMenuItem(menu2a, "l4d2speeddouble", "x2 速度");
	AddMenuItem(menu2a, "l4d2speedtriple", "x3 速度");
	AddMenuItem(menu2a, "l4d2speedhalf", "1/2 速度");
	AddMenuItem(menu2a, "l4d2speed3", "1/3 速度");
	AddMenuItem(menu2a, "l4d2speed4", "1/4 速度");
	AddMenuItem(menu2a, "l4d2speedquarter", "x4 速度");
	AddMenuItem(menu2a, "l4d2speedfreeze", "0 速度");
	AddMenuItem(menu2a, "l4d2speednormal", "正常速度");
	DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

DisplaySetHpValueMenu(client)
{
	new Handle:menu2b = CreateMenu(MenuHandler_SetHpPlayer);
	SetMenuTitle(menu2b, "新血量:");
	SetMenuExitBackButton(menu2b, true);
	AddMenuItem(menu2b, "l4d2hpdouble", "x2 血量");
	AddMenuItem(menu2b, "l4d2hptriple", "x3 血量");
	AddMenuItem(menu2b, "l4d2hphalf", "1/2 血量");
	AddMenuItem(menu2b, "l4d2hp3", "1/3 血量");
	AddMenuItem(menu2b, "l4d2hp4", "1/4 血量");
	AddMenuItem(menu2b, "l4d2hpquarter", "x4 血量");
	AddMenuItem(menu2b, "l4d2hppls100", "+100 血量");
	AddMenuItem(menu2b, "l4d2hppls50", "+50 血量");
	DisplayMenu(menu2b, client, MENU_TIME_FOREVER);
}

DisplayColorValueMenu(client)
{
	new Handle:menu2c = CreateMenu(MenuHandler_ColorPlayer);
	SetMenuTitle(menu2c, "选择颜色:");
	SetMenuExitBackButton(menu2c, true);
	AddMenuItem(menu2c, "l4d2colorred", "红");
	AddMenuItem(menu2c, "l4d2colorblue", "蓝");
	AddMenuItem(menu2c, "l4d2colorgreen", "绿");
	AddMenuItem(menu2c, "l4d2coloryellow", "黄");
	AddMenuItem(menu2c, "l4d2colorblack", "黑");
	AddMenuItem(menu2c, "l4d2colorwhite", "白(正常)");
	AddMenuItem(menu2c, "l4d2colortrans", "透明");
	AddMenuItem(menu2c, "l4d2colorhtrans", "半透明");
	DisplayMenu(menu2c, client, MENU_TIME_FOREVER);
}

DisplayScaleValueMenu(client)
{
	new Handle:menu2a = CreateMenu(MenuHandler_ScalePlayer);
	SetMenuTitle(menu2a, "选择大小:");
	SetMenuExitBackButton(menu2a, true);
	AddMenuItem(menu2a, "l4d2scaledouble", "x2 大小");
	AddMenuItem(menu2a, "l4d2scaletriple", "x3 大小");
	AddMenuItem(menu2a, "l4d2scalehalf", "1/2 大小");
	AddMenuItem(menu2a, "l4d2scale3", "1/3 大小");
	AddMenuItem(menu2a, "l4d2scale4", "1/4 大小");
	AddMenuItem(menu2a, "l4d2scalequarter", "x4 大小");
	AddMenuItem(menu2a, "l4d2scalefreeze", "0 大小");
	AddMenuItem(menu2a, "l4d2scalenormal", "正常大小");
	DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

DisplayShakeValueMenu(client)
{
	new Handle:menu2a = CreateMenu(MenuHandler_ShakePlayer);
	SetMenuTitle(menu2a, "摇晃时长:");
	AddMenuItem(menu2a, "shake60", "1 分钟");
	AddMenuItem(menu2a, "shake45", "45 秒");
	AddMenuItem(menu2a, "shake30", "30 秒");
	AddMenuItem(menu2a, "shake15", "15 秒");
	AddMenuItem(menu2a, "shake10", "10 秒");
	AddMenuItem(menu2a, "shake5", "5 秒");
	AddMenuItem(menu2a, "shake1", "1 秒");
	SetMenuExitBackButton(menu2a, true);
	DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}

DisplayChangeHpStyleMenu(client)
{
	new Handle:menu2a = CreateMenu(MenuHandler_ChangeHpPlayer);
	SetMenuTitle(menu2a, "选择类型:");
	SetMenuExitBackButton(menu2a, true);
	AddMenuItem(menu2a, "l4d2perm", "永久(实血)");
	AddMenuItem(menu2a, "l4d2temp", "临时(虚血)");
	DisplayMenu(menu2a, client, MENU_TIME_FOREVER);
}
	
//-------------------------------Do action------------------------------------
public MenuHandler_VomitPlayer(Handle:menu2, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu2, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		VomitPlayer(target, param1);
		DisplayVomitPlayerMenu(param1);
		LogCommand("\"%N\" used the \"Vomit Player\" command on \"%N\"", param1, target);
	}
}

public MenuHandler_TeleportPlayer(Handle:menu2, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu2, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		decl Float:VecOrigin[3], Float:VecAngles[3];
		GetClientAbsOrigin(param1, VecOrigin);
		GetClientEyeAngles(param1, VecAngles);
		TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, param1);
		if(TR_DidHit(INVALID_HANDLE))
		{
			TR_GetEndPosition(VecOrigin);
		}
		else
		{
			PrintToChat(param1, "Vector out of world geometry. Teleporting on origin instead");
		}
		TeleportEntity(target, VecOrigin, NULL_VECTOR, NULL_VECTOR);
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("'%s' used the 'Teleport' command on '%s'", name, name2);
		DisplayTeleportPlayerMenu(param1);
	}
}

public MenuHandler_ChargePlayer(Handle:menu2, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu2, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		Charge(target, param1);
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("%s used the 'Charger' command on '%s'", name, name2);
		DisplayChargePlayerMenu(param1);
	}
}

public MenuHandler_GodMode(Handle:menu2, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu2, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		GodMode(target, param1);
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("%s used the 'Gpd Mode' command on '%s'", name, name2);
		DisplayGodModeMenu(param1);
	}
}

public MenuHandler_IncapPlayer(Handle:menu3, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu3);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu3, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		IncapPlayer(target, param1);
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("%s used the 'Incap Player' command on '%s'", name, name2);
		DisplayIncapPlayerMenu(param1);
	}
}

public MenuHandler_SpeedPlayer(Handle:menu2a, MenuAction:action, param1, param2)
{	
	if (action == MenuAction_End)
	{
		CloseHandle(menu2a);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new Float:speed;
		new target = GetClientOfUserId(g_iCurrentUserId[param1]);
		switch(param2)
		{
			case 0:
			{
				speed = GetEntDataFloat(target, g_flLagMovement) * 2;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 1:
			{
				speed = GetEntDataFloat(target, g_flLagMovement) * 3;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 2:
			{
				speed = GetEntDataFloat(target, g_flLagMovement) / 2;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 3:
			{
				speed = GetEntDataFloat(target, g_flLagMovement) / 3;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 4:
			{
				speed = GetEntDataFloat(target, g_flLagMovement) / 4;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 5:
			{
				speed = GetEntDataFloat(target, g_flLagMovement) * 4.0;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 6:
			{
				speed = 0.0;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
			case 7:
			{
				
				speed = 1.0;
				ChangeSpeed(target, param1, speed);
				DisplaySpeedPlayerMenu(param1);
			}
		}
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("%s used the 'Speed Player' command on '%s' with value <%f>", name, name2, speed);
	}
}

public MenuHandler_SetHpPlayer(Handle:menu2b, MenuAction:action, param1, param2)
{	
	if (action == MenuAction_End)
	{
		CloseHandle(menu2b);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new health;
		new target = GetClientOfUserId(g_iCurrentUserId[param1]);
		switch(param2)
		{
			case 0:
			{
				health = GetClientHealth(target) * 2;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 1:
			{
				health = GetClientHealth(target) * 3;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 2:
			{
				health = GetClientHealth(target) / 2;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 3:
			{
				health = GetClientHealth(target) / 3;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 4:
			{
				health = GetClientHealth(target) / 4;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 5:
			{
				health = GetClientHealth(target) * 4;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 6:
			{
				health = GetClientHealth(target) + 100;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
			case 7:
			{
				health = GetClientHealth(target) + 50;
				SetHealth(target, param1, health);
				DisplaySetHpPlayerMenu(param1);
			}
		}
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("%s used the 'Set Health' command on '%s' with value <%i>", name, name2, health);
	}
}

public MenuHandler_ColorPlayer(Handle:menu2c, MenuAction:action, param1, param2)
{	
	if (action == MenuAction_End)
	{
		CloseHandle(menu2c);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new target = GetClientOfUserId(g_iCurrentUserId[param1]);
		switch(param2)
		{
			case 0:
			{
				ChangeColor(target, param1, RED);
				DisplayColorPlayerMenu(param1);
			}
			case 1:
			{
				ChangeColor(target, param1, BLUE);
				DisplayColorPlayerMenu(param1);
			}
			case 2:
			{
				ChangeColor(target, param1, GREEN);
				DisplayColorPlayerMenu(param1);
			}
			case 3:
			{
				ChangeColor(target, param1, YELLOW);
				DisplayColorPlayerMenu(param1);
			}
			case 4:
			{
				ChangeColor(target, param1, BLACK);
				DisplayColorPlayerMenu(param1);
			}
			case 5:
			{
				ChangeColor(target, param1, WHITE);
				DisplayColorPlayerMenu(param1);
			}
			case 6:
			{
				ChangeColor(target, param1, TRANSPARENT);
				DisplayColorPlayerMenu(param1);
			}
			case 7:
			{
				ChangeColor(target, param1, HALFTRANSPARENT);
				DisplayColorPlayerMenu(param1);
			}
		}
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("%s used the 'Set Color' command on '%s'", name, name2);
	}
}

public MenuHandler_CreateExplosion(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				decl Float:pos[3];
				GetClientAbsOrigin(param1, pos);
				CreateExplosion(pos);
			}
			case 1:
			{
				decl Float:VecOrigin[3], Float:VecAngles[3];
				GetClientAbsOrigin(param1, VecOrigin);
				GetClientEyeAngles(param1, VecAngles);
				TR_TraceRayFilter(VecOrigin, VecAngles, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitSelf, param1);
				if(TR_DidHit(INVALID_HANDLE))
				{
					TR_GetEndPosition(VecOrigin);
				}
				else
				{
					PrintToChat(param1, "Vector out of world geometry. Exploding on origin instead");
				}
				CreateExplosion(VecOrigin);
			}
		}
		decl String:name[256];
		GetClientName(param1, name, sizeof(name));
		LogCommand("'%s' used the 'Set Explosion' command", name);
		DisplayCreateExplosionMenu(param1);
	}
}

public MenuHandler_ScalePlayer(Handle:menu2a, MenuAction:action, param1, param2)
{	
	if (action == MenuAction_End)
	{
		CloseHandle(menu2a);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new Float:scale;
		new target = GetClientOfUserId(g_iCurrentUserId[param1]);
		switch(param2)
		{
			case 0:
			{
				scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale")  * 2;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 1:
			{
				scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale")  * 3;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 2:
			{
				scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale")  / 2;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 3:
			{
				scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale")  / 3;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 4:
			{
				scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale")  / 4;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 5:
			{
				scale = GetEntPropFloat(target, Prop_Send, "m_flModelScale")  * 4;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 6:
			{
				scale = 0.0;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
			case 7:
			{
				scale = 1.0;
				ChangeScale(target, param1, scale);
				DisplayScalePlayerMenu(param1);
			}
		}
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("'%s' used the 'Scale Player' command on '%s' with value <%f>", name, name2, scale);
	}
}

public MenuHandler_ShakePlayer(Handle:menu2a, MenuAction:action, param1, param2)
{	
	if (action == MenuAction_End)
	{
		CloseHandle(menu2a);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		new target = GetClientOfUserId(g_iCurrentUserId[param1]);
		switch(param2)
		{
			case 0:
			{
				Shake(target, param1, 60.0);
				DisplayShakePlayerMenu(param1);
			}
			case 1:
			{
				Shake(target, param1, 45.0);
				DisplayShakePlayerMenu(param1);
			}
			case 2:
			{
				Shake(target, param1, 30.0);
				DisplayShakePlayerMenu(param1);
			}
			case 3:
			{
				Shake(target, param1, 15.0);
				DisplayShakePlayerMenu(param1);
			}
			case 4:
			{
				Shake(target, param1, 10.0);
				DisplayShakePlayerMenu(param1);
			}
			case 5:
			{
				Shake(target, param1, 5.0);
				DisplayShakePlayerMenu(param1);
			}
			case 6:
			{
				Shake(target, param1, 1.0);
				DisplayShakePlayerMenu(param1);
			}
		}
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("'%s' used the 'Shake Player' command on '%s'", name, name2);
	}
}

public MenuHandler_BleedPlayer(Handle:menu10, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu10);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu10, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		TeleportBack(target, param1);
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("'%s' used the 'Bleed Player' command on '%s'", name, name2);
		DisplayBleedPlayerMenu(param1);
	}
}

public MenuHandler_Airstrike(Handle:menu2, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32];
		new userid, target;
		GetMenuItem(menu2, param2, info, sizeof(info));
		userid = StringToInt(info);
		target = GetClientOfUserId(userid);
		if(target == 0)
		{
			PrintToChat(param1, "\x04[SM] \x03客户端无效");
			return;
		}
		if(GetClientTeam(target) == 1)
		{
			PrintToChat(param1, "\x04[SM] \x03观察者不能成为目标");
			return;
		}
		Airstrike(target);
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(target, name2, sizeof(name2));
		LogCommand("'%s' used the 'Airstrike' command on '%s'", name, name2);
		DisplayAirstrikeMenu(param1);
	}
}

public MenuHandler_ChangeHpPlayer(Handle:menu2, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu2);
	}
	
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && GetAdminTopMenu() != INVALID_HANDLE)
		{
			DisplayTopMenu(GetAdminTopMenu(), param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				SwitchHealth(GetClientOfUserId(g_iCurrentUserId[param1]), param1, 1);
			}
			case 1:
			{
				SwitchHealth(GetClientOfUserId(g_iCurrentUserId[param1]), param1, 2);
			}
		}
		decl String:name[256], String:name2[256];
		GetClientName(param1, name, sizeof(name));
		GetClientName(GetClientOfUserId(g_iCurrentUserId[param1]), name2, sizeof(name2));
		LogCommand("'%s' used the 'Switch Health Style' command on '%s'", name, name2);
		DisplayChangeHpMenu(param1);
	}
}
//*******************************************FUNCTIONS******************************************
VomitPlayer(target, sender)
{
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "[SM]Spectators cannot be vomited!");
		return;
	}
	if(GetClientTeam(target) == 3)
	{
		SDKCall(sdkVomitInfected, target, sender, true);
	}
	if(GetClientTeam(target) == 2)
	{
		SDKCall(sdkVomitSurvivor, target, sender, true);
	}
}

IncapPlayer(target, sender)
{
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "[SM]Spectators cannot be incapacitated!");
		return;
	}
	else if(GetClientTeam(target) == 3 && GetEntProp(target, Prop_Send, "m_zombieClass") != 8)
	{
		PrintToChat(sender, "[SM]Only survivors and tanks can be incapacitated!");
		return;
	}
	else if(GetClientTeam(target) == 2 && GetEntProp(target, Prop_Send, "m_isIncapacitated") == 1)
	{
		PrintToChat(sender, "[SM]Cannot incap incapped survivors!");
		return;
	}
	
	if(IsValidEntity(target))
	{
		new iDmgEntity = CreateEntityByName("point_hurt");
		SetEntityHealth(target, 1);
		DispatchKeyValue(target, "targetname", "bm_target");
		DispatchKeyValue(iDmgEntity, "DamageTarget", "bm_target");
		DispatchKeyValue(iDmgEntity, "Damage", "100");
		DispatchKeyValue(iDmgEntity, "DamageType", "0");
		DispatchSpawn(iDmgEntity);
		AcceptEntityInput(iDmgEntity, "Hurt", target);
		DispatchKeyValue(target, "targetname", "bm_targetoff");
		RemoveEdict(iDmgEntity);
	}
}

ChangeSpeed(target, sender, Float:newspeed)
{
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "[SM]Cannot set a spectator's speed!");
		return;
	}
	SetEntDataFloat(target, g_flLagMovement, newspeed, true);
}

SetHealth(target, sender, amount)
{
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "[SM]Spectators have no health!");
		return;
	}
	SetEntityHealth(target, amount);
}

ChangeColor(target, sender, String:color[])
{
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "[SM]Cannot change color of an spectator");
		return;
	}
	DispatchKeyValue(target, "rendercolor", color);
}

CreateExplosion(Float:carPos[3])
{
	decl String:sRadius[256];
	decl String:sPower[256];
	new Float:flMxDistance = GetConVarFloat(g_cvarRadius);
	new Float:power = GetConVarFloat(g_cvarPower);
	IntToString(GetConVarInt(g_cvarRadius), sRadius, sizeof(sRadius));
	IntToString(GetConVarInt(g_cvarPower), sPower, sizeof(sPower));
	new exParticle2 = CreateEntityByName("info_particle_system");
	new exParticle3 = CreateEntityByName("info_particle_system");
	new exTrace = CreateEntityByName("info_particle_system");
	new exPhys = CreateEntityByName("env_physexplosion");
	new exHurt = CreateEntityByName("point_hurt");
	new exParticle = CreateEntityByName("info_particle_system");
	new exEntity = CreateEntityByName("env_explosion");
	/*new exPush = CreateEntityByName("point_push");*/
	
	//Set up the particle explosion
	DispatchKeyValue(exParticle, "effect_name", EXPLOSION_PARTICLE);
	DispatchSpawn(exParticle);
	ActivateEntity(exParticle);
	TeleportEntity(exParticle, carPos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchKeyValue(exParticle2, "effect_name", EXPLOSION_PARTICLE2);
	DispatchSpawn(exParticle2);
	ActivateEntity(exParticle2);
	TeleportEntity(exParticle2, carPos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchKeyValue(exParticle3, "effect_name", EXPLOSION_PARTICLE3);
	DispatchSpawn(exParticle3);
	ActivateEntity(exParticle3);
	TeleportEntity(exParticle3, carPos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchKeyValue(exTrace, "effect_name", FIRE_PARTICLE);
	DispatchSpawn(exTrace);
	ActivateEntity(exTrace);
	TeleportEntity(exTrace, carPos, NULL_VECTOR, NULL_VECTOR);
	
	
	//Set up explosion entity
	DispatchKeyValue(exEntity, "fireballsprite", "sprites/muzzleflash4.vmt");
	DispatchKeyValue(exEntity, "iMagnitude", sPower);
	DispatchKeyValue(exEntity, "iRadiusOverride", sRadius);
	DispatchKeyValue(exEntity, "spawnflags", "828");
	DispatchSpawn(exEntity);
	TeleportEntity(exEntity, carPos, NULL_VECTOR, NULL_VECTOR);
	
	//Set up physics movement explosion
	DispatchKeyValue(exPhys, "radius", sRadius);
	DispatchKeyValue(exPhys, "magnitude", sPower);
	DispatchSpawn(exPhys);
	TeleportEntity(exPhys, carPos, NULL_VECTOR, NULL_VECTOR);
	
	
	//Set up hurt point
	DispatchKeyValue(exHurt, "DamageRadius", sRadius);
	DispatchKeyValue(exHurt, "DamageDelay", "0.5");
	DispatchKeyValue(exHurt, "Damage", "5");
	DispatchKeyValue(exHurt, "DamageType", "8");
	DispatchSpawn(exHurt);
	TeleportEntity(exHurt, carPos, NULL_VECTOR, NULL_VECTOR);
	
	switch(GetRandomInt(1,3))
	{
		case 1:
		{
			if(!IsSoundPrecached(EXPLOSION_SOUND))
			{
				PrecacheSound(EXPLOSION_SOUND);
			}
			EmitSoundToAll(EXPLOSION_SOUND);
		}
		case 2:
		{
			if(!IsSoundPrecached(EXPLOSION_SOUND2))
			{
				PrecacheSound(EXPLOSION_SOUND2);
			}
			EmitSoundToAll(EXPLOSION_SOUND2);
		}
		case 3:
		{
			if(!IsSoundPrecached(EXPLOSION_SOUND3))
			{
				PrecacheSound(EXPLOSION_SOUND3);
			}
			EmitSoundToAll(EXPLOSION_SOUND3);
		}
	}
	
	if(!IsSoundPrecached(EXPLOSION_DEBRIS))
	{
		PrecacheSound(EXPLOSION_DEBRIS);
	}
	EmitSoundToAll(EXPLOSION_DEBRIS);
	
	//BOOM!
	AcceptEntityInput(exParticle, "Start");
	AcceptEntityInput(exParticle2, "Start");
	AcceptEntityInput(exParticle3, "Start");
	AcceptEntityInput(exTrace, "Start");
	AcceptEntityInput(exEntity, "Explode");
	AcceptEntityInput(exPhys, "Explode");
	AcceptEntityInput(exHurt, "TurnOn");
	
	new Handle:pack2 = CreateDataPack();
	WritePackCell(pack2, exParticle);
	WritePackCell(pack2, exParticle2);
	WritePackCell(pack2, exParticle3);
	WritePackCell(pack2, exTrace);
	WritePackCell(pack2, exEntity);
	WritePackCell(pack2, exPhys);
	WritePackCell(pack2, exHurt);
	CreateTimer(GetConVarFloat(g_cvarDuration)+1.5, timerDeleteParticles, pack2, TIMER_FLAG_NO_MAPCHANGE);
	
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, exTrace);
	WritePackCell(pack, exHurt);
	CreateTimer(GetConVarFloat(g_cvarDuration), timerStopFire, pack, TIMER_FLAG_NO_MAPCHANGE);
	
	decl Float:survivorPos[3], Float:traceVec[3], Float:resultingFling[3], Float:currentVelVec[3];
	for(new i=1; i<=MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2)
		{
			continue;
		}

		GetEntPropVector(i, Prop_Data, "m_vecOrigin", survivorPos);
		
		//Vector and radius distance calcs by AtomicStryker!
		if(GetVectorDistance(carPos, survivorPos) <= flMxDistance)
		{
			MakeVectorFromPoints(carPos, survivorPos, traceVec);				// draw a line from car to Survivor
			GetVectorAngles(traceVec, resultingFling);							// get the angles of that line
			
			resultingFling[0] = Cosine(DegToRad(resultingFling[1])) * power;	// use trigonometric magic
			resultingFling[1] = Sine(DegToRad(resultingFling[1])) * power;
			resultingFling[2] = power;
			
			GetEntPropVector(i, Prop_Data, "m_vecVelocity", currentVelVec);		// add whatever the Survivor had before
			resultingFling[0] += currentVelVec[0];
			resultingFling[1] += currentVelVec[1];
			resultingFling[2] += currentVelVec[2];
			
			FlingPlayer(i, resultingFling, i);
		}
	}
}

public Action:timerStopFire(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	new particle = ReadPackCell(pack);
	new hurt = ReadPackCell(pack);
	CloseHandle(pack);
	
	if(IsValidEntity(particle))
	{
		AcceptEntityInput(particle, "Stop");
	}
	if(IsValidEntity(hurt))
	{
		AcceptEntityInput(hurt, "TurnOff");
	}
}

public Action:timerDeleteParticles(Handle:timer, Handle:pack)
{
	ResetPack(pack);
	
	new entity;
	for (new i = 1; i <= 7; i++)
	{
		entity = ReadPackCell(pack);
		
		if(IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}
	}
	CloseHandle(pack);
}

stock FlingPlayer(target, Float:vector[3], attacker, Float:stunTime = 3.0)
{
	SDKCall(sdkCallPushPlayer, target, vector, 76, attacker, stunTime);
}

Charge(target, sender)
{
	decl Float:tpos[3], Float:spos[3];
	decl Float:distance[3], Float:ratio[3], Float:addVel[3], Float:tvec[3];
	GetClientAbsOrigin(target, tpos);
	GetClientAbsOrigin(sender, spos);
	distance[0] = (spos[0] - tpos[0]);
	distance[1] = (spos[1] - tpos[1]);
	distance[2] = (spos[2] - tpos[2]);
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", tvec);
	ratio[0] =  distance[0] / SquareRoot(distance[1]*distance[1] + distance[0]*distance[0]);//Ratio x/hypo
	ratio[1] =  distance[1] / SquareRoot(distance[1]*distance[1] + distance[0]*distance[0]);//Ratio y/hypo
	
	addVel[0] = (ratio[0]*-1) * 500.0;
	addVel[1] = (ratio[1]*-1) * 500.0;
	addVel[2] = 500.0;
	SDKCall(sdkCallPushPlayer, target, addVel, 76, sender, 7.0);
}

Bleed(target, sender, Float:duration)
{
	if(target == 0)
	{
		PrintToChat(sender, "\x04[SM] \x03客户端无效");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "\x04[SM] \x03没有目标为给定的名字!");
		return;
	}
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "\x04[SM] \x03不能让观察者流血!");
		return;
	}
	//Userid for targetting
	new userid = GetClientUserId(target);
	decl Float:pos[3], String:sName[64], String:sTargetName[64];
	new Particle = CreateEntityByName("info_particle_system");
	
	GetClientAbsOrigin(target, pos);
	TeleportEntity(Particle, pos, NULL_VECTOR, NULL_VECTOR);
	
	Format(sName, sizeof(sName), "%d", userid+25);
	DispatchKeyValue(target, "targetname", sName);
	GetEntPropString(target, Prop_Data, "m_iName", sName, sizeof(sName));
	
	Format(sTargetName, sizeof(sTargetName), "%d", userid+1000);
	
	DispatchKeyValue(Particle, "targetname", sTargetName);
	DispatchKeyValue(Particle, "parentname", sName);
	DispatchKeyValue(Particle, "effect_name", BLEED_PARTICLE);
	
	DispatchSpawn(Particle);
	
	DispatchSpawn(Particle);
	
	//Parent:		
	SetVariantString(sName);
	AcceptEntityInput(Particle, "SetParent", Particle, Particle);
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	
	CreateTimer(duration, timerEndEffect, Particle, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:timerEndEffect(Handle:timer, any:entity)
{
	if(entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

ChangeScale(target, sender, Float:scale)
{
	if(target == 0)
	{
		PrintToChat(sender, "\x04[SM] \x03客户端无效");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "\x04[SM] \x03没有目标为给定的名字!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "\x04[SM] \x03观察者没有默认大小的模型");
		return;
	}
	SetEntPropFloat(target, Prop_Send, "m_flModelScale", scale);
}

stock TeleportBack(target, sender)
{
	decl String:map[32], Float:pos[3];
	GetCurrentMap(map, sizeof(map));
	if(target == 0)
	{
		PrintToChat(sender, "[SM]Client is invalid");
		return;
	}
	if(target == -1)
	{
		PrintToChat(sender, "[SM]No targets with the given name!");
		return;
	}
	
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "[SM]Spectators cannot even rush!");
		return;
	}
	if(StrEqual(map, "c1m1_hotel"))
	{
		pos[0] = 568.0;
		pos[1] = 5707.0;
		pos[2] = 2848.0;
	}
	else if(StrEqual(map, "c1m2_streets"))
	{
		pos[0] = 2049.0;
		pos[1] = 4460.0;
		pos[2] = 1235.0;
	}
	else if(StrEqual(map, "c1m3_mall"))
	{
		pos[0] = 6697.0;
		pos[1] = -1424.0;
		pos[2] = 86.0;
	}
	else if(StrEqual(map, "c1m4_atrium"))
	{	
		pos[0] = -2046.0;
		pos[1] = -4641.0;
		pos[2] = 598.0;
	}
	else if(StrEqual(map, "c2m1_highway"))
	{
		pos[0] = 10855.0;
		pos[1] = 7864.0;
		pos[2] = -488.0;
	}
	else if(StrEqual(map, "c2m2_fairgrounds"))
	{
		pos[0] = 1653.0;
		pos[1] = 2796.0;
		pos[2] = 32.0;
	}
	else if(StrEqual(map, "c2m3_coaster"))
	{
		pos[0] = 4336.0;
		pos[1] = 2048.0;
		pos[2] = -1.0;
	}
	else if(StrEqual(map, "c2m4_barns"))
	{
		pos[0] = 3057.0;
		pos[1] = 3632.0;
		pos[2] = -152.0;
	}
	else if(StrEqual(map, "c2m5_concert"))
	{
		pos[0] = -938.0;
		pos[1] = 2194.0;
		pos[2] = -193.0;
	}
	else if(StrEqual(map, "c3m1_plankcountry"))
	{
		pos[0] = -12549.0;
		pos[1] = 10488.0;
		pos[2] = 270.0;
	}
	else if(StrEqual(map, "c3m2_swamp"))
	{
		pos[0] = -8158.0;
		pos[1] = 7531.0;
		pos[2] = 32.0;
	}
	else if(StrEqual(map, "c3m3_shantytown"))
	{
		pos[0] = -5718.0;
		pos[1] = 2137.0;
		pos[2] = 170.0;
	}
	else if(StrEqual(map, "c3m4_plantation"))
	{
		pos[0] = -5027.0;
		pos[1] = -1662.0;
		pos[2] = -34.0;
	}
	else if(StrEqual(map, "c4m1_milltown_a"))
	{
		pos[0] = -7097.0;
		pos[1] = 7706.0;
		pos[2] = 175.0;
	}
	else if(StrEqual(map, "c4m2_sugarmill_a"))
	{
		pos[0] = 3617.0;
		pos[1] = -1659.0;
		pos[2] = 270.0;
	}
	else if(StrEqual(map, "c4m3_sugarmill_b"))
	{
		pos[0] = -1788.0;
		pos[1] = -13701.0;
		pos[2] = 170.0;
	}
	else if(StrEqual(map, "c4m4_milltown_b"))
	{
		pos[0] = 3883.0;
		pos[1] = -1484.0;
		pos[2] = 270.0;
	}
	else if(StrEqual(map, "c4m5_milltown_escape"))
	{
		pos[0] = -3146.0;
		pos[1] = 7818.0;
		pos[2] = 182.0;
	}
	else if(StrEqual(map, "c5m1_waterfront"))
	{
		pos[0] = 790.0;
		pos[1] = 686.0;
		pos[2] = -419.0;
	}
	else if(StrEqual(map, "c5m2_park"))
	{
		pos[0] = -4119.0;
		pos[1] = -1263.0;
		pos[2] = -281.0;
	}
	else if(StrEqual(map, "c5m3_cemetery"))
	{
		pos[0] = 6361.0;
		pos[1] = 8372.0;
		pos[2] = 62.0;
	}
	else if(StrEqual(map, "c5m4_quarter"))
	{
		pos[0] = -3235.0;
		pos[1] = 4849.0;
		pos[2] = 130.0;
	}
	else if(StrEqual(map, "c5m5_bridge"))
	{
		pos[0] = -12062.0;
		pos[1] = 5913.0;
		pos[2] = 574.0;
	}
	else if(StrEqual(map, "c6m1_riverbank"))
	{
		pos[0] = 913.0;
		pos[1] = 3750.0;
		pos[2] = 156.0;
	}
	else if(StrEqual(map, "c6m2_bedlam"))
	{
		pos[0] = 3014.0;
		pos[1] = -1216.0;
		pos[2] = -233.0;
	}
	else if(StrEqual(map, "c6m3_port"))
	{
		pos[0] = -2364.0;
		pos[1] = -471.0;
		pos[2] = -193.0;
	}
	else
	{
		PrintToChat(sender, "\x04[SM] \x03当前地图不支持该指令!");
	}
	TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
	PrintHintText(target, "你因为冲太快而被送回起点!");
}

EndGame()
{
	for(new i=1; i<=MaxClients; i++)
	{
		if(i > 0 && IsValidEntity(i) && IsClientInGame(i) && IsPlayerAlive(i) && !IsClientObserver(i) && GetClientTeam(i) == 2)
		{
			ForcePlayerSuicide(i);
		}
	}
}

/*LaunchMissile(target, sender)
{
	//Missile: Doesn't exist
	decl Float:flCpos[3], Float:flTpos[3], Float:flDistance, Float:power, Float:distance[3], Float:flCang[3];
	power = 350.0;
	if(!AliveFilter(target))
	{
		PrintToChat(sender, "\x04[SM] \x03用户不是活着的!");
		return;
	}
	GetClientAbsOrigin(sender, flCpos);
	GetClientEyeAngles(sender, flCang);
	decl String:angles[32];
	Format(angles, sizeof(angles), "%f %f %f", flCang[0], flCang[1], flCang[2]);
	
	//Missile is being created
	new iMissile = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(iMissile, "model", MISSILE_MODEL);
	DispatchKeyValue(iMissile, "angles", angles);
	DispatchSpawn(iMissile);
	
	//Missile created but not visible. Teleporting
	TeleportEntity(iMissile, flCpos, NULL_VECTOR, NULL_VECTOR);
	
	decl Float:addVel[3], Float:final[3], Float:tvec[3], Float:ratio[3];
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", flTpos);
	distance[0] = (flCpos[0] - flTpos[0]);
	distance[1] = (flCpos[1] - flTpos[1]);
	distance[2] = (flCpos[2] - flTpos[2]);
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", tvec);
	ratio[0] =  FloatDiv(distance[0], SquareRoot(distance[1]*distance[1] + distance[0]*distance[0]));//Ratio x/hypo
	ratio[1] =  FloatDiv(distance[1], SquareRoot(distance[1]*distance[1] + distance[0]*distance[0]));//Ratio y/hypo
	
	addVel[0] = FloatMul(ratio[0]*-1, power);
	addVel[1] = FloatMul(ratio[1]*-1, power);
	addVel[2] = power;
	final[0] = FloatAdd(addVel[0], tvec[0]);
	final[1] = FloatAdd(addVel[1], tvec[1]);
	final[2] = power;
	FlingPlayer(target, addVel, target);
	TeleportEntity(iMissile, NULL_VECTOR, NULL_VECTOR, final);
}
*/

Airstrike(client)
{
	g_bStrike = true;
	CreateTimer(6.0, timerStrikeTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(1.0, timerStrike, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:timerStrikeTimeout(Handle:timer)
{
	g_bStrike = false;
}

public Action:timerStrike(Handle:timer, any:client)
{
	if(!g_bStrike)
	{
		return Plugin_Stop;
	}
	decl Float:pos[3];
	GetClientAbsOrigin(client, pos);
	new Float:radius = GetConVarFloat(g_cvarRainRadius);
	pos[0] += GetRandomFloat(radius*-1, radius);
	pos[1] += GetRandomFloat(radius*-1, radius);
	CreateExplosion(pos);		
	return Plugin_Continue;
}

stock BlackAndWhite(target, sender)
{
	if(target > 0 && IsValidEntity(target) && IsClientInGame(target) && IsPlayerAlive(target))
	{
		if(GetClientTeam(target) != 2)
		{
			PrintToChat(sender, "\x04[SM] \x03该指令只能用于生还者");
			return;
		}
		SetEntProp(target, Prop_Send, "m_currentReviveCount", GetConVarInt(FindConVar("survivor_max_incapacitated_count"))-1);
		SetEntProp(target, Prop_Send, "m_isIncapacitated", 1);
		SDKCall(sdkRevive, target);
		SetEntityHealth(target, 1);
		SetTempHealth(target, 50.0);
	}
}

stock SwitchHealth(target, sender, type)
{
	if(target > 0 && IsValidEntity(target) && IsClientInGame(target) && IsPlayerAlive(target))
	{
		if(GetClientTeam(target) != 2)
		{
			PrintToChat(sender, "\x04[SM] \x03该指令只能用于生还者");
			return;
		}
		if(type == 1)
		{
			new iTempHealth = GetClientTempHealth(target);
			new iPermHealth = GetClientHealth(target);
			RemoveTempHealth(target);
			SetEntityHealth(target, iTempHealth+iPermHealth);
		}
		else if(type == 2)
		{
			new iTempHealth = GetClientTempHealth(target);
			new iPermHealth = GetClientHealth(target);
			new Float:flTotal = Float:iTempHealth+iPermHealth;
			SetEntityHealth(target, 1);
			RemoveTempHealth(target);
			SetTempHealth(target, flTotal);
		}
	}
}

stock WeaponRain(String:weapon[], sender)
{
	decl String:item[64];
	Format(item, sizeof(item), "weapon_%s", weapon);
	g_bGnomeRain = true;
	CreateTimer(GetConVarFloat(g_cvarRainDur), timerRainTimeout, TIMER_FLAG_NO_MAPCHANGE);
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, sender);
	WritePackString(pack, item);
	CreateTimer(0.1, timerSpawnWeapon, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action:timerSpawnWeapon(Handle:timer, Handle:pack)
{
	decl String:item[96];
	ResetPack(pack);
	new client = ReadPackCell(pack);
	ReadPackString(pack, item, sizeof(item));
	
	
	decl Float:pos[3];
	new weap = CreateEntityByName(item);
	DispatchSpawn(weap);
	if(!g_bGnomeRain)
	{
		return Plugin_Stop;
	}
	GetClientAbsOrigin(client, pos);
	pos[2] += 350.0;
	new Float:radius = GetConVarFloat(g_cvarRainRadius);
	pos[0] += GetRandomFloat(radius*-1, radius);
	pos[1] += GetRandomFloat(radius*-1, radius);
	TeleportEntity(weap, pos, NULL_VECTOR, NULL_VECTOR);	
	return Plugin_Continue;
}

stock StartGnomeRain(client)
{
	g_bGnomeRain = true;
	CreateTimer(GetConVarFloat(g_cvarRainDur), timerRainTimeout, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, timerSpawnGnome, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

stock GodMode(target, sender)
{
	if(GetClientTeam(target) == 1)
	{
		PrintToChat(sender, "\x04[SM] \x03你不能将该指令用于观察者");
	}
	if(g_bHasGod[target])
	{
		SetEntProp(target, Prop_Data, "m_takedamage", 2, 1);
		g_bHasGod[target] = false;
		PrintToChat(sender, "\x04[SM] \x03选定玩家上帝模式 \x05[关闭]");
	}
	else
	{
		SetEntProp(target, Prop_Data, "m_takedamage", 0, 1);
		g_bHasGod[target] = true;
		PrintToChat(sender, "\x04[SM] \x03选定玩家上帝模式 \x05[开启]");
	}
}

public Action:timerRainTimeout(Handle:timer)
{
	g_bGnomeRain = false;
}

public Action:timerSpawnGnome(Handle:timer, any:client)
{
	decl Float:pos[3];
	new gnome = CreateEntityByName("weapon_gnome");
	DispatchSpawn(gnome);
	if(!g_bGnomeRain)
	{
		return Plugin_Stop;
	}
	GetClientAbsOrigin(client, pos);
	pos[2] += 350.0;
	new Float:radius = GetConVarFloat(g_cvarRainRadius);
	pos[0] += GetRandomFloat(radius*-1, radius);
	pos[1] += GetRandomFloat(radius*-1, radius);
	TeleportEntity(gnome, pos, NULL_VECTOR, NULL_VECTOR);	
	return Plugin_Continue;
}
	
stock bool:AliveFilter(client)
{
	if(client > 0 && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
	{
		return true;
	}
	return false;
}

stock CheatCommand(client, const String:command [], const String:arguments [])
{
	if (!client) return;
	if (!IsClientInGame(client)) return;
	if (!IsValidEntity(client)) return;
	new admindata = GetUserFlagBits(client);
	SetUserFlagBits(client, DESIRED_FLAGS);
	new flags = GetCommandFlags (command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, admindata);
}

public Action:Shake(target, sender, Float:duration)
{
	new Handle:hBf=StartMessageOne("Shake", target);
	if(hBf!=INVALID_HANDLE)
	{
		BfWriteByte(hBf, 0);                
		BfWriteFloat(hBf, 16.0);            // shake magnitude/amplitude
		BfWriteFloat(hBf, 0.5);                // shake noise frequency
		BfWriteFloat(hBf, duration);                // shake lasts this long
		EndMessage();
	}
}

stock InstructorHint(String:content[])
{	
	for(new i=1; i<=MaxClients; i++)
	{
		if(i > 0 && IsValidEntity(i) && IsClientInGame(i))
		{
			ClientCommand(i, "gameinstructor_enable 1");
		}
	}
	
	new iEntity = CreateEntityByName("env_instructor_hint");
	if(IsValidEntity(iEntity))
	{
		DispatchKeyValue(iEntity, "hint_auto_start", "0");
		DispatchKeyValue(iEntity, "hint_alphaoption", "1");
		DispatchKeyValue(iEntity, "hint_timeout", "10");
		DispatchKeyValue(iEntity, "hint_forcecaption", "Yes");
		DispatchKeyValue(iEntity, "hint_static", "1");
		DispatchKeyValue(iEntity, "hint_icon_offscreen", "icon_alert");
		DispatchKeyValue(iEntity, "hint_icon_onscreen", "icon_alert");
		DispatchKeyValue(iEntity, "hint_caption", content);
		DispatchKeyValue(iEntity, "hint_range", "1");
		DispatchKeyValue(iEntity, "hint_color", "255 255 255");
		
		DispatchSpawn(iEntity);
		AcceptEntityInput(iEntity, "ShowHint");
		CreateTimer(15.0, timerRemoveEntity, iEntity, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		LogError("Failed to create the instructor hint entity.");
	}
}

public Action:timerRemoveEntity(Handle:timer, any:entity)
{
	for(new i=1; i<=MaxClients; i++)
	{
		if(i > 0 && IsValidEntity(i) && IsClientInGame(i))
		{
			ClientCommand(i, "gameinstructor_enable 0");
		}
	}
	if(entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

stock bool:IsValidWeapon(String:weapon[])
{
	if(StrEqual(weapon, "rifle")
	|| StrEqual(weapon, "rifle_desert")
	|| StrEqual(weapon, "rifle_ak47")
	|| StrEqual(weapon, "sniper_military")
	|| StrEqual(weapon, "shotgun_spas")
	|| StrEqual(weapon, "shotgun_chrome")
	|| StrEqual(weapon, "smg")
	|| StrEqual(weapon, "pumpshotgun")
	|| StrEqual(weapon, "first_aid_kit")
	|| StrEqual(weapon, "chainsaw")
	|| StrEqual(weapon, "adrenaline")
	|| StrEqual(weapon, "autoshotgun")
	|| StrEqual(weapon, "sniper_scout")
	|| StrEqual(weapon, "molotov")
	|| StrEqual(weapon, "upgradepack_incendiary")
	|| StrEqual(weapon, "upgradepack_explosive")
	|| StrEqual(weapon, "pain_pills")
	|| StrEqual(weapon, "pipe_bomb")
	|| StrEqual(weapon, "vomitjar")
	|| StrEqual(weapon, "smg_silenced")
	|| StrEqual(weapon, "smg_mp5")
	|| StrEqual(weapon, "sniper_awp")
	|| StrEqual(weapon, "sniper_scout")
	|| StrEqual(weapon, "rifle_sg552")
	|| StrEqual(weapon, "gnome")
	|| StrEqual(weapon, "pistol_magnum")
	|| StrEqual(weapon, "hunting_rifle")
	|| StrEqual(weapon, "pistol")
	|| StrEqual(weapon, "grenade_launcher")
	|| StrEqual(weapon, "pistol_magnum")
	|| StrEqual(weapon, "gascan")
	|| StrEqual(weapon, "propanetank")
	|| StrEqual(weapon, "rifle_m60")
	|| StrEqual(weapon, "defibrillator"))
	{
		return true;
	}
	else 
	{
		return false;
	}
}

stock CreateParticle(client, String:Particle_Name[], bool:Parent, Float:duration)
{
	decl Float:pos[3], String:sName[64], String:sTargetName[64];
	new Particle = CreateEntityByName("info_particle_system");
	GetClientAbsOrigin(client, pos);
	TeleportEntity(Particle, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(Particle, "effect_name", Particle_Name);
	
	if(Parent)
	{
		new userid = GetClientUserId(client);
		Format(sName, sizeof(sName), "%d", userid+25);
		DispatchKeyValue(client, "targetname", sName);
		GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));
		
		Format(sTargetName, sizeof(sTargetName), "%d", userid+1000);
		DispatchKeyValue(Particle, "targetname", sTargetName);
		DispatchKeyValue(Particle, "parentname", sName);
	}
	DispatchSpawn(Particle);
	DispatchSpawn(Particle);
	if(Parent)
	{
		SetVariantString(sName);
		AcceptEntityInput(Particle, "SetParent", Particle, Particle);
	}
	ActivateEntity(Particle);
	AcceptEntityInput(Particle, "start");
	CreateTimer(duration, timerStopAndRemoveParticle, Particle, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:timerStopAndRemoveParticle(Handle:timer, any:entity)
{
	if(entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

stock IgnitePlayer(client, Float:duration)
{
	new team = GetClientTeam(client);
	if(team != 2)
	{
		IgniteEntity(client, duration);
	}
	else
	{
		decl Float:pos[3];
		GetClientAbsOrigin(client, pos);
		decl String:sUser[256];
		IntToString(GetClientUserId(client)+25, sUser, sizeof(sUser));
		CreateParticle(client, BURN_IGNITE_PARTICLE, true, duration);
		new Damage = CreateEntityByName("point_hurt");
		DispatchKeyValue(Damage, "Damage", "1");
		DispatchKeyValue(Damage, "DamageType", "8");
		DispatchKeyValue(client, "targetname", sUser);
		DispatchKeyValue(Damage, "DamageTarget", sUser);
		DispatchSpawn(Damage);
		TeleportEntity(Damage, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(Damage, "Hurt");
		CreateTimer(0.1, timerHurtMe, Damage, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		CreateTimer(duration, timerStopAndRemoveParticle, Damage, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:timerHurtMe(Handle:timer, any:hurt)
{
	if(IsValidEntity(hurt) && IsValidEdict(hurt))
	{
		AcceptEntityInput(hurt, "Hurt");
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	if(entity == data) // Check if the TraceRay hit the itself.
	{
		return false; // Don't let the entity be hit
	}
	return true; // It didn't hit itself
}
/***************DEVELOPMENT*********************************/

public Action:CmdEntityInfo(client, args)
{
	decl String:Classname[128];
	new entity = GetClientAimTarget(client, false);

	if ((entity == -1) || (!IsValidEntity (entity)))
	{
		ReplyToCommand (client, "Invalid entity, or looking to nothing");
	}
	GetEdictClassname(entity, Classname, sizeof(Classname));
	PrintToChat(client, "Classname: %s", Classname);
}

stock PrecacheParticle(String:ParticleName[])
{
	new Particle = CreateEntityByName("info_particle_system");
	if(IsValidEntity(Particle) && IsValidEdict(Particle))
	{
		DispatchKeyValue(Particle, "effect_name", ParticleName);
		DispatchSpawn(Particle);
		ActivateEntity(Particle);
		AcceptEntityInput(Particle, "start");
		CreateTimer(0.3, timerRemovePrecacheParticle, Particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:timerRemovePrecacheParticle(Handle:timer, any:Particle)
{
	if(IsValidEntity(Particle) && IsValidEdict(Particle))
	{
		AcceptEntityInput(Particle, "Kill");
	}
}

stock LogCommand(const String:format[], any:...)
{
	if(!GetConVarBool(g_cvarLog))
	{
		return;
	}
	decl String:buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	new Handle:file;
	decl String:FileName[256], String:sTime[256];
	FormatTime(sTime, sizeof(sTime), "%Y%m%d");
	BuildPath(Path_SM, FileName, sizeof(FileName), "logs/customcmds_%s.log", sTime);
	file = OpenFile(FileName, "a+");
	FormatTime(sTime, sizeof(sTime), "%b %d |%H:%M:%S| %Y");
	WriteFileLine(file, "%s: %s", sTime, buffer);
	FlushFile(file);
	CloseHandle(file);
}

stock GrabLookingEntity(client)
{
	new entity = GetLookingEntity(client);
	if(g_bGrab[client])
	{
		PrintToChat(client, "\x04[SM] \x03你已经持有一个entity");
		return;
	}
	else if(g_bGrabbed[entity])
	{
		PrintToChat(client, "\x04[SM] \x03该entity已经移动过");
		return;
	}
	if(client > 0 && IsValidEntity(client))
	{
		decl String:class[256];
		GetEdictClassname(client, class, sizeof(class));
		g_bGrab[client] = true;
		g_bGrabbed[entity] = true;
		g_iLastGrabbedEntity[client] = entity;
		PrintToChat(client, "\x04[SM] \x03你现在正拿着一个entity");
		
		decl String:sName[64], String:sObjectName[64];
		new userid = GetClientUserId(client);
		Format(sName, sizeof(sName), "%d", userid+25);
		Format(sObjectName, sizeof(sObjectName), "%d", entity+100);
		DispatchKeyValue(entity, "targetname", sObjectName);
		DispatchKeyValue(client, "targetname", sName);
		GetEntPropString(client, Prop_Data, "m_iName", sName, sizeof(sName));
		DispatchKeyValue(entity, "parentname", sName);
		SetVariantString(sName);
		AcceptEntityInput(entity, "SetParent", entity, entity);
		return;
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03该entity无效");
	}
}

stock ReleaseLookingEntity(client)
{
	new entity = g_iLastGrabbedEntity[client];
	if(entity > 0 && IsValidEntity(entity))
	{
		g_bGrab[client] = false;
		g_bGrabbed[entity] = false;
		PrintToChat(client, "\x04[SM] \x03你不再持有一个object");
		DispatchKeyValue(entity, "targetname", "NULL_TARGET_NAME");
		DispatchKeyValue(entity, "parentname", "NULL_PARENT_NAME");
		SetEntityRenderColor(entity, 255, 255 ,255, 255);
		AcceptEntityInput(entity, "SetParent");
		return;
	}
	else
	{
		PrintToChat(client, "\x04[SM] \x03该entity无效");
	}
}

stock CreateAcidSpill(iTarget, iSender)
{
	decl Float:vecPos[3];
	GetClientAbsOrigin(iTarget, vecPos);
	vecPos[2]+=16.0;
	
	new iAcid = CreateEntityByName("spitter_projectile");
	if(IsValidEntity(iAcid))
	{
		DispatchSpawn(iAcid);
		SetEntPropFloat(iAcid, Prop_Send, "m_DmgRadius", 1024.0); // Radius of the acid.
		SetEntProp(iAcid, Prop_Send, "m_bIsLive", 1 ); // Without this set to 1, the acid won't make any sound.
		SetEntPropEnt(iAcid, Prop_Send, "m_hThrower", iSender); // A player who caused the acid to appear.
		TeleportEntity(iAcid, vecPos, NULL_VECTOR, NULL_VECTOR);
		SDKCall(sdkDetonateAcid, iAcid);
	}
}

stock SetAdrenalineEffect(iTarget, iSender)
{
	SDKCall(sdkAdrenaline, iTarget, 15.0);
}

stock SetTempHealth(iTarget, Float:flAmount)
{
	SDKCall(sdkSetBuffer, iTarget, flAmount);
}

stock RevivePlayer(iTarget, iSender)
{
	if(GetEntProp(iTarget, Prop_Send, "m_isIncapacitated") || GetEntProp(iTarget, Prop_Send, "m_isHangingFromLedge"))
	{
		SDKCall(sdkRevive, iTarget);
	}
	else
	{
		PrintToChat(iSender, "\x04[SM] \x03该玩家未倒地");
	}
}

stock GetClientTempHealth(client)
{
	//First filter -> Must be a valid client, successfully in-game and not an spectator (The dont have health).
    if(!client
    || !IsValidEntity(client)
    || !IsClientInGame(client)
	|| !IsPlayerAlive(client)
    || IsClientObserver(client)
	|| GetClientTeam(client) != 2)
    {
        return -1;
    }
    
    //First, we get the amount of temporal health the client has
    new Float:buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    
    //We declare the permanent and temporal health variables
    new Float:TempHealth;
    
    //In case the buffer is 0 or less, we set the temporal health as 0, because the client has not used any pills or adrenaline yet
    if(buffer <= 0.0)
    {
        TempHealth = 0.0;
    }
    
    //In case it is higher than 0, we proceed to calculate the temporl health
    else
    {
        //This is the difference between the time we used the temporal item, and the current time
        new Float:difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
        
        //We get the decay rate from this convar (Note: Adrenaline uses this value)
        new Float:decay = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
        
        //This is a constant we create to determine the amount of health. This is the amount of time it has to pass
        //before 1 Temporal HP is consumed.
        new Float:constant = 1.0/decay;
        
        //Then we do the calcs
        TempHealth = buffer - (difference / constant);
    }
    
    //If the temporal health resulted less than 0, then it is just 0.
    if(TempHealth < 0.0)
    {
        TempHealth = 0.0;
    }
    
    //Return the value
    return RoundToFloor(TempHealth);
}

stock RemoveTempHealth(client)
{
	if(!client
    || !IsValidEntity(client)
    || !IsClientInGame(client)
	|| !IsPlayerAlive(client)
    || IsClientObserver(client)
	|| GetClientTeam(client) != 2)
    {
        return;
    }
	SetTempHealth(client, 0.0);
}

stock PanicEvent()
{
	new Director = CreateEntityByName("info_director");
	DispatchSpawn(Director);
	AcceptEntityInput(Director, "ForcePanicEvent");
	AcceptEntityInput(Director, "Kill");
}

stock GetLookingEntity(client)
{
	decl Float:VecOrigin[3], Float:VecAngles[3];
	GetClientEyePosition(client, VecOrigin);
	GetClientEyeAngles(client, VecAngles);
	TR_TraceRayFilter(VecOrigin, VecAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	if(TR_DidHit(INVALID_HANDLE))
	{
		new entity = TR_GetEntityIndex(INVALID_HANDLE);
		if(entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
		{
			return entity;
		}
	}
	return -1;
}