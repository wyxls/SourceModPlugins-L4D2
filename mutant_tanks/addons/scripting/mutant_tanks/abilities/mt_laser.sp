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

#define MT_LASER_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_LASER_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Laser Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank shoots lasers at survivors.",
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
			strcopy(error, err_max, "\"[MT] Laser Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_LASER_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define PARTICLE_LASER "electrical_arc_01_system"

#define SOUND_ELECTRICITY "ambient/energy/zap5.wav"
#define SOUND_ELECTRICITY2 "ambient/energy/zap7.wav"

#define SPRITE_LASER "sprites/laser.vmt"
#define SPRITE_LASERBEAM "sprites/laserbeam.vmt"

#define MT_LASER_SECTION "laserability"
#define MT_LASER_SECTION2 "laser ability"
#define MT_LASER_SECTION3 "laser_ability"
#define MT_LASER_SECTION4 "laser"

#define MT_MENU_LASER "Laser Ability"

enum struct esLaserPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flLaserChance;
	float g_flLaserDamage;
	float g_flLaserInterval;
	float g_flLaserRange;
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
	int g_iLaserAbility;
	int g_iLaserCooldown;
	int g_iLaserDuration;
	int g_iLaserMessage;
	int g_iRequiresHumans;
	int g_iTankType;
}

esLaserPlayer g_esLaserPlayer[MAXPLAYERS + 1];

enum struct esLaserAbility
{
	float g_flCloseAreasOnly;
	float g_flLaserChance;
	float g_flLaserDamage;
	float g_flLaserInterval;
	float g_flLaserRange;
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
	int g_iLaserAbility;
	int g_iLaserCooldown;
	int g_iLaserDuration;
	int g_iLaserMessage;
	int g_iRequiresHumans;
}

esLaserAbility g_esLaserAbility[MT_MAXTYPES + 1];

enum struct esLaserCache
{
	float g_flCloseAreasOnly;
	float g_flLaserChance;
	float g_flLaserDamage;
	float g_flLaserInterval;
	float g_flLaserRange;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iLaserAbility;
	int g_iLaserCooldown;
	int g_iLaserDuration;
	int g_iLaserMessage;
	int g_iRequiresHumans;
}

esLaserCache g_esLaserCache[MAXPLAYERS + 1];

int g_iLaserSprite = -1;

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_laser", cmdLaserInfo, "View information about the Laser ability.");
}
#endif

#if defined MT_ABILITIES_MAIN
void vLaserMapStart()
#else
public void OnMapStart()
#endif
{
	switch (g_bSecondGame)
	{
		case true: g_iLaserSprite = PrecacheModel(SPRITE_LASERBEAM, true);
		case false: g_iLaserSprite = PrecacheModel(SPRITE_LASER, true);
	}

	iPrecacheParticle(PARTICLE_LASER);

	PrecacheSound(SOUND_ELECTRICITY, true);
	PrecacheSound(SOUND_ELECTRICITY2, true);

	vLaserReset();
}

#if defined MT_ABILITIES_MAIN
void vLaserClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	vRemoveLaser(client);
}

#if defined MT_ABILITIES_MAIN
void vLaserClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveLaser(client);
}

#if defined MT_ABILITIES_MAIN
void vLaserMapEnd()
#else
public void OnMapEnd()
#endif
{
	vLaserReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdLaserInfo(int client, int args)
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
		case false: vLaserMenu(client, MT_LASER_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vLaserMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_LASER_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iLaserMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Laser Ability Information");
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

int iLaserMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLaserCache[param1].g_iLaserAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esLaserCache[param1].g_iHumanAmmo - g_esLaserPlayer[param1].g_iAmmoCount), g_esLaserCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLaserCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esLaserCache[param1].g_iHumanAbility == 1) ? g_esLaserCache[param1].g_iHumanCooldown : g_esLaserCache[param1].g_iLaserCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "LaserDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esLaserCache[param1].g_iHumanAbility == 1) ? g_esLaserCache[param1].g_iHumanDuration : g_esLaserCache[param1].g_iLaserDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esLaserCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vLaserMenu(param1, MT_LASER_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pLaser = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "LaserMenu", param1);
			pLaser.SetTitle(sMenuTitle);
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
void vLaserDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_LASER, MT_MENU_LASER);
}

