//SourcePawn

/*			Changelog
*	29/08/2014 Version 1.0 – Released.
*	28/12/2016 Version 1.1 – Changed syntax.
*	22/10/2017 Version 1.2 – Fixed jump after vomitjar-boost and after "TakeOverBot" event.
*	08/11/2018 Version 1.2.1 – Fixed incorrect flags initializing; some changes in syntax.
*	25/04/2019 Version 1.2.2 – Command "sm_autobhop" has fixed for localplayer in order to work properly in console.
*	16/11/2019 Version 1.3.2 – At the moment CBasePlayer specific flags (or rather FL_ONGROUND bit) aren't longer fixed, by reason
*							player's jump animation during boost is incorrect (it's must be ACT_RUN_CROUCH_* sequence always!);
*							removed 'm_nWaterLevel' check (we cannot swim in this game anyway) to avoid problems with jumping
*							on some deep water maps.
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define MAXCLIENTS 32
#define PLUGIN_VER "1.3.2"

new bool:g_AutoBhop[MAXCLIENTS + 1];

public Plugin:myinfo =
{
	name = "Auto Bunny Hop",
	author = "Zakikun, noa1mbot",
	description = "Make Bunny Hop easier.",
	version = PLUGIN_VER,
	url = "https://steamcommunity.com/groups/noa1mbot"
}

//============================================================
//============================================================

public OnPluginStart()
{
	RegConsoleCmd("sm_abh", Cmd_Autobhop);
}

public Action:Cmd_Autobhop(client, args)
{
	if (client == 0)
	{
		if (!IsDedicatedServer() && IsClientInGame(1)) client = 1;
		else return Plugin_Handled;
	}
	if (g_AutoBhop[client]) PrintToChat(client, "\x04[SM] \x03自动连跳开启");
	else PrintToChat(client, "\x04[SM] \x03自动连跳关闭");
	g_AutoBhop[client] = !g_AutoBhop[client];
	return Plugin_Handled;
}

public Action:OnPlayerRunCmd(int client, int &buttons)
{
	if (!g_AutoBhop[client] && IsPlayerAlive(client))
	{
		if (buttons & IN_JUMP)
		{
			if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
			{
				if (GetEntityMoveType(client) != MOVETYPE_LADDER)
				{
					buttons &= ~IN_JUMP;
				}
			}
		}
	}
	return Plugin_Continue;
}