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

#define MT_MEDIC_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_MEDIC_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Medic Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank heals nearby special infected.",
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
			strcopy(error, err_max, "\"[MT] Medic Ability\" only supports Left 4 Dead 1 & 2.");

			return APLRes_SilentFailure;
		}
	}

	g_bDedicated = IsDedicatedServer();

	return APLRes_Success;
}
#else
	#if MT_MEDIC_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SPRITE_GLOW "sprites/glow01.vmt"
#define SPRITE_LASERBEAM "sprites/laserbeam.vmt"

#define MT_MEDIC_SECTION "medicability"
#define MT_MEDIC_SECTION2 "medic ability"
#define MT_MEDIC_SECTION3 "medic_ability"
#define MT_MEDIC_SECTION4 "medic"

#define MT_MENU_MEDIC "Medic Ability"

enum struct esMedicPlayer
{
	bool g_bActivated;

	float g_flCloseAreasOnly;
	float g_flDamageBuff;
	float g_flDefaultSpeed;
	float g_flMedicBuffDamage;
	float g_flMedicBuffResistance;
	float g_flMedicBuffSpeed;
	float g_flMedicChance;
	float g_flMedicInterval;
	float g_flMedicRange;
	float g_flOpenAreasOnly;
	float g_flResistanceBuff;

	Handle g_hBuffTimer;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iMedicAbility;
	int g_iMedicCooldown;
	int g_iMedicDuration;
	int g_iMedicField;
	int g_iMedicFieldColor[4];
	int g_iMedicHealth[7];
	int g_iMedicMaxHealth[7];
	int g_iMedicMessage;
	int g_iMedicSymbiosis;
	int g_iRequiresHumans;
	int g_iTankType;
}

esMedicPlayer g_esMedicPlayer[MAXPLAYERS + 1];

enum struct esMedicAbility
{
	float g_flCloseAreasOnly;
	float g_flMedicBuffDamage;
	float g_flMedicBuffResistance;
	float g_flMedicBuffSpeed;
	float g_flMedicChance;
	float g_flMedicInterval;
	float g_flMedicRange;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iMedicAbility;
	int g_iMedicCooldown;
	int g_iMedicDuration;
	int g_iMedicField;
	int g_iMedicFieldColor[4];
	int g_iMedicHealth[7];
	int g_iMedicMaxHealth[7];
	int g_iMedicMessage;
	int g_iMedicSymbiosis;
	int g_iRequiresHumans;
}

esMedicAbility g_esMedicAbility[MT_MAXTYPES + 1];

enum struct esMedicCache
{
	float g_flCloseAreasOnly;
	float g_flMedicBuffDamage;
	float g_flMedicBuffResistance;
	float g_flMedicBuffSpeed;
	float g_flMedicChance;
	float g_flMedicInterval;
	float g_flMedicRange;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iMedicAbility;
	int g_iMedicCooldown;
	int g_iMedicDuration;
	int g_iMedicField;
	int g_iMedicFieldColor[4];
	int g_iMedicHealth[7];
	int g_iMedicMaxHealth[7];
	int g_iMedicMessage;
	int g_iMedicSymbiosis;
	int g_iRequiresHumans;
}

esMedicCache g_esMedicCache[MAXPLAYERS + 1];

int g_iMedicBeamSprite = -1, g_iMedicHaloSprite = -1;

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_medic", cmdMedicInfo, "View information about the Medic ability.");
}
#endif

#if defined MT_ABILITIES_MAIN2
void vMedicMapStart()
#else
public void OnMapStart()
#endif
{
	g_iMedicBeamSprite = PrecacheModel(SPRITE_LASERBEAM, true);
	g_iMedicHaloSprite = PrecacheModel(SPRITE_GLOW, true);

	vMedicReset();
}

#if defined MT_ABILITIES_MAIN2
void vMedicClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnMedicTakeDamage);
	vRemoveMedic(client);
}

#if defined MT_ABILITIES_MAIN2
void vMedicClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRemoveMedic(client);
}

#if defined MT_ABILITIES_MAIN2
void vMedicMapEnd()
#else
public void OnMapEnd()
#endif
{
	vMedicReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdMedicInfo(int client, int args)
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
		case false: vMedicMenu(client, MT_MEDIC_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vMedicMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_MEDIC_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iMedicMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Medic Ability Information");
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

int iMedicMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMedicCache[param1].g_iMedicAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esMedicCache[param1].g_iHumanAmmo - g_esMedicPlayer[param1].g_iAmmoCount), g_esMedicCache[param1].g_iHumanAmmo);
				case 2:
				{
					MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
					MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons4");
				}
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMedicCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esMedicCache[param1].g_iHumanAbility == 1) ? g_esMedicCache[param1].g_iHumanCooldown : g_esMedicCache[param1].g_iMedicCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "MedicDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esMedicCache[param1].g_iHumanAbility == 1) ? g_esMedicCache[param1].g_iHumanDuration : g_esMedicCache[param1].g_iMedicDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esMedicCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vMedicMenu(param1, MT_MEDIC_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pMedic = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "MedicMenu", param1);
			pMedic.SetTitle(sMenuTitle);
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
void vMedicDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_MEDIC, MT_MENU_MEDIC);
}

