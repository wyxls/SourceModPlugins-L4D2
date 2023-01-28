#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION 				"1.0.3"
#define INFECTED_NAMES 				6
#define WITCH_LEN 					32
#define CVAR_FLAGS 					FCVAR_NOTIFY
#define CVAR_FLAGS_PLUGIN_VERSION 	FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY

public Plugin myinfo =
{
	name 		= "[L4D1 AND L4D2] Infected HP",
	author 		= "NiCo-op, Edited By Ernecio (Satanael)",
	description = "L4D Infected HP",
	version 	= PLUGIN_VERSION,
	url 		= "http://nico-op.forjp.net/"
};

ConVar hPluginEnable;
ConVar hBarLEN;
ConVar hCharHealth;
ConVar hCharDamage;
ConVar hShowType;
ConVar hShowNum;
ConVar hTank;
ConVar hWitch;
ConVar hWitchHealth;
ConVar hInfected[INFECTED_NAMES];

int witchCUR = 0;
int witchMAX[WITCH_LEN];
int witchHP[WITCH_LEN];
int witchID[WITCH_LEN];
int prevMAX[MAXPLAYERS+1];
int prevHP[MAXPLAYERS+1];
int nCharLength;
int nShowType;
int nShowNum;
int nShowTank;
int nShowWitch;
int nShowFlag[INFECTED_NAMES];

char sCharHealth[8] = "#";
char sCharDamage[8] = "=";

char sClassName[][] = 
{
	"boome",
	"hunter",
	"smoker",
	"jockey",
	"spitter",
	"charger"
};

public void OnPluginStart()
{
	hWitchHealth = FindConVar("z_witch_health");

	CreateConVar(				   "l4d_infectedhp_version", PLUGIN_VERSION, "L4D Infected HP version", CVAR_FLAGS_PLUGIN_VERSION );
	hPluginEnable 	= CreateConVar("l4d_infectedhp", 			"1", 		"plugin on/off (on:1 / off:0)", CVAR_FLAGS, true, 0.0, true, 1.0 );
	hBarLEN 		= CreateConVar("l4d_infectedhp_bar", 		"10", 		"length of health bar (def:100 / min:10 / max:200)", CVAR_FLAGS, true, 10.0, true, 200.0 );
	hCharHealth 	= CreateConVar("l4d_infectedhp_health", 	"|", 		"show health character", CVAR_FLAGS );
	hCharDamage 	= CreateConVar("l4d_infectedhp_damage", 	" ", 		"show damage character", CVAR_FLAGS );
	hShowType 		= CreateConVar("l4d_infectedhp_type", 		"0", 		"health bar type (def:0 / center text:0 / hint text:1)", CVAR_FLAGS, true, 0.0, true, 1.0 );
	hShowNum 		= CreateConVar("l4d_infectedhp_num", 		"1", 		"health value display (def:0 / hidden:0 / visible:1)", CVAR_FLAGS, true, 0.0, true, 1.0 );
	hTank 			= CreateConVar("l4d_infectedhp_tank", 		"1", 		"show health bar for tank(def:1 / on:1 / off:0)", CVAR_FLAGS, true, 0.0, true, 1.0 );
	hWitch 			= CreateConVar("l4d_infectedhp_witch", 		"1", 		"show health bar for witch(def:1 / on:1 / off:0)", CVAR_FLAGS, true, 0.0, true, 1.0 );
	hInfected[0] 	= CreateConVar("l4d_infectedhp_boomer", 	"1", 		"show health bar (def:1 / on:1 / off:0)", CVAR_FLAGS, true, 0.0, true, 1.0 );
	
	char buffers[64];
	char sClassNames[64];
	for(int i = 1; i < INFECTED_NAMES; i ++)
	{
		Format(buffers, sizeof(buffers), "l4d_infectedhp_%s", sClassName[i]);
		Format(sClassNames, sizeof(sClassNames), "show health bar for %s (def:1 / on:1 / off:0)", sClassNames[i]);
		hInfected[i] = CreateConVar(buffers, "1", sClassNames, CVAR_FLAGS, true, 0.0, true, 1.0 );
	}

	HookEvent("round_start", 	OnRoundStart, 	 EventHookMode_Post);
	HookEvent("player_hurt", 	OnPlayerHurt);
	HookEvent("witch_spawn", 	OnWitchSpawn);
	HookEvent("witch_killed", 	OnWitchKilled);
	HookEvent("infected_hurt", 	OnWitchHurt);
	HookEvent("player_spawn", 	OnInfectedSpawn, EventHookMode_Post);
	HookEvent("player_death", 	OnInfectedDeath, EventHookMode_Pre);
//	HookEvent("tank_spawn", 	OnInfectedSpawn);
//	HookEvent("tank_killed", 	OnInfectedDeath, EventHookMode_Pre);

	AutoExecConfig(true, "l4d_infected_hp");
}