#if defined MT_ABILITIES_MAIN
void vLaserMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_LASER, false))
	{
		vLaserMenu(client, MT_LASER_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_LASER, false))
	{
		FormatEx(buffer, size, "%T", "LaserMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_LASER);
}

#if defined MT_ABILITIES_MAIN
void vLaserAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_LASER_SECTION);
	list2.PushString(MT_LASER_SECTION2);
	list3.PushString(MT_LASER_SECTION3);
	list4.PushString(MT_LASER_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vLaserCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLaserCache[tank].g_iHumanAbility != 2)
	{
		g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_LASER_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_LASER_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_LASER_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_LASER_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esLaserCache[tank].g_iLaserAbility == 1 && g_esLaserCache[tank].g_iComboAbility == 1 && !g_esLaserPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_LASER_SECTION, false) || StrEqual(sSubset[iPos], MT_LASER_SECTION2, false) || StrEqual(sSubset[iPos], MT_LASER_SECTION3, false) || StrEqual(sSubset[iPos], MT_LASER_SECTION4, false))
				{
					g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vLaser(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerLaserCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vLaserConfigsLoad(int mode)
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
				g_esLaserAbility[iIndex].g_iAccessFlags = 0;
				g_esLaserAbility[iIndex].g_iImmunityFlags = 0;
				g_esLaserAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esLaserAbility[iIndex].g_iComboAbility = 0;
				g_esLaserAbility[iIndex].g_iComboPosition = -1;
				g_esLaserAbility[iIndex].g_iHumanAbility = 0;
				g_esLaserAbility[iIndex].g_iHumanAmmo = 5;
				g_esLaserAbility[iIndex].g_iHumanCooldown = 0;
				g_esLaserAbility[iIndex].g_iHumanDuration = 5;
				g_esLaserAbility[iIndex].g_iHumanMode = 1;
				g_esLaserAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esLaserAbility[iIndex].g_iRequiresHumans = 0;
				g_esLaserAbility[iIndex].g_iLaserAbility = 0;
				g_esLaserAbility[iIndex].g_iLaserMessage = 0;
				g_esLaserAbility[iIndex].g_flLaserChance = 33.3;
				g_esLaserAbility[iIndex].g_iLaserCooldown = 0;
				g_esLaserAbility[iIndex].g_flLaserDamage = 5.0;
				g_esLaserAbility[iIndex].g_iLaserDuration = 5;
				g_esLaserAbility[iIndex].g_flLaserInterval = 1.0;
				g_esLaserAbility[iIndex].g_flLaserRange = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esLaserPlayer[iPlayer].g_iAccessFlags = 0;
					g_esLaserPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esLaserPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esLaserPlayer[iPlayer].g_iComboAbility = 0;
					g_esLaserPlayer[iPlayer].g_iHumanAbility = 0;
					g_esLaserPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esLaserPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esLaserPlayer[iPlayer].g_iHumanDuration = 0;
					g_esLaserPlayer[iPlayer].g_iHumanMode = 0;
					g_esLaserPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esLaserPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esLaserPlayer[iPlayer].g_iLaserAbility = 0;
					g_esLaserPlayer[iPlayer].g_iLaserMessage = 0;
					g_esLaserPlayer[iPlayer].g_flLaserChance = 0.0;
					g_esLaserPlayer[iPlayer].g_iLaserCooldown = 0;
					g_esLaserPlayer[iPlayer].g_flLaserDamage = 0.0;
					g_esLaserPlayer[iPlayer].g_iLaserDuration = 0;
					g_esLaserPlayer[iPlayer].g_flLaserInterval = 0.0;
					g_esLaserPlayer[iPlayer].g_flLaserRange = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esLaserPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLaserPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLaserPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLaserPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esLaserPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLaserPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esLaserPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLaserPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esLaserPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLaserPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esLaserPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esLaserPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esLaserPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esLaserPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esLaserPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLaserPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLaserPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLaserPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esLaserPlayer[admin].g_iLaserAbility = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLaserPlayer[admin].g_iLaserAbility, value, 0, 1);
		g_esLaserPlayer[admin].g_iLaserMessage = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLaserPlayer[admin].g_iLaserMessage, value, 0, 1);
		g_esLaserPlayer[admin].g_flLaserChance = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserChance", "Laser Chance", "Laser_Chance", "chance", g_esLaserPlayer[admin].g_flLaserChance, value, 0.0, 100.0);
		g_esLaserPlayer[admin].g_iLaserCooldown = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserCooldown", "Laser Cooldown", "Laser_Cooldown", "cooldown", g_esLaserPlayer[admin].g_iLaserCooldown, value, 0, 99999);
		g_esLaserPlayer[admin].g_flLaserDamage = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserDamage", "Laser Damage", "Laser_Damage", "damage", g_esLaserPlayer[admin].g_flLaserDamage, value, 0.0, 99999.0);
		g_esLaserPlayer[admin].g_iLaserDuration = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserDuration", "Laser Duration", "Laser_Duration", "duration", g_esLaserPlayer[admin].g_iLaserDuration, value, 0, 99999);
		g_esLaserPlayer[admin].g_flLaserInterval = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserInterval", "Laser Interval", "Laser_Interval", "interval", g_esLaserPlayer[admin].g_flLaserInterval, value, 0.1, 99999.0);
		g_esLaserPlayer[admin].g_flLaserRange = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserRange", "Laser Range", "Laser_Range", "range", g_esLaserPlayer[admin].g_flLaserRange, value, 1.0, 99999.0);
		g_esLaserPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLaserPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esLaserAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esLaserAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esLaserAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esLaserAbility[type].g_iComboAbility, value, 0, 1);
		g_esLaserAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esLaserAbility[type].g_iHumanAbility, value, 0, 2);
		g_esLaserAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esLaserAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esLaserAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esLaserAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esLaserAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esLaserAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esLaserAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esLaserAbility[type].g_iHumanMode, value, 0, 1);
		g_esLaserAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esLaserAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esLaserAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esLaserAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esLaserAbility[type].g_iLaserAbility = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esLaserAbility[type].g_iLaserAbility, value, 0, 1);
		g_esLaserAbility[type].g_iLaserMessage = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esLaserAbility[type].g_iLaserMessage, value, 0, 1);
		g_esLaserAbility[type].g_flLaserChance = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserChance", "Laser Chance", "Laser_Chance", "chance", g_esLaserAbility[type].g_flLaserChance, value, 0.0, 100.0);
		g_esLaserAbility[type].g_iLaserCooldown = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserCooldown", "Laser Cooldown", "Laser_Cooldown", "cooldown", g_esLaserAbility[type].g_iLaserCooldown, value, 0, 99999);
		g_esLaserAbility[type].g_flLaserDamage = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserDamage", "Laser Damage", "Laser_Damage", "damage", g_esLaserAbility[type].g_flLaserDamage, value, 0.0, 99999.0);
		g_esLaserAbility[type].g_iLaserDuration = iGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserDuration", "Laser Duration", "Laser_Duration", "duration", g_esLaserAbility[type].g_iLaserDuration, value, 0, 99999);
		g_esLaserAbility[type].g_flLaserInterval = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserInterval", "Laser Interval", "Laser_Interval", "interval", g_esLaserAbility[type].g_flLaserInterval, value, 0.1, 99999.0);
		g_esLaserAbility[type].g_flLaserRange = flGetKeyValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "LaserRange", "Laser Range", "Laser_Range", "range", g_esLaserAbility[type].g_flLaserRange, value, 1.0, 99999.0);
		g_esLaserAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esLaserAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_LASER_SECTION, MT_LASER_SECTION2, MT_LASER_SECTION3, MT_LASER_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esLaserCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_flCloseAreasOnly, g_esLaserAbility[type].g_flCloseAreasOnly);
	g_esLaserCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iComboAbility, g_esLaserAbility[type].g_iComboAbility);
	g_esLaserCache[tank].g_flLaserChance = flGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_flLaserChance, g_esLaserAbility[type].g_flLaserChance);
	g_esLaserCache[tank].g_flLaserDamage = flGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_flLaserDamage, g_esLaserAbility[type].g_flLaserDamage);
	g_esLaserCache[tank].g_flLaserInterval = flGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_flLaserInterval, g_esLaserAbility[type].g_flLaserInterval);
	g_esLaserCache[tank].g_flLaserRange = flGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_flLaserRange, g_esLaserAbility[type].g_flLaserRange);
	g_esLaserCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iHumanAbility, g_esLaserAbility[type].g_iHumanAbility);
	g_esLaserCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iHumanAmmo, g_esLaserAbility[type].g_iHumanAmmo);
	g_esLaserCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iHumanCooldown, g_esLaserAbility[type].g_iHumanCooldown);
	g_esLaserCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iHumanDuration, g_esLaserAbility[type].g_iHumanDuration);
	g_esLaserCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iHumanMode, g_esLaserAbility[type].g_iHumanMode);
	g_esLaserCache[tank].g_iLaserAbility = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iLaserAbility, g_esLaserAbility[type].g_iLaserAbility);
	g_esLaserCache[tank].g_iLaserCooldown = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iLaserCooldown, g_esLaserAbility[type].g_iLaserCooldown);
	g_esLaserCache[tank].g_iLaserDuration = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iLaserDuration, g_esLaserAbility[type].g_iLaserDuration);
	g_esLaserCache[tank].g_iLaserMessage = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iLaserMessage, g_esLaserAbility[type].g_iLaserMessage);
	g_esLaserCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_flOpenAreasOnly, g_esLaserAbility[type].g_flOpenAreasOnly);
	g_esLaserCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esLaserPlayer[tank].g_iRequiresHumans, g_esLaserAbility[type].g_iRequiresHumans);
	g_esLaserPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vLaserCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vLaserCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveLaser(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vLaserEventFired(Event event, const char[] name)
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
			vLaserCopyStats2(iBot, iTank);
			vRemoveLaser(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vLaserCopyStats2(iTank, iBot);
			vRemoveLaser(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveLaser(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vLaserReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iAccessFlags, g_esLaserPlayer[tank].g_iAccessFlags)) || g_esLaserCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esLaserCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esLaserCache[tank].g_iLaserAbility == 1 && g_esLaserCache[tank].g_iComboAbility == 0 && !g_esLaserPlayer[tank].g_bActivated)
	{
		vLaserAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esLaserCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLaserCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLaserPlayer[tank].g_iTankType) || (g_esLaserCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLaserCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iAccessFlags, g_esLaserPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esLaserCache[tank].g_iLaserAbility == 1 && g_esLaserCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esLaserPlayer[tank].g_iCooldown != -1 && g_esLaserPlayer[tank].g_iCooldown > iTime;

			switch (g_esLaserCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esLaserPlayer[tank].g_bActivated && !bRecharging)
					{
						vLaserAbility(tank);
					}
					else if (g_esLaserPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman4", (g_esLaserPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esLaserPlayer[tank].g_iAmmoCount < g_esLaserCache[tank].g_iHumanAmmo && g_esLaserCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esLaserPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esLaserPlayer[tank].g_bActivated = true;
							g_esLaserPlayer[tank].g_iAmmoCount++;

							vLaser2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman", g_esLaserPlayer[tank].g_iAmmoCount, g_esLaserCache[tank].g_iHumanAmmo);
						}
						else if (g_esLaserPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman4", (g_esLaserPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esLaserCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esLaserCache[tank].g_iHumanMode == 1 && g_esLaserPlayer[tank].g_bActivated && (g_esLaserPlayer[tank].g_iCooldown == -1 || g_esLaserPlayer[tank].g_iCooldown < GetTime()))
		{
			vLaserReset2(tank);
			vLaserReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vLaserChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveLaser(tank);
}

void vLaser(int tank, int pos = -1)
{
	int iTime = GetTime();
	if (g_esLaserPlayer[tank].g_iCooldown != -1 && g_esLaserPlayer[tank].g_iCooldown > iTime)
	{
		return;
	}

	g_esLaserPlayer[tank].g_bActivated = true;

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLaserCache[tank].g_iHumanAbility == 1)
	{
		g_esLaserPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman", g_esLaserPlayer[tank].g_iAmmoCount, g_esLaserCache[tank].g_iHumanAmmo);
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esLaserCache[tank].g_flLaserInterval;
	DataPack dpLaser;
	CreateDataTimer(flInterval, tTimerLaser, dpLaser, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpLaser.WriteCell(GetClientUserId(tank));
	dpLaser.WriteCell(g_esLaserPlayer[tank].g_iTankType);
	dpLaser.WriteCell(iTime);
	dpLaser.WriteCell(pos);
}

void vLaser2(int tank, int pos = -1)
{
	float flTankPos[3], flTankAngles[3];
	GetClientAbsOrigin(tank, flTankPos);
	GetClientAbsAngles(tank, flTankAngles);
	flTankPos[2] += 65.0;

	int iSurvivor = iGetNearestSurvivor(tank, flTankPos, g_esLaserCache[tank].g_flLaserRange);
	if (bIsSurvivor(iSurvivor))
	{
		float flSurvivorPos[3];
		GetClientEyePosition(iSurvivor, flSurvivorPos);
		flSurvivorPos[2] -= 15.0;
		vAttachParticle2(flSurvivorPos, NULL_VECTOR, PARTICLE_LASER, 3.0);

		EmitSoundToAll(((MT_GetRandomInt(1, 2) == 1) ? SOUND_ELECTRICITY : SOUND_ELECTRICITY2), 0, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, flSurvivorPos, NULL_VECTOR, true, 0.0);
		EmitSoundToAll(((MT_GetRandomInt(1, 2) == 1) ? SOUND_ELECTRICITY : SOUND_ELECTRICITY2), 0, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL, -1, flTankPos, NULL_VECTOR, true, 0.0);

		int iColor[4];
		GetEntityRenderColor(tank, iColor[0], iColor[1], iColor[2], iColor[3]);
		TE_SetupBeamPoints(flTankPos, flSurvivorPos, g_iLaserSprite, 0, 0, 0, 0.5, 5.0, 5.0, 1, 0.0, iColor, 0);
		TE_SendToAll();

		float flDamage = (pos != -1) ? MT_GetCombinationSetting(tank, 3, pos) : g_esLaserCache[tank].g_flLaserDamage;
		if (flDamage > 0.0)
		{
			vDamagePlayer(iSurvivor, tank, MT_GetScaledDamage(flDamage), "1024");
		}

		if (g_esLaserCache[tank].g_iLaserMessage == 1)
		{
			char sTankName[33];
			MT_GetTankName(tank, sTankName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Laser", sTankName, iSurvivor);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Laser", LANG_SERVER, sTankName, iSurvivor);
		}
	}
}

void vLaserAbility(int tank)
{
	if ((g_esLaserPlayer[tank].g_iCooldown != -1 && g_esLaserPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esLaserCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esLaserCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLaserPlayer[tank].g_iTankType) || (g_esLaserCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLaserCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iAccessFlags, g_esLaserPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esLaserPlayer[tank].g_iAmmoCount < g_esLaserCache[tank].g_iHumanAmmo && g_esLaserCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esLaserCache[tank].g_flLaserChance && !g_esLaserPlayer[tank].g_bActivated)
		{
			vLaser(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLaserCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLaserCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserAmmo");
	}
}

void vLaserCopyStats2(int oldTank, int newTank)
{
	g_esLaserPlayer[newTank].g_iAmmoCount = g_esLaserPlayer[oldTank].g_iAmmoCount;
	g_esLaserPlayer[newTank].g_iCooldown = g_esLaserPlayer[oldTank].g_iCooldown;
}

void vRemoveLaser(int tank)
{
	g_esLaserPlayer[tank].g_bActivated = false;
	g_esLaserPlayer[tank].g_iAmmoCount = 0;
	g_esLaserPlayer[tank].g_iCooldown = -1;
}

void vLaserReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveLaser(iPlayer);
		}
	}
}

void vLaserReset2(int tank)
{
	g_esLaserPlayer[tank].g_bActivated = false;

	if (g_esLaserCache[tank].g_iLaserMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Laser2", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Laser2", LANG_SERVER, sTankName);
	}
}

void vLaserReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esLaserAbility[g_esLaserPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esLaserCache[tank].g_iLaserCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esLaserCache[tank].g_iHumanAbility == 1 && g_esLaserCache[tank].g_iHumanMode == 0 && g_esLaserPlayer[tank].g_iAmmoCount < g_esLaserCache[tank].g_iHumanAmmo && g_esLaserCache[tank].g_iHumanAmmo > 0) ? g_esLaserCache[tank].g_iHumanCooldown : iCooldown;
	g_esLaserPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esLaserPlayer[tank].g_iCooldown != -1 && g_esLaserPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "LaserHuman5", (g_esLaserPlayer[tank].g_iCooldown - iTime));
	}
}

