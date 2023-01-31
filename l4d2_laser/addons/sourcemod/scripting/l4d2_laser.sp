#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <multicolors>

EngineVersion g_eGame; 

//定义插件信息
#define NAME 			"[L4D2]Auto grab laser sight"
#define AUTHOR 			"Zakikun"
#define DESCRIPTION 	"Make survivors can auto grab/remove laser sight when pickup/drop primary weapon. Support admin global toggle and individual player toggle."
#define	VERSION 		"1.0"
#define URL 			"https://github.com/wyxls/SourceModPlugins-L4D2"

/* Weapon upgrade bit flags */
#define L4D2_WEPUPGFLAG_NONE            (0 << 0)
#define L4D2_WEPUPGFLAG_INCENDIARY      (1 << 0)
#define L4D2_WEPUPGFLAG_EXPLOSIVE       (1 << 1)
#define L4D2_WEPUPGFLAG_LASER           (1 << 2)

ConVar	g_hLaserSwitch;
bool 	g_bGlobalLaserSwitch;
bool 	g_bPlayerLaserSwitch[MAXPLAYERS + 1];

//写入插件信息
public Plugin myinfo =
{
	name			=	NAME,
	author			=	AUTHOR,
	description		=	DESCRIPTION,
	version			=	VERSION,
	url				=	URL
};

//插件加载
public void OnPluginStart()
{
	g_eGame = GetEngineVersion();
	if(g_eGame != Engine_Left4Dead2) 
		SetFailState("This plugin only for L4D2");
	
	RegConsoleCmd("sm_laserswitch", Global_Switch, "Admin toggle auto grab laser sight function.");
	RegConsoleCmd("sm_laser", Player_Switch, "Players can type !laser to toggle laser auto grab function for themselves only.");

	
	g_hLaserSwitch = CreateConVar("l4d2_laser_enable", "1", "Whether or not survivors auto grab laser sight upgrade on picking primary weapons. (admin type !laserswitch to on/off) 0=off, 1=on.", FCVAR_NOTIFY, true, 0.0, false, 1.0);
	g_hLaserSwitch.AddChangeHook(ConVarChanged);

	// Set variables
	g_bGlobalLaserSwitch = g_hLaserSwitch.BoolValue;

	for (int i = 1; i <= MaxClients; i++)
	{
		g_bPlayerLaserSwitch[i] = g_hLaserSwitch.BoolValue;
	}

	AutoExecConfig(true, "l4d2_laser");
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bGlobalLaserSwitch = g_hLaserSwitch.BoolValue;
}

public Action Global_Switch(int client, int args)
{
	if(bCheckClientAccess(client))
	{
		if (g_bGlobalLaserSwitch)
		{
			g_bGlobalLaserSwitch = !g_bGlobalLaserSwitch;
			CPrintToChatAll("{green}[Laser] {lightgreen}已{olive}关闭{lightgreen}所有幸存者捡起主武器自动获得激光升级功能.");
		
			for (int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && GetClientTeam(i) == 2)
				{
					int weapon = GetPlayerWeaponSlot(i, 0);
					CheckWeaponLaser(weapon);
				}
			}
		}
		else
		{
			g_bGlobalLaserSwitch = !g_bGlobalLaserSwitch;
			CPrintToChatAll("{green}[Laser] {lightgreen}已{olive}开启{lightgreen}所有幸存者捡起主武器自动获得激光升级功能.");
			
			for (int i = 1; i <= MaxClients; i++)
				if(IsClientInGame(i) && GetClientTeam(i) == 2)
					CheckPlayerWeaponLaser(client);
		}

	}
	else
	{
		CPrintToChat(client, "{green}[Laser] {lightgreen}你无权使用此指令.");
	}
	return Plugin_Handled;
}

public Action Player_Switch(int client, int args)
{
	if (g_bPlayerLaserSwitch[client])
	{
		g_bPlayerLaserSwitch[client] = !g_bPlayerLaserSwitch[client];
		CPrintToChat(client, "{green}[Laser] {lightgreen}你已{olive}关闭{lightgreen}主武器自动获得激光升级功能.");

		if(IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			int weapon = GetPlayerWeaponSlot(client, 0);
			CheckWeaponLaser(weapon);
		}
	}
	else
	{
		g_bPlayerLaserSwitch[client] = !g_bPlayerLaserSwitch[client];
		CPrintToChat(client, "{green}[Laser] {lightgreen}你已{olive}开启{lightgreen}主武器自动获得激光升级功能.");
		
		if(IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			CheckPlayerWeaponLaser(client);
		}
				
	}

	return Plugin_Handled;
}

bool bCheckClientAccess(int client)
{
	if(GetUserFlagBits(client) & ADMFLAG_ROOT)
	{
		return true;
	}
	else
	{
		return false;
	}
	
}

public void OnClientPutInServer(int client)
{
	// hook events with void
	SDKHook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip); // grab laser when weapon picked up
	SDKHook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop); // remove laser when weapon dropped
}

public void OnClientDisconnect(int client)
{
	// unook events with void
	SDKUnhook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip); // grab laser when weapon picked up
	SDKUnhook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop); // remove laser when weapon dropped
}

// grab laser sight when weapon picked up
public void OnClientWeaponEquip(int client, int weapon)
{
	if (g_bGlobalLaserSwitch & g_bPlayerLaserSwitch[client])
	{
		if (IsValidClient(client) && GetClientTeam(client) == 2)
		{
			CheckPlayerWeaponLaser(client);
		}
	}
}

public void CheckPlayerWeaponLaser(int client)
{
	int iWeapon = GetPlayerWeaponSlot(client, 0); // Get primary weapon
	if(iWeapon > 0 && IsValidEdict(iWeapon) && IsValidEntity(iWeapon))
	{
		char netclass[128];
		GetEntityNetClass(iWeapon, netclass, sizeof(netclass));
		if(FindSendPropInfo(netclass, "m_upgradeBitVec") < 1)
			return; // This weapon does not support laser upgrade

		int iLaser = GetEntProp(iWeapon, Prop_Send, "m_upgradeBitVec"); // Get upgrade status of primary weapon
		if(iLaser & L4D2_WEPUPGFLAG_LASER)
			return; // Primary weapon already have laser sight, return
		
		SetEntProp(iWeapon, Prop_Send, "m_upgradeBitVec", iLaser | L4D2_WEPUPGFLAG_LASER); // Add laser sight to primary weapon
	}
}

// remove laser sight when weapon dropped
public void OnClientWeaponDrop(int client, int weapon)
{
	if (g_bGlobalLaserSwitch & g_bPlayerLaserSwitch[client])
	{
		if (IsValidClient(client) && GetClientTeam(client) == 2)
		{
			CheckWeaponLaser(weapon);
		}
	}
}

public void CheckWeaponLaser(int weapon)
{
	if(weapon > 0 && IsValidEdict(weapon) && IsValidEntity(weapon))
	{
		char netclass[128];
		GetEntityNetClass(weapon, netclass, sizeof(netclass));
		if(FindSendPropInfo(netclass, "m_upgradeBitVec") < 1)
			return; // This weapon does not support laser upgrade

		int iLaser = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec"); // Get upgrade status of dropped weapon
		if(!(iLaser & L4D2_WEPUPGFLAG_LASER))
			return; // weapon did not have laser sight, return
		
		SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", iLaser ^ L4D2_WEPUPGFLAG_LASER); // Remove laser sight from primary weapon
	}
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}