#include <sourcemod>
#include <l4d_stocks>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

public Plugin:myinfo = 
{
    name = "Auto grab laser sight",
    author = "WolfGang",
    description = "Laser Sight on weapon pickup",
    version = PLUGIN_VERSION,
    url = ""
}

public OnPluginStart()
{
	new Handle:cvar = CreateConVar("autograblasersight_version", PLUGIN_VERSION, "AutoGrabLaserSight Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	SetConVarString(cvar, PLUGIN_VERSION);
}

public OnAllPluginsLoaded()
{
	/* For plugin reloading in mid game */
	for (new client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsClientAuthorized(client)) continue;
		SDKHook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip);
		SDKHook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop);
	}
}

public OnClientPostAdminCheck(client)
{
	if (client <= 0) return;

	SDKHook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip);
	SDKHook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop);
}

public OnClientDisconnect(client)
{
	if (client <= 0) return;

	SDKUnhook(client, SDKHook_WeaponEquipPost, OnClientWeaponEquip);
	SDKUnhook(client, SDKHook_WeaponDropPost, OnClientWeaponDrop);
}

public OnClientWeaponEquip(client, weapon)
{
	if (client <= 0 || !IsClientInGame(client) || L4DTeam:GetClientTeam(client) != L4DTeam_Survivor || !IsPlayerAlive(client)) return; // Invalid survivor, return

	new priWeapon = GetPlayerWeaponSlot(client, _:L4DWeaponSlot_Primary); // Get primary weapon
	if (priWeapon <= 0 || !IsValidEntity(priWeapon)) return; // Invalid weapon, return

	decl String:netclass[128];
	GetEntityNetClass(priWeapon, netclass, 128);
	if (FindSendPropInfo(netclass, "m_upgradeBitVec") < 1) return; // This weapon does not support upgrades

	new upgrades = L4D2_GetWeaponUpgrades(priWeapon); // Get upgrades of primary weapon
	if (upgrades & L4D2_WEPUPGFLAG_LASER) return; // Primary weapon already have laser sight, return

	L4D2_SetWeaponUpgrades(priWeapon, upgrades | L4D2_WEPUPGFLAG_LASER); // Add laser sight to primary weapon
}

public OnClientWeaponDrop(client, weapon)
{
	if (client <= 0 || !IsClientInGame(client) || L4DTeam:GetClientTeam(client) != L4DTeam_Survivor) return; // Invalid survivor, return

	if (weapon <= 0 || !IsValidEntity(weapon)) return; // Invalid weapon, return

	decl String:netclass[128];
	GetEntityNetClass(weapon, netclass, 128);
	if (FindSendPropInfo(netclass, "m_upgradeBitVec") < 1) return; // This weapon does not support upgrades

	new upgrades = L4D2_GetWeaponUpgrades(weapon); // Get upgrades of dropped weapon
	if (!(upgrades & L4D2_WEPUPGFLAG_LASER)) return; // Weapon did not have laser sight, return

	L4D2_SetWeaponUpgrades(weapon, upgrades ^ L4D2_WEPUPGFLAG_LASER); // Remove laser sight from weapon
}