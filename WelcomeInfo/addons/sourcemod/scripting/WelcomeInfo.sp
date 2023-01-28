#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <colors> //http://forums.alliedmods.net/showthread.php?t=96831
#include <geoip>
#include <dbi>
//其实这 3个是多余的. 只是给你们参考看而已
#define L4D_TEAM_INFECTED 3
#define L4D_TEAM_SURVIVOR 2
#define L4D_TEAM_SPECTATOR 1
#define DB_CONF_NAME "ip"
static bool:g_bCooldown[MAXPLAYERS + 1] = {false};

new String:logFile[1024];
new SwitchTeamDEnabled;
new Handle:hSwitchTeamDEnabled  = INVALID_HANDLE;
new bool:g_ClientPutInServer[MAXPLAYERS+1] = {false};
new player_num;

public Plugin:myinfo =    
{   
	name = "Welcome or Teamchange Info with SteamID,Country,City,IP",   
	author = "by Zakikun",   
	description = "Left 4 Dead 1 & 2",   
	version = "3.0"
}   

public OnPluginStart()   
{   
	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/Ip_Info.log");
	RegConsoleCmd("sm_info", ipCommand,"查看自己信息");
	
	hSwitchTeamDEnabled = CreateConVar("l4d_switchteamdenabled", "0", "开启关闭队伍变更提示");
	
	// 捆绑游戏事件
	HookEvent("player_team",Event_PlayerChangeTeam);
	HookEvent("round_start", evtRoundStart, EventHookMode_Post);
	HookEvent("round_end", evtRoundEnd, EventHookMode_Pre);
	HookEvent("map_transition", evtRoundEnd, EventHookMode_Pre);

	// 捆绑变量变化事件
	HookConVarChange(hSwitchTeamDEnabled, ConVarSwitchTeamDEnabled);

	AutoExecConfig(true,"WelcomeInfo");
}

public OnClientPutInServer(client)
{
	if (IsFakeClient(client))
		return;
	g_ClientPutInServer[client] = true;
	ipCommand(client, 0);
}

//public OnClientAuthorized(client,const String:SteamId[])
public OnClientConnected(client)   
{
	if (IsFakeClient(client))
	{
		return;
	}

	// 检测当前玩家数量
	SurvivorCheck();

	// 由于新加入玩家未计入，所以需要+1才能显示正确数量
	player_num++;

	g_ClientPutInServer[client] = true;
	if (!IsFakeClient(client) && g_ClientPutInServer[client])
	{
		decl String:ClientIP[16];
		GetClientIP(client, ClientIP, sizeof(ClientIP));

		decl String:Name[128];
		GetClientName(client, Name, sizeof(Name));

		new String:SteamId[128];
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId), false);

		decl String:country[46];

		decl String:city[128];

		if(GeoipCountry(ClientIP, country, sizeof(country)) && GeoipCity(ClientIP, city, sizeof(city)) && !IsFakeClient(client))
		{   
			CPrintToChatAll("{green}[WelcomeInfo]\n{olive} %N {lightgreen}加入游戏! 目前玩家总人数是{green}%i{lightgreen}人\nsteamID: {olive}%s\n{lightgreen}IP: {olive}%s  {lightgreen}来自: {olive}%s %s", client, player_num, SteamId, ClientIP, country, city);
			PrintToServer(" %N 加入游戏了! %s  IP: %s  来自: %s %s", client, SteamId, ClientIP, country, city);
		}
		else if(!IsFakeClient(client))
		{
			CPrintToChatAll("{green}[WelcomeInfo]\n{olive} %N {lightgreen}加入游戏! 目前玩家总人数是{green}%i{lightgreen}人\nsteamID: {olive}%s\n{lightgreen}IP: {olive}%s  {lightgreen}来自: {olive}", client, player_num, SteamId, ClientIP);
			PrintToServer(" %N 加入游戏了! %s  IP: %s  来自: 局域网", client, SteamId, ClientIP);
		}
		CreateTimer(0.5, Cooldown_Timer, client);
	}
}

public OnClientDisconnect(client)
{
	// 检测当前玩家数量
	SurvivorCheck();

	decl String:ClientIP[16];
	GetClientIP(client, ClientIP, sizeof(ClientIP));

	decl String:Name[128];
	GetClientName(client, Name, sizeof(Name));

	new String:SteamId[128];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId), true);

	decl String:country[46];
	GeoipCountry(ClientIP, country, sizeof(country));

	decl String:city[128];
	GeoipCity(ClientIP, city, sizeof(city));

	if(!IsFakeClient(client))
	{
		--player_num;
		CPrintToChatAll("{green}[WelcomeInfo] {olive}%N {lightgreen}退出游戏, 目前玩家总人数是{green}%i{lightgreen}人", client, player_num);
		PrintToServer(" %N 退出游戏了! %s  IP: %s  来自: %s %s", client, SteamId, ClientIP, country, city);
	}
}