#if defined MT_ABILITIES_MAIN2
void vMedicMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_MEDIC, false))
	{
		vMedicMenu(client, MT_MEDIC_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_MEDIC, false))
	{
		FormatEx(buffer, size, "%T", "MedicMenu2", client);
	}
}

Action OnMedicTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (bIsInfected(victim) && g_esMedicPlayer[victim].g_flResistanceBuff > 0.0)
		{
			damage *= g_esMedicPlayer[victim].g_flResistanceBuff;

			return Plugin_Changed;
		}
		else if (bIsInfected(attacker) && g_esMedicPlayer[attacker].g_flDamageBuff > 0.0)
		{
			damage *= g_esMedicPlayer[attacker].g_flDamageBuff;

			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vMedicPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_MEDIC);
}

#if defined MT_ABILITIES_MAIN2
void vMedicAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_MEDIC_SECTION);
	list2.PushString(MT_MEDIC_SECTION2);
	list3.PushString(MT_MEDIC_SECTION3);
	list4.PushString(MT_MEDIC_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vMedicCombineAbilities(int tank, int type, const float random, const char[] combo)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMedicCache[tank].g_iHumanAbility != 2)
	{
		g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_MEDIC_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_MEDIC_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_MEDIC_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_MEDIC_SECTION4);
	if (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1)
	{
		if (type == MT_COMBO_MAINRANGE && g_esMedicCache[tank].g_iMedicAbility == 1 && g_esMedicCache[tank].g_iComboAbility == 1 && !g_esMedicPlayer[tank].g_bActivated)
		{
			char sAbilities[320], sSubset[10][32];
			strcopy(sAbilities, sizeof sAbilities, combo);
			ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

			float flDelay = 0.0;
			for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
			{
				if (StrEqual(sSubset[iPos], MT_MEDIC_SECTION, false) || StrEqual(sSubset[iPos], MT_MEDIC_SECTION2, false) || StrEqual(sSubset[iPos], MT_MEDIC_SECTION3, false) || StrEqual(sSubset[iPos], MT_MEDIC_SECTION4, false))
				{
					g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iComboPosition = iPos;

					if (random <= MT_GetCombinationSetting(tank, 1, iPos))
					{
						flDelay = MT_GetCombinationSetting(tank, 4, iPos);

						switch (flDelay)
						{
							case 0.0: vMedic(tank, iPos);
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerMedicCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vMedicConfigsLoad(int mode)
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
				g_esMedicAbility[iIndex].g_iAccessFlags = 0;
				g_esMedicAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esMedicAbility[iIndex].g_iComboAbility = 0;
				g_esMedicAbility[iIndex].g_iComboPosition = -1;
				g_esMedicAbility[iIndex].g_iHumanAbility = 0;
				g_esMedicAbility[iIndex].g_iHumanAmmo = 5;
				g_esMedicAbility[iIndex].g_iHumanCooldown = 0;
				g_esMedicAbility[iIndex].g_iHumanDuration = 5;
				g_esMedicAbility[iIndex].g_iHumanMode = 1;
				g_esMedicAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esMedicAbility[iIndex].g_iRequiresHumans = 0;
				g_esMedicAbility[iIndex].g_iMedicAbility = 0;
				g_esMedicAbility[iIndex].g_iMedicMessage = 0;
				g_esMedicAbility[iIndex].g_flMedicBuffDamage = 1.25;
				g_esMedicAbility[iIndex].g_flMedicBuffResistance = 0.75;
				g_esMedicAbility[iIndex].g_flMedicBuffSpeed = 1.25;
				g_esMedicAbility[iIndex].g_flMedicChance = 33.3;
				g_esMedicAbility[iIndex].g_iMedicCooldown = 0;
				g_esMedicAbility[iIndex].g_iMedicDuration = 0;
				g_esMedicAbility[iIndex].g_iMedicField = 1;
				g_esMedicAbility[iIndex].g_iMedicFieldColor[0] = 0;
				g_esMedicAbility[iIndex].g_iMedicFieldColor[1] = 255;
				g_esMedicAbility[iIndex].g_iMedicFieldColor[2] = 0;
				g_esMedicAbility[iIndex].g_iMedicFieldColor[3] = 255;
				g_esMedicAbility[iIndex].g_flMedicInterval = 5.0;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[0] = 250;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[1] = 50;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[2] = 250;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[3] = 100;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[4] = 325;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[5] = 600;
				g_esMedicAbility[iIndex].g_iMedicMaxHealth[6] = 8000;
				g_esMedicAbility[iIndex].g_flMedicRange = 500.0;
				g_esMedicAbility[iIndex].g_iMedicSymbiosis = 1;

				for (int iPos = 0; iPos < (sizeof esMedicAbility::g_iMedicHealth); iPos++)
				{
					g_esMedicAbility[iIndex].g_iMedicHealth[iPos] = 25;
				}
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esMedicPlayer[iPlayer].g_iAccessFlags = 0;
					g_esMedicPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esMedicPlayer[iPlayer].g_iComboAbility = 0;
					g_esMedicPlayer[iPlayer].g_iHumanAbility = 0;
					g_esMedicPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esMedicPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esMedicPlayer[iPlayer].g_iHumanDuration = 0;
					g_esMedicPlayer[iPlayer].g_iHumanMode = 0;
					g_esMedicPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esMedicPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esMedicPlayer[iPlayer].g_iMedicAbility = 0;
					g_esMedicPlayer[iPlayer].g_iMedicMessage = 0;
					g_esMedicPlayer[iPlayer].g_flMedicBuffDamage = 0.0;
					g_esMedicPlayer[iPlayer].g_flMedicBuffResistance = 0.0;
					g_esMedicPlayer[iPlayer].g_flMedicBuffSpeed = 0.0;
					g_esMedicPlayer[iPlayer].g_flMedicChance = 0.0;
					g_esMedicPlayer[iPlayer].g_iMedicCooldown = 0;
					g_esMedicPlayer[iPlayer].g_iMedicDuration = 0;
					g_esMedicPlayer[iPlayer].g_iMedicField = 0;
					g_esMedicPlayer[iPlayer].g_iMedicFieldColor[3] = 255;
					g_esMedicPlayer[iPlayer].g_flMedicInterval = 0.0;
					g_esMedicPlayer[iPlayer].g_flMedicRange = 0.0;
					g_esMedicPlayer[iPlayer].g_iMedicSymbiosis = 0;

					for (int iPos = 0; iPos < (sizeof esMedicPlayer::g_iMedicHealth); iPos++)
					{
						g_esMedicPlayer[iPlayer].g_iMedicHealth[iPos] = 0;
						g_esMedicPlayer[iPlayer].g_iMedicMaxHealth[iPos] = 0;

						if (iPos < (sizeof esMedicPlayer::g_iMedicFieldColor - 1))
						{
							g_esMedicPlayer[iPlayer].g_iMedicFieldColor[iPos] = -1;
						}
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esMedicPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esMedicPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esMedicPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esMedicPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esMedicPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esMedicPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esMedicPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esMedicPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esMedicPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esMedicPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esMedicPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esMedicPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esMedicPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esMedicPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esMedicPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esMedicPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esMedicPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esMedicPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esMedicPlayer[admin].g_iMedicAbility = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esMedicPlayer[admin].g_iMedicAbility, value, 0, 1);
		g_esMedicPlayer[admin].g_iMedicMessage = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esMedicPlayer[admin].g_iMedicMessage, value, 0, 1);
		g_esMedicPlayer[admin].g_flMedicBuffDamage = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicBuffDamage", "Medic Buff Damage", "Medic_Buff_Damage", "buffdmg", g_esMedicPlayer[admin].g_flMedicBuffDamage, value, 0.0, 99999.0);
		g_esMedicPlayer[admin].g_flMedicBuffResistance = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicBuffResistance", "Medic Buff Resistance", "Medic_Buff_Resistance", "buffres", g_esMedicPlayer[admin].g_flMedicBuffResistance, value, 0.0, 1.0);
		g_esMedicPlayer[admin].g_flMedicBuffSpeed = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicBuffSpeed", "Medic Buff Speed", "Medic_Buff_Speed", "buffspeed", g_esMedicPlayer[admin].g_flMedicBuffSpeed, value, 0.0, 10.0);
		g_esMedicPlayer[admin].g_flMedicChance = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicChance", "Medic Chance", "Medic_Chance", "chance", g_esMedicPlayer[admin].g_flMedicChance, value, 0.0, 100.0);
		g_esMedicPlayer[admin].g_iMedicCooldown = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicCooldown", "Medic Cooldown", "Medic_Cooldown", "cooldown", g_esMedicPlayer[admin].g_iMedicCooldown, value, 0, 99999);
		g_esMedicPlayer[admin].g_iMedicDuration = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicDuration", "Medic Duration", "Medic_Duration", "duration", g_esMedicPlayer[admin].g_iMedicDuration, value, 0, 99999);
		g_esMedicPlayer[admin].g_iMedicField = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicField", "Medic Field", "Medic_Field", "field", g_esMedicPlayer[admin].g_iMedicField, value, 0, 1);
		g_esMedicPlayer[admin].g_flMedicInterval = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicInterval", "Medic Interval", "Medic_Interval", "interval", g_esMedicPlayer[admin].g_flMedicInterval, value, 0.1, 99999.0);
		g_esMedicPlayer[admin].g_flMedicRange = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicRange", "Medic Range", "Medic_Range", "range", g_esMedicPlayer[admin].g_flMedicRange, value, 1.0, 99999.0);
		g_esMedicPlayer[admin].g_iMedicSymbiosis = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicSymbiosis", "Medic Symbiosis", "Medic_Symbiosis", "symbiosis", g_esMedicPlayer[admin].g_iMedicSymbiosis, value, 0, 1);
		g_esMedicPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);

		if (StrEqual(subsection, MT_MEDIC_SECTION, false) || StrEqual(subsection, MT_MEDIC_SECTION2, false) || StrEqual(subsection, MT_MEDIC_SECTION3, false) || StrEqual(subsection, MT_MEDIC_SECTION4, false))
		{
			if (StrEqual(key, "MedicFieldColor", false) || StrEqual(key, "Medic Field Color", false) || StrEqual(key, "Medic_Field_Color", false) || StrEqual(key, "fieldcolor", false))
			{
				char sSet[3][4], sValue[12];
				MT_GetConfigColors(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof sSet - 1); iPos++)
				{
					g_esMedicPlayer[admin].g_iMedicFieldColor[iPos] = (sSet[iPos][0] != '\0') ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
				}

				g_esMedicPlayer[admin].g_iMedicFieldColor[3] = 255;
			}
			else
			{
				char sSet[7][11], sValue[77];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof sSet); iPos++)
				{
					g_esMedicPlayer[admin].g_iMedicHealth[iPos] = iGetClampedValue(key, "MedicHealth", "Medic Health", "Medic_Health", "health", g_esMedicPlayer[admin].g_iMedicHealth[iPos], sSet[iPos], MT_MAX_HEALTH_REDUCTION, MT_MAXHEALTH);
					g_esMedicPlayer[admin].g_iMedicMaxHealth[iPos] = iGetClampedValue(key, "MedicMaxHealth", "Medic Max Health", "Medic_Max_Health", "maxhealth", g_esMedicPlayer[admin].g_iMedicMaxHealth[iPos], sSet[iPos], 1, MT_MAXHEALTH);
				}
			}
		}
	}

	if (mode < 3 && type > 0)
	{
		g_esMedicAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esMedicAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esMedicAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esMedicAbility[type].g_iComboAbility, value, 0, 1);
		g_esMedicAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esMedicAbility[type].g_iHumanAbility, value, 0, 2);
		g_esMedicAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esMedicAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esMedicAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esMedicAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esMedicAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esMedicAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esMedicAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esMedicAbility[type].g_iHumanMode, value, 0, 1);
		g_esMedicAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esMedicAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esMedicAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esMedicAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esMedicAbility[type].g_iMedicAbility = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esMedicAbility[type].g_iMedicAbility, value, 0, 1);
		g_esMedicAbility[type].g_iMedicMessage = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esMedicAbility[type].g_iMedicMessage, value, 0, 1);
		g_esMedicAbility[type].g_flMedicBuffDamage = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicBuffDamage", "Medic Buff Damage", "Medic_Buff_Damage", "buffdmg", g_esMedicAbility[type].g_flMedicBuffDamage, value, 0.0, 99999.0);
		g_esMedicAbility[type].g_flMedicBuffResistance = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicBuffResistance", "Medic Buff Resistance", "Medic_Buff_Resistance", "buffres", g_esMedicAbility[type].g_flMedicBuffResistance, value, 0.0, 1.0);
		g_esMedicAbility[type].g_flMedicBuffSpeed = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicBuffSpeed", "Medic Buff Speed", "Medic_Buff_Speed", "buffspeed", g_esMedicAbility[type].g_flMedicBuffSpeed, value, 0.0, 10.0);
		g_esMedicAbility[type].g_flMedicChance = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicChance", "Medic Chance", "Medic_Chance", "chance", g_esMedicAbility[type].g_flMedicChance, value, 0.0, 100.0);
		g_esMedicAbility[type].g_iMedicCooldown = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicCooldown", "Medic Cooldown", "Medic_Cooldown", "cooldown", g_esMedicAbility[type].g_iMedicCooldown, value, 0, 99999);
		g_esMedicAbility[type].g_iMedicDuration = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicDuration", "Medic Duration", "Medic_Duration", "duration", g_esMedicAbility[type].g_iMedicDuration, value, 0, 99999);
		g_esMedicAbility[type].g_iMedicField = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicField", "Medic Field", "Medic_Field", "field", g_esMedicAbility[type].g_iMedicField, value, 0, 1);
		g_esMedicAbility[type].g_flMedicInterval = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicInterval", "Medic Interval", "Medic_Interval", "interval", g_esMedicAbility[type].g_flMedicInterval, value, 0.1, 99999.0);
		g_esMedicAbility[type].g_flMedicRange = flGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicRange", "Medic Range", "Medic_Range", "range", g_esMedicAbility[type].g_flMedicRange, value, 1.0, 99999.0);
		g_esMedicAbility[type].g_iMedicSymbiosis = iGetKeyValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "MedicSymbiosis", "Medic Symbiosis", "Medic_Symbiosis", "symbiosis", g_esMedicAbility[type].g_iMedicSymbiosis, value, 0, 1);
		g_esMedicAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_MEDIC_SECTION, MT_MEDIC_SECTION2, MT_MEDIC_SECTION3, MT_MEDIC_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);

		if (StrEqual(subsection, MT_MEDIC_SECTION, false) || StrEqual(subsection, MT_MEDIC_SECTION2, false) || StrEqual(subsection, MT_MEDIC_SECTION3, false) || StrEqual(subsection, MT_MEDIC_SECTION4, false))
		{
			if (StrEqual(key, "MedicFieldColor", false) || StrEqual(key, "Medic Field Color", false) || StrEqual(key, "Medic_Field_Color", false) || StrEqual(key, "fieldcolor", false))
			{
				char sSet[3][4], sValue[12];
				MT_GetConfigColors(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof sSet - 1); iPos++)
				{
					g_esMedicAbility[type].g_iMedicFieldColor[iPos] = (sSet[iPos][0] != '\0') ? iClamp(StringToInt(sSet[iPos]), 0, 255) : -1;
				}

				g_esMedicAbility[type].g_iMedicFieldColor[3] = 255;
			}
			else
			{
				char sSet[7][11], sValue[77];
				strcopy(sValue, sizeof sValue, value);
				ReplaceString(sValue, sizeof sValue, " ", "");
				ExplodeString(sValue, ",", sSet, sizeof sSet, sizeof sSet[]);
				for (int iPos = 0; iPos < (sizeof sSet); iPos++)
				{
					g_esMedicAbility[type].g_iMedicHealth[iPos] = iGetClampedValue(key, "MedicHealth", "Medic Health", "Medic_Health", "health", g_esMedicAbility[type].g_iMedicHealth[iPos], sSet[iPos], MT_MAX_HEALTH_REDUCTION, MT_MAXHEALTH);
					g_esMedicAbility[type].g_iMedicMaxHealth[iPos] = iGetClampedValue(key, "MedicMaxHealth", "Medic Max Health", "Medic_Max_Health", "maxhealth", g_esMedicAbility[type].g_iMedicMaxHealth[iPos], sSet[iPos], 1, MT_MAXHEALTH);
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esMedicCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flCloseAreasOnly, g_esMedicAbility[type].g_flCloseAreasOnly);
	g_esMedicCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iComboAbility, g_esMedicAbility[type].g_iComboAbility);
	g_esMedicCache[tank].g_flMedicBuffDamage = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flMedicBuffDamage, g_esMedicAbility[type].g_flMedicBuffDamage);
	g_esMedicCache[tank].g_flMedicBuffResistance = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flMedicBuffResistance, g_esMedicAbility[type].g_flMedicBuffResistance);
	g_esMedicCache[tank].g_flMedicBuffSpeed = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flMedicBuffSpeed, g_esMedicAbility[type].g_flMedicBuffSpeed);
	g_esMedicCache[tank].g_flMedicChance = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flMedicChance, g_esMedicAbility[type].g_flMedicChance);
	g_esMedicCache[tank].g_flMedicInterval = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flMedicInterval, g_esMedicAbility[type].g_flMedicInterval);
	g_esMedicCache[tank].g_flMedicRange = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flMedicRange, g_esMedicAbility[type].g_flMedicRange);
	g_esMedicCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iHumanAbility, g_esMedicAbility[type].g_iHumanAbility);
	g_esMedicCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iHumanAmmo, g_esMedicAbility[type].g_iHumanAmmo);
	g_esMedicCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iHumanCooldown, g_esMedicAbility[type].g_iHumanCooldown);
	g_esMedicCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iHumanDuration, g_esMedicAbility[type].g_iHumanDuration);
	g_esMedicCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iHumanMode, g_esMedicAbility[type].g_iHumanMode);
	g_esMedicCache[tank].g_iMedicAbility = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicAbility, g_esMedicAbility[type].g_iMedicAbility);
	g_esMedicCache[tank].g_iMedicCooldown = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicCooldown, g_esMedicAbility[type].g_iMedicCooldown);
	g_esMedicCache[tank].g_iMedicDuration = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicDuration, g_esMedicAbility[type].g_iMedicDuration);
	g_esMedicCache[tank].g_iMedicField = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicField, g_esMedicAbility[type].g_iMedicField);
	g_esMedicCache[tank].g_iMedicMessage = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicMessage, g_esMedicAbility[type].g_iMedicMessage);
	g_esMedicCache[tank].g_iMedicSymbiosis = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicSymbiosis, g_esMedicAbility[type].g_iMedicSymbiosis);
	g_esMedicCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_flOpenAreasOnly, g_esMedicAbility[type].g_flOpenAreasOnly);
	g_esMedicCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iRequiresHumans, g_esMedicAbility[type].g_iRequiresHumans);
	g_esMedicPlayer[tank].g_iTankType = apply ? type : 0;

	for (int iPos = 0; iPos < (sizeof esMedicCache::g_iMedicHealth); iPos++)
	{
		g_esMedicCache[tank].g_iMedicHealth[iPos] = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicHealth[iPos], g_esMedicAbility[type].g_iMedicHealth[iPos]);
		g_esMedicCache[tank].g_iMedicMaxHealth[iPos] = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicMaxHealth[iPos], g_esMedicAbility[type].g_iMedicMaxHealth[iPos]);

		if (iPos < sizeof esMedicCache::g_iMedicFieldColor)
		{
			g_esMedicCache[tank].g_iMedicFieldColor[iPos] = iGetSettingValue(apply, bHuman, g_esMedicPlayer[tank].g_iMedicFieldColor[iPos], g_esMedicAbility[type].g_iMedicFieldColor[iPos]);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vMedicCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveMedic(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vMedicEventFired(Event event, const char[] name)
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
			vMedicCopyStats2(iBot, iTank);
			vRemoveMedic(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vMedicCopyStats2(iTank, iBot);
			vRemoveMedic(iTank);
		}
	}
	else if (StrEqual(name, "player_death"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveMedic(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vMedicReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iAccessFlags, g_esMedicPlayer[tank].g_iAccessFlags)) || g_esMedicCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esMedicCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esMedicCache[tank].g_iMedicAbility == 1 && g_esMedicCache[tank].g_iComboAbility == 0 && !g_esMedicPlayer[tank].g_bActivated)
	{
		vMedicAbility(tank);
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esMedicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMedicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMedicPlayer[tank].g_iTankType) || (g_esMedicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMedicCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iAccessFlags, g_esMedicPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_MAIN_KEY) && g_esMedicCache[tank].g_iMedicAbility == 1 && g_esMedicCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();
			bool bRecharging = g_esMedicPlayer[tank].g_iCooldown != -1 && g_esMedicPlayer[tank].g_iCooldown > iTime;

			switch (g_esMedicCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esMedicPlayer[tank].g_bActivated && !bRecharging)
					{
						vMedicAbility(tank);
					}
					else if (g_esMedicPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman3");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman4", (g_esMedicPlayer[tank].g_iCooldown - iTime));
					}
				}
				case 1:
				{
					if (g_esMedicPlayer[tank].g_iAmmoCount < g_esMedicCache[tank].g_iHumanAmmo && g_esMedicCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esMedicPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esMedicPlayer[tank].g_bActivated = true;
							g_esMedicPlayer[tank].g_iAmmoCount++;

							vMedic2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman", g_esMedicPlayer[tank].g_iAmmoCount, g_esMedicCache[tank].g_iHumanAmmo);
						}
						else if (g_esMedicPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman3");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman4", (g_esMedicPlayer[tank].g_iCooldown - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicAmmo");
					}
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esMedicCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esMedicCache[tank].g_iHumanMode == 1 && g_esMedicPlayer[tank].g_bActivated && (g_esMedicPlayer[tank].g_iCooldown == -1 || g_esMedicPlayer[tank].g_iCooldown < GetTime()))
		{
			vMedicReset2(tank);
			vMedicReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vMedicChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveMedic(tank);
}

void vMedic(int tank, int pos = -1)
{
	if (g_esMedicPlayer[tank].g_iCooldown != -1 && g_esMedicPlayer[tank].g_iCooldown > GetTime())
	{
		return;
	}

	g_esMedicPlayer[tank].g_bActivated = true;

	vMedic2(tank, pos);

	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMedicCache[tank].g_iHumanAbility == 1)
	{
		g_esMedicPlayer[tank].g_iAmmoCount++;

		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman", g_esMedicPlayer[tank].g_iAmmoCount, g_esMedicCache[tank].g_iHumanAmmo);
	}

	if (g_esMedicCache[tank].g_iMedicMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Medic", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Medic", LANG_SERVER, sTankName);
	}
}

