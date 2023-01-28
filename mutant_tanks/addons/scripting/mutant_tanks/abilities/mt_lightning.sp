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

#define MT_LIGHTNING_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_LIGHTNING_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Lightning Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank creates lightning storms.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bSecondGame;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch (GetEngineVersion())
	{
		case Engine_Left4Dead: g_bSecondGame = false;
		case Engine_Left4Dead2: g_bSecondGame = true;
		default:
		{
			strcopy(error, err_max, "\"[MT] Lightning Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_LIGHTNING_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define PARTICLE_LIGHTNING "storm_lightning_01"

#define SPRITE_EXPLODE "sprites/zerogxplode.spr"

#define MT_LIGHTNING_SECTION "lightningability"
#define MT_LIGHTNING_SECTION2 "lightning ability"
#define MT_LIGHTNING_SECTION3 "lightning_ability"
#define MT_LIGHTNING_SECTION4 "lightning"

#define MT_MENU_LIGHTNING "Lightning Ability"

char g_sLightningSounds[8][26] =
{
	"ambient/energy/zap1.wav",
	"ambient/energy/zap2.wav",
	"ambient/energy/zap3.wav",
	"ambient/energy/zap5.wav",
	"ambient/energy/zap6.wav",
	"ambient/energy/zap7.wav",
	"ambient/energy/zap8.wav",
	"ambient/energy/zap9.wav"
};

enum struct esLightningPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flLightningChance;
	float g_flLightningDamage;
	float g_flLightningInterval;
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
	int g_iLightningAbility;
	int g_iLightningCooldown;
	int g_iLightningDuration;
	int g_iLightningMessage;
	int g_iRequiresHumans;
	int g_iTankType;
}

esLightningPlayer g_esLightningPlayer[MAXPLAYERS + 1];

enum struct esLightningAbility
{
	float g_flCloseAreasOnly;
	float g_flLightningChance;
	float g_flLightningDamage;
	float g_flLightningInterval;
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
	int g_iLightningAbility;
	int g_iLightningCooldown;
	int g_iLightningDuration;
	int g_iLightningMessage;
	int g_iRequiresHumans;
}

esLightningAbility g_esLightningAbility[MT_MAXTYPES + 1];

enum struct esLightningCache
{
	float g_flCloseAreasOnly;
	float g_flLightningChance;
	float g_flLightningDamage;
	float g_flLightningInterval;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iLightningAbility;
	int g_iLightningCooldown;
	int g_iLightningDuration;
	int g_iLightningMessage;
	int g_iRequiresHumans;
}

esLightningCache g_esLightningCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_lightning", cmdLightningInfo, "View information about the Lightning ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vLightningMapStart()
#else
public void OnMapStart()
#endif
{
	if (g_bSecondGame)
	{
		PrecacheModel(SPRITE_EXPLODE, true);
		iPrecacheParticle(PARTICLE_LIGHTNING);

		for (int iPos = 0; iPos < (sizeof g_sLightningSounds); iPos++)
		{
			PrecacheSound(g_sLightningSounds[iPos], true);
		}
	}

	vLightningReset();
}

#if defined MT_ABILITIES_MAIN
void vLightningClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveLightning(client);
}

#if defined MT_ABILITIES_MAIN
void vLightningClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveLightning(client);
}

#if defined MT_ABILITIES_MAIN
void vLightningMapEnd()
#else
public void OnMapEnd()
#endif
{
	vLightningReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdLightningInfo(int client, int args)
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
		case false: vLightningMenu(client, MT_LIGHTNING_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vLightningMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_LIGHTNING_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iLightningMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Lightning Ability Information");
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

int iLightningMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLightningCache[param1].g_iLightningAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esLightningCache[param1].g_iHumanAmmo - g_esLightningPlayer[param1].g_iAmmoCount), g_esLightningCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLightningCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esLightningCache[param1].g_iHumanAbility == 1) ? g_esLightningCache[param1].g_iHumanCooldown : g_esLightningCache[param1].g_iLightningCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "LightningDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esLightningCache[param1].g_iHumanAbility == 1) ? g_esLightningCache[param1].g_iHumanDuration : g_esLightningCache[param1].g_iLightningDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLightningCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vLightningMenu(param1, MT_LIGHTNING_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pLightning = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "LightningMenu", param1);
			pLightning.SetTitle(sMenuTitle);
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
void vLightningDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_LIGHTNING, MT_MENU_LIGHTNING);
}

