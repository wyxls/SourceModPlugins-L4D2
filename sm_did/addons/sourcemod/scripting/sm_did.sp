#include <sourcemod>

#define Version "1.3.5b"
#define DEBUGMODE 0
#define BaseDisplayMode 2
#define BaseDisplayOnDeathMode 2

new Handle:Allowed = INVALID_HANDLE;
new Handle:cvarAnnounce = INVALID_HANDLE;
new Handle:DefaultMode = INVALID_HANDLE;
new Handle:DefaultOnDeathMode = INVALID_HANDLE;
new Handle:SurvivorBlockMode = INVALID_HANDLE;
new Handle:CurrentGameMode = INVALID_HANDLE;
new Handle:kvDIDUS; //handle for user settings

new DisplayMode[MAXPLAYERS+1] = {BaseDisplayMode, ...};
new DisplayOnDeathMode[MAXPLAYERS+1] = {BaseDisplayOnDeathMode, ...};
new Damage[MAXPLAYERS+1][MAXPLAYERS+1];
new CurrentDamage[MAXPLAYERS+1][MAXPLAYERS+1];
new TotalDamageDone[MAXPLAYERS+1];
new TotalDamageReceived[MAXPLAYERS+1];
new TotalDamageDoneTA[MAXPLAYERS+1];
new TotalDamageReceivedTA[MAXPLAYERS+1];
new TotalDamageReceivedInfected[MAXPLAYERS+1];
new CurTotalDamageDone[MAXPLAYERS+1];
new CurTotalDamageReceived[MAXPLAYERS+1];
new CurTotalDamageDoneTA[MAXPLAYERS+1];
new CurTotalDamageReceivedTA[MAXPLAYERS+1];
new CurTotalDamageReceivedInfected[MAXPLAYERS+1];
new InfectedKills[MAXPLAYERS+1];
new CurInfectedKills[MAXPLAYERS+1];
new PlayerKills[MAXPLAYERS+1];
new CurPlayerKills[MAXPLAYERS+1];
new FirstHurt[MAXPLAYERS+1][MAXPLAYERS+1]; // Fix incorrect calculation CurrentDamage at round change
new PlayerReachedSafeRoom[MAXPLAYERS+1];

new bool:ReachedSafeRoom;	// (Coop) Start counting number of survivors in saferoom
new bool:HasRoundEnded;		// Prevent duplicate RoundEnd events
new bool:lateLoaded;		// Check plugin was late loaded

new String:fileDIDUS[128]; //file for user settings

public Plugin:myinfo = 
{
	name = "Damage Info Display",
	author = "Dionys && -pk- && sheleu",
	description = "Display the damage info.",
	version = Version,
	url = "skiner@inbox.ru"
};

public bool AskPluginLoad2()
{
	lateLoaded = true;
	return true;
}