void vMedic2(int tank, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esMedicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMedicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMedicPlayer[tank].g_iTankType) || (g_esMedicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMedicCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iAccessFlags, g_esMedicPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esMedicCache[tank].g_flMedicInterval;
	DataPack dpMedic;
	CreateDataTimer(flInterval, tTimerMedic, dpMedic, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpMedic.WriteCell(GetClientUserId(tank));
	dpMedic.WriteCell(g_esMedicPlayer[tank].g_iTankType);
	dpMedic.WriteCell(GetTime());
	dpMedic.WriteCell(pos);
}

void vMedic3(int special, int tank, int duration)
{
	int iHealth = 0, iValue = 0, iLimit = 0, iMaxHealth = 0, iNewHealth = 0, iLeftover = 0, iExtraHealth = 0, iExtraHealth2 = 0, iRealHealth = 0, iTotalHealth = 0;
	iHealth = GetEntProp(special, Prop_Data, "m_iHealth");
	iValue = iGetHealth(tank, special);
	iLimit = iGetMaxHealth(tank, special);
	iMaxHealth = MT_TankMaxHealth(special, 1);
	iNewHealth = (iHealth + iValue);
	iLeftover = (iNewHealth > iLimit) ? (iNewHealth - iLimit) : iNewHealth;
	iExtraHealth = (iNewHealth > iLimit) ? iLimit : iNewHealth;
	iExtraHealth2 = (iNewHealth < iHealth) ? 1 : iNewHealth;
	iRealHealth = (iNewHealth >= 0) ? iExtraHealth : iExtraHealth2;
	iTotalHealth = (iNewHealth > iLimit) ? iLeftover : iValue;
	MT_TankMaxHealth(special, 3, (iMaxHealth + iTotalHealth));
	SetEntProp(special, Prop_Data, "m_iHealth", iRealHealth);

	g_esMedicPlayer[special].g_flDamageBuff = g_esMedicCache[tank].g_flMedicBuffDamage;
	g_esMedicPlayer[special].g_flDefaultSpeed = MT_GetRunSpeed(tank);
	g_esMedicPlayer[special].g_flResistanceBuff = g_esMedicCache[tank].g_flMedicBuffResistance;

	if (g_esMedicCache[tank].g_flMedicBuffSpeed > 0.0)
	{
		SetEntPropFloat(special, Prop_Send, "m_flLaggedMovementValue", (g_esMedicPlayer[special].g_flDefaultSpeed * g_esMedicCache[tank].g_flMedicBuffSpeed));
	}

	delete g_esMedicPlayer[special].g_hBuffTimer;

	float flDuration = float(duration);
	if (flDuration > 0.0)
	{
		g_esMedicPlayer[special].g_hBuffTimer = CreateTimer(flDuration, tTimerRemoveBuffs, GetClientUserId(special), TIMER_FLAG_NO_MAPCHANGE);
	}

	if (g_esMedicCache[tank].g_iMedicMessage == 1)
	{
		char sTankName[33], sInfectedName[33];
		MT_GetTankName(tank, sTankName);
		if (bIsSpecialInfected(special, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			MT_PrintToChatAll("%s %t", MT_TAG2, "Medic2", sTankName, special);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Medic2", LANG_SERVER, sTankName, special);
		}
		else
		{
			MT_GetTankName(special, sInfectedName);
			MT_PrintToChatAll("%s %t", MT_TAG2, "Medic3", sTankName, sInfectedName);
			MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Medic3", LANG_SERVER, sTankName, sInfectedName);
		}
	}
}

void vMedicAbility(int tank)
{
	if ((g_esMedicPlayer[tank].g_iCooldown != -1 && g_esMedicPlayer[tank].g_iCooldown > GetTime()) || bIsAreaNarrow(tank, g_esMedicCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esMedicCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMedicPlayer[tank].g_iTankType) || (g_esMedicCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMedicCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iAccessFlags, g_esMedicPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esMedicPlayer[tank].g_iAmmoCount < g_esMedicCache[tank].g_iHumanAmmo && g_esMedicCache[tank].g_iHumanAmmo > 0))
	{
		if (MT_GetRandomFloat(0.1, 100.0) <= g_esMedicCache[tank].g_flMedicChance)
		{
			vMedic(tank);
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMedicCache[tank].g_iHumanAbility == 1)
		{
			MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman2");
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMedicCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicAmmo");
	}
}

void vMedicCopyStats2(int oldTank, int newTank)
{
	g_esMedicPlayer[newTank].g_iAmmoCount = g_esMedicPlayer[oldTank].g_iAmmoCount;
	g_esMedicPlayer[newTank].g_iCooldown = g_esMedicPlayer[oldTank].g_iCooldown;
}

void vRemoveMedic(int tank)
{
	g_esMedicPlayer[tank].g_bActivated = false;
	g_esMedicPlayer[tank].g_hBuffTimer = null;
	g_esMedicPlayer[tank].g_flDamageBuff = 0.0;
	g_esMedicPlayer[tank].g_flDefaultSpeed = 0.0;
	g_esMedicPlayer[tank].g_flResistanceBuff = 0.0;
	g_esMedicPlayer[tank].g_iAmmoCount = 0;
	g_esMedicPlayer[tank].g_iCooldown = -1;
}

void vMedicReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveMedic(iPlayer);
		}
	}
}