#if defined MT_ABILITIES_MAIN
void vLightningMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_LIGHTNING, false))
	{
		vLightningMenu(client, MT_LIGHTNING_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_LIGHTNING, false))
	{
		FormatEx(buffer, size, "%T", "LightningMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_LIGHTNING);
}

#if defined MT_ABILITIES_MAIN
void vLightningAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_LIGHTNING_SECTION);
	list2.PushString(MT_LIGHTNING_SECTION2);
	list3.PushString(MT_LIGHTNING_SECTION3);
	list4.PushString(MT_LIGHTNING_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vLightningCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (!g_bSecondGame || (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLightningCache[tank].g_iHumanAbility != 2))
	{
		g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_LIGHTNING_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_LIGHTNING_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_LIGHTNING_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_LIGHTNING_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esLightningCache[tank].g_iLightningAbility == 1 && g_esLightningCache[tank].g_iComboAbility == 1 && !g_esLightningPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_LIGHTNING_SECTION, false) || StrEqual(sSubset[iPos], MT_LIGHTNING_SECTION2, false) || StrEqual(sSubset[iPos], MT_LIGHTNING_SECTION3, false) || StrEqual(sSubset[iPos], MT_LIGHTNING_SECTION4, false))
				{
					g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vLightning(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerLightningCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vLightningConfigsLoad(int mode)
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
				g_esLightningAbility[iIndex].g_iAccessFlags = 0;
				g_esLightningAbility[iIndex].g_iImmunityFlags = 0;
				g_esLightningAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esLightningAbility[iIndex].g_iComboAbility = 0;
				g_esLightningAbility[iIndex].g_iComboPosition = -1;
				g_esLightningAbility[iIndex].g_iHumanAbility = 0;
				g_esLightningAbility[iIndex].g_iHumanAmmo = 5;
				g_esLightningAbility[iIndex].g_iHumanCooldown = 0;
				g_esLightningAbility[iIndex].g_iHumanDuration = 5;
				g_esLightningAbility[iIndex].g_iHumanMode = 1;
				g_esLightningAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esLightningAbility[iIndex].g_iRequiresHumans = 0;
				g_esLightningAbility[iIndex].g_iLightningAbility = 0;
				g_esLightningAbility[iIndex].g_iLightningMessage = 0;
				g_esLightningAbility[iIndex].g_flLightningChance = 33.3;
				g_esLightningAbility[iIndex].g_iLightningCooldown = 0;
				g_esLightningAbility[iIndex].g_flLightningDamage = 5.0;
				g_esLightningAbility[iIndex].g_iLightningDuration = 5;
				g_esLightningAbility[iIndex].g_flLightningInterval = 1.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esLightningPlayer[iPlayer].g_iAccessFlags = 0;
					g_esLightningPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esLightningPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esLightningPlayer[iPlayer].g_iComboAbility = 0;
					g_esLightningPlayer[iPlayer].g_iHumanAbility = 0;
					g_esLightningPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esLightningPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esLightningPlayer[iPlayer].g_iHumanDuration = 0;
					g_esLightningPlayer[iPlayer].g_iHumanMode = 0;
					g_esLightningPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esLightningPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esLightningPlayer[iPlayer].g_iLightningAbility = 0;
					g_esLightningPlayer[iPlayer].g_iLightningMessage = 0;
					g_esLightningPlayer[iPlayer].g_flLightningChance = 0.0;
					g_esLightningPlayer[iPlayer].g_iLightningCooldown = 0;
					g_esLightningPlayer[iPlayer].g_flLightningDamage = 0.0;
					g_esLightningPlayer[iPlayer].g_iLightningDuration = 0;
					g_esLightningPlayer[iPlayer].g_flLightningInterval = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esLightningPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLightningPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLightningPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLightningPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esLightningPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLightningPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esLightningPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLightningPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esLightningPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLightningPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esLightningPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esLightningPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esLightningPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esLightningPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esLightningPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLightningPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLightningPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLightningPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esLightningPlayer[admin].g_iLightningAbility = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLightningPlayer[admin].g_iLightningAbility, value, 0, 1);
		g_esLightningPlayer[admin].g_iLightningMessage = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLightningPlayer[admin].g_iLightningMessage, value, 0, 1);
		g_esLightningPlayer[admin].g_flLightningChance = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningChance", "Lightning Chance", "Lightning_Chance", "chance", g_esLightningPlayer[admin].g_flLightningChance, value, 0.0, 100.0);
		g_esLightningPlayer[admin].g_iLightningCooldown = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningCooldown", "Lightning Cooldown", "Lightning_Cooldown", "cooldown", g_esLightningPlayer[admin].g_iLightningCooldown, value, 0, 99999);
		g_esLightningPlayer[admin].g_flLightningDamage = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningDamage", "Lightning Damage", "Lightning_Damage", "damage", g_esLightningPlayer[admin].g_flLightningDamage, value, 0.0, 99999.0);
		g_esLightningPlayer[admin].g_iLightningDuration = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningDuration", "Lightning Duration", "Lightning_Duration", "duration", g_esLightningPlayer[admin].g_iLightningDuration, value, 0, 99999);
		g_esLightningPlayer[admin].g_flLightningInterval = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningInterval", "Lightning Interval", "Lightning_Interval", "interval", g_esLightningPlayer[admin].g_flLightningInterval, value, 0.1, 99999.0);
		g_esLightningPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLightningPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esLightningAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLightningAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLightningAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLightningAbility[type].g_iComboAbility, value, 0, 1);
		g_esLightningAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLightningAbility[type].g_iHumanAbility, value, 0, 2);
		g_esLightningAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLightningAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esLightningAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLightningAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esLightningAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esLightningAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esLightningAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esLightningAbility[type].g_iHumanMode, value, 0, 1);
		g_esLightningAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLightningAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLightningAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLightningAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esLightningAbility[type].g_iLightningAbility = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLightningAbility[type].g_iLightningAbility, value, 0, 1);
		g_esLightningAbility[type].g_iLightningMessage = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLightningAbility[type].g_iLightningMessage, value, 0, 1);
		g_esLightningAbility[type].g_flLightningChance = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningChance", "Lightning Chance", "Lightning_Chance", "chance", g_esLightningAbility[type].g_flLightningChance, value, 0.0, 100.0);
		g_esLightningAbility[type].g_iLightningCooldown = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningCooldown", "Lightning Cooldown", "Lightning_Cooldown", "cooldown", g_esLightningAbility[type].g_iLightningCooldown, value, 0, 99999);
		g_esLightningAbility[type].g_flLightningDamage = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningDamage", "Lightning Damage", "Lightning_Damage", "damage", g_esLightningAbility[type].g_flLightningDamage, value, 0.0, 99999.0);
		g_esLightningAbility[type].g_iLightningDuration = iGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningDuration", "Lightning Duration", "Lightning_Duration", "duration", g_esLightningAbility[type].g_iLightningDuration, value, 0, 99999);
		g_esLightningAbility[type].g_flLightningInterval = flGetKeyValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "LightningInterval", "Lightning Interval", "Lightning_Interval", "interval", g_esLightningAbility[type].g_flLightningInterval, value, 0.1, 99999.0);
		g_esLightningAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLightningAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LIGHTNING_SECTION, MT_LIGHTNING_SECTION2, MT_LIGHTNING_SECTION3, MT_LIGHTNING_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esLightningCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_flCloseAreasOnly, g_esLightningAbility[type].g_flCloseAreasOnly);
	g_esLightningCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iComboAbility, g_esLightningAbility[type].g_iComboAbility);
	g_esLightningCache[tank].g_flLightningChance = flGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_flLightningChance, g_esLightningAbility[type].g_flLightningChance);
	g_esLightningCache[tank].g_flLightningDamage = flGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_flLightningDamage, g_esLightningAbility[type].g_flLightningDamage);
	g_esLightningCache[tank].g_flLightningInterval = flGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_flLightningInterval, g_esLightningAbility[type].g_flLightningInterval);
	g_esLightningCache[tank].g_iLightningAbility = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iLightningAbility, g_esLightningAbility[type].g_iLightningAbility);
	g_esLightningCache[tank].g_iLightningCooldown = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iLightningCooldown, g_esLightningAbility[type].g_iLightningCooldown);
	g_esLightningCache[tank].g_iLightningDuration = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iLightningDuration, g_esLightningAbility[type].g_iLightningDuration);
	g_esLightningCache[tank].g_iLightningMessage = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iLightningMessage, g_esLightningAbility[type].g_iLightningMessage);
	g_esLightningCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iHumanAbility, g_esLightningAbility[type].g_iHumanAbility);
	g_esLightningCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iHumanAmmo, g_esLightningAbility[type].g_iHumanAmmo);
	g_esLightningCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iHumanCooldown, g_esLightningAbility[type].g_iHumanCooldown);
	g_esLightningCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iHumanDuration, g_esLightningAbility[type].g_iHumanDuration);
	g_esLightningCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iHumanMode, g_esLightningAbility[type].g_iHumanMode);
	g_esLightningCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_flOpenAreasOnly, g_esLightningAbility[type].g_flOpenAreasOnly);
	g_esLightningCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esLightningPlayer[tank].g_iRequiresHumans, g_esLightningAbility[type].g_iRequiresHumans);
	g_esLightningPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vLightningCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vLightningCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveLightning(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vLightningEventFired(Event event, const char[] name)
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
			vLightningCopyStats2(iBot, iTank);
			vRemoveLightning(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vLightningCopyStats2(iTank, iBot);
			vRemoveLightning(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveLightning(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vLightningReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (!g_bSecondGame || (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iAccessFlags, g_esLightningPlayer[tank].g_iAccessFlags)) || g_esLightningCache[tank].g_iHumanAbility == 0)))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esLightningCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esLightningCache[tank].g_iLightningAbility == 1 && g_esLightningCache[tank].g_iComboAbility == 0 && !g_esLightningPlayer[tank].g_bActivated)
	{
		vLightningAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (!g_bSecondGame || bIsAreaNarrow(tank, g_esLightningCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLightningCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLightningPlayer[tank].g_iTankType) || (g_esLightningCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLightningCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iAccessFlags, g_esLightningPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esLightningCache[tank].g_iLightningAbility == 1 && g_esLightningCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esLightningPlayer[tank].g_iCooldown != -1 && g_esLightningPlayer[tank].g_iCooldown > iTime;

			switch (g_esLightningCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esLightningPlayer[tank].g_bActivated && !bRecharging)
					{
						vLightningAbility(tank);
					}
					else if (g_esLightningPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman4", (g_esLightningPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esLightningPlayer[tank].g_iAmmoCount < g_esLightningCache[tank].g_iHumanAmmo && g_esLightningCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esLightningPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esLightningPlayer[tank].g_bActivated = true;
							g_esLightningPlayer[tank].g_iAmmoCount++;

							vLightning2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman", g_esLightningPlayer[tank].g_iAmmoCount, g_esLightningCache[tank].g_iHumanAmmo);
						}
						else if (g_esLightningPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman4", (g_esLightningPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esLightningCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esLightningCache[tank].g_iHumanMode == 1 && g_esLightningPlayer[tank].g_bActivated && (g_esLightningPlayer[tank].g_iCooldown == -1 || g_esLightningPlayer[tank].g_iCooldown < GetTime()))
		{
			vLightningReset2(tank);
			vLightningReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLightningChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveLightning(tank);
}

void vLightning(int tank, int pos = -1)
{
	if (g_esLightningPlayer[tank].g_iCooldown != -1 && g_esLightningPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esLightningPlayer[tank].g_bActivated = true;

	vLightning2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLightningCache[tank].g_iHumanAbility == 1)
	{
		g_esLightningPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman", g_esLightningPlayer[tank].g_iAmmoCount, g_esLightningCache[tank].g_iHumanAmmo);
	}

	if (g_esLightningCache[tank].g_iLightningMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Lightning", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Lightning", LANG_SERVER, sTankName);
	}
}

void vLightning2(int tank, int pos = -1)
{
	if (!g_bSecondGame || bIsAreaNarrow(tank, g_esLightningCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLightningCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLightningPlayer[tank].g_iTankType) || (g_esLightningCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLightningCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iAccessFlags, g_esLightningPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esLightningCache[tank].g_flLightningInterval;
	DataPack dpLightning;
	CreateDataTimer(flInterval, tTimerLightning, dpLightning, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpLightning.WriteCell(GetClientUserId(tank));
	dpLightning.WriteCell(g_esLightningPlayer[tank].g_iTankType);
	dpLightning.WriteCell(GetTime());
	dpLightning.WriteCell(pos);
}

void vLightningAbility(int tank)
{
	if (!g_bSecondGame || (g_esLightningPlayer[tank].g_iCooldown != -1 && g_esLightningPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esLightningCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLightningCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLightningPlayer[tank].g_iTankType) || (g_esLightningCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLightningCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iAccessFlags, g_esLightningPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esLightningPlayer[tank].g_iAmmoCount < g_esLightningCache[tank].g_iHumanAmmo && g_esLightningCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esLightningCache[tank].g_flLightningChance)
		{
			vLightning(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLightningCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLightningCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningAmmo");
	}
}

void vLightningCopyStats2(int oldTank, int newTank)
{
	g_esLightningPlayer[newTank].g_iAmmoCount = g_esLightningPlayer[oldTank].g_iAmmoCount;
	g_esLightningPlayer[newTank].g_iCooldown = g_esLightningPlayer[oldTank].g_iCooldown;
}

void vRemoveLightning(int tank)
{
	g_esLightningPlayer[tank].g_bActivated = false;
	g_esLightningPlayer[tank].g_iAmmoCount = 0;
	g_esLightningPlayer[tank].g_iCooldown = -1;
}

void vLightningReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveLightning(iPlayer);
		}
	}
}

void vLightningReset2(int tank)
{
	g_esLightningPlayer[tank].g_bActivated = false;

	if (g_esLightningCache[tank].g_iLightningMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Lightning2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Lightning2", LANG_SERVER, sTankName);
	}
}

void vLightningReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esLightningAbility[g_esLightningPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esLightningCache[tank].g_iLightningCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLightningCache[tank].g_iHumanAbility == 1 && g_esLightningCache[tank].g_iHumanMode == 0 && g_esLightningPlayer[tank].g_iAmmoCount < g_esLightningCache[tank].g_iHumanAmmo && g_esLightningCache[tank].g_iHumanAmmo > 0) ? g_esLightningCache[tank].g_iHumanCooldown : iCooldown;
	g_esLightningPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esLightningPlayer[tank].g_iCooldown != -1 && g_esLightningPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LightningHuman5", (g_esLightningPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerLightningCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!g_bSecondGame || !MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLightningAbility[g_esLightningPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLightningPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLightningPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esLightningCache[iTank].g_iLightningAbility == 0 || g_esLightningPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vLightning(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerLightning(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!g_bSecondGame || !MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLightningAbility[g_esLightningPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLightningPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLightningPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esLightningPlayer[iTank].g_iTankType || !g_esLightningPlayer[iTank].g_bActivated)
	{
		g_esLightningPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	if (g_esLightningCache[iTank].g_iLightningAbility == 0 || bIsAreaNarrow(iTank, g_esLightningCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esLightningCache[iTank].g_flCloseAreasOnly))
	{
		vLightningReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esLightningCache[iTank].g_iLightningDuration;
	iDuration = (bHuman && g_esLightningCache[iTank].g_iHumanAbility == 1) ? g_esLightningCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esLightningCache[iTank].g_iHumanAbility == 1 && g_esLightningCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime)
	{
		vLightningReset2(iTank);
		vLightningReset3(iTank);

		return Plugin_Stop;
	}

	char sTargetName[64];
	float flOrigin[3];
	GetClientAbsOrigin(iTank, flOrigin);
	float flRadius = MT_GetRandomFloat(100.0, 360.0),
		flRadius2 = MT_GetRandomFloat(0.0, 360.0);
	flOrigin[0] += (flRadius * Cosine(DegToRad(flRadius2)));
	flOrigin[1] += (flRadius * Sine(DegToRad(flRadius2)));

	int iTarget = CreateEntityByName("info_particle_target");
	if (bIsValidEntity(iTarget))
	{
		Format(sTargetName, sizeof sTargetName, "mutant_tank_target_%i_%i", iTank, g_esLightningPlayer[iTank].g_iTankType);
		DispatchKeyValue(iTarget, "targetname", sTargetName);
		TeleportEntity(iTarget, flOrigin);
		DispatchSpawn(iTarget);
		ActivateEntity(iTarget);
		SetVariantString("OnUser2 !self:Kill::2.0:1");
		AcceptEntityInput(iTarget, "AddOutput");
		AcceptEntityInput(iTarget, "FireUser2");
	}

	float flSurvivorPos[3], flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esLightningCache[iTank].g_flLightningDamage;
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, iTank) && !bIsAdminImmune(iSurvivor, g_esLightningPlayer[iTank].g_iTankType, g_esLightningAbility[g_esLightningPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esLightningPlayer[iSurvivor].g_iImmunityFlags))
		{
			GetClientAbsOrigin(iSurvivor, flSurvivorPos);
			if (GetVectorDistance(flOrigin, flSurvivorPos) <= 200.0)
			{
				if (flDamage > 0.0)
				{
					vDamagePlayer(iSurvivor, iTank, MT_GetScaledDamage(flDamage), "1024");
				}

				EmitSoundToAll(g_sLightningSounds[MT_GetRandomInt(0, (sizeof g_sLightningSounds - 1))], iSurvivor);
			}
		}
	}

	flOrigin[2] += 1800.0;

	int iLightning = CreateEntityByName("info_particle_system");
	if (bIsValidEntity(iLightning))
	{
		DispatchKeyValue(iLightning, "effect_name", PARTICLE_LIGHTNING);
		DispatchKeyValue(iLightning, "cpoint1", sTargetName);

		TeleportEntity(iLightning, flOrigin);
		DispatchSpawn(iLightning);
		ActivateEntity(iLightning);
		AcceptEntityInput(iLightning, "Start");

		iLightning = EntIndexToEntRef(iLightning);
		vDeleteEntity(iLightning, 2.0);
	}

	return Plugin_Continue;
}