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

#define MT_CLOUD_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_CLOUD_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Cloud Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank constantly emits clouds of smoke that damage survivors caught in them.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Cloud Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_CLOUD_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define PARTICLE_SMOKE "smoker_smokecloud"

#define MT_CLOUD_SECTION "cloudability"
#define MT_CLOUD_SECTION2 "cloud ability"
#define MT_CLOUD_SECTION3 "cloud_ability"
#define MT_CLOUD_SECTION4 "cloud"

#define MT_MENU_CLOUD "Cloud Ability"

enum struct esCloudPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flCloudChance;
	float g_flCloudDamage;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iCloudAbility;
	int g_iCloudCooldown;
	int g_iCloudDuration;
	int g_iCloudMessage;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iTankType;
}

esCloudPlayer g_esCloudPlayer[MAXPLAYERS + 1];

enum struct esCloudAbility
{
	float g_flCloseAreasOnly;
	float g_flCloudChance;
	float g_flCloudDamage;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iCloudAbility;
	int g_iCloudCooldown;
	int g_iCloudDuration;
	int g_iCloudMessage;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esCloudAbility g_esCloudAbility[MT_MAXTYPES + 1];

enum struct esCloudCache
{
	float g_flCloseAreasOnly;
	float g_flCloudChance;
	float g_flCloudDamage;
	float g_flOpenAreasOnly;

	int g_iCloudAbility;
	int g_iCloudCooldown;
	int g_iCloudDuration;
	int g_iCloudMessage;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
}

esCloudCache g_esCloudCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_cloud", cmdCloudInfo, "View information about the Cloud ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vCloudMapStart()
#else
public void OnMapStart()
#endif
{
	iPrecacheParticle(PARTICLE_SMOKE);
	vCloudReset();
}

#if defined MT_ABILITIES_MAIN
void vCloudClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveCloud(client);
}

#if defined MT_ABILITIES_MAIN
void vCloudClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveCloud(client);
}

#if defined MT_ABILITIES_MAIN
void vCloudMapEnd()
#else
public void OnMapEnd()
#endif
{
	vCloudReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdCloudInfo(int client, int args)
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
		case false: vCloudMenu(client, MT_CLOUD_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vCloudMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_CLOUD_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iCloudMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Cloud Ability Information");
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

int iCloudMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esCloudCache[param1].g_iCloudAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esCloudCache[param1].g_iHumanAmmo - g_esCloudPlayer[param1].g_iAmmoCount), g_esCloudCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esCloudCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esCloudCache[param1].g_iHumanAbility == 1) ? g_esCloudCache[param1].g_iHumanCooldown : g_esCloudCache[param1].g_iCloudCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "CloudDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esCloudCache[param1].g_iHumanAbility == 1) ? g_esCloudCache[param1].g_iHumanDuration : g_esCloudCache[param1].g_iCloudDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esCloudCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vCloudMenu(param1, MT_CLOUD_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pCloud = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "CloudMenu", param1);
			pCloud.SetTitle(sMenuTitle);
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
void vCloudDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_CLOUD, MT_MENU_CLOUD);
}