public Event_PlayerChangeTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userID = GetClientOfUserId(GetEventInt(event, "userid"));
	new userTeam = GetEventInt(event, "team");
	if (userID == 0) 
		return;
	g_ClientPutInServer[userID] = true;
	new String:SteamId[128];
	GetClientAuthId(userID, AuthId_Steam2, SteamId, sizeof(SteamId), false);
	if (StrEqual(SteamId, "BOT"))
		return;
	if (SwitchTeamDEnabled == 0)
		return;
	decl String:ClientIP[16];
	GetClientIP(userID, ClientIP, sizeof(ClientIP));
	
	decl String:country[46];

	decl String:city[128];

	if (g_ClientPutInServer[userID])
	{
		if(userTeam==L4D_TEAM_SPECTATOR && GeoipCountry(ClientIP, country, sizeof(country)) && GeoipCity(ClientIP, city, sizeof(city)) && !IsFakeClient(userID))
		{
			CPrintToChatAll("{green}[WelcomeInfo] {olive} %N {default}加入旁观{default}! {olive}%s .\n {default}IP: {olive}%s  {default}来自: {olive}%s %s", userID, SteamId, ClientIP, country, city);
			PrintToServer(" %N 加入旁观! %s  IP: %s  来自: %s %s", userID, SteamId, ClientIP, country, city);
		}
		else if(userTeam==L4D_TEAM_SPECTATOR && !IsFakeClient(userID))
		{
			PrintToChatAll("\x04 %N \x01 加入旁观\x01 \x05%s .\n \x04IP: \x05%s  \x04来自: \x05局域网",  userID, SteamId, ClientIP);
		}
		if(userTeam==L4D_TEAM_SURVIVOR && GeoipCountry(ClientIP, country, sizeof(country)) && GeoipCity(ClientIP, city, sizeof(city)) && !IsFakeClient(userID))
		{
			CPrintToChatAll("{green}[WelcomeInfo] {olive} %N {blue}加入幸存者{default}! {olive}%s\n{default}IP: {olive}%s  {default}来自: {olive}%s %s", userID, SteamId, ClientIP, country, city);
			PrintToServer(" %N 加入幸存者! %s  IP: %s  来自: %s %s", userID, SteamId, ClientIP, country, city);
		}
		else if(userTeam==L4D_TEAM_SURVIVOR && !IsFakeClient(userID))
		{
			PrintToChatAll("\x04 %N \x01 加入幸存者\x01 \x05%s .\n \x04IP: \x05%s  \x04来自: \x05局域网",  userID, SteamId, ClientIP);
		}
		if(userTeam==L4D_TEAM_INFECTED && GeoipCountry(ClientIP, country, sizeof(country)) && GeoipCity(ClientIP, city, sizeof(city)) && !IsFakeClient(userID))
		{
			CPrintToChatAll("{green}[WelcomeInfo] {olive} %N {red}加入感染者{default}! {olive}%s .\n {default}IP: {olive}%s  {default}来自: {olive}%s %s", userID, SteamId, ClientIP, country, city);
			PrintToServer(" %N 加入感染者! %s  IP: %s  来自: %s %s %i", userID, SteamId, ClientIP, country, city);
		}
		else if(userTeam==L4D_TEAM_INFECTED && !IsFakeClient(userID))
		{
			PrintToChatAll("\x04 %N \x01 加入感染者\x01 \x05%s\n\x04IP: \x05%s  \x04来自: \x05局域网", userID, SteamId, ClientIP);
		}
	}
}

public Action:Cooldown_Timer(Handle:timer, any:client)
{
	g_bCooldown[client] = false;
	g_ClientPutInServer[client] = false;
	return Plugin_Stop;
}

// 在回合开始时检测一次当前玩家数量
public Action:evtRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	SurvivorCheck();
}

// 在回合结束时检测一次当前玩家数量
public Action:evtRoundEnd (Handle:event, const String:name[], bool:dontBroadcast)
{
	SurvivorCheck();
}

// 地图最终关结束时玩家数量统计清零
public OnMapEnd()
{
	player_num = 0;
}

// 检测变量变化
public ConVarSwitchTeamDEnabled(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SwitchTeamDEnabled = GetConVarInt(hSwitchTeamDEnabled);
	if(SwitchTeamDEnabled)
	{
		CPrintToChatAll("{green}[WelcomeInfo] {lightgreen}开启玩家切换队伍提示");
	}
	else
	{
		CPrintToChatAll("{green}[WelcomeInfo] {lightgreen}关闭玩家切换队伍提示");
	}
}

// 下面是info指令和全局自定义函数
public Action:ipCommand(client, args)
{
	// 先检查一遍玩家数量
	SurvivorCheck();

	if (g_bCooldown[client]) return Plugin_Handled;
	g_bCooldown[client] = true;
	
	decl String:ClientIP[16];
	GetClientIP(client, ClientIP, sizeof(ClientIP));
	
	new String:SteamId[128];
	GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId), true);
	
	decl String:country[46];
	GeoipCountry(ClientIP, country, sizeof(country));

	decl String:city[128];
	GeoipCity(ClientIP, city, sizeof(city));

	new const maxLen = 512;
	decl String:result[maxLen];

	Format(result, maxLen, "\n================================================\n");
	Format(result, maxLen, "%s 玩家信息\n", result);
	Format(result, maxLen, "%s 名字: %N \n", result, client);
	Format(result, maxLen, "%s steamID: %s \n", result, SteamId);
	Format(result, maxLen, "%s IP: %s \n", result, ClientIP);
	Format(result, maxLen, "%s 来自: %s %s \n", result, country, city);
	Format(result, maxLen, "%s\n", result);
	Format(result, maxLen, "%s=================================================\n", result);
	PrintToConsole(client, result);

	CPrintToChat(client, "{green}[WelcomeInfo]\n{lightgreen}目前玩家总人数是{green}%i{lightgreen}人\nsteamID: {olive}%s\n{lightgreen}IP: {olive}%s  {lightgreen}来自: {olive}%s %s", player_num, SteamId, ClientIP, country, city);
	CreateTimer(0.5, Cooldown_Timer, client);
	return Plugin_Handled;
}

// 检查当前存活玩家数量
SurvivorCheck()
{
	player_num = 0;
	for (new i = 1; i <= MaxClients; i++)
	{
		if(i)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2 && !IsFakeClient(i))
				{
				player_num++;
			}
		}
	}
}