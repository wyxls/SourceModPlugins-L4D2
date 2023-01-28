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

#define MT_METEOR_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_METEOR_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Meteor Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates meteor showers.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Meteor Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_METEOR_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MODEL_GASCAN "models/props_junk/gascan001a.mdl"
#define MODEL_PROPANETANK "models/props_junk/propanecanister001a.mdl"

#define MT_METEOR_SECTION "meteorability"
#define MT_METEOR_SECTION2 "meteor ability"
#define MT_METEOR_SECTION3 "meteor_ability"
#define MT_METEOR_SECTION4 "meteor"

#define MT_MENU_METEOR "Meteor Ability"

enum struct esMeteorPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flMeteorChance;
	float g_flMeteorDamage;
	float g_flMeteorInterval;
	float g_flMeteorLifetime;
	float g_flMeteorRadius[2];
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iMeteorAbility;
	int g_iMeteorCooldown;
	int g_iMeteorDuration;
	int g_iMeteorMessage;
	int g_iMeteorMode;
	int g_iRequiresHumans;
	int g_iTankType;
}

esMeteorPlayer g_esMeteorPlayer[MAXPLAYERS + 1];

enum struct esMeteorAbility
{
	float g_flCloseAreasOnly;
	float g_flMeteorChance;
	float g_flMeteorDamage;
	float g_flMeteorInterval;
	float g_flMeteorLifetime;
	float g_flMeteorRadius[2];
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iMeteorAbility;
	int g_iMeteorCooldown;
	int g_iMeteorDuration;
	int g_iMeteorMessage;
	int g_iMeteorMode;
	int g_iRequiresHumans;
}

esMeteorAbility g_esMeteorAbility[MT_MAXTYPES + 1];

enum struct esMeteorCache
{
	float g_flCloseAreasOnly;
	float g_flMeteorChance;
	float g_flMeteorDamage;
	float g_flMeteorInterval;
	float g_flMeteorLifetime;
	float g_flMeteorRadius[2];
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iMeteorAbility;
	int g_iMeteorCooldown;
	int g_iMeteorDuration;
	int g_iMeteorMessage;
	int g_iMeteorMode;
	int g_iRequiresHumans;
}

esMeteorCache g_esMeteorCache[MAXPLAYERS + 1];

int g_iUserID[2048];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_meteor", cmdMeteorInfo, "View information about the Meteor ability.");

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

#if defined MT_ABILITIES_MAIN2
void vMeteorMapStart()
#else
public void OnMapStart()
#endif
{
	vMeteorReset();
}

#if defined MT_ABILITIES_MAIN2
void vMeteorClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnMeteorTakeDamage);
	vRemoveMeteor(client);
}

#if defined MT_ABILITIES_MAIN2
void vMeteorClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveMeteor(client);
}

#if defined MT_ABILITIES_MAIN2
void vMeteorMapEnd()
#else
public void OnMapEnd()
#endif
{
	vMeteorReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdMeteorInfo(int client, int args)
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
		case false: vMeteorMenu(client, MT_METEOR_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vMeteorMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_METEOR_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iMeteorMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Meteor Ability Information");
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

int iMeteorMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMeteorCache[param1].g_iMeteorAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esMeteorCache[param1].g_iHumanAmmo - g_esMeteorPlayer[param1].g_iAmmoCount), g_esMeteorCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMeteorCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esMeteorCache[param1].g_iHumanAbility == 1) ? g_esMeteorCache[param1].g_iHumanCooldown : g_esMeteorCache[param1].g_iMeteorCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "MeteorDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esMeteorCache[param1].g_iHumanAbility == 1) ? g_esMeteorCache[param1].g_iHumanDuration : g_esMeteorCache[param1].g_iMeteorDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMeteorCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vMeteorMenu(param1, MT_METEOR_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pMeteor = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MeteorMenu", param1);
			pMeteor.SetTitle(sMenuTitle);
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

#if defined MT_ABILITIES_MAIN2
void vMeteorDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_METEOR, MT_MENU_METEOR);
}