#if defined MT_ABILITIES_MAIN
void vCloudMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_CLOUD, false))
	{
		vCloudMenu(client, MT_CLOUD_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_CLOUD, false))
	{
		FormatEx(buffer, size, "%T", "CloudMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_CLOUD);
}

#if defined MT_ABILITIES_MAIN
void vCloudAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_CLOUD_SECTION);
	list2.PushString(MT_CLOUD_SECTION2);
	list3.PushString(MT_CLOUD_SECTION3);
	list4.PushString(MT_CLOUD_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vCloudCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloudCache[tank].g_iHumanAbility != 2)
	{
		g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_CLOUD_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_CLOUD_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_CLOUD_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_CLOUD_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esCloudCache[tank].g_iCloudAbility == 1 && g_esCloudCache[tank].g_iComboAbility == 1 && !g_esCloudPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_CLOUD_SECTION, false) || StrEqual(sSubset[iPos], MT_CLOUD_SECTION2, false) || StrEqual(sSubset[iPos], MT_CLOUD_SECTION3, false) || StrEqual(sSubset[iPos], MT_CLOUD_SECTION4, false))
				{
					g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vCloud(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerCloudCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vCloudConfigsLoad(int mode)
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
				g_esCloudAbility[iIndex].g_iAccessFlags = 0;
				g_esCloudAbility[iIndex].g_iImmunityFlags = 0;
				g_esCloudAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esCloudAbility[iIndex].g_iComboAbility = 0;
				g_esCloudAbility[iIndex].g_iComboPosition = -1;
				g_esCloudAbility[iIndex].g_iHumanAbility = 0;
				g_esCloudAbility[iIndex].g_iHumanAmmo = 5;
				g_esCloudAbility[iIndex].g_iHumanCooldown = 0;
				g_esCloudAbility[iIndex].g_iHumanDuration = 5;
				g_esCloudAbility[iIndex].g_iHumanMode = 1;
				g_esCloudAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esCloudAbility[iIndex].g_iRequiresHumans = 0;
				g_esCloudAbility[iIndex].g_iCloudAbility = 0;
				g_esCloudAbility[iIndex].g_iCloudMessage = 0;
				g_esCloudAbility[iIndex].g_flCloudChance = 33.3;
				g_esCloudAbility[iIndex].g_iCloudCooldown = 0;
				g_esCloudAbility[iIndex].g_flCloudDamage = 5.0;
				g_esCloudAbility[iIndex].g_iCloudDuration = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esCloudPlayer[iPlayer].g_iAccessFlags = 0;
					g_esCloudPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esCloudPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esCloudPlayer[iPlayer].g_iComboAbility = 0;
					g_esCloudPlayer[iPlayer].g_iHumanAbility = 0;
					g_esCloudPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esCloudPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esCloudPlayer[iPlayer].g_iHumanDuration = 0;
					g_esCloudPlayer[iPlayer].g_iHumanMode = 0;
					g_esCloudPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esCloudPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esCloudPlayer[iPlayer].g_iCloudAbility = 0;
					g_esCloudPlayer[iPlayer].g_iCloudMessage = 0;
					g_esCloudPlayer[iPlayer].g_flCloudChance = 0.0;
					g_esCloudPlayer[iPlayer].g_iCloudCooldown = 0;
					g_esCloudPlayer[iPlayer].g_flCloudDamage = 0.0;
					g_esCloudPlayer[iPlayer].g_iCloudDuration = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esCloudPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esCloudPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esCloudPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esCloudPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esCloudPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esCloudPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esCloudPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esCloudPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esCloudPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esCloudPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esCloudPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esCloudPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esCloudPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esCloudPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esCloudPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esCloudPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esCloudPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esCloudPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esCloudPlayer[admin].g_iCloudAbility = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esCloudPlayer[admin].g_iCloudAbility, value, 0, 1);
		g_esCloudPlayer[admin].g_iCloudMessage = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esCloudPlayer[admin].g_iCloudMessage, value, 0, 1);
		g_esCloudPlayer[admin].g_flCloudChance = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudChance", "Cloud Chance", "Cloud_Chance", "chance", g_esCloudPlayer[admin].g_flCloudChance, value, 0.0, 100.0);
		g_esCloudPlayer[admin].g_iCloudCooldown = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudCooldown", "Cloud Cooldown", "Cloud_Cooldown", "cooldown", g_esCloudPlayer[admin].g_iCloudCooldown, value, 0, 99999);
		g_esCloudPlayer[admin].g_flCloudDamage = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudDamage", "Cloud Damage", "Cloud_Damage", "damage", g_esCloudPlayer[admin].g_flCloudDamage, value, 0.0, 99999.0);
		g_esCloudPlayer[admin].g_iCloudDuration = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudDuration", "Cloud Duration", "Cloud_Duration", "duration", g_esCloudPlayer[admin].g_iCloudDuration, value, 0, 99999);
		g_esCloudPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esCloudPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esCloudAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esCloudAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esCloudAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esCloudAbility[type].g_iComboAbility, value, 0, 1);
		g_esCloudAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esCloudAbility[type].g_iHumanAbility, value, 0, 2);
		g_esCloudAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esCloudAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esCloudAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esCloudAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esCloudAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esCloudAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esCloudAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esCloudAbility[type].g_iHumanMode, value, 0, 1);
		g_esCloudAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esCloudAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esCloudAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esCloudAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esCloudAbility[type].g_iCloudAbility = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esCloudAbility[type].g_iCloudAbility, value, 0, 1);
		g_esCloudAbility[type].g_iCloudMessage = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esCloudAbility[type].g_iCloudMessage, value, 0, 1);
		g_esCloudAbility[type].g_flCloudChance = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudChance", "Cloud Chance", "Cloud_Chance", "chance", g_esCloudAbility[type].g_flCloudChance, value, 0.0, 100.0);
		g_esCloudAbility[type].g_iCloudCooldown = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudCooldown", "Cloud Cooldown", "Cloud_Cooldown", "cooldown", g_esCloudAbility[type].g_iCloudCooldown, value, 0, 99999);
		g_esCloudAbility[type].g_flCloudDamage = flGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudDamage", "Cloud Damage", "Cloud_Damage", "damage", g_esCloudAbility[type].g_flCloudDamage, value, 0.0, 99999.0);
		g_esCloudAbility[type].g_iCloudDuration = iGetKeyValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "CloudDuration", "Cloud Duration", "Cloud_Duration", "duration", g_esCloudAbility[type].g_iCloudDuration, value, 0, 99999);
		g_esCloudAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esCloudAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_CLOUD_SECTION, MT_CLOUD_SECTION2, MT_CLOUD_SECTION3, MT_CLOUD_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esCloudCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_flCloseAreasOnly, g_esCloudAbility[type].g_flCloseAreasOnly);
	g_esCloudCache[tank].g_flCloudChance = flGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_flCloudChance, g_esCloudAbility[type].g_flCloudChance);
	g_esCloudCache[tank].g_flCloudDamage = flGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_flCloudDamage, g_esCloudAbility[type].g_flCloudDamage);
	g_esCloudCache[tank].g_iCloudAbility = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iCloudAbility, g_esCloudAbility[type].g_iCloudAbility);
	g_esCloudCache[tank].g_iCloudCooldown = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iCloudCooldown, g_esCloudAbility[type].g_iCloudCooldown);
	g_esCloudCache[tank].g_iCloudDuration = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iCloudDuration, g_esCloudAbility[type].g_iCloudDuration);
	g_esCloudCache[tank].g_iCloudMessage = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iCloudMessage, g_esCloudAbility[type].g_iCloudMessage);
	g_esCloudCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iComboAbility, g_esCloudAbility[type].g_iComboAbility);
	g_esCloudCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iHumanAbility, g_esCloudAbility[type].g_iHumanAbility);
	g_esCloudCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iHumanAmmo, g_esCloudAbility[type].g_iHumanAmmo);
	g_esCloudCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iHumanCooldown, g_esCloudAbility[type].g_iHumanCooldown);
	g_esCloudCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iHumanDuration, g_esCloudAbility[type].g_iHumanDuration);
	g_esCloudCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iHumanMode, g_esCloudAbility[type].g_iHumanMode);
	g_esCloudCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_flOpenAreasOnly, g_esCloudAbility[type].g_flOpenAreasOnly);
	g_esCloudCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esCloudPlayer[tank].g_iRequiresHumans, g_esCloudAbility[type].g_iRequiresHumans);
	g_esCloudPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vCloudCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vCloudCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveCloud(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vCloudEventFired(Event event, const char[] name)
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
			vCloudCopyStats2(iBot, iTank);
			vRemoveCloud(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vCloudCopyStats2(iTank, iBot);
			vRemoveCloud(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveCloud(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vCloudReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iAccessFlags, g_esCloudPlayer[tank].g_iAccessFlags)) || g_esCloudCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esCloudCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esCloudCache[tank].g_iCloudAbility == 1 && g_esCloudCache[tank].g_iComboAbility == 0 && !g_esCloudPlayer[tank].g_bActivated)
	{
		vCloudAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esCloudCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esCloudCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esCloudPlayer[tank].g_iTankType) || (g_esCloudCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esCloudCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iAccessFlags, g_esCloudPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esCloudCache[tank].g_iCloudAbility == 1 && g_esCloudCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esCloudPlayer[tank].g_iCooldown != -1 && g_esCloudPlayer[tank].g_iCooldown > iTime;

			switch (g_esCloudCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esCloudPlayer[tank].g_bActivated && !bRecharging)
					{
						vCloudAbility(tank);
					}
					else if (g_esCloudPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman4", (g_esCloudPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esCloudPlayer[tank].g_iAmmoCount < g_esCloudCache[tank].g_iHumanAmmo && g_esCloudCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esCloudPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esCloudPlayer[tank].g_bActivated = true;
							g_esCloudPlayer[tank].g_iAmmoCount++;

							vCloud2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman", g_esCloudPlayer[tank].g_iAmmoCount, g_esCloudCache[tank].g_iHumanAmmo);
						}
						else if (g_esCloudPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman4", (g_esCloudPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esCloudCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esCloudCache[tank].g_iHumanMode == 1 && g_esCloudPlayer[tank].g_bActivated && (g_esCloudPlayer[tank].g_iCooldown == -1 || g_esCloudPlayer[tank].g_iCooldown < GetTime()))
		{
			vCloudReset2(tank);
			vCloudReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vCloudChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveCloud(tank);
}

void vCloud(int tank, int pos = -1)
{
	if (g_esCloudPlayer[tank].g_iCooldown != -1 && g_esCloudPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esCloudPlayer[tank].g_bActivated = true;

	vCloud2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloudCache[tank].g_iHumanAbility == 1)
	{
		g_esCloudPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman", g_esCloudPlayer[tank].g_iAmmoCount, g_esCloudCache[tank].g_iHumanAmmo);
	}

	if (g_esCloudCache[tank].g_iCloudMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Cloud", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Cloud", LANG_SERVER, sTankName);
	}
}

void vCloud2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esCloudCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esCloudCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esCloudPlayer[tank].g_iTankType) || (g_esCloudCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esCloudCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iAccessFlags, g_esCloudPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	DataPack dpCloud;
	CreateDataTimer(1.5, tTimerCloud, dpCloud, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpCloud.WriteCell(GetClientUserId(tank));
	dpCloud.WriteCell(g_esCloudPlayer[tank].g_iTankType);
	dpCloud.WriteCell(GetTime());
	dpCloud.WriteCell(pos);
}

void vCloudAbility(int tank)
{
	if ((g_esCloudPlayer[tank].g_iCooldown != -1 && g_esCloudPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esCloudCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esCloudCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esCloudPlayer[tank].g_iTankType) || (g_esCloudCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esCloudCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iAccessFlags, g_esCloudPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esCloudPlayer[tank].g_iAmmoCount < g_esCloudCache[tank].g_iHumanAmmo && g_esCloudCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esCloudCache[tank].g_flCloudChance)
		{
			vCloud(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloudCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloudCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudAmmo");
	}
}

void vCloudCopyStats2(int oldTank, int newTank)
{
	g_esCloudPlayer[newTank].g_iAmmoCount = g_esCloudPlayer[oldTank].g_iAmmoCount;
	g_esCloudPlayer[newTank].g_iCooldown = g_esCloudPlayer[oldTank].g_iCooldown;
}

void vRemoveCloud(int tank)
{
	g_esCloudPlayer[tank].g_bActivated = false;
	g_esCloudPlayer[tank].g_iAmmoCount = 0;
	g_esCloudPlayer[tank].g_iCooldown = -1;
}

void vCloudReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveCloud(iPlayer);
		}
	}
}

void vCloudReset2(int tank)
{
	g_esCloudPlayer[tank].g_bActivated = false;

	if (g_esCloudCache[tank].g_iCloudMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Cloud2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Cloud2", LANG_SERVER, sTankName);
	}
}

void vCloudReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esCloudAbility[g_esCloudPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esCloudCache[tank].g_iCloudCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esCloudCache[tank].g_iHumanAbility == 1 && g_esCloudCache[tank].g_iHumanMode == 0 && g_esCloudPlayer[tank].g_iAmmoCount < g_esCloudCache[tank].g_iHumanAmmo && g_esCloudCache[tank].g_iHumanAmmo > 0) ? g_esCloudCache[tank].g_iHumanCooldown : iCooldown;
	g_esCloudPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esCloudPlayer[tank].g_iCooldown != -1 && g_esCloudPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "CloudHuman5", (g_esCloudPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerCloud(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esCloudAbility[g_esCloudPlayer[iTank].g_iTankType].g_iAccessFlags, g_esCloudPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esCloudPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esCloudPlayer[iTank].g_iTankType || !g_esCloudPlayer[iTank].g_bActivated)
	{
		g_esCloudPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	if (g_esCloudCache[iTank].g_iCloudAbility == 0 || bIsAreaNarrow(iTank, g_esCloudCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esCloudCache[iTank].g_flCloseAreasOnly))
	{
		vCloudReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esCloudCache[iTank].g_iCloudDuration;
	iDuration = (bHuman && g_esCloudCache[iTank].g_iHumanAbility == 1) ? g_esCloudCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esCloudCache[iTank].g_iHumanAbility == 1 && g_esCloudCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esCloudPlayer[iTank].g_iCooldown == -1 || g_esCloudPlayer[iTank].g_iCooldown < iCurrentTime))
	{
		vCloudReset2(iTank);
		vCloudReset3(iTank);

		return Plugin_Stop;
	}

	vAttachParticle(iTank, PARTICLE_SMOKE, 1.5);

	float flTankPos[3], flSurvivorPos[3];
	GetClientAbsOrigin(iTank, flTankPos);
	float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esCloudCache[iTank].g_flCloudDamage;
	if (flDamage > 0.0)
	{
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, iTank) && !bIsAdminImmune(iSurvivor, g_esCloudPlayer[iTank].g_iTankType, g_esCloudAbility[g_esCloudPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esCloudPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= 200.0)
				{
					vDamagePlayer(iSurvivor, iTank, MT_GetScaledDamage(flDamage), "65536");
				}
			}
		}
	}

	return Plugin_Continue;
}

Action tTimerCloudCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esCloudAbility[g_esCloudPlayer[iTank].g_iTankType].g_iAccessFlags, g_esCloudPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esCloudPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esCloudCache[iTank].g_iCloudAbility == 0 || g_esCloudPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vCloud(iTank, iPos);

	return Plugin_Continue;
}