void vMedicReset2(int tank)
{
	g_esMedicPlayer[tank].g_bActivated = false;

	if (g_esMedicCache[tank].g_iMedicMessage == 1)
	{
		char sTankName[33];
		MT_GetTankName(tank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Medic4", sTankName);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Medic4", LANG_SERVER, sTankName);
	}
}

void vMedicReset3(int tank)
{
	int iTime = GetTime(), iPos = g_esMedicAbility[g_esMedicPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esMedicCache[tank].g_iMedicCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esMedicCache[tank].g_iHumanAbility == 1 && g_esMedicCache[tank].g_iHumanMode == 0 && g_esMedicPlayer[tank].g_iAmmoCount < g_esMedicCache[tank].g_iHumanAmmo && g_esMedicCache[tank].g_iHumanAmmo > 0) ? g_esMedicCache[tank].g_iHumanCooldown : iCooldown;
	g_esMedicPlayer[tank].g_iCooldown = (iTime + iCooldown);
	if (g_esMedicPlayer[tank].g_iCooldown != -1 && g_esMedicPlayer[tank].g_iCooldown > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "MedicHuman5", (g_esMedicPlayer[tank].g_iCooldown - iTime));
	}
}

int iGetHealth(int tank, int infected)
{
	int iClass = GetEntProp(infected, Prop_Send, "m_zombieClass");

	switch (iClass)
	{
		case 1: return g_esMedicCache[tank].g_iMedicHealth[iClass - 1];
		case 2: return g_esMedicCache[tank].g_iMedicHealth[iClass - 1];
		case 3: return g_esMedicCache[tank].g_iMedicHealth[iClass - 1];
		case 4: return g_esMedicCache[tank].g_iMedicHealth[iClass - 1];
		case 5: return g_bSecondGame ? g_esMedicCache[tank].g_iMedicHealth[iClass - 1] : g_esMedicCache[tank].g_iMedicHealth[iClass + 1];
		case 6: return g_esMedicCache[tank].g_iMedicHealth[iClass - 1];
		case 8: return g_esMedicCache[tank].g_iMedicHealth[iClass - 2];
	}

	return 0;
}

