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

#define MT_ZOMBIE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_ZOMBIE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Zombie Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank spawns zombies.",
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
			strcopy(error, err_max, "\"[MT] Zombie Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_ZOMBIE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MODEL_CEDA "models/infected/common_male_ceda.mdl"
#define MODEL_CLOWN "models/infected/common_male_clown.mdl"
#define MODEL_FALLEN "models/infected/common_male_fallen_survivor.mdl"
#define MODEL_JIMMY "models/infected/common_male_jimmy.mdl"
#define MODEL_MUDMAN "models/infected/common_male_mud.mdl"
#define MODEL_RIOTCOP "models/infected/common_male_riot.mdl"
#define MODEL_ROADCREW "models/infected/common_male_roadcrew.mdl"

#define MT_ZOMBIE_SECTION "zombieability"
#define MT_ZOMBIE_SECTION2 "zombie ability"
#define MT_ZOMBIE_SECTION3 "zombie_ability"
#define MT_ZOMBIE_SECTION4 "zombie"

#define MT_MENU_ZOMBIE "Zombie Ability"

enum struct esZombiePlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flZombieChance;
	float g_flZombieInterval;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iZombieAbility;
	int g_iZombieAmount;
	int g_iZombieCooldown;
	int g_iZombieDuration;
	int g_iZombieMessage;
	int g_iZombieMode;
	int g_iZombieType;
}

esZombiePlayer g_esZombiePlayer[MAXPLAYERS + 1];

enum struct esZombieAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flZombieChance;
	float g_flZombieInterval;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iZombieAbility;
	int g_iZombieAmount;
	int g_iZombieCooldown;
	int g_iZombieDuration;
	int g_iZombieMessage;
	int g_iZombieMode;
	int g_iZombieType;
}

esZombieAbility g_esZombieAbility[MT_MAXTYPES + 1];

enum struct esZombieCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flZombieChance;
	float g_flZombieInterval;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iZombieAbility;
	int g_iZombieAmount;
	int g_iZombieCooldown;
	int g_iZombieDuration;
	int g_iZombieMessage;
	int g_iZombieMode;
	int g_iZombieType;
}

esZombieCache g_esZombieCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_zombie", cmdZombieInfo, "View information about the Zombie ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vZombieMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheModel(MODEL_CEDA, true);
	PrecacheModel(MODEL_CLOWN, true);
	PrecacheModel(MODEL_FALLEN, true);
	PrecacheModel(MODEL_JIMMY, true);
	PrecacheModel(MODEL_MUDMAN, true);
	PrecacheModel(MODEL_RIOTCOP, true);
	PrecacheModel(MODEL_ROADCREW, true);

	vZombieReset();
}

#if defined MT_ABILITIES_MAIN2
void vZombieClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveZombie(client);
}

#if defined MT_ABILITIES_MAIN2
void vZombieClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveZombie(client);
}

#if defined MT_ABILITIES_MAIN2
void vZombieMapEnd()
#else
public void OnMapEnd()
#endif
{
	vZombieReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdZombieInfo(int client, int args)
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
		case false: vZombieMenu(client, MT_ZOMBIE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vZombieMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ZOMBIE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iZombieMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Zombie Ability Information");
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

int iZombieMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esZombieCache[param1].g_iZombieAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esZombieCache[param1].g_iHumanAmmo - g_esZombiePlayer[param1].g_iAmmoCount), g_esZombieCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esZombieCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esZombieCache[param1].g_iHumanAbility == 1) ? g_esZombieCache[param1].g_iHumanCooldown : g_esZombieCache[param1].g_iZombieCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "ZombieDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esZombieCache[param1].g_iHumanAbility == 1) ? g_esZombieCache[param1].g_iHumanDuration : g_esZombieCache[param1].g_iZombieDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esZombieCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vZombieMenu(param1, MT_ZOMBIE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pZombie = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "ZombieMenu", param1);
			pZombie.SetTitle(sMenuTitle);
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
void vZombieDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ZOMBIE, MT_MENU_ZOMBIE);
}

