/**
 * Mutant Tanks: a L4D/L4D2 SourceMod Plugin
 * Copyright (C) 2022  Alfred "Psyk0tik" Llagas
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.
 **/

#define MT_FLY_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_FLY_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Fly Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank can fly.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Fly Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_FLY_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_FLY_SECTION "flyability"
#define MT_FLY_SECTION2 "fly ability"
#define MT_FLY_SECTION3 "fly_ability"
#define MT_FLY_SECTION4 "fly"

#define MT_FLY_ATTACK (1 << 0) // when tank attacks
#define MT_FLY_HURT (1 << 1) // when tank is hurt
#define MT_FLY_THROW (1 << 2) // when tank throws a rock
#define MT_FLY_JUMP (1 << 3) // when tank jumps

#define MT_MENU_FLY "Fly Ability"

enum struct esFlyPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flCurrentVelocity[3];
	float g_flFlyChance;
	float g_flFlySpeed;
	float g_flLastTime;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iDuration;
	int g_iFlyAbility;
	int g_iFlyCooldown;
	int g_iFlyDuration;
	int g_iFlyMessage;
	int g_iFlyType;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTankType;
}

esFlyPlayer g_esFlyPlayer[MAXPLAYERS + 1];

enum struct esFlyAbility
{
	float g_flCloseAreasOnly;
	float g_flFlyChance;
	float g_flFlySpeed;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iFlyAbility;
	int g_iFlyCooldown;
	int g_iFlyDuration;
	int g_iFlyMessage;
	int g_iFlyType;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esFlyAbility g_esFlyAbility[MT_MAXTYPES + 1];

enum struct esFlyCache
{
	float g_flCloseAreasOnly;
	float g_flFlyChance;
	float g_flFlySpeed;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iFlyAbility;
	int g_iFlyCooldown;
	int g_iFlyDuration;
	int g_iFlyMessage;
	int g_iFlyType;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
}

esFlyCache g_esFlyCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_fly", cmdFlyInfo, "View information about the Fly ability.");

	if (g_bLateLoad)
	{
		for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
		{
			if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
			{
				OnClientPutInServer(iPlayer);
			}
		}

		g_bLateLoad = false;
	}
}
#endif

#if defined MT_ABILITIES_MAIN
void vFlyMapStart()
#else
public void OnMapStart()
#endif
{
	vFlyReset();
}

#if defined MT_ABILITIES_MAIN
void vFlyClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnFlyTakeDamage);
	vRemoveFly(client);
}

#if defined MT_ABILITIES_MAIN
void vFlyClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveFly(client);
}

#if defined MT_ABILITIES_MAIN
void vFlyMapEnd()
#else
public void OnMapEnd()
#endif
{
	vFlyReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdFlyInfo(int client, int args)
{
	client = iGetListenServerHost(client, g_bDedicated);

	if (!MT_IsCorePluginEnabled())
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG5, "PluginDisabled");

		return Plugin_Handled;
	}

	if (!bIsValidClient(client, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT))
	{
		MT_ReplyToCommand(client, "%s %t", MT_TAG, "Command is in-game only");

		return Plugin_Handled;
	}

	switch (IsVoteInProgress())
	{
		case true: MT_ReplyToCommand(client, "%s %t", MT_TAG2, "Vote in Progress");
		case false: vFlyMenu(client, MT_FLY_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vFlyMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_FLY_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iFlyMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Fly Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Button Mode", "Button Mode");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iFlyMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFlyCache[param1].g_iFlyAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esFlyCache[param1].g_iHumanAmmo - g_esFlyPlayer[param1].g_iAmmoCount), g_esFlyCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFlyCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esFlyCache[param1].g_iHumanAbility == 1) ? g_esFlyCache[param1].g_iHumanCooldown : g_esFlyCache[param1].g_iFlyCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "FlyDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esFlyCache[param1].g_iHumanAbility == 1) ? g_esFlyCache[param1].g_iHumanDuration : g_esFlyCache[param1].g_iFlyDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esFlyCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vFlyMenu(param1, MT_FLY_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pFly = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "FlyMenu", param1);
			pFly.SetTitle(sMenuTitle);
		}
		case MenuAction_DisplayItem:
		{
			if (param2 >= 0)
			{
				char sMenuOption[PLATFORM_MAX_PATH];

				switch (param2)
				{
					case 0: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Status", param1);
					case 1: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Ammunition", param1);
					case 2: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Buttons", param1);
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "ButtonMode", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vFlyDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_FLY, MT_MENU_FLY);
}

#if defined MT_ABILITIES_MAIN
void vFlyMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_FLY, false))
	{
		vFlyMenu(client, MT_FLY_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_FLY, false))
	{
		FormatEx(buffer, size, "%T", "FlyMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyPlayerRunCmd(int client)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsTankSupported(client) || !g_esFlyPlayer[client].g_bActivated || (bIsTank(client, MT_CHECK_FAKECLIENT) && g_esFlyCache[client].g_iHumanMode == 1) || g_esFlyPlayer[client].g_iDuration == -1)
	{
#if defined MT_ABILITIES_MAIN
		return;
#else
		return Plugin_Continue;
#endif
	}

	if (g_esFlyPlayer[client].g_iDuration < GetTime())
	{
		vStopFly(client);
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

Action OnFlyTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (MT_IsTankSupported(attacker) && (!bIsTank(attacker, MT_CHECK_FAKECLIENT) || g_esFlyCache[attacker].g_iHumanAbility == 2) && MT_IsCustomTankSupported(attacker) && g_esFlyCache[attacker].g_iFlyAbility == 1 && bIsSurvivor(victim))
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esFlyAbility[g_esFlyPlayer[attacker].g_iTankType].g_iAccessFlags, g_esFlyPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esFlyPlayer[attacker].g_iTankType, g_esFlyAbility[g_esFlyPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esFlyPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			char sClassname[32];
			GetEntityClassname(inflictor, sClassname, sizeof sClassname);
			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				if ((g_esFlyCache[attacker].g_iFlyType == 0 || (g_esFlyCache[attacker].g_iFlyType & MT_FLY_ATTACK)) && !g_esFlyPlayer[attacker].g_bActivated)
				{
					vFlyAbility(attacker);
				}
				else if (g_esFlyPlayer[attacker].g_bActivated)
				{
					vStopFly(attacker);
				}
			}
		}
		else if (MT_IsTankSupported(victim) && (!bIsTank(victim, MT_CHECK_FAKECLIENT) || g_esFlyCache[victim].g_iHumanAbility == 2) && MT_IsCustomTankSupported(victim) && g_esFlyCache[victim].g_iFlyAbility == 1 && bIsSurvivor(attacker))
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esFlyAbility[g_esFlyPlayer[victim].g_iTankType].g_iAccessFlags, g_esFlyPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esFlyPlayer[victim].g_iTankType, g_esFlyAbility[g_esFlyPlayer[victim].g_iTankType].g_iImmunityFlags, g_esFlyPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if ((g_esFlyCache[victim].g_iFlyType == 0 || (g_esFlyCache[victim].g_iFlyType & MT_FLY_HURT)) && !g_esFlyPlayer[victim].g_bActivated)
			{
				vFlyAbility(victim);
			}
		}
	}

	return Plugin_Continue;
}