int iGetMaxHealth(int tank, int infected)
{
	int iClass = GetEntProp(infected, Prop_Send, "m_zombieClass");

	switch (iClass)
	{
		case 1: return g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 1];
		case 2: return g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 1];
		case 3: return g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 1];
		case 4: return g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 1];
		case 5: return g_bSecondGame ? g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 1] : g_esMedicCache[tank].g_iMedicMaxHealth[iClass + 1];
		case 6: return g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 1];
		case 8: return g_esMedicCache[tank].g_iMedicMaxHealth[iClass - 2];
	}

	return 0;
}

int[] iGetRandomColors(int tank)
{
	for (int iPos = 0; iPos < (sizeof esMedicCache::g_iMedicFieldColor - 1); iPos++)
	{
		g_esMedicCache[tank].g_iMedicFieldColor[iPos] = iGetRandomColor(g_esMedicCache[tank].g_iMedicFieldColor[iPos]);
	}

	g_esMedicCache[tank].g_iMedicFieldColor[3] = 255;

	return g_esMedicCache[tank].g_iMedicFieldColor;
}

Action tTimerMedicCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esMedicAbility[g_esMedicPlayer[iTank].g_iTankType].g_iAccessFlags, g_esMedicPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esMedicPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esMedicCache[iTank].g_iMedicAbility == 0 || g_esMedicPlayer[iTank].g_bActivated)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vMedic(iTank, iPos);

	return Plugin_Continue;
}