public OnPluginStart()
{
	decl String:ModName[50];
	GetGameFolderName(ModName, sizeof(ModName));

	/* 2010.08.07 sheleu
	if (!StrEqual(ModName, "left4dead", false))
	{
		SetFailState("Use this Left 4 Dead only.");
	}
	*/

	LoadTranslations("plugin.sm_did");
	AutoExecConfig(true, "sm_did");

	//Events we need to hook
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_ready", Event_RoundEnd_Finale, EventHookMode_PostNoCopy);

	CreateConVar("sm_did_version", Version, "Version of Display Damage plugin.", FCVAR_NOTIFY);
	Allowed = CreateConVar("sm_did_enabled","1","Enables Display Damage to players.");
	CurrentGameMode = FindConVar("mp_gamemode");
	DefaultMode = CreateConVar("sm_did_defhint","2","Default Display Damage mode. 1 = all; 2 = damage done; 3 = damage received; any other = no display.");
	DefaultOnDeathMode = CreateConVar("sm_did_deftotal","2","Default Display Damage on Death mode. 1 = Display Total Damage; 2 = Display Damage Since Last Spawn; any other = no display.");
	SurvivorBlockMode = CreateConVar("sm_did_survivor_block","0","Block HintInfo about infected damages for survivor. 0 = off; 1 = on.");
	cvarAnnounce = CreateConVar("sm_did_announce","1","Enables Display Damage to advertise to players.");

	HookConVarChange(CurrentGameMode, OnCVGameModeChange);

	RegConsoleCmd("sm_did_hmode", DIDMenu);
	RegConsoleCmd("sm_did_tmode", DIDOnDeathMenu);
	RegConsoleCmd("sm_did", CallDIDTotalMenu, "Call DID Total Panel");
	RegConsoleCmd("sm_did_clear", cmdClearDID, "Clear all Damages");


	// initial game mode
	if (l4d_gamemode() == 2)
	{
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	}
	else if (l4d_gamemode() == 1)
	{
		HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
		HookEvent("map_transition", Event_Maptransition, EventHookMode_PostNoCopy);
		HookEvent("player_entered_checkpoint", Event_PlayerEnterRescueZone);
		HookEvent("player_left_checkpoint", Event_PlayerLeavesRescueZone);
	}

	// initialize client settings
	kvDIDUS=CreateKeyValues("didUserSettings");
  	BuildPath(Path_SM, fileDIDUS, 128, "data/sm_did_settings.txt");
	if (!FileToKeyValues(kvDIDUS, fileDIDUS))
    	KeyValuesToFile(kvDIDUS, fileDIDUS);

    // if the plugin was loaded late we have a bunch of initialization that needs to be done
	if (lateLoaded)
	{
	    // First need to do whatever we would have done at OnMapStart()
		SaveUserSettings();
		// Next need to whatever we would have done as each client authorized
		new maxClients = GetMaxClients();
		for (new i = 1; i <= maxClients; i++)
		{
			if (IsClientInGame(i))
			{
				PrepareClient(i);
			}
		}
	}
}

public OnMapStart()
{
	SaveUserSettings();
}

public OnClientPutInServer(client)
{
	if (client)
	{
		new maxClients = GetMaxClients();
		for (new Arg = 1; Arg <= maxClients; Arg++)
		{
			FirstHurt[Arg][client] = 1;
			FirstHurt[client][Arg] = 1;
		}

		PrepareClient(client);

		TotalDamageDone[client] = 0;
		TotalDamageReceived[client] = 0;
		TotalDamageDoneTA[client] = 0;
		TotalDamageReceivedTA[client] = 0;
		TotalDamageReceivedInfected[client] = 0;
		InfectedKills[client] = 0;
		PlayerKills[client] = 0;
		CurTotalDamageDone[client] = 0;
		CurTotalDamageReceived[client] = 0;
		CurTotalDamageDoneTA[client] = 0;
		CurTotalDamageReceivedTA[client] = 0;
		CurTotalDamageReceivedInfected[client] = 0;
		CurInfectedKills[client] = 0;
		CurPlayerKills[client] = 0;
	}
}

public OnClientDisconnect(client)
{
	decl String:steamId[20];
	if (client && !IsFakeClient(client))
	{
		GetClientAuthString(client, steamId, 20);

		KvRewind(kvDIDUS);
		if (KvJumpToKey(kvDIDUS, steamId))
		{
			new String:datestamp[60];
			FormatTime(datestamp, sizeof(datestamp), "%H:%M:%S / %d-%m-%Y", GetTime());
			KvSetString(kvDIDUS, "last connect", datestamp);
		}
	}
}

public Handler_DeathPanel(Handle:menu, MenuAction:action, param1, param2)
{
}