Action OnFlyPreThink(int tank)
{
	switch (MT_IsTankSupported(tank) && g_esFlyPlayer[tank].g_bActivated)
	{
		case true:
		{
			float flDuration = (GetEngineTime() - g_esFlyPlayer[tank].g_flLastTime);
			int iButtons = GetClientButtons(tank);
			vFlyThink(tank, iButtons, flDuration);
		}
		case false: SDKUnhook(tank, SDKHook_PreThink, OnFlyPreThink);
	}

	return Plugin_Continue;
}

Action OnFlyStartTouch(int tank, int other)
{
	if (bIsTank(tank) && bIsValidEntity(other))
	{
		vStopFly(tank);
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vFlyPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_FLY);
}

#if defined MT_ABILITIES_MAIN
void vFlyAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_FLY_SECTION);
	list2.PushString(MT_FLY_SECTION2);
	list3.PushString(MT_FLY_SECTION3);
	list4.PushString(MT_FLY_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vFlyCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility != 2)
	{
		g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_FLY_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_FLY_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_FLY_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_FLY_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esFlyCache[tank].g_iFlyAbility == 1 && g_esFlyCache[tank].g_iComboAbility == 1 && !g_esFlyPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_FLY_SECTION, false) || StrEqual(sSubset[iPos], MT_FLY_SECTION2, false) || StrEqual(sSubset[iPos], MT_FLY_SECTION3, false) || StrEqual(sSubset[iPos], MT_FLY_SECTION4, false))
				{
					g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vFly(tank, true, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerFlyCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteCell(iPos);
							}
						}
					}

					break;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyConfigsLoad(int mode)