void GetConfig()
{
	char bufA[8];
	char bufB[8];
	hCharHealth.GetString( bufA, sizeof( bufA ) );
	hCharDamage.GetString( bufB, sizeof( bufB ) );
	nCharLength = strlen(bufA);
	if(!nCharLength || nCharLength != strlen(bufB))
	{
		nCharLength = 1;
		sCharHealth[0] = '#';
		sCharHealth[1] = '\0';
		sCharDamage[0] = '=';
		sCharDamage[1] = '\0';
	}
	else
	{
		strcopy(sCharHealth, sizeof(sCharHealth), bufA);
		strcopy(sCharDamage, sizeof(sCharDamage), bufB);
	}

	nShowType = hShowType.BoolValue;
	nShowNum = hShowNum.BoolValue;
	nShowTank = hTank.BoolValue;
	nShowWitch = hWitch.BoolValue;
	for(int i = 0; i < INFECTED_NAMES; i ++)
	{
		nShowFlag[i] = GetConVarBool(hInfected[i]);
	}
}

void ShowHealthGauge(int client, int maxBAR, int maxHP, int nowHP, char[] clName)
{
	int percent = RoundToCeil((float(nowHP) / float(maxHP)) * float(maxBAR));
	int i; 
	int length = maxBAR * nCharLength + 2;
	static char showBAR[256];
	
	showBAR[0] = '\0';
	for(i = 0; i < percent && i < maxBAR; i ++) StrCat(showBAR, length, sCharHealth);
	for(; i < maxBAR; i ++) 					StrCat(showBAR, length, sCharDamage);

	if(nShowType)
	{
		if(!nShowNum) 	PrintHintText(client, "HP: |-%s-|  %s", showBAR, clName);
		else 			PrintHintText(client, "HP: |-%s-|  [%d / %d]  %s", showBAR, nowHP, maxHP, clName);
	}
	else
	{
		if(!nShowNum) 	PrintCenterText(client, "HP: |-%s-|  %s", showBAR, clName);
		else 			PrintCenterText(client, "HP: |-%s-|  [%d / %d]  %s", showBAR, nowHP, maxHP, clName);
	}
}

public void OnRoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	nShowTank = 0;
	nShowWitch = 0;
	witchCUR = 0;
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		witchMAX[i] = -1;
		witchHP[i] = -1;
		witchID[i] = -1;

	}
	for(int i = 0; i < MAXPLAYERS + 1; i ++)
	{
		prevMAX[i] = -1;
		prevHP[i] = -1;
	}
}

public Action TimerSpawn(Handle timer, any client)
{
	if(IsValidEntity(client))
	{
		int val = GetEntProp(client, Prop_Send, "m_iMaxHealth") & 0xffff;
		prevMAX[client] = ( val <= 0 ) ? val : 1;
		prevHP[client] = 999999;
	}
	return Plugin_Stop;
}