// Mode switcher - DID Mode
public DIDMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new ModeCheck = 0;
	if (param1 >= 0)
		ModeCheck = DisplayMode[param1];

	new selNum = param2 + 1;

	if (action == MenuAction_Select)
	{
		if (selNum == 4)
		{
			DisplayMode[param1] = 0;
		}
		else
		{
			DisplayMode[param1] = selNum;
		}

		decl String:steamId[20];
		GetClientAuthString(param1, steamId, 20);
		KvRewind(kvDIDUS);
		KvJumpToKey(kvDIDUS, steamId);
		KvSetNum(kvDIDUS, "hint preference", DisplayMode[param1]);

		if (ModeCheck == DisplayMode[param1])
		{
			PrintToChat(param1, "\x04[DID]\x03 %t", "menu stay mode");
		}
		else
		{
			switch (DisplayMode[param1])
			{
			  case 0:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu disable mode");
			  case 1:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu all mode");
			  case 2:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu done mode");
			  case 3:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu received mode");
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		// nothing
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//  This creates menu - DID mode
public Action:DIDMenu(client, args)
{
	new Handle:menu = CreateMenu(DIDMenuHandler);
	decl String:mBuffer[100];
	
	Format(mBuffer, sizeof(mBuffer), "%t", "DID Menu", client);
	SetMenuTitle(menu, mBuffer);

	if (DisplayMode[client] == 1)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu all mode", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu all mode", client);
	AddMenuItem(menu, "mode_all", mBuffer);
	if (DisplayMode[client] == 2)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu done mode", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu done mode", client);
	AddMenuItem(menu, "mode_done", mBuffer);
	if (DisplayMode[client] == 3)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu received mode", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu received mode", client);
	AddMenuItem(menu, "mode_received", mBuffer);
	if (DisplayMode[client] == 0)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu disable mode", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu disable mode", client);
	AddMenuItem(menu, "mode_off", mBuffer);
 
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
 
	return Plugin_Handled
}