#else
public void MT_OnConfigsLoad(int mode)
#endif
{
	switch (mode)
	{
		case 1:
		{
			int iMaxType = MT_GetMaxType();
			for (int iIndex = MT_GetMinType(); iIndex <= iMaxType; iIndex++)
			{
				g_esFlyAbility[iIndex].g_iAccessFlags = 0;
				g_esFlyAbility[iIndex].g_iImmunityFlags = 0;
				g_esFlyAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esFlyAbility[iIndex].g_iComboAbility = 0;
				g_esFlyAbility[iIndex].g_iComboPosition = -1;
				g_esFlyAbility[iIndex].g_iHumanAbility = 0;
				g_esFlyAbility[iIndex].g_iHumanAmmo = 5;
				g_esFlyAbility[iIndex].g_iHumanCooldown = 0;
				g_esFlyAbility[iIndex].g_iHumanDuration = 30;
				g_esFlyAbility[iIndex].g_iHumanMode = 1;
				g_esFlyAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esFlyAbility[iIndex].g_iRequiresHumans = 0;
				g_esFlyAbility[iIndex].g_iFlyAbility = 0;
				g_esFlyAbility[iIndex].g_iFlyMessage = 0;
				g_esFlyAbility[iIndex].g_flFlyChance = 33.3;
				g_esFlyAbility[iIndex].g_iFlyCooldown = 0;
				g_esFlyAbility[iIndex].g_iFlyDuration = 30;
				g_esFlyAbility[iIndex].g_flFlySpeed = 500.0;
				g_esFlyAbility[iIndex].g_iFlyType = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esFlyPlayer[iPlayer].g_iAccessFlags = 0;
					g_esFlyPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esFlyPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esFlyPlayer[iPlayer].g_iComboAbility = 0;
					g_esFlyPlayer[iPlayer].g_iHumanAbility = 0;
					g_esFlyPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esFlyPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esFlyPlayer[iPlayer].g_iHumanDuration = 0;
					g_esFlyPlayer[iPlayer].g_iHumanMode = 0;
					g_esFlyPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esFlyPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esFlyPlayer[iPlayer].g_iFlyAbility = 0;
					g_esFlyPlayer[iPlayer].g_iFlyMessage = 0;
					g_esFlyPlayer[iPlayer].g_flFlyChance = 0.0;
					g_esFlyPlayer[iPlayer].g_iFlyCooldown = 0;
					g_esFlyPlayer[iPlayer].g_iFlyDuration = 0;
					g_esFlyPlayer[iPlayer].g_flFlySpeed = 0.0;
					g_esFlyPlayer[iPlayer].g_iFlyType = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esFlyPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFlyPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFlyPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFlyPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esFlyPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFlyPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esFlyPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFlyPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esFlyPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFlyPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esFlyPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esFlyPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esFlyPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esFlyPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esFlyPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFlyPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFlyPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFlyPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esFlyPlayer[admin].g_iFlyAbility = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFlyPlayer[admin].g_iFlyAbility, value, 0, 1);
		g_esFlyPlayer[admin].g_iFlyMessage = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFlyPlayer[admin].g_iFlyMessage, value, 0, 1);
		g_esFlyPlayer[admin].g_flFlyChance = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyChance", "Fly Chance", "Fly_Chance", "chance", g_esFlyPlayer[admin].g_flFlyChance, value, 0.0, 100.0);
		g_esFlyPlayer[admin].g_iFlyCooldown = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyCooldown", "Fly Cooldown", "Fly_Cooldown", "cooldown", g_esFlyPlayer[admin].g_iFlyCooldown, value, 0, 99999);
		g_esFlyPlayer[admin].g_iFlyDuration = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyDuration", "Fly Duration", "Fly_Duration", "duration", g_esFlyPlayer[admin].g_iFlyDuration, value, 0, 99999);
		g_esFlyPlayer[admin].g_flFlySpeed = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlySpeed", "Fly Speed", "Fly_Speed", "speed", g_esFlyPlayer[admin].g_flFlySpeed, value, 0.1, 99999.0);
		g_esFlyPlayer[admin].g_iFlyType = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyType", "Fly Type", "Fly_Type", "type", g_esFlyPlayer[admin].g_iFlyType, value, 0, 15);
		g_esFlyPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esFlyPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esFlyAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esFlyAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esFlyAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esFlyAbility[type].g_iComboAbility, value, 0, 1);
		g_esFlyAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esFlyAbility[type].g_iHumanAbility, value, 0, 2);
		g_esFlyAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esFlyAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esFlyAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esFlyAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esFlyAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esFlyAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esFlyAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esFlyAbility[type].g_iHumanMode, value, 0, 1);
		g_esFlyAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esFlyAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esFlyAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esFlyAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esFlyAbility[type].g_iFlyAbility = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esFlyAbility[type].g_iFlyAbility, value, 0, 1);
		g_esFlyAbility[type].g_iFlyMessage = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esFlyAbility[type].g_iFlyMessage, value, 0, 1);
		g_esFlyAbility[type].g_flFlyChance = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyChance", "Fly Chance", "Fly_Chance", "chance", g_esFlyAbility[type].g_flFlyChance, value, 0.0, 100.0);
		g_esFlyAbility[type].g_iFlyCooldown = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyCooldown", "Fly Cooldown", "Fly_Cooldown", "cooldown", g_esFlyAbility[type].g_iFlyCooldown, value, 0, 99999);
		g_esFlyAbility[type].g_iFlyDuration = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyDuration", "Fly Duration", "Fly_Duration", "duration", g_esFlyAbility[type].g_iFlyDuration, value, 0, 99999);
		g_esFlyAbility[type].g_flFlySpeed = flGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlySpeed", "Fly Speed", "Fly_Speed", "speed", g_esFlyAbility[type].g_flFlySpeed, value, 0.1, 99999.0);
		g_esFlyAbility[type].g_iFlyType = iGetKeyValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "FlyType", "Fly Type", "Fly_Type", "type", g_esFlyAbility[type].g_iFlyType, value, 0, 15);
		g_esFlyAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esFlyAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_FLY_SECTION, MT_FLY_SECTION2, MT_FLY_SECTION3, MT_FLY_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vFlySettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esFlyCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_flCloseAreasOnly, g_esFlyAbility[type].g_flCloseAreasOnly);
	g_esFlyCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iComboAbility, g_esFlyAbility[type].g_iComboAbility);
	g_esFlyCache[tank].g_flFlyChance = flGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_flFlyChance, g_esFlyAbility[type].g_flFlyChance);
	g_esFlyCache[tank].g_flFlySpeed = flGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_flFlySpeed, g_esFlyAbility[type].g_flFlySpeed);
	g_esFlyCache[tank].g_iFlyAbility = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iFlyAbility, g_esFlyAbility[type].g_iFlyAbility);
	g_esFlyCache[tank].g_iFlyCooldown = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iFlyCooldown, g_esFlyAbility[type].g_iFlyCooldown);
	g_esFlyCache[tank].g_iFlyDuration = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iFlyDuration, g_esFlyAbility[type].g_iFlyDuration);
	g_esFlyCache[tank].g_iFlyType = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iFlyType, g_esFlyAbility[type].g_iFlyType);
	g_esFlyCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iHumanAbility, g_esFlyAbility[type].g_iHumanAbility);
	g_esFlyCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iHumanAmmo, g_esFlyAbility[type].g_iHumanAmmo);
	g_esFlyCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iHumanCooldown, g_esFlyAbility[type].g_iHumanCooldown);
	g_esFlyCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iHumanDuration, g_esFlyAbility[type].g_iHumanDuration);
	g_esFlyCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iHumanMode, g_esFlyAbility[type].g_iHumanMode);
	g_esFlyCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_flOpenAreasOnly, g_esFlyAbility[type].g_flOpenAreasOnly);
	g_esFlyCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esFlyPlayer[tank].g_iRequiresHumans, g_esFlyAbility[type].g_iRequiresHumans);
	g_esFlyPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vFlyCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vFlyCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveFly(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vFlyHookEvent(bool hooked)
#else
public void MT_OnHookEvent(bool hooked)
#endif
{
	static bool bCheck;

	switch (hooked)
	{
		case true: bCheck = HookEventEx("player_jump", MT_OnEventFired);
		case false:
		{
			if (bCheck)
			{
				bCheck = false;
				UnhookEvent("player_jump", MT_OnEventFired);
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyEventFired(Event event, const char[] name)
#else
public void MT_OnEventFired(Event event, const char[] name, bool dontBroadcast)
#endif
{
	if (StrEqual(name, "bot_player_replace"))
	{
		int iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId),
			iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId);
		if (bIsValidClient(iBot) && bIsTank(iTank))
		{
			vFlyCopyStats2(iBot, iTank);
			vRemoveFly(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vFlyCopyStats2(iTank, iBot);
			vRemoveFly(iTank);
		}
	}
	else if (StrEqual(name, "player_jump"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank) && (!bIsTank(iTank, MT_CHECK_FAKECLIENT) || g_esFlyCache[iTank].g_iHumanAbility == 2))
		{
			if (g_esFlyCache[iTank].g_iFlyAbility == 1 && (g_esFlyCache[iTank].g_iFlyType == 0 || (g_esFlyCache[iTank].g_iFlyType & MT_FLY_JUMP)) && !g_esFlyPlayer[iTank].g_bActivated)
			{
				vFlyAbility(iTank);
			}
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveFly(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vFlyReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlyPlayer[tank].g_iAccessFlags)) || g_esFlyCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esFlyCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esFlyCache[tank].g_iFlyAbility == 1 && g_esFlyCache[tank].g_iComboAbility == 0 && !g_esFlyPlayer[tank].g_bActivated)
	{
		vFlyAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esFlyCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFlyCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFlyPlayer[tank].g_iTankType) || (g_esFlyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlyPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esFlyCache[tank].g_iFlyAbility == 1 && g_esFlyCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esFlyPlayer[tank].g_iCooldown != -1 && g_esFlyPlayer[tank].g_iCooldown > iTime;

			switch (g_esFlyCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esFlyPlayer[tank].g_bActivated && !bRecharging)
					{
						vFlyAbility(tank);
					}
					else if (g_esFlyPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman4", (g_esFlyPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esFlyPlayer[tank].g_iAmmoCount < g_esFlyCache[tank].g_iHumanAmmo && g_esFlyCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esFlyPlayer[tank].g_bActivated && !bRecharging)
						{
							vFly(tank, false);
						}
						else if (g_esFlyPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman4", (g_esFlyPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esFlyCache[tank].g_iHumanMode == 1 && g_esFlyPlayer[tank].g_bActivated && (g_esFlyPlayer[tank].g_iCooldown == -1 || g_esFlyPlayer[tank].g_iCooldown < GetTime()))
		{
			vStopFly(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vFlyChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveFly(tank);
}

#if defined MT_ABILITIES_MAIN
void vFlyRockThrow(int tank)
#else
public void MT_OnRockThrow(int tank, int rock)
#endif
{
	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esFlyCache[tank].g_iHumanAbility == 2) && MT_IsCustomTankSupported(tank) && g_esFlyCache[tank].g_iFlyAbility == 1 && (g_esFlyCache[tank].g_iFlyType == 0 || (g_esFlyCache[tank].g_iFlyType & MT_FLY_THROW)) && !g_esFlyPlayer[tank].g_bActivated)
	{
		if (bIsAreaNarrow(tank, g_esFlyCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFlyCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFlyPlayer[tank].g_iTankType) || (g_esFlyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlyPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		vFlyAbility(tank);
	}
}

void vFly(int tank, bool announce, int pos = -1)
{
	if (bIsAreaNarrow(tank))
	{
		if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman6");
		}

		return;
	}

	int iTime = GetTime();
	if (g_esFlyPlayer[tank].g_iCooldown != -1 && g_esFlyPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	int iDuration = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 5, pos)) : g_esFlyCache[tank].g_iFlyDuration;
	iDuration = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility == 1) ? g_esFlyCache[tank].g_iHumanDuration : iDuration;
	g_esFlyPlayer[tank].g_bActivated = true;
	g_esFlyPlayer[tank].g_iAmmoCount++;
	g_esFlyPlayer[tank].g_iDuration = (iTime + iDuration);
	g_esFlyPlayer[tank].g_flLastTime = (GetEngineTime() - 0.01);

	float flOrigin[3], flEyeAngles[3];
	GetEntPropVector(tank, Prop_Data, "m_vecAbsOrigin", flOrigin);
	GetClientEyeAngles(tank, flEyeAngles);
	flOrigin[2] += 5.0;
	flEyeAngles[2] = 30.0;

	GetAngleVectors(flEyeAngles, flEyeAngles, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(flEyeAngles, flEyeAngles);
	ScaleVector(flEyeAngles, 55.0);
	TeleportEntity(tank, flOrigin, .velocity = flEyeAngles);
	vCopyVector(flEyeAngles, g_esFlyPlayer[tank].g_flCurrentVelocity);

	SDKUnhook(tank, SDKHook_PreThink, OnFlyPreThink);
	SDKHook(tank, SDKHook_PreThink, OnFlyPreThink);
	SDKUnhook(tank, SDKHook_StartTouch, OnFlyStartTouch);
	SDKHook(tank, SDKHook_StartTouch, OnFlyStartTouch);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility > 0)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman", g_esFlyPlayer[tank].g_iAmmoCount, g_esFlyCache[tank].g_iHumanAmmo);
	}

	if (announce && g_esFlyCache[tank].g_iFlyMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Fly", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fly", LANG_SERVER, sTankName);
	}
}

void vFlyAbility(int tank)
{
	if ((g_esFlyPlayer[tank].g_iCooldown != -1 && g_esFlyPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esFlyCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esFlyCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esFlyPlayer[tank].g_iTankType) || (g_esFlyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlyPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esFlyPlayer[tank].g_iAmmoCount < g_esFlyCache[tank].g_iHumanAmmo && g_esFlyCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esFlyCache[tank].g_flFlyChance)
		{
			vFly(tank, true);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyAmmo");
	}
}

void vFlyThink(int tank, int buttons, float duration)
{
	if (bIsValidClient(tank))
	{
		if (MT_DoesTypeRequireHumans(g_esFlyPlayer[tank].g_iTankType) || (g_esFlyCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esFlyCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iAccessFlags, g_esFlyPlayer[tank].g_iAccessFlags)))
		{
			vStopFly(tank);

			return;
		}

		int iPos = g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iComboPosition;
		float flSpeed = (iPos != -1) ? MT_GetCombinationSetting(tank, 16, iPos) : g_esFlyCache[tank].g_flFlySpeed;
		if (bIsTank(tank, MT_CHECK_FAKECLIENT))
		{
			if (buttons & IN_USE)
			{
				float flFall;
				if (buttons & IN_SPEED)
				{
					flFall = 0.75;
				}
				else
				{
					switch (buttons & IN_DUCK)
					{
						case true: flFall = 0.5;
						case false: flFall = 1.0;
					}
				}

				SetEntityGravity(tank, flFall);

				return;
			}

			SetEntityMoveType(tank, MOVETYPE_FLYGRAVITY);

			float flEyeAngles[3], flOrigin[3], flTemp[3], flSpeed2[3], flSpeed3, flForce[3], flForce2 = 50.0, flGravity = 0.001, flGravity2 = 0.01;
			GetEntPropVector(tank, Prop_Data, "m_vecVelocity", flSpeed2);
			GetClientEyeAngles(tank, flEyeAngles);
			GetClientAbsOrigin(tank, flOrigin);

			bool bJumping = false;
			if (buttons & IN_JUMP)
			{
				bJumping = true;
				flEyeAngles[0] = -50.0;

				GetAngleVectors(flEyeAngles, flEyeAngles, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(flEyeAngles, flEyeAngles);
				ScaleVector(flEyeAngles, flSpeed);
				TeleportEntity(tank, .velocity = flEyeAngles);

				return;
			}

			if ((buttons & IN_SPEED) && !bJumping)
			{
				flSpeed3 = ((flSpeed * 75.0) / 100.0);
				if (buttons & IN_FORWARD)
				{
					flSpeed3 = flSpeed;
				}

				GetAngleVectors(flEyeAngles, flEyeAngles, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(flEyeAngles, flEyeAngles);
				ScaleVector(flEyeAngles, flSpeed3);
				TeleportEntity(tank, .velocity = flEyeAngles);

				return;
			}
			else if (!(buttons & IN_SPEED) && (buttons & IN_DUCK) && !bJumping)
			{
				flSpeed3 = ((flSpeed * 33.33) / 100.0);
				if (buttons & IN_FORWARD)
				{
					flSpeed3 = ((flSpeed * 50.0) / 100.0);
				}

				GetAngleVectors(flEyeAngles, flEyeAngles, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(flEyeAngles, flEyeAngles);
				ScaleVector(flEyeAngles, flSpeed3);
				TeleportEntity(tank, .velocity = flEyeAngles);

				return;
			}

			if (buttons & IN_FORWARD)
			{
				GetAngleVectors(flEyeAngles, flTemp, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(flTemp, flTemp);
				AddVectors(flForce, flTemp, flForce);
			}
			else if (buttons & IN_BACK)
			{
				GetAngleVectors(flEyeAngles, flTemp, NULL_VECTOR, NULL_VECTOR);
				NormalizeVector(flTemp, flTemp);
				SubtractVectors(flForce, flTemp, flForce);
			}

			if (buttons & IN_MOVELEFT)
			{
				GetAngleVectors(flEyeAngles, NULL_VECTOR, flTemp, NULL_VECTOR);
				NormalizeVector(flTemp, flTemp);
				SubtractVectors(flForce, flTemp, flForce);
			}
			else if (buttons & IN_MOVERIGHT)
			{
				GetAngleVectors(flEyeAngles, NULL_VECTOR, flTemp, NULL_VECTOR);
				NormalizeVector(flTemp, flTemp);
				AddVectors(flForce, flTemp, flForce);
			}

			NormalizeVector(flForce, flForce);
			ScaleVector(flForce, flForce2 * duration);

			switch (FloatAbs(flSpeed2[2]) > 40.0)
			{
				case true: flGravity = (flSpeed2[2] * duration);
				case false: flGravity = flGravity2;
			}

			if (flGravity > 0.5)
			{
				flGravity = 0.5;
			}
			else if (flGravity < -0.5)
			{
				flGravity = -0.5;
			}

			float flSpeed4 = GetVectorLength(flSpeed2);
			if (flSpeed4 > flSpeed)
			{
				NormalizeVector(flSpeed2, flSpeed2);
				ScaleVector(flSpeed2, flSpeed);
				TeleportEntity(tank, .velocity = flSpeed2);
				flGravity = flGravity2;
			}

			SetEntityGravity(tank, flGravity);

			return;
		}

		float flPos[3], flVelocity[3];
		GetClientAbsOrigin(tank, flPos);
		GetEntPropVector(tank, Prop_Data, "m_vecVelocity", flVelocity);
		flPos[2] += 30.0;

		vCopyVector(g_esFlyPlayer[tank].g_flCurrentVelocity, flVelocity);

		if (GetVectorLength(flVelocity) < 10.0)
		{
			return;
		}

		NormalizeVector(flVelocity, flVelocity);

		int iTarget;
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT))
		{
			iTarget = iGetFlyTarget(flPos, flVelocity, tank);
		}
		else
		{
			float flDirection[3];
			GetClientEyeAngles(tank, flDirection);
			GetAngleVectors(flDirection, flDirection, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(flDirection, flDirection);
			iTarget = iGetFlyTarget(flPos, flDirection, tank);
		}

		bool bVisible = false;
		float flVector[3], flVelocity2[3], flAngles[3], flDistance = 1000.0;

		if (bIsSurvivor(iTarget))
		{
			float flPos2[3];
			GetClientEyePosition(iTarget, flPos2);
			flDistance = GetVectorDistance(flPos, flPos2);
			bVisible = bIsVisiblePosition(flPos, flPos2, tank, 1);

			GetEntPropVector(iTarget, Prop_Data, "m_vecVelocity", flVelocity2);
			ScaleVector(flVelocity2, duration);
			AddVectors(flPos2, flVelocity2, flPos2);
			MakeVectorFromPoints(flPos, flPos2, flVector);
		}

		float flLeft[3], flRight[3], flUp[3], flDown[3], flFront[3], flVector1[3], flVector2[3], flVector3[3], flVector4[3],
			flVector5[3], flVector6[3], flVector7[3], flVector8[3], flVector9, flFactor1 = 0.2, flFactor2 = 0.5, flBase = 1500.0, flBase2 = 10.0;
		GetVectorAngles(flVelocity, flAngles);

		float flFront2 = flGetDistance(flPos, flAngles, 0.0, 0.0, flFront, tank, 3),
			flDown2 = flGetDistance(flPos, flAngles, 90.0, 0.0, flDown, tank, 3),
			flUp2 = flGetDistance(flPos, flAngles, -90.0, 0.0, flUp, tank, 3),
			flLeft2 = flGetDistance(flPos, flAngles, 0.0, 90.0, flLeft, tank, 3),
			flRight2 = flGetDistance(flPos, flAngles, 0.0, -90.0, flRight, tank, 3),
			flDistance2 = flGetDistance(flPos, flAngles, 30.0, 0.0, flVector1, tank, 3),
			flDistance3 = flGetDistance(flPos, flAngles, 30.0, 45.0, flVector2, tank, 3),
			flDistance4 = flGetDistance(flPos, flAngles, 0.0, 45.0, flVector3, tank, 3),
			flDistance5 = flGetDistance(flPos, flAngles, -30.0, 45.0, flVector4, tank, 3),
			flDistance6 = flGetDistance(flPos, flAngles, -30.0, 0.0, flVector5, tank, 3),
			flDistance7 = flGetDistance(flPos, flAngles, -30.0, -45.0, flVector6, tank, 3),
			flDistance8 = flGetDistance(flPos, flAngles, 0.0, -45.0, flVector7, tank, 3),
			flDistance9 = flGetDistance(flPos, flAngles, 30.0, -45.0, flVector8, tank, 3);

		NormalizeVector(flFront, flFront);
		NormalizeVector(flUp, flUp);
		NormalizeVector(flDown, flDown);
		NormalizeVector(flLeft, flLeft);
		NormalizeVector(flRight, flRight);
		NormalizeVector(flVector, flVector);
		NormalizeVector(flVector1, flVector1);
		NormalizeVector(flVector2, flVector2);
		NormalizeVector(flVector3, flVector3);
		NormalizeVector(flVector4, flVector4);
		NormalizeVector(flVector5, flVector5);
		NormalizeVector(flVector6, flVector6);
		NormalizeVector(flVector7, flVector7);
		NormalizeVector(flVector8, flVector8);

		if (bVisible)
		{
			flBase = 80.0;
		}

		if (flFront2 > flBase)
		{
			flFront2 = flBase;
		}

		if (flUp2 > flBase)
		{
			flUp2 = flBase;
		}

		if (flDown2 > flBase)
		{
			flDown2 = flBase;
		}

		if (flLeft2 > flBase)
		{
			flLeft2 = flBase;
		}

		if (flRight2 > flBase)
		{
			flRight2 = flBase;
		}

		if (flDistance2 > flBase)
		{
			flDistance2 = flBase;
		}

		if (flDistance3 > flBase)
		{
			flDistance3 = flBase;
		}

		if (flDistance4 > flBase)
		{
			flDistance4 = flBase;
		}

		if (flDistance5 > flBase)
		{
			flDistance5 = flBase;
		}

		if (flDistance6 > flBase)
		{
			flDistance6 = flBase;
		}

		if (flDistance7 > flBase)
		{
			flDistance7 = flBase;
		}

		if (flDistance8 > flBase)
		{
			flDistance8 = flBase;
		}

		if (flDistance9 > flBase)
		{
			flDistance9 = flBase;
		}

		if (flFront2 < flBase2)
		{
			flFront2 = flBase2;
		}

		if (flUp2 < flBase2)
		{
			flUp2 = flBase2;
		}

		if (flDown2 < flBase2)
		{
			flDown2 = flBase2;
		}

		if (flLeft2 < flBase2)
		{
			flLeft2 = flBase2;
		}

		if (flRight2 < flBase2)
		{
			flRight2 = flBase2;
		}

		if (flDistance2 < flBase2)
		{
			flDistance2 = flBase2;
		}

		if (flDistance3 < flBase2)
		{
			flDistance3 = flBase2;
		}

		if (flDistance4 < flBase2)
		{
			flDistance4 = flBase2;
		}

		if (flDistance5 < flBase2)
		{
			flDistance5 = flBase2;
		}

		if (flDistance6 < flBase2)
		{
			flDistance6 = flBase2;
		}

		if (flDistance7 < flBase2)
		{
			flDistance7 = flBase2;
		}

		if (flDistance8 < flBase2)
		{
			flDistance8 = flBase2;
		}

		if (flDistance9 < flBase2)
		{
			flDistance9 = flBase2;
		}

		flVector9 =- ((1.0 * flFactor1 * (flBase - flFront2)) / flBase);
		ScaleVector(flFront, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flUp2)) / flBase);
		ScaleVector(flUp, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDown2)) / flBase);
		ScaleVector(flDown, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flLeft2)) / flBase);
		ScaleVector(flLeft, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flRight2)) / flBase);
		ScaleVector(flRight, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance2)) / flDistance2);
		ScaleVector(flVector1, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance3)) / flDistance3);
		ScaleVector(flVector2, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance4)) / flDistance4);
		ScaleVector(flVector3, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance5)) / flDistance5);
		ScaleVector(flVector4, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance6)) / flDistance6);
		ScaleVector(flVector5, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance7)) / flDistance7);
		ScaleVector(flVector6, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance8)) / flDistance8);
		ScaleVector(flVector7, flVector9);

		flVector9 =- ((1.0 * flFactor1 * (flBase - flDistance9)) / flDistance9);
		ScaleVector(flVector8, flVector9);

		if (flDistance >= 500.0)
		{
			flDistance = 500.0;
		}

		flVector9 = ((1.0 * flFactor2 * (1000.0 - flDistance)) / 500.0);
		ScaleVector(flVector, flVector9);

		AddVectors(flFront, flUp, flFront);
		AddVectors(flFront, flDown, flFront);
		AddVectors(flFront, flLeft, flFront);
		AddVectors(flFront, flRight, flFront);
		AddVectors(flFront, flVector1, flFront);
		AddVectors(flFront, flVector2, flFront);
		AddVectors(flFront, flVector3, flFront);
		AddVectors(flFront, flVector4, flFront);
		AddVectors(flFront, flVector5, flFront);
		AddVectors(flFront, flVector6, flFront);
		AddVectors(flFront, flVector7, flFront);
		AddVectors(flFront, flVector8, flFront);
		AddVectors(flFront, flVector, flFront);

		NormalizeVector(flFront, flFront);
		ScaleVector(flFront, (FLOAT_PI * duration * 2.0));

		float flVelocity3[3];
		AddVectors(flVelocity, flFront, flVelocity3);
		NormalizeVector(flVelocity3, flVelocity3);
		ScaleVector(flVelocity3, flSpeed);
		SetEntityMoveType(tank, MOVETYPE_FLY);
		vCopyVector(flVelocity3, g_esFlyPlayer[tank].g_flCurrentVelocity);
		TeleportEntity(tank, .velocity = flVelocity3);
	}
}