#if defined MT_ABILITIES_MAIN2
void vMeteorMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_METEOR, false))
	{
		vMeteorMenu(client, MT_METEOR_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_METEOR, false))
	{
		FormatEx(buffer, size, "%T", "MeteorMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorEntityCreated(int entity, const char[] classname)
#else
public void OnEntityCreated(int entity, const char[] classname)
#endif
{
	if (bIsValidEntity(entity))
	{
		g_iUserID[entity] = 0;

		if (StrEqual(classname, "pipe_bomb_projectile"))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnPropSpawn);
		}
	}
}

void OnPropSpawn(int prop)
{
	int iTank = GetEntPropEnt(prop, Prop_Data, "m_hOwnerEntity");
	if (bIsTank(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
	{
		g_iUserID[prop] = GetClientUserId(iTank);
	}
}

Action OnMeteorTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		int iTank = GetClientOfUserId(g_iUserID[inflictor]);
		if (MT_IsTankSupported(iTank) && g_esMeteorCache[iTank].g_iMeteorAbility == 1 && g_esMeteorCache[iTank].g_iMeteorMode == 1 && StrEqual(sClassname, "pipe_bomb_projectile") && damagetype == 134217792)
		{
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vMeteorPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_METEOR);
}

#if defined MT_ABILITIES_MAIN2
void vMeteorAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_METEOR_SECTION);
	list2.PushString(MT_METEOR_SECTION2);
	list3.PushString(MT_METEOR_SECTION3);
	list4.PushString(MT_METEOR_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vMeteorCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMeteorCache[tank].g_iHumanAbility != 2)
	{
		g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_METEOR_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_METEOR_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_METEOR_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_METEOR_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esMeteorCache[tank].g_iMeteorAbility == 1 && g_esMeteorCache[tank].g_iComboAbility == 1 && !g_esMeteorPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_METEOR_SECTION, false) || StrEqual(sSubset[iPos], MT_METEOR_SECTION2, false) || StrEqual(sSubset[iPos], MT_METEOR_SECTION3, false) || StrEqual(sSubset[iPos], MT_METEOR_SECTION4, false))
				{
					g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vMeteor(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerMeteorCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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

#if defined MT_ABILITIES_MAIN2
void vMeteorConfigsLoad(int mode)
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
				g_esMeteorAbility[iIndex].g_iAccessFlags = 0;
				g_esMeteorAbility[iIndex].g_iImmunityFlags = 0;
				g_esMeteorAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esMeteorAbility[iIndex].g_iComboAbility = 0;
				g_esMeteorAbility[iIndex].g_iComboPosition = -1;
				g_esMeteorAbility[iIndex].g_iHumanAbility = 0;
				g_esMeteorAbility[iIndex].g_iHumanAmmo = 5;
				g_esMeteorAbility[iIndex].g_iHumanCooldown = 0;
				g_esMeteorAbility[iIndex].g_iHumanDuration = 5;
				g_esMeteorAbility[iIndex].g_iHumanMode = 1;
				g_esMeteorAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esMeteorAbility[iIndex].g_iRequiresHumans = 0;
				g_esMeteorAbility[iIndex].g_iMeteorAbility = 0;
				g_esMeteorAbility[iIndex].g_iMeteorMessage = 0;
				g_esMeteorAbility[iIndex].g_flMeteorChance = 33.3;
				g_esMeteorAbility[iIndex].g_iMeteorCooldown = 0;
				g_esMeteorAbility[iIndex].g_flMeteorDamage = 5.0;
				g_esMeteorAbility[iIndex].g_iMeteorDuration = 5;
				g_esMeteorAbility[iIndex].g_flMeteorInterval = 0.6;
				g_esMeteorAbility[iIndex].g_flMeteorLifetime = 15.0;
				g_esMeteorAbility[iIndex].g_iMeteorMode = 0;
				g_esMeteorAbility[iIndex].g_flMeteorRadius[0] = -180.0;
				g_esMeteorAbility[iIndex].g_flMeteorRadius[1] = 180.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esMeteorPlayer[iPlayer].g_iAccessFlags = 0;
					g_esMeteorPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esMeteorPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esMeteorPlayer[iPlayer].g_iComboAbility = 0;
					g_esMeteorPlayer[iPlayer].g_iHumanAbility = 0;
					g_esMeteorPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esMeteorPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esMeteorPlayer[iPlayer].g_iHumanDuration = 0;
					g_esMeteorPlayer[iPlayer].g_iHumanMode = 0;
					g_esMeteorPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esMeteorPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esMeteorPlayer[iPlayer].g_iMeteorAbility = 0;
					g_esMeteorPlayer[iPlayer].g_iMeteorMessage = 0;
					g_esMeteorPlayer[iPlayer].g_flMeteorChance = 0.0;
					g_esMeteorPlayer[iPlayer].g_iMeteorCooldown = 0;
					g_esMeteorPlayer[iPlayer].g_flMeteorDamage = 0.0;
					g_esMeteorPlayer[iPlayer].g_iMeteorDuration = 0;
					g_esMeteorPlayer[iPlayer].g_flMeteorInterval = 0.0;
					g_esMeteorPlayer[iPlayer].g_flMeteorLifetime = 0.0;
					g_esMeteorPlayer[iPlayer].g_iMeteorMode = 0;
					g_esMeteorPlayer[iPlayer].g_flMeteorRadius[0] = 0.0;
					g_esMeteorPlayer[iPlayer].g_flMeteorRadius[1] = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esMeteorPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esMeteorPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esMeteorPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esMeteorPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esMeteorPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esMeteorPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esMeteorPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esMeteorPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esMeteorPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esMeteorPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esMeteorPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esMeteorPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esMeteorPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esMeteorPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esMeteorPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esMeteorPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esMeteorPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esMeteorPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esMeteorPlayer[admin].g_iMeteorAbility = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esMeteorPlayer[admin].g_iMeteorAbility, value, 0, 1);
		g_esMeteorPlayer[admin].g_iMeteorMessage = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esMeteorPlayer[admin].g_iMeteorMessage, value, 0, 1);
		g_esMeteorPlayer[admin].g_flMeteorChance = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorChance", "Meteor Chance", "Meteor_Chance", "chance", g_esMeteorPlayer[admin].g_flMeteorChance, value, 0.0, 100.0);
		g_esMeteorPlayer[admin].g_iMeteorCooldown = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorCooldown", "Meteor Cooldown", "Meteor_Cooldown", "cooldown", g_esMeteorPlayer[admin].g_iMeteorCooldown, value, 0, 99999);
		g_esMeteorPlayer[admin].g_flMeteorDamage = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorDamage", "Meteor Damage", "Meteor_Damage", "damage", g_esMeteorPlayer[admin].g_flMeteorDamage, value, 0.0, 99999.0);
		g_esMeteorPlayer[admin].g_iMeteorDuration = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorDuration", "Meteor Duration", "Meteor_Duration", "duration", g_esMeteorPlayer[admin].g_iMeteorDuration, value, 0, 99999);
		g_esMeteorPlayer[admin].g_flMeteorInterval = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorInterval", "Meteor Interval", "Meteor_Interval", "interval", g_esMeteorPlayer[admin].g_flMeteorInterval, value, 0.1, 1.0);
		g_esMeteorPlayer[admin].g_flMeteorLifetime = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorLifetime", "Meteor Lifetime", "Meteor_Lifetime", "lifetime", g_esMeteorPlayer[admin].g_flMeteorLifetime, value, 0.1, 99999.0);
		g_esMeteorPlayer[admin].g_iMeteorMode = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorMode", "Meteor Mode", "Meteor_Mode", "mode", g_esMeteorPlayer[admin].g_iMeteorMode, value, 0, 1);
		g_esMeteorPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esMeteorPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		if (StrEqual(subsection, MT_METEOR_SECTION, false) || StrEqual(subsection, MT_METEOR_SECTION2, false) || StrEqual(subsection, MT_METEOR_SECTION3, false) || StrEqual(subsection, MT_METEOR_SECTION4, false))
		{
			if (StrEqual(key, "MeteorRadius", false) || StrEqual(key, "Meteor Radius", false) || StrEqual(key, "Meteor_Radius", false) || StrEqual(key, "radius", false))
			{
				char sSet[2][7], sValue[14];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);

				g_esMeteorPlayer[admin].g_flMeteorRadius[0] = (sSet[0][0] != '\0') ? flClamp(StringToFloat(sSet[0]), -200.0, 0.0) : g_esMeteorPlayer[admin].g_flMeteorRadius[0];
				g_esMeteorPlayer[admin].g_flMeteorRadius[1] = (sSet[1][0] != '\0') ? flClamp(StringToFloat(sSet[1]), 0.0, 200.0) : g_esMeteorPlayer[admin].g_flMeteorRadius[1];
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esMeteorAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esMeteorAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esMeteorAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esMeteorAbility[type].g_iComboAbility, value, 0, 1);
		g_esMeteorAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esMeteorAbility[type].g_iHumanAbility, value, 0, 2);
		g_esMeteorAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esMeteorAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esMeteorAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esMeteorAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esMeteorAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esMeteorAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esMeteorAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esMeteorAbility[type].g_iHumanMode, value, 0, 1);
		g_esMeteorAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esMeteorAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esMeteorAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esMeteorAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esMeteorAbility[type].g_iMeteorAbility = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esMeteorAbility[type].g_iMeteorAbility, value, 0, 1);
		g_esMeteorAbility[type].g_iMeteorMessage = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esMeteorAbility[type].g_iMeteorMessage, value, 0, 1);
		g_esMeteorAbility[type].g_flMeteorChance = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorChance", "Meteor Chance", "Meteor_Chance", "chance", g_esMeteorAbility[type].g_flMeteorChance, value, 0.0, 100.0);
		g_esMeteorAbility[type].g_iMeteorCooldown = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorCooldown", "Meteor Cooldown", "Meteor_Cooldown", "cooldown", g_esMeteorAbility[type].g_iMeteorCooldown, value, 0, 99999);
		g_esMeteorAbility[type].g_flMeteorDamage = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorDamage", "Meteor Damage", "Meteor_Damage", "damage", g_esMeteorAbility[type].g_flMeteorDamage, value, 0.0, 99999.0);
		g_esMeteorAbility[type].g_iMeteorDuration = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorDuration", "Meteor Duration", "Meteor_Duration", "duration", g_esMeteorAbility[type].g_iMeteorDuration, value, 0, 99999);
		g_esMeteorAbility[type].g_flMeteorInterval = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorInterval", "Meteor Interval", "Meteor_Interval", "interval", g_esMeteorAbility[type].g_flMeteorInterval, value, 0.1, 1.0);
		g_esMeteorAbility[type].g_flMeteorLifetime = flGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorLifetime", "Meteor Lifetime", "Meteor_Lifetime", "lifetime", g_esMeteorAbility[type].g_flMeteorLifetime, value, 0.1, 99999.0);
		g_esMeteorAbility[type].g_iMeteorMode = iGetKeyValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "MeteorMode", "Meteor Mode", "Meteor_Mode", "mode", g_esMeteorAbility[type].g_iMeteorMode, value, 0, 1);
		g_esMeteorAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esMeteorAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_METEOR_SECTION, MT_METEOR_SECTION2, MT_METEOR_SECTION3, MT_METEOR_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);

		if (StrEqual(subsection, MT_METEOR_SECTION, false) || StrEqual(subsection, MT_METEOR_SECTION2, false) || StrEqual(subsection, MT_METEOR_SECTION3, false) || StrEqual(subsection, MT_METEOR_SECTION4, false))
		{
			if (StrEqual(key, "MeteorRadius", false) || StrEqual(key, "Meteor Radius", false) || StrEqual(key, "Meteor_Radius", false) || StrEqual(key, "radius", false))
			{
				char sSet[2][7], sValue[14];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);

				g_esMeteorAbility[type].g_flMeteorRadius[0] = (sSet[0][0] != '\0') ? flClamp(StringToFloat(sSet[0]), -200.0, 0.0) : g_esMeteorAbility[type].g_flMeteorRadius[0];
				g_esMeteorAbility[type].g_flMeteorRadius[1] = (sSet[1][0] != '\0') ? flClamp(StringToFloat(sSet[1]), 0.0, 200.0) : g_esMeteorAbility[type].g_flMeteorRadius[1];
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esMeteorCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flCloseAreasOnly, g_esMeteorAbility[type].g_flCloseAreasOnly);
	g_esMeteorCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iComboAbility, g_esMeteorAbility[type].g_iComboAbility);
	g_esMeteorCache[tank].g_flMeteorChance = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flMeteorChance, g_esMeteorAbility[type].g_flMeteorChance);
	g_esMeteorCache[tank].g_flMeteorDamage = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flMeteorDamage, g_esMeteorAbility[type].g_flMeteorDamage);
	g_esMeteorCache[tank].g_flMeteorInterval = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flMeteorInterval, g_esMeteorAbility[type].g_flMeteorInterval);
	g_esMeteorCache[tank].g_flMeteorLifetime = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flMeteorLifetime, g_esMeteorAbility[type].g_flMeteorLifetime);
	g_esMeteorCache[tank].g_flMeteorRadius[0] = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flMeteorRadius[0], g_esMeteorAbility[type].g_flMeteorRadius[0]);
	g_esMeteorCache[tank].g_flMeteorRadius[1] = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flMeteorRadius[1], g_esMeteorAbility[type].g_flMeteorRadius[1]);
	g_esMeteorCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iHumanAbility, g_esMeteorAbility[type].g_iHumanAbility);
	g_esMeteorCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iHumanAmmo, g_esMeteorAbility[type].g_iHumanAmmo);
	g_esMeteorCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iHumanCooldown, g_esMeteorAbility[type].g_iHumanCooldown);
	g_esMeteorCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iHumanDuration, g_esMeteorAbility[type].g_iHumanDuration);
	g_esMeteorCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iHumanMode, g_esMeteorAbility[type].g_iHumanMode);
	g_esMeteorCache[tank].g_iMeteorAbility = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iMeteorAbility, g_esMeteorAbility[type].g_iMeteorAbility);
	g_esMeteorCache[tank].g_iMeteorCooldown = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iMeteorCooldown, g_esMeteorAbility[type].g_iMeteorCooldown);
	g_esMeteorCache[tank].g_iMeteorDuration = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iMeteorDuration, g_esMeteorAbility[type].g_iMeteorDuration);
	g_esMeteorCache[tank].g_iMeteorMessage = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iMeteorMessage, g_esMeteorAbility[type].g_iMeteorMessage);
	g_esMeteorCache[tank].g_iMeteorMode = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iMeteorMode, g_esMeteorAbility[type].g_iMeteorMode);
	g_esMeteorCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_flOpenAreasOnly, g_esMeteorAbility[type].g_flOpenAreasOnly);
	g_esMeteorCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esMeteorPlayer[tank].g_iRequiresHumans, g_esMeteorAbility[type].g_iRequiresHumans);
	g_esMeteorPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vMeteorCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vMeteorCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveMeteor(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vMeteorEventFired(Event event, const char[] name)
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
			vMeteorCopyStats2(iBot, iTank);
			vRemoveMeteor(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vMeteorCopyStats2(iTank, iBot);
			vRemoveMeteor(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveMeteor(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vMeteorReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[tank].g_iAccessFlags)) || g_esMeteorCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esMeteorCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esMeteorCache[tank].g_iMeteorAbility == 1 && g_esMeteorCache[tank].g_iComboAbility == 0 && !g_esMeteorPlayer[tank].g_bActivated)
	{
		vMeteorAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esMeteorCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMeteorCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMeteorPlayer[tank].g_iTankType) || (g_esMeteorCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMeteorCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esMeteorCache[tank].g_iMeteorAbility == 1 && g_esMeteorCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esMeteorPlayer[tank].g_iCooldown != -1 && g_esMeteorPlayer[tank].g_iCooldown > iTime;

			switch (g_esMeteorCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esMeteorPlayer[tank].g_bActivated && !bRecharging)
					{
						vMeteorAbility(tank);
					}
					else if (g_esMeteorPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman4", (g_esMeteorPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esMeteorPlayer[tank].g_iAmmoCount < g_esMeteorCache[tank].g_iHumanAmmo && g_esMeteorCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esMeteorPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esMeteorPlayer[tank].g_bActivated = true;
							g_esMeteorPlayer[tank].g_iAmmoCount++;

							vMeteor2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman", g_esMeteorPlayer[tank].g_iAmmoCount, g_esMeteorCache[tank].g_iHumanAmmo);
						}
						else if (g_esMeteorPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman4", (g_esMeteorPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esMeteorCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esMeteorCache[tank].g_iHumanMode == 1 && g_esMeteorPlayer[tank].g_bActivated && (g_esMeteorPlayer[tank].g_iCooldown == -1 || g_esMeteorPlayer[tank].g_iCooldown < GetTime()))
		{
			vMeteorReset2(tank);
			vMeteorReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMeteorChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveMeteor(tank);
}

void vMeteor(int tank, int pos = -1)
{
	if (g_esMeteorPlayer[tank].g_iCooldown != -1 && g_esMeteorPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esMeteorPlayer[tank].g_bActivated = true;

	vMeteor2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMeteorCache[tank].g_iHumanAbility == 1)
	{
		g_esMeteorPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman", g_esMeteorPlayer[tank].g_iAmmoCount, g_esMeteorCache[tank].g_iHumanAmmo);
	}

	if (g_esMeteorCache[tank].g_iMeteorMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Meteor", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Meteor", LANG_SERVER, sTankName);
	}
}

void vMeteor2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esMeteorCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMeteorCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMeteorPlayer[tank].g_iTankType) || (g_esMeteorCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMeteorCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esMeteorCache[tank].g_flMeteorInterval;
	DataPack dpMeteor;
	CreateDataTimer(flInterval, tTimerMeteor, dpMeteor, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpMeteor.WriteCell(GetClientUserId(tank));
	dpMeteor.WriteCell(g_esMeteorPlayer[tank].g_iTankType);
	dpMeteor.WriteCell(GetTime());
	dpMeteor.WriteCell(pos);
}

void vMeteor3(int tank, int rock, int pos = -1)
{
	if (!MT_IsTankSupported(tank) || bIsAreaNarrow(tank, g_esMeteorCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMeteorCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMeteorPlayer[tank].g_iTankType) || (g_esMeteorCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMeteorCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[tank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esMeteorPlayer[tank].g_iTankType) || !MT_IsCustomTankSupported(tank) || !bIsValidEntity(rock))
	{
		return;
	}

	RemoveEntity(rock);

	switch (g_esMeteorCache[tank].g_iMeteorMode)
	{
		case 0:
		{
			float flRockPos[3];
			GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flRockPos);
			vSpawnBreakProp(tank, flRockPos, 50.0, MODEL_GASCAN);
			vSpawnBreakProp(tank, flRockPos, 50.0, MODEL_PROPANETANK);
		}
		case 1:
		{
			float flRockPos[3];
			GetEntPropVector(rock, Prop_Data, "m_vecOrigin", flRockPos);
			vSpawnBreakProp(tank, flRockPos, 50.0, MODEL_PROPANETANK);

			float flTankPos[3], flSurvivorPos[3];
			GetClientAbsOrigin(tank, flTankPos);
			float flDamage = (pos != -1) ? MT_GetCombinationSetting(tank, 3, pos) : g_esMeteorCache[tank].g_flMeteorDamage;
			if (flDamage > 0.0)
			{
				for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
				{
					if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esMeteorPlayer[tank].g_iTankType, g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iImmunityFlags, g_esMeteorPlayer[iSurvivor].g_iImmunityFlags))
					{
						GetClientAbsOrigin(iSurvivor, flSurvivorPos);
						if (GetVectorDistance(flTankPos, flSurvivorPos) <= 200.0)
						{
							vDamagePlayer(iSurvivor, tank, MT_GetScaledDamage(flDamage), "16");
						}
					}
				}
			}

			vPushNearbyEntities(tank, flRockPos);
		}
	}
}

