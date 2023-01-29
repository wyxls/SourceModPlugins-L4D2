#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1"

public Plugin:myinfo = 
	{
		name = "[L4D] Kill",
		author = "Danny & FlamFlam & Zakikun",
		description = "use the !zs command in chat",
		version = PLUGIN_VERSION,
		url = ""
	}

	public OnPluginStart()
	{
		RegConsoleCmd("sm_zs", Kill_Me);
	}


	/* kill */
	public Action:Kill_Me(client, args)
	{
		ForcePlayerSuicide(client);
	}

/* Disable Advertisement 
	Timed Message
	public bool:OnClientConnect(client, String:rejectmsg[], maxlen)

	{
		CreateTimer(60.0, Timer_Advertise, client);
		return true;
	}

	public Action:Timer_Advertise(Handle:timer, any:client)

	{
		if(IsClientInGame(client))
		PrintHintText(client, "Type in chat !kill to kill yourself");
		else if (IsClientConnected(client))
		CreateTimer(60.0, Timer_Advertise, client);
	}
*/