void vFlyCopyStats2(int oldTank, int newTank)
{
	g_esFlyPlayer[newTank].g_iAmmoCount = g_esFlyPlayer[oldTank].g_iAmmoCount;
	g_esFlyPlayer[newTank].g_iCooldown = g_esFlyPlayer[oldTank].g_iCooldown;
}

void vRemoveFly(int tank)
{
	vStopFly(tank);

	g_esFlyPlayer[tank].g_iAmmoCount = 0;
	g_esFlyPlayer[tank].g_iCooldown = -1;
}

void vFlyReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveFly(iPlayer);
		}
	}
}

void vFlyReset2(int tank)
{
	vFlyReset4(tank);

	if (g_esFlyCache[tank].g_iFlyMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Fly2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Fly2", LANG_SERVER, sTankName);
	}
}

void vFlyReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esFlyCache[tank].g_iFlyCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esFlyCache[tank].g_iHumanAbility == 1 && g_esFlyCache[tank].g_iHumanMode == 0 && g_esFlyPlayer[tank].g_iAmmoCount < g_esFlyCache[tank].g_iHumanAmmo && g_esFlyCache[tank].g_iHumanAmmo > 0) ? g_esFlyCache[tank].g_iHumanCooldown : iCooldown;
	g_esFlyPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esFlyPlayer[tank].g_iCooldown != -1 && g_esFlyPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "FlyHuman5", (g_esFlyPlayer[tank].g_iCooldown - iTime));
	}
}