void vMeteorAbility(int tank)
{
	if ((g_esMeteorPlayer[tank].g_iCooldown != -1 && g_esMeteorPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esMeteorCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMeteorCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMeteorPlayer[tank].g_iTankType) || (g_esMeteorCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMeteorCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esMeteorPlayer[tank].g_iAmmoCount < g_esMeteorCache[tank].g_iHumanAmmo && g_esMeteorCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esMeteorCache[tank].g_flMeteorChance)
		{
			vMeteor(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMeteorCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMeteorCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorAmmo");
	}
}

void vMeteorCopyStats2(int oldTank, int newTank)
{
	g_esMeteorPlayer[newTank].g_iAmmoCount = g_esMeteorPlayer[oldTank].g_iAmmoCount;
	g_esMeteorPlayer[newTank].g_iCooldown = g_esMeteorPlayer[oldTank].g_iCooldown;
}

void vRemoveMeteor(int tank)
{
	g_esMeteorPlayer[tank].g_bActivated = false;
	g_esMeteorPlayer[tank].g_iAmmoCount = 0;
	g_esMeteorPlayer[tank].g_iCooldown = -1;
}

void vMeteorReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveMeteor(iPlayer);
		}
	}
}

void vMeteorReset2(int tank)
{
	g_esMeteorPlayer[tank].g_bActivated = false;

	if (g_esMeteorCache[tank].g_iMeteorMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Meteor2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Meteor2", LANG_SERVER, sTankName);
	}
}

void vMeteorReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esMeteorAbility[g_esMeteorPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esMeteorCache[tank].g_iMeteorCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMeteorCache[tank].g_iHumanAbility == 1 && g_esMeteorCache[tank].g_iHumanMode == 0 && g_esMeteorPlayer[tank].g_iAmmoCount < g_esMeteorCache[tank].g_iHumanAmmo && g_esMeteorCache[tank].g_iHumanAmmo > 0) ? g_esMeteorCache[tank].g_iHumanCooldown : iCooldown;
	g_esMeteorPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esMeteorPlayer[tank].g_iCooldown != -1 && g_esMeteorPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MeteorHuman5", (g_esMeteorPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerMeteorCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esMeteorAbility[g_esMeteorPlayer[iTank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esMeteorPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esMeteorCache[iTank].g_iMeteorAbility == 0 || g_esMeteorPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vMeteor(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerDestroyMeteor(Handle timer, DataPack pack)
{
	pack.Reset();

	int iMeteor = EntRefToEntIndex(pack.ReadCell()), iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || iMeteor == INVALID_ENT_REFERENCE || !bIsValidEntity(iMeteor))
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vMeteor3(iTank, iMeteor, iPos);

	return Plugin_Continue;
}

Action tTimerMeteor(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || MT_DoesTypeRequireHumans(g_esMeteorPlayer[iTank].g_iTankType) || (g_esMeteorCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMeteorCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esMeteorAbility[g_esMeteorPlayer[iTank].g_iTankType].g_iAccessFlags, g_esMeteorPlayer[iTank].g_iAccessFlags)) || !MT_IsCustomTankSupported(iTank) || iType != g_esMeteorPlayer[iTank].g_iTankType || !g_esMeteorPlayer[iTank].g_bActivated)
	{
		g_esMeteorPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	if (g_esMeteorCache[iTank].g_iMeteorAbility == 0 || bIsAreaNarrow(iTank, g_esMeteorCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esMeteorCache[iTank].g_flCloseAreasOnly))
	{
		vMeteorReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esMeteorCache[iTank].g_iMeteorDuration;
	iDuration = (bHuman && g_esMeteorCache[iTank].g_iHumanAbility == 1) ? g_esMeteorCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esMeteorCache[iTank].g_iHumanAbility == 1 && g_esMeteorCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime)
	{
		vMeteorReset2(iTank);
		vMeteorReset3(iTank);

		return Plugin_Stop;
	}

	float flPos[3], flAngles[3];
	GetClientEyePosition(iTank, flPos);
	flAngles[0] = MT_GetRandomFloat(-20.0, 20.0);
	flAngles[1] = MT_GetRandomFloat(-20.0, 20.0);
	flAngles[2] = 60.0;
	GetVectorAngles(flAngles, flAngles);

	float flMinRadius = (iPos != -1) ? MT_GetCombinationSetting(iTank, 7, iPos) : g_esMeteorCache[iTank].g_flMeteorRadius[0],
		flMaxRadius = (iPos != -1) ? MT_GetCombinationSetting(iTank, 8, iPos) : g_esMeteorCache[iTank].g_flMeteorRadius[1],
		flHitpos[3];
	iGetRayHitPos(flPos, flAngles, flHitpos, iTank, true, 2);
	float flDistance = GetVectorDistance(flPos, flHitpos);
	if (flDistance > 1600.0)
	{
		flDistance = 1600.0;
	}

	float flVector[3];
	MakeVectorFromPoints(flPos, flHitpos, flVector);
	NormalizeVector(flVector, flVector);
	ScaleVector(flVector, (flDistance - 40.0));
	AddVectors(flPos, flVector, flHitpos);
	if (flDistance > 100.0)
	{
		int iMeteor = CreateEntityByName("tank_rock");
		if (bIsValidEntity(iMeteor))
		{
			float flAngles2[3];
			for (int iIndex = 0; iIndex < (sizeof flAngles2); iIndex++)
			{
				flAngles2[iIndex] = MT_GetRandomFloat(flMinRadius, flMaxRadius);
			}

			float flVelocity[3];
			flVelocity[0] = MT_GetRandomFloat(0.0, 350.0);
			flVelocity[1] = MT_GetRandomFloat(0.0, 350.0);
			flVelocity[2] = MT_GetRandomFloat(0.0, 30.0);

			TeleportEntity(iMeteor, flHitpos, flAngles2);
			DispatchSpawn(iMeteor);
			TeleportEntity(iMeteor, .velocity = flVelocity);
			ActivateEntity(iMeteor);
			AcceptEntityInput(iMeteor, "Ignite");

			SetEntPropEnt(iMeteor, Prop_Data, "m_hThrower", iTank);
			iMeteor = EntIndexToEntRef(iMeteor);
			vDeleteEntity(iMeteor, g_esMeteorCache[iTank].g_flMeteorLifetime);

			DataPack dpMeteor;
			CreateDataTimer(10.0, tTimerDestroyMeteor, dpMeteor, TIMER_FLAG_NO_MAPCHANGE);
			dpMeteor.WriteCell(iMeteor);
			dpMeteor.WriteCell(GetClientUserId(iTank));
			dpMeteor.WriteCell(iPos);
		}
	}

	int iMeteor = -1;
	while ((iMeteor = FindEntityByClassname(iMeteor, "tank_rock")) != INVALID_ENT_REFERENCE)
	{
		int iTank2 = GetEntPropEnt(iMeteor, Prop_Data, "m_hThrower");
		if (iTank == iTank2 && flGetGroundUnits(iMeteor) < 200.0)
		{
			vMeteor3(iTank2, iMeteor, iPos);
		}
	}

	return Plugin_Continue;
}