#if defined MT_ABILITIES_MAIN2
void vZombieMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ZOMBIE, false))
	{
		vZombieMenu(client, MT_ZOMBIE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ZOMBIE, false))
	{
		FormatEx(buffer, size, "%T", "ZombieMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombiePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ZOMBIE);
}

#if defined MT_ABILITIES_MAIN2
void vZombieAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ZOMBIE_SECTION);
	list2.PushString(MT_ZOMBIE_SECTION2);
	list3.PushString(MT_ZOMBIE_SECTION3);
	list4.PushString(MT_ZOMBIE_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vZombieCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esZombieCache[tank].g_iHumanAbility != 2)
	{
		g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ZOMBIE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ZOMBIE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ZOMBIE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ZOMBIE_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esZombieCache[tank].g_iZombieAbility == 1 && g_esZombieCache[tank].g_iComboAbility == 1 && !g_esZombiePlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_ZOMBIE_SECTION, false) || StrEqual(sSubset[iPos], MT_ZOMBIE_SECTION2, false) || StrEqual(sSubset[iPos], MT_ZOMBIE_SECTION3, false) || StrEqual(sSubset[iPos], MT_ZOMBIE_SECTION4, false))
				{
					g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vZombie(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerZombieCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vZombieConfigsLoad(int mode)
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
				g_esZombieAbility[iIndex].g_iAccessFlags = 0;
				g_esZombieAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esZombieAbility[iIndex].g_iComboAbility = 0;
				g_esZombieAbility[iIndex].g_iComboPosition = -1;
				g_esZombieAbility[iIndex].g_iHumanAbility = 0;
				g_esZombieAbility[iIndex].g_iHumanAmmo = 5;
				g_esZombieAbility[iIndex].g_iHumanCooldown = 0;
				g_esZombieAbility[iIndex].g_iHumanDuration = 5;
				g_esZombieAbility[iIndex].g_iHumanMode = 1;
				g_esZombieAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esZombieAbility[iIndex].g_iRequiresHumans = 0;
				g_esZombieAbility[iIndex].g_iZombieAbility = 0;
				g_esZombieAbility[iIndex].g_iZombieMessage = 0;
				g_esZombieAbility[iIndex].g_iZombieAmount = 10;
				g_esZombieAbility[iIndex].g_flZombieChance = 33.3;
				g_esZombieAbility[iIndex].g_iZombieCooldown = 0;
				g_esZombieAbility[iIndex].g_iZombieDuration = 0;
				g_esZombieAbility[iIndex].g_flZombieInterval = 5.0;
				g_esZombieAbility[iIndex].g_iZombieMode = 0;
				g_esZombieAbility[iIndex].g_iZombieType = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esZombiePlayer[iPlayer].g_iAccessFlags = 0;
					g_esZombiePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esZombiePlayer[iPlayer].g_iComboAbility = 0;
					g_esZombiePlayer[iPlayer].g_iHumanAbility = 0;
					g_esZombiePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esZombiePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esZombiePlayer[iPlayer].g_iHumanDuration = 0;
					g_esZombiePlayer[iPlayer].g_iHumanMode = 0;
					g_esZombiePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esZombiePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esZombiePlayer[iPlayer].g_iZombieAbility = 0;
					g_esZombiePlayer[iPlayer].g_iZombieMessage = 0;
					g_esZombiePlayer[iPlayer].g_iZombieAmount = 0;
					g_esZombiePlayer[iPlayer].g_flZombieChance = 0.0;
					g_esZombiePlayer[iPlayer].g_iZombieCooldown = 0;
					g_esZombiePlayer[iPlayer].g_iZombieDuration = 0;
					g_esZombiePlayer[iPlayer].g_flZombieInterval = 0.0;
					g_esZombiePlayer[iPlayer].g_iZombieMode = 0;
					g_esZombiePlayer[iPlayer].g_iZombieType = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esZombiePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esZombiePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esZombiePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esZombiePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esZombiePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esZombiePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esZombiePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esZombiePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esZombiePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esZombiePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esZombiePlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esZombiePlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esZombiePlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esZombiePlayer[admin].g_iHumanMode, value, 0, 1);
		g_esZombiePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esZombiePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esZombiePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esZombiePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esZombiePlayer[admin].g_iZombieAbility = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esZombiePlayer[admin].g_iZombieAbility, value, 0, 1);
		g_esZombiePlayer[admin].g_iZombieMessage = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esZombiePlayer[admin].g_iZombieMessage, value, 0, 1);
		g_esZombiePlayer[admin].g_iZombieAmount = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieAmount", "Zombie Amount", "Zombie_Amount", "amount", g_esZombiePlayer[admin].g_iZombieAmount, value, 1, 100);
		g_esZombiePlayer[admin].g_flZombieChance = flGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieChance", "Zombie Chance", "Zombie_Chance", "chance", g_esZombiePlayer[admin].g_flZombieChance, value, 0.0, 100.0);
		g_esZombiePlayer[admin].g_iZombieCooldown = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieCooldown", "Zombie Cooldown", "Zombie_Cooldown", "cooldown", g_esZombiePlayer[admin].g_iZombieCooldown, value, 0, 99999);
		g_esZombiePlayer[admin].g_iZombieDuration = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieDuration", "Zombie Duration", "Zombie_Duration", "duration", g_esZombiePlayer[admin].g_iZombieDuration, value, 0, 99999);
		g_esZombiePlayer[admin].g_flZombieInterval = flGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieInterval", "Zombie Interval", "Zombie_Interval", "interval", g_esZombiePlayer[admin].g_flZombieInterval, value, 0.1, 99999.0);
		g_esZombiePlayer[admin].g_iZombieMode = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieMode", "Zombie Mode", "Zombie_Mode", "mode", g_esZombiePlayer[admin].g_iZombieMode, value, 0, 2);
		g_esZombiePlayer[admin].g_iZombieType = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieType", "Zombie Type", "Zombie_Type", "type", g_esZombiePlayer[admin].g_iZombieType, value, 0, 127);
		g_esZombiePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esZombieAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esZombieAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esZombieAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esZombieAbility[type].g_iComboAbility, value, 0, 1);
		g_esZombieAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esZombieAbility[type].g_iHumanAbility, value, 0, 2);
		g_esZombieAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esZombieAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esZombieAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esZombieAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esZombieAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esZombieAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esZombieAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esZombieAbility[type].g_iHumanMode, value, 0, 1);
		g_esZombieAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esZombieAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esZombieAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esZombieAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esZombieAbility[type].g_iZombieAbility = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esZombieAbility[type].g_iZombieAbility, value, 0, 1);
		g_esZombieAbility[type].g_iZombieMessage = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esZombieAbility[type].g_iZombieMessage, value, 0, 1);
		g_esZombieAbility[type].g_iZombieAmount = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieAmount", "Zombie Amount", "Zombie_Amount", "amount", g_esZombieAbility[type].g_iZombieAmount, value, 1, 100);
		g_esZombieAbility[type].g_flZombieChance = flGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieChance", "Zombie Chance", "Zombie_Chance", "chance", g_esZombieAbility[type].g_flZombieChance, value, 0.0, 100.0);
		g_esZombieAbility[type].g_iZombieCooldown = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieCooldown", "Zombie Cooldown", "Zombie_Cooldown", "cooldown", g_esZombieAbility[type].g_iZombieCooldown, value, 0, 99999);
		g_esZombieAbility[type].g_iZombieDuration = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieDuration", "Zombie Duration", "Zombie_Duration", "duration", g_esZombieAbility[type].g_iZombieDuration, value, 0, 99999);
		g_esZombieAbility[type].g_flZombieInterval = flGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieInterval", "Zombie Interval", "Zombie_Interval", "interval", g_esZombieAbility[type].g_flZombieInterval, value, 0.1, 99999.0);
		g_esZombieAbility[type].g_iZombieMode = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieMode", "Zombie Mode", "Zombie_Mode", "mode", g_esZombieAbility[type].g_iZombieMode, value, 0, 2);
		g_esZombieAbility[type].g_iZombieType = iGetKeyValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "ZombieType", "Zombie Type", "Zombie_Type", "type", g_esZombieAbility[type].g_iZombieType, value, 0, 127);
		g_esZombieAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ZOMBIE_SECTION, MT_ZOMBIE_SECTION2, MT_ZOMBIE_SECTION3, MT_ZOMBIE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esZombieCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_flCloseAreasOnly, g_esZombieAbility[type].g_flCloseAreasOnly);
	g_esZombieCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iComboAbility, g_esZombieAbility[type].g_iComboAbility);
	g_esZombieCache[tank].g_flZombieChance = flGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_flZombieChance, g_esZombieAbility[type].g_flZombieChance);
	g_esZombieCache[tank].g_flZombieInterval = flGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_flZombieInterval, g_esZombieAbility[type].g_flZombieInterval);
	g_esZombieCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iHumanAbility, g_esZombieAbility[type].g_iHumanAbility);
	g_esZombieCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iHumanAmmo, g_esZombieAbility[type].g_iHumanAmmo);
	g_esZombieCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iHumanCooldown, g_esZombieAbility[type].g_iHumanCooldown);
	g_esZombieCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iHumanDuration, g_esZombieAbility[type].g_iHumanDuration);
	g_esZombieCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iHumanMode, g_esZombieAbility[type].g_iHumanMode);
	g_esZombieCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_flOpenAreasOnly, g_esZombieAbility[type].g_flOpenAreasOnly);
	g_esZombieCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iRequiresHumans, g_esZombieAbility[type].g_iRequiresHumans);
	g_esZombieCache[tank].g_iZombieAbility = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieAbility, g_esZombieAbility[type].g_iZombieAbility);
	g_esZombieCache[tank].g_iZombieAmount = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieAmount, g_esZombieAbility[type].g_iZombieAmount);
	g_esZombieCache[tank].g_iZombieCooldown = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieCooldown, g_esZombieAbility[type].g_iZombieCooldown);
	g_esZombieCache[tank].g_iZombieDuration = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieDuration, g_esZombieAbility[type].g_iZombieDuration);
	g_esZombieCache[tank].g_iZombieMessage = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieMessage, g_esZombieAbility[type].g_iZombieMessage);
	g_esZombieCache[tank].g_iZombieMode = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieMode, g_esZombieAbility[type].g_iZombieMode);
	g_esZombieCache[tank].g_iZombieType = iGetSettingValue(apply, bHuman, g_esZombiePlayer[tank].g_iZombieType, g_esZombieAbility[type].g_iZombieType);
	g_esZombiePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vZombieCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vZombieCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveZombie(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vZombieEventFired(Event event, const char[] name)
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
			vZombieCopyStats2(iBot, iTank);
			vRemoveZombie(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vZombieCopyStats2(iTank, iBot);
			vRemoveZombie(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vZombieRange(iTank);
			vRemoveZombie(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vZombieReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[tank].g_iAccessFlags)) || g_esZombieCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esZombieCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esZombieCache[tank].g_iZombieAbility == 1 && g_esZombieCache[tank].g_iComboAbility == 0 && !g_esZombiePlayer[tank].g_bActivated)
	{
		vZombieAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esZombieCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esZombieCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esZombiePlayer[tank].g_iTankType) || (g_esZombieCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esZombieCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esZombieCache[tank].g_iZombieAbility == 1 && g_esZombieCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esZombiePlayer[tank].g_iCooldown != -1 && g_esZombiePlayer[tank].g_iCooldown > iTime;

			switch (g_esZombieCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esZombiePlayer[tank].g_bActivated && !bRecharging)
					{
						vZombieAbility(tank);
					}
					else if (g_esZombiePlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman4", (g_esZombiePlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esZombiePlayer[tank].g_iAmmoCount < g_esZombieCache[tank].g_iHumanAmmo && g_esZombieCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esZombiePlayer[tank].g_bActivated && !bRecharging)
						{
							g_esZombiePlayer[tank].g_bActivated = true;
							g_esZombiePlayer[tank].g_iAmmoCount++;

							vZombie2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman", g_esZombiePlayer[tank].g_iAmmoCount, g_esZombieCache[tank].g_iHumanAmmo);
						}
						else if (g_esZombiePlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman4", (g_esZombiePlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esZombieCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esZombieCache[tank].g_iHumanMode == 1 && g_esZombiePlayer[tank].g_bActivated && (g_esZombiePlayer[tank].g_iCooldown == -1 || g_esZombiePlayer[tank].g_iCooldown < GetTime()))
		{
			vZombieReset2(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vZombieChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveZombie(tank);
}

#if defined MT_ABILITIES_MAIN2
void vZombiePostTankSpawn(int tank)
#else
public void MT_OnPostTankSpawn(int tank)
#endif
{
	vZombieRange(tank);
}

void vSpawnUncommon(int tank, const char[] model)
{
	int iInfected = CreateEntityByName("infected");
	if (bIsValidEntity(iInfected))
	{
		SetEntityModel(iInfected, model);
		SetEntProp(iInfected, Prop_Data, "m_nNextThinkTick", (RoundToNearest(GetGameTime() / GetTickInterval()) + 5));
		DispatchSpawn(iInfected);
		ActivateEntity(iInfected);

		float flOrigin[3], flAngles[3];
		GetClientAbsOrigin(tank, flOrigin);
		GetClientEyeAngles(tank, flAngles);

		flOrigin[0] += (50.0 * (Cosine(DegToRad(flAngles[1]))));
		flOrigin[1] += (50.0 * (Sine(DegToRad(flAngles[1]))));
		flOrigin[2] += 5.0;

		TeleportEntity(iInfected, flOrigin);
	}
}

void vSpawnZombie(int tank, bool uncommon)
{
	switch (uncommon)
	{
		case true:
		{
			if (g_bSecondGame)
			{
				int iTypeCount = 0, iTypes[7], iFlag = 0;
				for (int iBit = 0; iBit < (sizeof iTypes); iBit++)
				{
					iFlag = (1 << iBit);
					if (!(g_esZombieCache[tank].g_iZombieType & iFlag))
					{
						continue;
					}

					iTypes[iTypeCount] = iFlag;
					iTypeCount++;
				}

				switch (iTypes[MT_GetRandomInt(0, (iTypeCount - 1))])
				{
					case 1: vSpawnUncommon(tank, MODEL_CEDA);
					case 2: vSpawnUncommon(tank, MODEL_JIMMY);
					case 4: vSpawnUncommon(tank, MODEL_FALLEN);
					case 8: vSpawnUncommon(tank, MODEL_CLOWN);
					case 16: vSpawnUncommon(tank, MODEL_MUDMAN);
					case 32: vSpawnUncommon(tank, MODEL_ROADCREW);
					case 64: vSpawnUncommon(tank, MODEL_RIOTCOP);
					default:
					{
						switch (MT_GetRandomInt(1, (sizeof iTypes)))
						{
							case 1: vSpawnUncommon(tank, MODEL_CEDA);
							case 2: vSpawnUncommon(tank, MODEL_JIMMY);
							case 3: vSpawnUncommon(tank, MODEL_FALLEN);
							case 4: vSpawnUncommon(tank, MODEL_CLOWN);
							case 5: vSpawnUncommon(tank, MODEL_MUDMAN);
							case 6: vSpawnUncommon(tank, MODEL_ROADCREW);
							case 7: vSpawnUncommon(tank, MODEL_RIOTCOP);
						}
					}
				}
			}
			else
			{
				vSpawnZombie(tank, false);
			}
		}
		case false:
		{
			if (bIsValidClient(tank))
			{
				vCheatCommand(tank, g_bSecondGame ? "z_spawn_old" : "z_spawn", "zombie area");
			}
		}
	}
}

void vZombie(int tank, int pos = -1)
{
	if (g_esZombiePlayer[tank].g_iCooldown != -1 && g_esZombiePlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esZombiePlayer[tank].g_bActivated = true;
	vZombie2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esZombieCache[tank].g_iHumanAbility == 1)
	{
		g_esZombiePlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman", g_esZombiePlayer[tank].g_iAmmoCount, g_esZombieCache[tank].g_iHumanAmmo);
	}

	if (g_esZombieCache[tank].g_iZombieMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Zombie", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Zombie", LANG_SERVER, sTankName);
	}
}

void vZombie2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esZombieCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esZombieCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esZombiePlayer[tank].g_iTankType) || (g_esZombieCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esZombieCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esZombieCache[tank].g_flZombieInterval;
	DataPack dpZombie;
	CreateDataTimer(flInterval, tTimerZombie, dpZombie, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpZombie.WriteCell(GetClientUserId(tank));
	dpZombie.WriteCell(g_esZombiePlayer[tank].g_iTankType);
	dpZombie.WriteCell(GetTime());
	dpZombie.WriteCell(pos);
}

void vZombie3(int tank)
{
	if (bIsAreaNarrow(tank, g_esZombieCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esZombieCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esZombiePlayer[tank].g_iTankType) || (g_esZombieCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esZombieCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	for (int iZombie = 1; iZombie <= g_esZombieCache[tank].g_iZombieAmount; iZombie++)
	{
		switch (g_esZombieCache[tank].g_iZombieMode)
		{
			case 0: vSpawnZombie(tank, (MT_GetRandomInt(1, 2) == 2));
			case 1: vSpawnZombie(tank, false);
			case 2: vSpawnZombie(tank, true);
		}
	}
}

void vZombieAbility(int tank)
{
	if ((g_esZombiePlayer[tank].g_iCooldown != -1 && g_esZombiePlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esZombieCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esZombieCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esZombiePlayer[tank].g_iTankType) || (g_esZombieCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esZombieCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esZombiePlayer[tank].g_iAmmoCount < g_esZombieCache[tank].g_iHumanAmmo && g_esZombieCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esZombieCache[tank].g_flZombieChance)
		{
			vZombie(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esZombieCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esZombieCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieAmmo");
	}
}

void vZombieRange(int tank)
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME) && MT_IsCustomTankSupported(tank) && g_esZombieCache[tank].g_iZombieAbility == 1 && MT_GetRandomFloat(0.1, 100.0) <= g_esZombieCache[tank].g_flZombieChance)
	{
		if (bIsAreaNarrow(tank, g_esZombieCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esZombieCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esZombiePlayer[tank].g_iTankType) || (g_esZombieCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esZombieCache[tank].g_iRequiresHumans) || (bIsTank(tank, MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[tank].g_iAccessFlags)) || g_esZombieCache[tank].g_iHumanAbility == 0)))
		{
			return;
		}

		vZombie3(tank);
	}
}

void vZombieCopyStats2(int oldTank, int newTank)
{
	g_esZombiePlayer[newTank].g_iAmmoCount = g_esZombiePlayer[oldTank].g_iAmmoCount;
	g_esZombiePlayer[newTank].g_iCooldown = g_esZombiePlayer[oldTank].g_iCooldown;
}

void vRemoveZombie(int tank)
{
	g_esZombiePlayer[tank].g_bActivated = false;
	g_esZombiePlayer[tank].g_iAmmoCount = 0;
	g_esZombiePlayer[tank].g_iCooldown = -1;
}

void vZombieReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveZombie(iPlayer);
		}
	}
}