void vFlyReset4(int tank)
{
	g_esFlyPlayer[tank].g_bActivated = false;
	g_esFlyPlayer[tank].g_flCurrentVelocity[0] = 0.0;
	g_esFlyPlayer[tank].g_flCurrentVelocity[1] = 0.0;
	g_esFlyPlayer[tank].g_flCurrentVelocity[2] = 0.0;
	g_esFlyPlayer[tank].g_flLastTime = 0.0;
	g_esFlyPlayer[tank].g_iDuration = -1;
}

void vStopFly(int tank)
{
	vFlyReset2(tank);

	SDKUnhook(tank, SDKHook_PreThink, OnFlyPreThink);
	SDKUnhook(tank, SDKHook_StartTouch, OnFlyStartTouch);

	if (bIsValidClient(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE))
	{
		SetEntityMoveType(tank, MOVETYPE_WALK);
		SetEntityGravity(tank, 1.0);

		if (g_esFlyPlayer[tank].g_iCooldown == -1 || g_esFlyPlayer[tank].g_iCooldown < GetTime())
		{
			vFlyReset3(tank);
		}
	}
}

int iGetFlyTarget(float pos[3], float angles[3], int tank)
{
	float flMin = 4.0, flPos[3], flAngle;
	int iTarget = 0;
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			if (bIsSurvivorDisabled(iSurvivor) || MT_IsAdminImmune(iSurvivor, tank) || bIsAdminImmune(iSurvivor, g_esFlyPlayer[tank].g_iTankType, g_esFlyAbility[g_esFlyPlayer[tank].g_iTankType].g_iImmunityFlags, g_esFlyPlayer[iSurvivor].g_iImmunityFlags))
			{
				continue;
			}

			GetClientEyePosition(iSurvivor, flPos);
			MakeVectorFromPoints(pos, flPos, flPos);
			flAngle = flGetAngle(angles, flPos);
			if (flAngle <= flMin)
			{
				flMin = flAngle;
				iTarget = iSurvivor;
			}
		}
	}

	return iTarget;
}

Action tTimerFlyCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esFlyAbility[g_esFlyPlayer[iTank].g_iTankType].g_iAccessFlags, g_esFlyPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esFlyPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esFlyCache[iTank].g_iFlyAbility == 0 || g_esFlyPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vFly(iTank, true, iPos);

	return Plugin_Continue;
}