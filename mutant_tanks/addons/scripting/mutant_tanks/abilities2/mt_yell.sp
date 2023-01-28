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

#define MT_YELL_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_YELL_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Yell Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank yells to deafen survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Yell Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_YELL_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SPRITE_GLOW "sprites/glow01.vmt"
#define SPRITE_LASERBEAM "sprites/laserbeam.vmt"

#define MT_YELL_SECTION "yellability"
#define MT_YELL_SECTION2 "yell ability"
#define MT_YELL_SECTION3 "yell_ability"
#define MT_YELL_SECTION4 "yell"

#define MT_MENU_YELL "Yell Ability"

char g_sTankYells[][] =
{
	"player/tank/voice/yell/tank_yell_01.wav",
	"player/tank/voice/yell/tank_yell_02.wav",
	"player/tank/voice/yell/tank_yell_03.wav",
	"player/tank/voice/yell/tank_yell_04.wav",
	"player/tank/voice/yell/tank_yell_05.wav",
	"player/tank/voice/yell/tank_yell_06.wav",
	"player/tank/voice/yell/tank_yell_07.wav",
	"player/tank/voice/yell/tank_yell_08.wav",
	"player/tank/voice/yell/tank_yell_09.wav",
	"player/tank/voice/yell/tank_yell_10.wav",
	"player/tank/voice/yell/tank_yell_12.wav"
};

enum struct esYellPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flYellChance;
	float g_flYellDamage;
	float g_flYellInterval;
	float g_flYellRange;

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
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iYellAbility;
	int g_iYellCooldown;
	int g_iYellDuration;
	int g_iYellMessage;
	int g_iYellMode;
	int g_iYellPitch;
}

esYellPlayer g_esYellPlayer[MAXPLAYERS + 1];

enum struct esYellAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flYellChance;
	float g_flYellDamage;
	float g_flYellInterval;
	float g_flYellRange;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iYellAbility;
	int g_iYellCooldown;
	int g_iYellDuration;
	int g_iYellMessage;
	int g_iYellMode;
	int g_iYellPitch;
}

esYellAbility g_esYellAbility[MT_MAXTYPES + 1];

enum struct esYellCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flYellChance;
	float g_flYellDamage;
	float g_flYellInterval;
	float g_flYellRange;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iRequiresHumans;
	int g_iYellAbility;
	int g_iYellCooldown;
	int g_iYellDuration;
	int g_iYellMessage;
	int g_iYellMode;
	int g_iYellPitch;
}

esYellCache g_esYellCache[MAXPLAYERS + 1];

int g_iBeamSprite = -1, g_iHaloSprite = -1;

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_yell", cmdYellInfo, "View information about the Yell ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vYellMapStart()
#else
public void OnMapStart()
#endif
{
	g_iBeamSprite = PrecacheModel(SPRITE_LASERBEAM, true);
	g_iHaloSprite = PrecacheModel(SPRITE_GLOW, true);

	for (int iPos = 0; iPos < (sizeof g_sTankYells); iPos++)
	{
		PrecacheSound(g_sTankYells[iPos], true);
	}

	vYellReset();
}

#if defined MT_ABILITIES_MAIN2
void vYellClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveYell(client);
}

#if defined MT_ABILITIES_MAIN2
void vYellClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveYell(client);
}

#if defined MT_ABILITIES_MAIN2
void vYellMapEnd()
#else
public void OnMapEnd()
#endif
{
	vYellReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdYellInfo(int client, int args)
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
		case false: vYellMenu(client, MT_YELL_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vYellMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_YELL_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iYellMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Yell Ability Information");
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

int iYellMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esYellCache[param1].g_iYellAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esYellCache[param1].g_iHumanAmmo - g_esYellPlayer[param1].g_iAmmoCount), g_esYellCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esYellCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esYellCache[param1].g_iHumanAbility == 1) ? g_esYellCache[param1].g_iHumanCooldown : g_esYellCache[param1].g_iYellCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "YellDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esYellCache[param1].g_iHumanAbility == 1) ? g_esYellCache[param1].g_iHumanDuration : g_esYellCache[param1].g_iYellDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esYellCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vYellMenu(param1, MT_YELL_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pYell = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "YellMenu", param1);
			pYell.SetTitle(sMenuTitle);
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
void vYellDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_YELL, MT_MENU_YELL);
}