Action tTimerMedic(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsPlayerIncapacitated(iTank) || bIsAreaNarrow(iTank, g_esMedicCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esMedicCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esMedicPlayer[iTank].g_iTankType) || (g_esMedicCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esMedicCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esMedicAbility[g_esMedicPlayer[iTank].g_iTankType].g_iAccessFlags, g_esMedicPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esMedicPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esMedicPlayer[iTank].g_iTankType || g_esMedicCache[iTank].g_iMedicAbility == 0 || !g_esMedicPlayer[iTank].g_bActivated)
	{
		vMedicReset2(iTank);

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esMedicCache[iTank].g_iMedicDuration;
	iDuration = (bHuman && g_esMedicCache[iTank].g_iHumanAbility == 1) ? g_esMedicCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esMedicCache[iTank].g_iHumanAbility == 1 && g_esMedicCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esMedicPlayer[iTank].g_iCooldown == -1 || g_esMedicPlayer[iTank].g_iCooldown < iCurrentTime))
	{
		vMedicReset2(iTank);
		vMedicReset3(iTank);

		return Plugin_Stop;
	}

	float flTankPos[3], flInfectedPos[3];
	GetClientAbsOrigin(iTank, flTankPos);
	float flRange = (iPos != -1) ? MT_GetCombinationSetting(iTank, 9, iPos) : g_esMedicCache[iTank].g_flMedicRange;

	if (g_esMedicCache[iTank].g_iMedicField == 1)
	{
		flTankPos[2] += 10.0;
		TE_SetupBeamRingPoint(flTankPos, 50.0, flRange, g_iMedicBeamSprite, g_iMedicHaloSprite, 0, 0, 1.0, 3.0, 0.0, iGetRandomColors(iTank), 0, 0);
		TE_SendToAll();
	}

	int iCount = 0;
	for (int iInfected = 1; iInfected <= MaxClients; iInfected++)
	{
		if (((MT_IsTankSupported(iInfected, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !bIsPlayerIncapacitated(iInfected)) || bIsSpecialInfected(iInfected, MT_CHECK_INGAME|MT_CHECK_ALIVE)) && iTank != iInfected)
		{
			GetClientAbsOrigin(iInfected, flInfectedPos);
			if (GetVectorDistance(flTankPos, flInfectedPos) <= flRange)
			{
				vMedic3(iInfected, iTank, iDuration);

				iCount++;
			}
		}
	}

	if (g_esMedicCache[iTank].g_iMedicSymbiosis == 1 && iCount > 0)
	{
		vMedic3(iTank, iTank, iDuration);
	}

	return Plugin_Continue;
}

Action tTimerRemoveBuffs(Handle timer, int userid)
{
	int iInfected = GetClientOfUserId(userid);
	if (!bIsInfected(iInfected))
	{
		g_esMedicPlayer[iInfected].g_hBuffTimer = null;

		return Plugin_Stop;
	}

	float flSpeed = bIsTank(iInfected) ? g_esMedicPlayer[iInfected].g_flDefaultSpeed : 1.0;
	g_esMedicPlayer[iInfected].g_hBuffTimer = null;
	g_esMedicPlayer[iInfected].g_flDamageBuff = 0.0;
	g_esMedicPlayer[iInfected].g_flResistanceBuff = 0.0;
	g_esMedicPlayer[iInfected].g_flDefaultSpeed = 0.0;

	SetEntPropFloat(iInfected, Prop_Send, "m_flLaggedMovementValue", flSpeed);

	return Plugin_Continue;
}