// Mode switcher - Display on Death mode
public DIDOnDeathMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new ModeCheck = 0;
	if (param1 >= 0)
		ModeCheck = DisplayOnDeathMode[param1];

	new selNum = param2 + 1;

	if (action == MenuAction_Select)
	{
		if (selNum == 3)
		{
			DisplayOnDeathMode[param1] = 0;
		}
		else
		{
			DisplayOnDeathMode[param1] = selNum;
		}

		decl String:steamId[20];
		GetClientAuthString(param1, steamId, 20);
		KvRewind(kvDIDUS);
		KvJumpToKey(kvDIDUS, steamId);
		KvSetNum(kvDIDUS, "total preference", DisplayOnDeathMode[param1]);

		if (ModeCheck == DisplayOnDeathMode[param1])
		{
			PrintToChat(param1, "\x04[DID]\x03 %t", "menu stay mode");
		}
		else
		{
			switch (DisplayOnDeathMode[param1])
			{
			  case 0:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu disable mode");
			  case 1:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu PDeath total");
			  case 2:
				PrintToChat(param1, "\x04[DID]\x03 %t \x04%t\x03", "menu get mode", "menu PDeath current");
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		// nothing
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//  This creates menu - Display on Death mode
public Action:DIDOnDeathMenu(client, args)
{
	new Handle:menu = CreateMenu(DIDOnDeathMenuHandler);
	decl String:mBuffer[100];
	
	Format(mBuffer, sizeof(mBuffer), "%t", "DID PDeath Menu", client);
	SetMenuTitle(menu, mBuffer);

	if (DisplayOnDeathMode[client] == 1)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu PDeath total", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu PDeath total", client);
	AddMenuItem(menu, "mode_ptotal", mBuffer);
	if (DisplayOnDeathMode[client] == 2)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu PDeath current", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu PDeath current", client);
	AddMenuItem(menu, "mode_pcurrent", mBuffer);
	if (DisplayOnDeathMode[client] == 0)
		Format(mBuffer, sizeof(mBuffer), "%t [%t]", "menu disable mode", "menu current use", client);
	else
		Format(mBuffer, sizeof(mBuffer), "%t", "menu disable mode", client);
	AddMenuItem(menu, "mode_disable", mBuffer);
 
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
 
	return Plugin_Handled
}

// Mode switcher - Select mode for call current total
public CallDIDTotalMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	new selNum = param2 + 1;

	if (action == MenuAction_Select)
	{
		if (selNum == 1)
		{
			DisplayTotal(param1);
		}
		if (selNum == 2)
		{
			DisplayCurrentTotal(param1);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		// nothing
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

//  This creates menu - Select mode for call current total
public Action:CallDIDTotalMenu(client, args)
{
	new Handle:menu = CreateMenu(CallDIDTotalMenuHandler);
	decl String:mBuffer[100];
	
	Format(mBuffer, sizeof(mBuffer), "%t", "DID Current Total Menu", client);
	SetMenuTitle(menu, mBuffer);

	Format(mBuffer, sizeof(mBuffer), "%t", "menu PDeath total", client);
	AddMenuItem(menu, "mode_tmode", mBuffer);
	Format(mBuffer, sizeof(mBuffer), "%t", "menu PDeath current", client);
	AddMenuItem(menu, "mode_cmode", mBuffer);
 
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
 
	return Plugin_Handled
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		new DamageHealth = GetEventInt(event, "dmg_health");

		//Total game event byte length must be < 1024
		if (DamageHealth < 1024)
		{
			new victim = GetClientOfUserId(GetEventInt(event, "userid"));
			new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

			if (FirstHurt[attacker][victim] == 1)
			{
				Damage[attacker][victim] = 0;
				CurrentDamage[attacker][victim] = 0;
				FirstHurt[attacker][victim] = 0;
			}

			Damage[attacker][victim] += DamageHealth;
			CurrentDamage[attacker][victim] += DamageHealth;

			// Display info
			if (victim != 0 && attacker != 0)
			{
				if (victim == attacker)
				{
					PrintHintText(victim, "%t %iHP.", "Hint Noob Hurt", CurrentDamage[attacker][victim]);
				}
				else if (GetClientTeam(victim) == GetClientTeam(attacker))
				{
					TotalDamageReceivedTA[victim] += Damage[attacker][victim];
					TotalDamageDoneTA[attacker] += Damage[attacker][victim];
					CurTotalDamageReceivedTA[victim] += Damage[attacker][victim];
					CurTotalDamageDoneTA[attacker] += Damage[attacker][victim];

					if (DisplayMode[victim] == 1 || DisplayMode[victim] == 3)
						PrintHintText(victim, "友伤!!! %N %t %iHP.", attacker, "Hint EtoP Hurt", CurrentDamage[attacker][victim]);
					if (DisplayMode[attacker] == 1 || DisplayMode[attacker] == 2)
						PrintHintText(attacker, "停!!! %t %N: %iHP.", "Hint PtoE Hurt", victim, CurrentDamage[attacker][victim]);
				}
				else
				{
					TotalDamageReceived[victim] += Damage[attacker][victim];
					TotalDamageDone[attacker] += Damage[attacker][victim];
					CurTotalDamageReceived[victim] += Damage[attacker][victim];
					CurTotalDamageDone[attacker] += Damage[attacker][victim];

					if (DisplayMode[victim] == 1 || DisplayMode[victim] == 3)
						PrintHintText(victim, "%N %t %iHP.", attacker, "Hint EtoP Hurt", CurrentDamage[attacker][victim]);
					if ((DisplayMode[attacker] == 1 || DisplayMode[attacker] == 2) && (!GetConVarBool(SurvivorBlockMode) || (GetConVarBool(SurvivorBlockMode) && GetClientTeam(attacker) != 2)))
						PrintHintText(attacker, "%t %N: %iHP.", "Hint PtoE Hurt", victim, CurrentDamage[attacker][victim]);
				}
			}
			else
			{
				TotalDamageReceivedInfected[victim] += Damage[attacker][victim];
				CurTotalDamageReceivedInfected[victim] += Damage[attacker][victim];
			}

			Damage[attacker][victim] = 0;
		}
	}
}

public Action:Event_InfectedDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		if (attacker && attacker != 0)
		{
			if (!IsFakeClient(attacker))
			{
				InfectedKills[attacker] += 1;
				CurInfectedKills[attacker] += 1;
			}
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		new victim = GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		new maxClients = GetMaxClients();
		for (new Arg = 1; Arg <= maxClients; Arg++)
		{
			CurrentDamage[Arg][victim] = 0;
			CurrentDamage[victim][Arg] = 0;
		}

		// Note: players can die from entities too (attacker=0) when they take fire or fall damage
		if (victim != 0 && attacker != victim)
		{

			// If a real player kills another player or bot
			if (attacker != 0 && !IsFakeClient(attacker))
			{
				PlayerKills[attacker] += 1;
				CurPlayerKills[attacker] += 1;
			}

			// If victim is a real player
			if (!IsFakeClient(victim))
			{
				switch (DisplayOnDeathMode[victim])
				{
				  case 1: // Total Damage
					DisplayTotal(victim);
				  case 2: // Current Total Damage
					DisplayCurrentTotal(victim);
				}

				ClearCurrentTotal(victim);	//must be cleared on each death
			}

			// (Coop) Check if all survivors are in saferoom
			if (ReachedSafeRoom)
			{
				if (IsClientInGame(victim) && GetClientTeam(victim) == 2)
				{
					#if DEBUGMODE
					PrintToChatAll("\x04survivor died (clientid %i)", victim);
					#endif

					// If player dies in the saferoom, remove them before we recount
					// Note: game automatically removes them from checkpoint after death, but this would happen after the survivor count causing an 'extra player' in saferoom.
					PlayerReachedSafeRoom[victim] = 0;

					if (SurvivorsSafe() >= SurvivorsAlive())
					{
						// Don't display if a survivor died after round has ended
						if (!HasRoundEnded)
						{
							#if DEBUGMODE
							PrintToChatAll("\x04All Survivors Reached SafeRoom.");
							#endif

							RoundEndMsg();
							return Plugin_Continue;
						}
					}
				}
				return Plugin_Continue;
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_RoundStart (Handle:event, const String:name[], bool:dontBroadcast)
{
	HasRoundEnded = false;
	ReachedSafeRoom = false;

	new maxClients = GetMaxClients();
	for (new i = 1; i <= maxClients; i++)
	{
		PlayerReachedSafeRoom[i] = 0;
	}
	return;
}

public Action:Event_PlayerEnterRescueZone(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		decl String:door[64];
		GetEventString(event, "doorname", door, sizeof(door));

		if (StrEqual(door, "checkpoint_entrance", false) || StrEqual(door, "door_checkpointentrance", false))
		{
			new client = GetClientOfUserId(GetEventInt(event, "userid"));

			if (client != 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
			{
				#if DEBUGMODE
				PrintToChatAll("\x04entered saferoom (clientid %i)", client);
				#endif

				PlayerReachedSafeRoom[client] = 1;

				//start counting survivors after the first survivor enters saferoom
				ReachedSafeRoom = true;

				if (SurvivorsSafe() >= SurvivorsAlive())
				{
					// dont display damage again
					if (!HasRoundEnded)
					{
						#if DEBUGMODE
						PrintToChatAll("\x04All Survivors Reached SafeRoom.");
						#endif

						RoundEndMsg();
						return Plugin_Continue;
					}
				}
			}
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerLeavesRescueZone(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		if (ReachedSafeRoom)
		{
			//note: We must assume the checkpoint is the saferoom because "area" values wont match up.
			new client = GetClientOfUserId(GetEventInt(event, "userid"));

			if (client != 0 && IsClientInGame(client) && GetClientTeam(client) == 2)
			{
				PlayerReachedSafeRoom[client] = 0;

				#if DEBUGMODE
				PrintToChatAll("\x04left saferoom (clientid %i)", client);
				//SurvivorsSafe();
				//SurvivorsAlive();
				#endif

			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_MissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		#if DEBUGMODE
		PrintToChatAll("\x04All survivors have died.");
		#endif

		RoundEndMsg();
		return;
	}
	return;
}

public Action:Event_Maptransition(Handle:event, const String:name[], bool:dontBroadcast)
{
	//this is a backup display if the checkpoint system fails on custom maps
	if (GetConVarBool(Allowed))
	{
		if (!HasRoundEnded)
		{
			#if DEBUGMODE
			PrintToChatAll("\x04Warning: map_transition triggered, checkpoint system failed. Check if map has the correct checkpoints.");
			#endif

			RoundEndMsg();
			return;
		}
	}
	return;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(Allowed))
	{
		if (!HasRoundEnded)
		{
			#if DEBUGMODE
			PrintToChatAll("\x04RoundEnd Triggered.");
			#endif

			RoundEndMsg();
			return;
		}
	}
	return;
}

public Action:Event_RoundEnd_Finale(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if DEBUGMODE
	PrintToChatAll("\x04Finale End Triggered.");
	#endif

	if (GetConVarBool(Allowed))
		RoundEndMsg();

	return;
}

SurvivorsAlive()
{
	new Survivors = 0;
	new maxClients = GetMaxClients();
	for (new client = 1; client <= maxClients; client++)
	{
		if (IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
			Survivors++;
	}

	#if DEBUGMODE
	PrintToChatAll("\x04  survivors alive: %i ", Survivors);
	#endif

	return Survivors;
}

SurvivorsSafe()
{
	new Survivors;
	new maxClients = GetMaxClients();
	for (new i = 1; i <= maxClients; i++)
	{
		if (PlayerReachedSafeRoom[i] == 1)
			Survivors++;
	}

	#if DEBUGMODE
	PrintToChatAll("\x04  survivors in saferoom: %i ", Survivors);
	#endif

	return Survivors;
}

RoundEndMsg()
{
	HasRoundEnded = true;
	ReachedSafeRoom = false;

	new maxClients = GetMaxClients();
	for (new client = 1; client <= maxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			// Dont display for infected waiting to spawn if they just saw Total Damage display
			// Always display for survivors incase they died early on
			if (!(GetClientTeam(client) == 3 && IsPlayerAlive(client) == false && DisplayOnDeathMode[1] == 1))
				DisplayTotal(client);
		}

		ClearTotal(client);
	}
}

public Action:cmdClearDID(client, args)
{
	ClearTotal(client);
	PrintToChat(client, "\x04[DID]\x03 DID now is clear.");
}

l4d_gamemode()
{
	// 1 - coop / 2 - versus / 3 - survival / or false (thx DDR Khat for code)
	new String:gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));

	if (strcmp(gmode, "coop") == 0)
	{
		return 1;
	}
	else if (strcmp(gmode, "versus", false) == 0)
	{
		return 2;
	}
	else if (strcmp(gmode, "survival", false) == 0)
	{
		return 3;
	}
	else
	{
		return false;
	}
}

DisplayTotal(client)
{
	decl String:pDeath[100];
	new Handle:pDeathPanel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	Format(pDeath, sizeof(pDeath), "%t", "DID Total Panel", client);
	SetPanelTitle(pDeathPanel, pDeath);
	DrawPanelItem(pDeathPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg done", TotalDamageDone[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg doneta", TotalDamageDoneTA[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg receive", TotalDamageReceived[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg zombie", TotalDamageReceivedInfected[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg receiveta", TotalDamageReceivedTA[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	DrawPanelItem(pDeathPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	Format(pDeath, sizeof(pDeath), "%t: %i", "pnl kill zombie", InfectedKills[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %i", "pnl kill player", PlayerKills[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	SendPanelToClient(pDeathPanel, client, Handler_DeathPanel, 10);
	CloseHandle(pDeathPanel);
}

DisplayCurrentTotal(client)
{
	decl String:pDeath[100];
	new Handle:pDeathPanel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
	Format(pDeath, sizeof(pDeath), "%t", "DID Current Panel", client);
	SetPanelTitle(pDeathPanel, pDeath);
	DrawPanelItem(pDeathPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg done", CurTotalDamageDone[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg doneta", CurTotalDamageDoneTA[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg receive", CurTotalDamageReceived[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg zombie", CurTotalDamageReceivedInfected[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %iHP", "pnl dmg receiveta", CurTotalDamageReceivedTA[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	DrawPanelItem(pDeathPanel, " ", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	Format(pDeath, sizeof(pDeath), "%t: %i", "pnl kill zombie", CurInfectedKills[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	Format(pDeath, sizeof(pDeath), "%t: %i", "pnl kill player", CurPlayerKills[client], client);
	DrawPanelText(pDeathPanel, pDeath);
	SendPanelToClient(pDeathPanel, client, Handler_DeathPanel, 10);
	CloseHandle(pDeathPanel);
}

ClearTotal(client)
{
	TotalDamageDone[client] = 0;
	TotalDamageReceived[client] = 0;
	TotalDamageDoneTA[client] = 0;
	TotalDamageReceivedTA[client] = 0;
	TotalDamageReceivedInfected[client] = 0;
	InfectedKills[client] = 0;
	PlayerKills[client] = 0;

	// Need to clear CurrentTotal every time we clear the Total.  End of round and did_clear in chat.
	ClearCurrentTotal(client);
}

ClearCurrentTotal(client)
{
	CurTotalDamageDone[client] = 0;
	CurTotalDamageReceived[client] = 0;
	CurTotalDamageDoneTA[client] = 0;
	CurTotalDamageReceivedTA[client] = 0;
	CurTotalDamageReceivedInfected[client] = 0;
	CurInfectedKills[client] = 0;
	CurPlayerKills[client] = 0;
}

SaveUserSettings()
{
	// Save user settings to a file
	KvRewind(kvDIDUS);
	KeyValuesToFile(kvDIDUS, fileDIDUS);
}

PrepareClient(client)
{
	decl String:steamId[20];

	if (!IsFakeClient(client))
	{
		GetClientAuthString(client, steamId, 20);

		// Get the users saved setting or create them if they don't exist
		KvRewind(kvDIDUS);
		if (KvJumpToKey(kvDIDUS, steamId))
		{
			DisplayMode[client] = KvGetNum(kvDIDUS, "hint preference", GetConVarInt(DefaultMode));
			DisplayOnDeathMode[client] = KvGetNum(kvDIDUS, "total preference", GetConVarInt(DefaultOnDeathMode));
		}
		else
		{
			KvJumpToKey(kvDIDUS, steamId, true);
			KvSetNum(kvDIDUS, "hint preference", GetConVarInt(DefaultMode));
			KvSetNum(kvDIDUS, "total preference", GetConVarInt(DefaultOnDeathMode));
			new String:datestamp[60];
			FormatTime(datestamp, sizeof(datestamp), "%H:%M:%S / %d-%m-%Y", GetTime());
			KvSetString(kvDIDUS, "last connect", datestamp);

			DisplayMode[client] = GetConVarInt(DefaultMode);
			DisplayOnDeathMode[client] = GetConVarInt(DefaultOnDeathMode);
		}
		KvRewind(kvDIDUS);

		// Make the announcement in 30 seconds unless announcements are turned off
		if (GetConVarBool(cvarAnnounce))
			CreateTimer(30.0, TimerAnnounce, client);
	}
}

public OnCVGameModeChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	//If game mode actually changed
	if (strcmp(oldValue, newValue) != 0 && (l4d_gamemode() == 1 || l4d_gamemode() == 2 || l4d_gamemode() == 3))
	{
		// initial game mode
		if (l4d_gamemode() == 2)
		{
			HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		}
		else if (l4d_gamemode() == 1)
		{
			HookEvent("mission_lost", Event_MissionLost, EventHookMode_PostNoCopy);
			HookEvent("map_transition", Event_Maptransition, EventHookMode_PostNoCopy);
			HookEvent("player_entered_checkpoint", Event_PlayerEnterRescueZone);
			HookEvent("player_left_checkpoint", Event_PlayerLeavesRescueZone);
		}
	}
}

public Action:TimerAnnounce(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		PrintToChat(client, "\x04[DID]\x03 %t \x04!did_hmode !did_tmode !did !did_clear", "About");
		if (GetConVarBool(SurvivorBlockMode))
			PrintToChat(client, "\x04[DID]\x03 %t", "HintsTextBlocked");
	}
}