void vZombieReset2(int tank)
{
	g_esZombiePlayer[tank].g_bActivated = false;

	int iTime = GetTime(), iPos = g_esZombieAbility[g_esZombiePlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esZombieCache[tank].g_iZombieCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esZombieCache[tank].g_iHumanAbility == 1 && g_esZombiePlayer[tank].g_iAmmoCount < g_esZombieCache[tank].g_iHumanAmmo && g_esZombieCache[tank].g_iHumanAmmo > 0) ? g_esZombieCache[tank].g_iHumanCooldown : iCooldown;
	g_esZombiePlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esZombiePlayer[tank].g_iCooldown != -1 && g_esZombiePlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "ZombieHuman5", (g_esZombiePlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerZombieCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esZombieAbility[g_esZombiePlayer[iTank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esZombiePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esZombieCache[iTank].g_iZombieAbility == 0 || g_esZombiePlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vZombie(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerZombie(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esZombieCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esZombieCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esZombiePlayer[iTank].g_iTankType) || (g_esZombieCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esZombieCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esZombieAbility[g_esZombiePlayer[iTank].g_iTankType].g_iAccessFlags, g_esZombiePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esZombiePlayer[iTank].g_iTankType) || !MT_IsCorePluginEnabled() || !MT_IsCustomTankSupported(iTank) || iType != g_esZombiePlayer[iTank].g_iTankType || g_esZombieCache[iTank].g_iZombieAbility == 0 || !g_esZombiePlayer[iTank].g_bActivated)
	{
		g_esZombiePlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esZombieCache[iTank].g_iZombieDuration;
	iDuration = (bHuman && g_esZombieCache[iTank].g_iHumanAbility == 1) ? g_esZombieCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esZombieCache[iTank].g_iHumanAbility == 1 && g_esZombieCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esZombiePlayer[iTank].g_iCooldown == -1 || g_esZombiePlayer[iTank].g_iCooldown < iCurrentTime))
	{
		vZombieReset2(iTank);

		return Plugin_Stop;
	}

	vZombie3(iTank);

	if (g_esZombieCache[iTank].g_iZombieMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(iTank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Zombie2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Zombie2", LANG_SERVER, sTankName);
	}

	return Plugin_Continue;
}