#if defined MT_ABILITIES_MAIN2
void vYellMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_YELL, false))
	{
		vYellMenu(client, MT_YELL_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_YELL, false))
	{
		FormatEx(buffer, size, "%T", "YellMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_YELL);
}

#if defined MT_ABILITIES_MAIN2
void vYellAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_YELL_SECTION);
	list2.PushString(MT_YELL_SECTION2);
	list3.PushString(MT_YELL_SECTION3);
	list4.PushString(MT_YELL_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vYellCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esYellCache[tank].g_iHumanAbility != 2)
	{
		g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_YELL_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_YELL_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_YELL_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_YELL_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esYellCache[tank].g_iYellAbility == 1 && g_esYellCache[tank].g_iComboAbility == 1 && !g_esYellPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_YELL_SECTION, false) || StrEqual(sSubset[iPos], MT_YELL_SECTION2, false) || StrEqual(sSubset[iPos], MT_YELL_SECTION3, false) || StrEqual(sSubset[iPos], MT_YELL_SECTION4, false))
				{
					g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vYell(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerYellCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vYellConfigsLoad(int mode)
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
				g_esYellAbility[iIndex].g_iAccessFlags = 0;
				g_esYellAbility[iIndex].g_iImmunityFlags = 0;
				g_esYellAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esYellAbility[iIndex].g_iComboAbility = 0;
				g_esYellAbility[iIndex].g_iComboPosition = -1;
				g_esYellAbility[iIndex].g_iHumanAbility = 0;
				g_esYellAbility[iIndex].g_iHumanAmmo = 5;
				g_esYellAbility[iIndex].g_iHumanCooldown = 0;
				g_esYellAbility[iIndex].g_iHumanDuration = 5;
				g_esYellAbility[iIndex].g_iHumanMode = 1;
				g_esYellAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esYellAbility[iIndex].g_iRequiresHumans = 0;
				g_esYellAbility[iIndex].g_iYellAbility = 0;
				g_esYellAbility[iIndex].g_iYellMessage = 0;
				g_esYellAbility[iIndex].g_flYellChance = 33.3;
				g_esYellAbility[iIndex].g_iYellCooldown = 0;
				g_esYellAbility[iIndex].g_flYellDamage = 5.0;
				g_esYellAbility[iIndex].g_iYellDuration = 5;
				g_esYellAbility[iIndex].g_flYellInterval = 5.0;
				g_esYellAbility[iIndex].g_iYellMode = 0;
				g_esYellAbility[iIndex].g_iYellPitch = 100;
				g_esYellAbility[iIndex].g_flYellRange = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esYellPlayer[iPlayer].g_iAccessFlags = 0;
					g_esYellPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esYellPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esYellPlayer[iPlayer].g_iComboAbility = 0;
					g_esYellPlayer[iPlayer].g_iHumanAbility = 0;
					g_esYellPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esYellPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esYellPlayer[iPlayer].g_iHumanDuration = 0;
					g_esYellPlayer[iPlayer].g_iHumanMode = 0;
					g_esYellPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esYellPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esYellPlayer[iPlayer].g_iYellAbility = 0;
					g_esYellPlayer[iPlayer].g_iYellMessage = 0;
					g_esYellPlayer[iPlayer].g_flYellChance = 0.0;
					g_esYellPlayer[iPlayer].g_iYellCooldown = 0;
					g_esYellPlayer[iPlayer].g_flYellDamage = 0.0;
					g_esYellPlayer[iPlayer].g_iYellDuration = 0;
					g_esYellPlayer[iPlayer].g_flYellInterval = 0.0;
					g_esYellPlayer[iPlayer].g_iYellMode = 0;
					g_esYellPlayer[iPlayer].g_iYellPitch = 0;
					g_esYellPlayer[iPlayer].g_flYellRange = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esYellPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esYellPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esYellPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esYellPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esYellPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esYellPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esYellPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esYellPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esYellPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esYellPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esYellPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esYellPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esYellPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esYellPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esYellPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esYellPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esYellPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esYellPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esYellPlayer[admin].g_iYellAbility = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esYellPlayer[admin].g_iYellAbility, value, 0, 1);
		g_esYellPlayer[admin].g_iYellMessage = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esYellPlayer[admin].g_iYellMessage, value, 0, 1);
		g_esYellPlayer[admin].g_flYellChance = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellChance", "Yell Chance", "Yell_Chance", "chance", g_esYellPlayer[admin].g_flYellChance, value, 0.0, 100.0);
		g_esYellPlayer[admin].g_iYellCooldown = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellCooldown", "Yell Cooldown", "Yell_Cooldown", "cooldown", g_esYellPlayer[admin].g_iYellCooldown, value, 0, 99999);
		g_esYellPlayer[admin].g_flYellDamage = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellDamage", "Yell Damage", "Yell_Damage", "damage", g_esYellPlayer[admin].g_flYellDamage, value, 0.0, 99999.0);
		g_esYellPlayer[admin].g_iYellDuration = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellDuration", "Yell Duration", "Yell_Duration", "duration", g_esYellPlayer[admin].g_iYellDuration, value, 0, 99999);
		g_esYellPlayer[admin].g_flYellInterval = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellInterval", "Yell Interval", "Yell_Interval", "interval", g_esYellPlayer[admin].g_flYellInterval, value, 0.1, 99999.0);
		g_esYellPlayer[admin].g_iYellMode = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellMode", "Yell Mode", "Yell_Mode", "mode", g_esYellPlayer[admin].g_iYellMode, value, 0, 2);
		g_esYellPlayer[admin].g_iYellPitch = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellPitch", "Yell Pitch", "Yell_Pitch", "pitch", g_esYellPlayer[admin].g_iYellPitch, value, 0, 255);
		g_esYellPlayer[admin].g_flYellRange = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellRange", "Yell Range", "Yell_Range", "range", g_esYellPlayer[admin].g_flYellRange, value, 1.0, 99999.0);
		g_esYellPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esYellPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esYellAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esYellAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esYellAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esYellAbility[type].g_iComboAbility, value, 0, 1);
		g_esYellAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esYellAbility[type].g_iHumanAbility, value, 0, 2);
		g_esYellAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esYellAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esYellAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esYellAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esYellAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esYellAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esYellAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esYellAbility[type].g_iHumanMode, value, 0, 1);
		g_esYellAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esYellAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esYellAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esYellAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esYellAbility[type].g_iYellAbility = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esYellAbility[type].g_iYellAbility, value, 0, 1);
		g_esYellAbility[type].g_iYellMessage = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esYellAbility[type].g_iYellMessage, value, 0, 1);
		g_esYellAbility[type].g_flYellChance = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellChance", "Yell Chance", "Yell_Chance", "chance", g_esYellAbility[type].g_flYellChance, value, 0.0, 100.0);
		g_esYellAbility[type].g_iYellCooldown = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellCooldown", "Yell Cooldown", "Yell_Cooldown", "cooldown", g_esYellAbility[type].g_iYellCooldown, value, 0, 99999);
		g_esYellAbility[type].g_flYellDamage = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellDamage", "Yell Damage", "Yell_Damage", "damage", g_esYellAbility[type].g_flYellDamage, value, 0.0, 99999.0);
		g_esYellAbility[type].g_iYellDuration = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellDuration", "Yell Duration", "Yell_Duration", "duration", g_esYellAbility[type].g_iYellDuration, value, 0, 99999);
		g_esYellAbility[type].g_flYellInterval = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellInterval", "Yell Interval", "Yell_Interval", "interval", g_esYellAbility[type].g_flYellInterval, value, 0.1, 99999.0);
		g_esYellAbility[type].g_iYellMode = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellMode", "Yell Mode", "Yell_Mode", "mode", g_esYellAbility[type].g_iYellMode, value, 0, 2);
		g_esYellAbility[type].g_iYellPitch = iGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellPitch", "Yell Pitch", "Yell_Pitch", "pitch", g_esYellAbility[type].g_iYellPitch, value, 0, 255);
		g_esYellAbility[type].g_flYellRange = flGetKeyValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "YellRange", "Yell Range", "Yell_Range", "range", g_esYellAbility[type].g_flYellRange, value, 1.0, 99999.0);
		g_esYellAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esYellAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_YELL_SECTION, MT_YELL_SECTION2, MT_YELL_SECTION3, MT_YELL_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esYellCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_flCloseAreasOnly, g_esYellAbility[type].g_flCloseAreasOnly);
	g_esYellCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iComboAbility, g_esYellAbility[type].g_iComboAbility);
	g_esYellCache[tank].g_flYellChance = flGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_flYellChance, g_esYellAbility[type].g_flYellChance);
	g_esYellCache[tank].g_flYellDamage = flGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_flYellDamage, g_esYellAbility[type].g_flYellDamage);
	g_esYellCache[tank].g_flYellInterval = flGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_flYellInterval, g_esYellAbility[type].g_flYellInterval);
	g_esYellCache[tank].g_flYellRange = flGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_flYellRange, g_esYellAbility[type].g_flYellRange);
	g_esYellCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iHumanAbility, g_esYellAbility[type].g_iHumanAbility);
	g_esYellCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iHumanAmmo, g_esYellAbility[type].g_iHumanAmmo);
	g_esYellCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iHumanCooldown, g_esYellAbility[type].g_iHumanCooldown);
	g_esYellCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iHumanDuration, g_esYellAbility[type].g_iHumanDuration);
	g_esYellCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iHumanMode, g_esYellAbility[type].g_iHumanMode);
	g_esYellCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_flOpenAreasOnly, g_esYellAbility[type].g_flOpenAreasOnly);
	g_esYellCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iRequiresHumans, g_esYellAbility[type].g_iRequiresHumans);
	g_esYellCache[tank].g_iYellAbility = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iYellAbility, g_esYellAbility[type].g_iYellAbility);
	g_esYellCache[tank].g_iYellCooldown = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iYellCooldown, g_esYellAbility[type].g_iYellCooldown);
	g_esYellCache[tank].g_iYellDuration = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iYellDuration, g_esYellAbility[type].g_iYellDuration);
	g_esYellCache[tank].g_iYellMessage = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iYellMessage, g_esYellAbility[type].g_iYellMessage);
	g_esYellCache[tank].g_iYellMode = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iYellMode, g_esYellAbility[type].g_iYellMode);
	g_esYellCache[tank].g_iYellPitch = iGetSettingValue(apply, bHuman, g_esYellPlayer[tank].g_iYellPitch, g_esYellAbility[type].g_iYellPitch);
	g_esYellPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vYellCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vYellCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveYell(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vYellEventFired(Event event, const char[] name)
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
			vYellCopyStats2(iBot, iTank);
			vRemoveYell(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vYellCopyStats2(iTank, iBot);
			vRemoveYell(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveYell(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vYellReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iAccessFlags, g_esYellPlayer[tank].g_iAccessFlags)) || g_esYellCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esYellCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esYellCache[tank].g_iYellAbility == 1 && g_esYellCache[tank].g_iComboAbility == 0 && !g_esYellPlayer[tank].g_bActivated)
	{
		vYellAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esYellCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esYellCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esYellPlayer[tank].g_iTankType) || (g_esYellCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esYellCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iAccessFlags, g_esYellPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esYellCache[tank].g_iYellAbility == 1 && g_esYellCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esYellPlayer[tank].g_iCooldown != -1 && g_esYellPlayer[tank].g_iCooldown > iTime;

			switch (g_esYellCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esYellPlayer[tank].g_bActivated && !bRecharging)
					{
						vYellAbility(tank);
					}
					else if (g_esYellPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman4", (g_esYellPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esYellPlayer[tank].g_iAmmoCount < g_esYellCache[tank].g_iHumanAmmo && g_esYellCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esYellPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esYellPlayer[tank].g_bActivated = true;
							g_esYellPlayer[tank].g_iAmmoCount++;

							vYell2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman", g_esYellPlayer[tank].g_iAmmoCount, g_esYellCache[tank].g_iHumanAmmo);
						}
						else if (g_esYellPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman4", (g_esYellPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esYellCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esYellCache[tank].g_iHumanMode == 1 && g_esYellPlayer[tank].g_bActivated && (g_esYellPlayer[tank].g_iCooldown == -1 || g_esYellPlayer[tank].g_iCooldown < GetTime()))
		{
			vYellReset2(tank);
			vYellReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vYellChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveYell(tank);
}

void vYell(int tank, int pos = -1)
{
	if (g_esYellPlayer[tank].g_iCooldown != -1 && g_esYellPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esYellPlayer[tank].g_bActivated = true;

	vYell2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esYellCache[tank].g_iHumanAbility == 1)
	{
		g_esYellPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman", g_esYellPlayer[tank].g_iAmmoCount, g_esYellCache[tank].g_iHumanAmmo);
	}

	if (g_esYellCache[tank].g_iYellMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Yell", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Yell", LANG_SERVER, sTankName);
	}
}

void vYell2(int tank, int pos = -1)
{
	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esYellCache[tank].g_flYellInterval;
	DataPack dpYell;
	CreateDataTimer(flInterval, tTimerYell, dpYell, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpYell.WriteCell(GetClientUserId(tank));
	dpYell.WriteCell(g_esYellPlayer[tank].g_iTankType);
	dpYell.WriteCell(GetTime());
	dpYell.WriteCell(pos);
}

void vYellAbility(int tank)
{
	if ((g_esYellPlayer[tank].g_iCooldown != -1 && g_esYellPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esYellCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esYellCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esYellPlayer[tank].g_iTankType) || (g_esYellCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esYellCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iAccessFlags, g_esYellPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esYellPlayer[tank].g_iAmmoCount < g_esYellCache[tank].g_iHumanAmmo && g_esYellCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esYellCache[tank].g_flYellChance)
		{
			vYell(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esYellCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esYellCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellAmmo");
	}
}

void vYellCopyStats2(int oldTank, int newTank)
{
	g_esYellPlayer[newTank].g_iAmmoCount = g_esYellPlayer[oldTank].g_iAmmoCount;
	g_esYellPlayer[newTank].g_iCooldown = g_esYellPlayer[oldTank].g_iCooldown;
}

void vRemoveYell(int tank)
{
	g_esYellPlayer[tank].g_bActivated = false;
	g_esYellPlayer[tank].g_iAmmoCount = 0;
	g_esYellPlayer[tank].g_iCooldown = -1;
}

void vYellReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveYell(iPlayer);
		}
	}
}

void vYellReset2(int tank)
{
	g_esYellPlayer[tank].g_bActivated = false;

	if (g_esYellCache[tank].g_iYellMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Yell2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Yell2", LANG_SERVER, sTankName);
	}
}

void vYellReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esYellAbility[g_esYellPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esYellCache[tank].g_iYellCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esYellCache[tank].g_iHumanAbility == 1 && g_esYellCache[tank].g_iHumanMode == 0 && g_esYellPlayer[tank].g_iAmmoCount < g_esYellCache[tank].g_iHumanAmmo && g_esYellCache[tank].g_iHumanAmmo > 0) ? g_esYellCache[tank].g_iHumanCooldown : iCooldown;
	g_esYellPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esYellPlayer[tank].g_iCooldown != -1 && g_esYellPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "YellHuman5", (g_esYellPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerYellCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esYellAbility[g_esYellPlayer[iTank].g_iTankType].g_iAccessFlags, g_esYellPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esYellPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esYellCache[iTank].g_iYellAbility == 0 || g_esYellPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vYell(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerYell(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esYellCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esYellCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esYellPlayer[iTank].g_iTankType) || (g_esYellCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esYellCache[iTank].g_iRequiresHumans) || !MT_HasAdminAccess(iTank) || !bHasAdminAccess(iTank, g_esYellAbility[g_esYellPlayer[iTank].g_iTankType].g_iAccessFlags, g_esYellPlayer[iTank].g_iAccessFlags) || !MT_IsTypeEnabled(g_esYellPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esYellPlayer[iTank].g_iTankType || !g_esYellPlayer[iTank].g_bActivated || g_esYellCache[iTank].g_iYellAbility == 0)
	{
		g_esYellPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esYellCache[iTank].g_iYellDuration;
	iDuration = (bHuman && g_esYellCache[iTank].g_iHumanAbility == 1) ? g_esYellCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esYellCache[iTank].g_iHumanAbility == 1 && g_esYellCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esYellPlayer[iTank].g_iCooldown == -1 || g_esYellPlayer[iTank].g_iCooldown < iCurrentTime))
	{
		vYellReset2(iTank);
		vYellReset3(iTank);

		return Plugin_Stop;
	}

	int iBeamColor[4];
	MT_GetTankColors(iTank, 2, iBeamColor[0], iBeamColor[1], iBeamColor[2], iBeamColor[3]);
	iBeamColor[3] = 50;

	float flTankPos[3], flSurvivorPos[3];
	GetClientAbsOrigin(iTank, flTankPos);
	flTankPos[2] -= 30.0;
	float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esYellCache[iTank].g_flYellDamage,
		flRange = (iPos != -1) ? MT_GetCombinationSetting(iTank, 9, iPos) : g_esYellCache[iTank].g_flYellRange;
	int iMode = g_esYellCache[iTank].g_iYellMode;
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, iTank) && !bIsAdminImmune(iSurvivor, g_esYellPlayer[iTank].g_iTankType, g_esYellAbility[g_esYellPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esYellPlayer[iSurvivor].g_iImmunityFlags) && !MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
		{
			GetClientAbsOrigin(iSurvivor, flSurvivorPos);
			if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
			{
				if (iMode == 0 || iMode == 1)
				{
					MT_DeafenPlayer(iSurvivor);
				}

				if (iMode == 0 || iMode == 2)
				{
					for (int iIndex = 0; iIndex < (sizeof g_sTankYells); iIndex++)
					{
						EmitSoundToClient(iSurvivor, g_sTankYells[iIndex], .pitch = g_esYellCache[iTank].g_iYellPitch);
					}
				}

				if (flDamage > 0.0)
				{
					vDamagePlayer(iSurvivor, iTank, MT_GetScaledDamage(flDamage), "65536");
				}

				vShakePlayerScreen(iSurvivor, 2.0);
			}
		}
	}

	TE_SetupBeamRingPoint(flTankPos, 10.0, (flRange * 2.0), g_iBeamSprite, g_iHaloSprite, 0, 50, 1.0, 88.0, 3.0, iBeamColor, 1000, 0);
	TE_SendToAll();

	return Plugin_Continue;
}