public void OnInfectedSpawn(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	GetConfig();

	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if( client > 0 && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		TimerSpawn(INVALID_HANDLE, client);
		CreateTimer(0.5, TimerSpawn, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnInfectedDeath(Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if ( !hPluginEnable.BoolValue ) return;

	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if( client > 0 && IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 3 )
	{
		char clName[128];
		GetClientName(client, clName, sizeof(clName));
		prevMAX[client] = -1;
		prevHP[client] = -1;
		if(nShowTank && StrContains(clName, "Tank", false) != -1)
			for(int i = 1; i <= MaxClients; i ++)
				if(IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2)
					PrintHintText(i, "++ %s 死亡 ++", clName);
	}
}

public void OnPlayerHurt( Event hEvent, const char[] sName, bool bDontBroadcast)
{
	if(!GetConVarBool(hPluginEnable)) return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!attacker || !IsClientConnected(attacker) || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) return;
	
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	if(!client || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 3) return;

	char class[128];
	GetClientModel(client, class, sizeof(class));
	int match = 0;
	for(int i = 0; i < INFECTED_NAMES; i ++){
		if(nShowFlag[i] && StrContains(class, sClassName[i], false) != -1){
			match = 1;
			break;
		}
	}
	
	if(!match && (!nShowTank || (nShowTank && StrContains(class, "tank", false) == -1 && StrContains(class, "hulk", false) == -1))) return;

	int maxBAR = hBarLEN.IntValue;
	int nowHP = GetEventInt(hEvent, "health") & 0xffff;
	int maxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth") & 0xffff;

	if(nowHP <= 0 || prevMAX[client] < 0) 	nowHP = 0;
	
	if(nowHP && nowHP > prevHP[client]) 	nowHP = prevHP[client];
	else 									prevHP[client] = nowHP;
	
	if(maxHP < prevMAX[client]) 			maxHP = prevMAX[client];
	
	if(maxHP < nowHP){
		maxHP = nowHP;
		prevMAX[client] = nowHP;
	}
	
	if(maxHP < 1) maxHP = 1;

	char clName[MAX_NAME_LENGTH];
	GetClientName(client, clName, sizeof(clName));
	ShowHealthGauge(attacker, maxBAR, maxHP, nowHP, clName);
}

public void OnWitchSpawn( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	GetConfig();

	int entity = hEvent.GetInt( "witchid" );
	witchID[witchCUR] = entity;

	int health = (hWitchHealth == INVALID_HANDLE) ? 0 : hWitchHealth.IntValue;
	witchMAX[witchCUR] = health;
	witchHP[witchCUR] = health;
	witchCUR = (witchCUR + 1) % WITCH_LEN;
}

public void OnWitchKilled( Event hEvent, const char[] sName, bool bDontBroadcast)
{
	int entity = hEvent.GetInt( "witchid" );
	
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == entity)
		{
			witchMAX[i] = -1;
			witchHP[i] = -1;
			witchID[i] = -1;
			break;
		}
	}
}

public void OnWitchHurt( Event hEvent, const char[] sName, bool bDontBroadcast )
{
	if ( !nShowWitch || !GetConVarBool( hPluginEnable ) ) return;
	
	int attacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	if(!attacker || !IsClientConnected(attacker) || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2) return;

	int entity = hEvent.GetInt( "entityid" );
	for(int i = 0; i < WITCH_LEN; i ++)
	{
		if(witchID[i] == entity)
		{
			int damage = GetEventInt(hEvent, "amount");
			int maxBAR = GetConVarInt(hBarLEN);
			int nowHP = witchHP[i] - damage;
			int maxHP = witchMAX[i];

			if(nowHP <= 0 || witchMAX[i] < 0) nowHP = 0;
			
			if(nowHP && nowHP > witchHP[i])	nowHP = witchHP[i];
			else							witchHP[i] = nowHP;
			
			if( maxHP < 1 )	maxHP = 1;
			
			char clName[64];
			if(i == 0) 	strcopy(clName, sizeof(clName), "Witch");
			else 		Format(clName, sizeof(clName), "(%d)Witch", i);
			
			ShowHealthGauge(attacker, maxBAR, maxHP, nowHP, clName);
		}
	}
}