Action tTimerLaserCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esLaserAbility[g_esLaserPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLaserPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esLaserPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esLaserCache[iTank].g_iLaserAbility == 0 || g_esLaserPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vLaser(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerLaser(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esLaserCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esLaserCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esLaserPlayer[iTank].g_iTankType) || (g_esLaserCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esLaserCache[iTank].g_iRequiresHumans) || !MT_HasAdminAccess(iTank) || !bHasAdminAccess(iTank, g_esLaserAbility[g_esLaserPlayer[iTank].g_iTankType].g_iAccessFlags, g_esLaserPlayer[iTank].g_iAccessFlags) || !MT_IsTypeEnabled(g_esLaserPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esLaserPlayer[iTank].g_iTankType || !g_esLaserPlayer[iTank].g_bActivated)
	{
		vLaserReset2(iTank);

		return Plugin_Stop;
	}

	int iTime = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esLaserCache[iTank].g_iLaserDuration;
	iDuration = (bIsTank(iTank, MT_CHECK_FAKECLIENT) && g_esLaserCache[iTank].g_iHumanAbility == 1) ? g_esLaserCache[iTank].g_iHumanDuration : iDuration;
	if ((iTime + iDuration) < GetTime())
	{
		vLaserReset2(iTank);
		vLaserReset3(iTank);

		return Plugin_Stop;
	}

	vLaser2(iTank, iPos);

	return Plugin_Continue;
}