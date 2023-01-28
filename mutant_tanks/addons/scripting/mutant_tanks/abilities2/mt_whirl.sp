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

#define MT_WHIRL_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_WHIRL_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Whirl Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank makes survivors' screens whirl.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Whirl Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_WHIRL_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SPRITE_DOT "sprites/dot.vmt"

#define MT_WHIRL_SECTION "whirlability"
#define MT_WHIRL_SECTION2 "whirl ability"
#define MT_WHIRL_SECTION3 "whirl_ability"
#define MT_WHIRL_SECTION4 "whirl"

#define MT_MENU_WHIRL "Whirl Ability"

enum struct esWhirlPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flWhirlChance;
	float g_flWhirlRange;
	float g_flWhirlRangeChance;
	float g_flWhirlSpeed;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
	int g_iWhirlAbility;
	int g_iWhirlAxis;
	int g_iWhirlCooldown;
	int g_iWhirlDuration;
	int g_iWhirlEffect;
	int g_iWhirlHit;
	int g_iWhirlHitMode;
	int g_iWhirlMessage;
	int g_iWhirlRangeCooldown;
}

esWhirlPlayer g_esWhirlPlayer[MAXPLAYERS + 1];

enum struct esWhirlAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flWhirlChance;
	float g_flWhirlRange;
	float g_flWhirlRangeChance;
	float g_flWhirlSpeed;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iWhirlAbility;
	int g_iWhirlAxis;
	int g_iWhirlCooldown;
	int g_iWhirlDuration;
	int g_iWhirlEffect;
	int g_iWhirlHit;
	int g_iWhirlHitMode;
	int g_iWhirlMessage;
	int g_iWhirlRangeCooldown;
}

esWhirlAbility g_esWhirlAbility[MT_MAXTYPES + 1];

enum struct esWhirlCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flWhirlChance;
	float g_flWhirlRange;
	float g_flWhirlRangeChance;
	float g_flWhirlSpeed;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iWhirlAbility;
	int g_iWhirlAxis;
	int g_iWhirlCooldown;
	int g_iWhirlDuration;
	int g_iWhirlEffect;
	int g_iWhirlHit;
	int g_iWhirlHitMode;
	int g_iWhirlMessage;
	int g_iWhirlRangeCooldown;
}

esWhirlCache g_esWhirlCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_whirl", cmdWhirlInfo, "View information about the Whirl ability.");

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
void vWhirlMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheModel(SPRITE_DOT, true);

	vWhirlReset();
}

#if defined MT_ABILITIES_MAIN2
void vWhirlClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnWhirlTakeDamage);
	vWhirlReset3(client);
}

#if defined MT_ABILITIES_MAIN2
void vWhirlClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vWhirlReset3(client);
}

#if defined MT_ABILITIES_MAIN2
void vWhirlMapEnd()
#else
public void OnMapEnd()
#endif
{
	vWhirlReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdWhirlInfo(int client, int args)
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
		case false: vWhirlMenu(client, MT_WHIRL_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vWhirlMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_WHIRL_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iWhirlMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Whirl Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iWhirlMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esWhirlCache[param1].g_iWhirlAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esWhirlCache[param1].g_iHumanAmmo - g_esWhirlPlayer[param1].g_iAmmoCount), g_esWhirlCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esWhirlCache[param1].g_iHumanAbility == 1) ? g_esWhirlCache[param1].g_iHumanCooldown : g_esWhirlCache[param1].g_iWhirlCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "WhirlDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esWhirlCache[param1].g_iWhirlDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esWhirlCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esWhirlCache[param1].g_iHumanAbility == 1) ? g_esWhirlCache[param1].g_iHumanRangeCooldown : g_esWhirlCache[param1].g_iWhirlRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vWhirlMenu(param1, MT_WHIRL_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pWhirl = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "WhirlMenu", param1);
			pWhirl.SetTitle(sMenuTitle);
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
					case 3: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Cooldown", param1);
					case 4: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Details", param1);
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "Duration", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 7: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vWhirlDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_WHIRL, MT_MENU_WHIRL);
}

#if defined MT_ABILITIES_MAIN2
void vWhirlMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_WHIRL, false))
	{
		vWhirlMenu(client, MT_WHIRL_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_WHIRL, false))
	{
		FormatEx(buffer, size, "%T", "WhirlMenu2", client);
	}
}

Action OnWhirlTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esWhirlCache[attacker].g_iWhirlHitMode == 0 || g_esWhirlCache[attacker].g_iWhirlHitMode == 1) && bIsHumanSurvivor(victim) && g_esWhirlCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esWhirlAbility[g_esWhirlPlayer[attacker].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esWhirlPlayer[attacker].g_iTankType, g_esWhirlAbility[g_esWhirlPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esWhirlPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vWhirlHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esWhirlCache[attacker].g_flWhirlChance, g_esWhirlCache[attacker].g_iWhirlHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esWhirlCache[victim].g_iWhirlHitMode == 0 || g_esWhirlCache[victim].g_iWhirlHitMode == 2) && bIsHumanSurvivor(attacker) && g_esWhirlCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esWhirlAbility[g_esWhirlPlayer[victim].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esWhirlPlayer[victim].g_iTankType, g_esWhirlAbility[g_esWhirlPlayer[victim].g_iTankType].g_iImmunityFlags, g_esWhirlPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vWhirlHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esWhirlCache[victim].g_flWhirlChance, g_esWhirlCache[victim].g_iWhirlHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vWhirlPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_WHIRL);
}

#if defined MT_ABILITIES_MAIN2
void vWhirlAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_WHIRL_SECTION);
	list2.PushString(MT_WHIRL_SECTION2);
	list3.PushString(MT_WHIRL_SECTION3);
	list4.PushString(MT_WHIRL_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vWhirlCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_WHIRL_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_WHIRL_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_WHIRL_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_WHIRL_SECTION4);
	if (g_esWhirlCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_WHIRL_SECTION, false) || StrEqual(sSubset[iPos], MT_WHIRL_SECTION2, false) || StrEqual(sSubset[iPos], MT_WHIRL_SECTION3, false) || StrEqual(sSubset[iPos], MT_WHIRL_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esWhirlCache[tank].g_iWhirlAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vWhirlAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerWhirlCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
									dpCombo.WriteCell(GetClientUserId(tank));
									dpCombo.WriteFloat(random);
									dpCombo.WriteCell(iPos);
								}
							}
						}
					}
					case MT_COMBO_MELEEHIT:
					{
						flChance = MT_GetCombinationSetting(tank, 1, iPos);

						switch (flDelay)
						{
							case 0.0:
							{
								if ((g_esWhirlCache[tank].g_iWhirlHitMode == 0 || g_esWhirlCache[tank].g_iWhirlHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vWhirlHit(survivor, tank, random, flChance, g_esWhirlCache[tank].g_iWhirlHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esWhirlCache[tank].g_iWhirlHitMode == 0 || g_esWhirlCache[tank].g_iWhirlHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vWhirlHit(survivor, tank, random, flChance, g_esWhirlCache[tank].g_iWhirlHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerWhirlCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
								dpCombo.WriteCell(GetClientUserId(survivor));
								dpCombo.WriteCell(GetClientUserId(tank));
								dpCombo.WriteFloat(random);
								dpCombo.WriteFloat(flChance);
								dpCombo.WriteCell(iPos);
								dpCombo.WriteString(classname);
							}
						}
					}
				}

				break;
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlConfigsLoad(int mode)
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
				g_esWhirlAbility[iIndex].g_iAccessFlags = 0;
				g_esWhirlAbility[iIndex].g_iImmunityFlags = 0;
				g_esWhirlAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esWhirlAbility[iIndex].g_iComboAbility = 0;
				g_esWhirlAbility[iIndex].g_iHumanAbility = 0;
				g_esWhirlAbility[iIndex].g_iHumanAmmo = 5;
				g_esWhirlAbility[iIndex].g_iHumanCooldown = 0;
				g_esWhirlAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esWhirlAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esWhirlAbility[iIndex].g_iRequiresHumans = 1;
				g_esWhirlAbility[iIndex].g_iWhirlAbility = 0;
				g_esWhirlAbility[iIndex].g_iWhirlEffect = 0;
				g_esWhirlAbility[iIndex].g_iWhirlMessage = 0;
				g_esWhirlAbility[iIndex].g_iWhirlAxis = 0;
				g_esWhirlAbility[iIndex].g_flWhirlChance = 33.3;
				g_esWhirlAbility[iIndex].g_iWhirlCooldown = 0;
				g_esWhirlAbility[iIndex].g_iWhirlDuration = 5;
				g_esWhirlAbility[iIndex].g_iWhirlHit = 0;
				g_esWhirlAbility[iIndex].g_iWhirlHitMode = 0;
				g_esWhirlAbility[iIndex].g_flWhirlRange = 150.0;
				g_esWhirlAbility[iIndex].g_flWhirlRangeChance = 15.0;
				g_esWhirlAbility[iIndex].g_iWhirlRangeCooldown = 0;
				g_esWhirlAbility[iIndex].g_flWhirlSpeed = 500.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esWhirlPlayer[iPlayer].g_iAccessFlags = 0;
					g_esWhirlPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esWhirlPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esWhirlPlayer[iPlayer].g_iComboAbility = 0;
					g_esWhirlPlayer[iPlayer].g_iHumanAbility = 0;
					g_esWhirlPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esWhirlPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esWhirlPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esWhirlPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esWhirlPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlAbility = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlEffect = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlMessage = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlAxis = 0;
					g_esWhirlPlayer[iPlayer].g_flWhirlChance = 0.0;
					g_esWhirlPlayer[iPlayer].g_iWhirlCooldown = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlDuration = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlHit = 0;
					g_esWhirlPlayer[iPlayer].g_iWhirlHitMode = 0;
					g_esWhirlPlayer[iPlayer].g_flWhirlRange = 0.0;
					g_esWhirlPlayer[iPlayer].g_flWhirlRangeChance = 0.0;
					g_esWhirlPlayer[iPlayer].g_iWhirlRangeCooldown = 0;
					g_esWhirlPlayer[iPlayer].g_flWhirlSpeed = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esWhirlPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esWhirlPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esWhirlPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esWhirlPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esWhirlPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esWhirlPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esWhirlPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esWhirlPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esWhirlPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esWhirlPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esWhirlPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esWhirlPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esWhirlPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esWhirlPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esWhirlPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esWhirlPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esWhirlPlayer[admin].g_iWhirlAbility = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esWhirlPlayer[admin].g_iWhirlAbility, value, 0, 1);
		g_esWhirlPlayer[admin].g_iWhirlEffect = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esWhirlPlayer[admin].g_iWhirlEffect, value, 0, 7);
		g_esWhirlPlayer[admin].g_iWhirlMessage = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esWhirlPlayer[admin].g_iWhirlMessage, value, 0, 3);
		g_esWhirlPlayer[admin].g_iWhirlAxis = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlAxis", "Whirl Axis", "Whirl_Axis", "axis", g_esWhirlPlayer[admin].g_iWhirlAxis, value, 0, 7);
		g_esWhirlPlayer[admin].g_flWhirlChance = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlChance", "Whirl Chance", "Whirl_Chance", "chance", g_esWhirlPlayer[admin].g_flWhirlChance, value, 0.0, 100.0);
		g_esWhirlPlayer[admin].g_iWhirlCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlCooldown", "Whirl Cooldown", "Whirl_Cooldown", "cooldown", g_esWhirlPlayer[admin].g_iWhirlCooldown, value, 0, 99999);
		g_esWhirlPlayer[admin].g_iWhirlDuration = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlDuration", "Whirl Duration", "Whirl_Duration", "duration", g_esWhirlPlayer[admin].g_iWhirlDuration, value, 1, 99999);
		g_esWhirlPlayer[admin].g_iWhirlHit = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlHit", "Whirl Hit", "Whirl_Hit", "hit", g_esWhirlPlayer[admin].g_iWhirlHit, value, 0, 1);
		g_esWhirlPlayer[admin].g_iWhirlHitMode = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlHitMode", "Whirl Hit Mode", "Whirl_Hit_Mode", "hitmode", g_esWhirlPlayer[admin].g_iWhirlHitMode, value, 0, 2);
		g_esWhirlPlayer[admin].g_flWhirlRange = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlRange", "Whirl Range", "Whirl_Range", "range", g_esWhirlPlayer[admin].g_flWhirlRange, value, 1.0, 99999.0);
		g_esWhirlPlayer[admin].g_flWhirlRangeChance = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlRangeChance", "Whirl Range Chance", "Whirl_Range_Chance", "rangechance", g_esWhirlPlayer[admin].g_flWhirlRangeChance, value, 0.0, 100.0);
		g_esWhirlPlayer[admin].g_flWhirlSpeed = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlSpeed", "Whirl Speed", "Whirl_Speed", "speed", g_esWhirlPlayer[admin].g_flWhirlSpeed, value, 1.0, 99999.0);
		g_esWhirlPlayer[admin].g_iWhirlRangeCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlRangeCooldown", "Whirl Range Cooldown", "Whirl_Range_Cooldown", "rangecooldown", g_esWhirlPlayer[admin].g_iWhirlRangeCooldown, value, 0, 99999);
		g_esWhirlPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esWhirlPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esWhirlAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_SHAKE_SECTION, MT_SHAKE_SECTION2, MT_SHAKE_SECTION3, MT_SHAKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esWhirlAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esWhirlAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esWhirlAbility[type].g_iComboAbility, value, 0, 1);
		g_esWhirlAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esWhirlAbility[type].g_iHumanAbility, value, 0, 2);
		g_esWhirlAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esWhirlAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esWhirlAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esWhirlAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esWhirlAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esWhirlAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esWhirlAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esWhirlAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esWhirlAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esWhirlAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esWhirlAbility[type].g_iWhirlAbility = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esWhirlAbility[type].g_iWhirlAbility, value, 0, 1);
		g_esWhirlAbility[type].g_iWhirlEffect = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esWhirlAbility[type].g_iWhirlEffect, value, 0, 7);
		g_esWhirlAbility[type].g_iWhirlMessage = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esWhirlAbility[type].g_iWhirlMessage, value, 0, 3);
		g_esWhirlAbility[type].g_iWhirlAxis = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlAxis", "Whirl Axis", "Whirl_Axis", "axis", g_esWhirlAbility[type].g_iWhirlAxis, value, 0, 7);
		g_esWhirlAbility[type].g_flWhirlChance = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlChance", "Whirl Chance", "Whirl_Chance", "chance", g_esWhirlAbility[type].g_flWhirlChance, value, 0.0, 100.0);
		g_esWhirlAbility[type].g_iWhirlCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlCooldown", "Whirl Cooldown", "Whirl_Cooldown", "cooldown", g_esWhirlAbility[type].g_iWhirlCooldown, value, 0, 99999);
		g_esWhirlAbility[type].g_iWhirlDuration = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlDuration", "Whirl Duration", "Whirl_Duration", "duration", g_esWhirlAbility[type].g_iWhirlDuration, value, 1, 99999);
		g_esWhirlAbility[type].g_iWhirlHit = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlHit", "Whirl Hit", "Whirl_Hit", "hit", g_esWhirlAbility[type].g_iWhirlHit, value, 0, 1);
		g_esWhirlAbility[type].g_iWhirlHitMode = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlHitMode", "Whirl Hit Mode", "Whirl_Hit_Mode", "hitmode", g_esWhirlAbility[type].g_iWhirlHitMode, value, 0, 2);
		g_esWhirlAbility[type].g_flWhirlRange = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlRange", "Whirl Range", "Whirl_Range", "range", g_esWhirlAbility[type].g_flWhirlRange, value, 1.0, 99999.0);
		g_esWhirlAbility[type].g_flWhirlRangeChance = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlRangeChance", "Whirl Range Chance", "Whirl_Range_Chance", "rangechance", g_esWhirlAbility[type].g_flWhirlRangeChance, value, 0.0, 100.0);
		g_esWhirlAbility[type].g_iWhirlRangeCooldown = iGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlRangeCooldown", "Whirl Range Cooldown", "Whirl_Range_Cooldown", "rangecooldown", g_esWhirlAbility[type].g_iWhirlRangeCooldown, value, 0, 99999);
		g_esWhirlAbility[type].g_flWhirlSpeed = flGetKeyValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "WhirlSpeed", "Whirl Speed", "Whirl_Speed", "speed", g_esWhirlAbility[type].g_flWhirlSpeed, value, 1.0, 99999.0);
		g_esWhirlAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esWhirlAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_WHIRL_SECTION, MT_WHIRL_SECTION2, MT_WHIRL_SECTION3, MT_WHIRL_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esWhirlCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_flCloseAreasOnly, g_esWhirlAbility[type].g_flCloseAreasOnly);
	g_esWhirlCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iComboAbility, g_esWhirlAbility[type].g_iComboAbility);
	g_esWhirlCache[tank].g_flWhirlChance = flGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_flWhirlChance, g_esWhirlAbility[type].g_flWhirlChance);
	g_esWhirlCache[tank].g_flWhirlRange = flGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_flWhirlRange, g_esWhirlAbility[type].g_flWhirlRange);
	g_esWhirlCache[tank].g_flWhirlRangeChance = flGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_flWhirlRangeChance, g_esWhirlAbility[type].g_flWhirlRangeChance);
	g_esWhirlCache[tank].g_flWhirlSpeed = flGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_flWhirlSpeed, g_esWhirlAbility[type].g_flWhirlSpeed);
	g_esWhirlCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iHumanAbility, g_esWhirlAbility[type].g_iHumanAbility);
	g_esWhirlCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iHumanAmmo, g_esWhirlAbility[type].g_iHumanAmmo);
	g_esWhirlCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iHumanCooldown, g_esWhirlAbility[type].g_iHumanCooldown);
	g_esWhirlCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iHumanRangeCooldown, g_esWhirlAbility[type].g_iHumanRangeCooldown);
	g_esWhirlCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_flOpenAreasOnly, g_esWhirlAbility[type].g_flOpenAreasOnly);
	g_esWhirlCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iRequiresHumans, g_esWhirlAbility[type].g_iRequiresHumans);
	g_esWhirlCache[tank].g_iWhirlAbility = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlAbility, g_esWhirlAbility[type].g_iWhirlAbility);
	g_esWhirlCache[tank].g_iWhirlAxis = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlAxis, g_esWhirlAbility[type].g_iWhirlAxis);
	g_esWhirlCache[tank].g_iWhirlCooldown = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlCooldown, g_esWhirlAbility[type].g_iWhirlCooldown);
	g_esWhirlCache[tank].g_iWhirlDuration = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlDuration, g_esWhirlAbility[type].g_iWhirlDuration);
	g_esWhirlCache[tank].g_iWhirlEffect = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlEffect, g_esWhirlAbility[type].g_iWhirlEffect);
	g_esWhirlCache[tank].g_iWhirlHit = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlHit, g_esWhirlAbility[type].g_iWhirlHit);
	g_esWhirlCache[tank].g_iWhirlHitMode = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlHitMode, g_esWhirlAbility[type].g_iWhirlHitMode);
	g_esWhirlCache[tank].g_iWhirlMessage = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlMessage, g_esWhirlAbility[type].g_iWhirlMessage);
	g_esWhirlCache[tank].g_iWhirlRangeCooldown = iGetSettingValue(apply, bHuman, g_esWhirlPlayer[tank].g_iWhirlRangeCooldown, g_esWhirlAbility[type].g_iWhirlRangeCooldown);
	g_esWhirlPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vWhirlCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vWhirlCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveWhirl(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vWhirlPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esWhirlPlayer[iSurvivor].g_bAffected)
		{
			SetClientViewEntity(iSurvivor, iSurvivor);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlEventFired(Event event, const char[] name)
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
			vWhirlCopyStats2(iBot, iTank);
			vRemoveWhirl(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vWhirlCopyStats2(iTank, iBot);
			vRemoveWhirl(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveWhirl(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vWhirlReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWhirlAbility[g_esWhirlPlayer[tank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[tank].g_iAccessFlags)) || g_esWhirlCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esWhirlCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esWhirlCache[tank].g_iWhirlAbility == 1 && g_esWhirlCache[tank].g_iComboAbility == 0)
	{
		vWhirlAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esWhirlCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWhirlCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWhirlPlayer[tank].g_iTankType) || (g_esWhirlCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWhirlCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWhirlAbility[g_esWhirlPlayer[tank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esWhirlCache[tank].g_iWhirlAbility == 1 && g_esWhirlCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esWhirlPlayer[tank].g_iRangeCooldown == -1 || g_esWhirlPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vWhirlAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlHuman3", (g_esWhirlPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vWhirlChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveWhirl(tank);
}

void vWhirlAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esWhirlCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWhirlCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWhirlPlayer[tank].g_iTankType) || (g_esWhirlCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWhirlCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWhirlAbility[g_esWhirlPlayer[tank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esWhirlPlayer[tank].g_iAmmoCount < g_esWhirlCache[tank].g_iHumanAmmo && g_esWhirlCache[tank].g_iHumanAmmo > 0))
	{
		g_esWhirlPlayer[tank].g_bFailed = false;
		g_esWhirlPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esWhirlCache[tank].g_flWhirlRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esWhirlCache[tank].g_flWhirlRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esWhirlPlayer[tank].g_iTankType, g_esWhirlAbility[g_esWhirlPlayer[tank].g_iTankType].g_iImmunityFlags, g_esWhirlPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vWhirlHit(iSurvivor, tank, random, flChance, g_esWhirlCache[tank].g_iWhirlAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlAmmo");
	}
}

void vWhirlHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esWhirlCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esWhirlCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWhirlPlayer[tank].g_iTankType) || (g_esWhirlCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWhirlCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esWhirlAbility[g_esWhirlPlayer[tank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esWhirlPlayer[tank].g_iTankType, g_esWhirlAbility[g_esWhirlPlayer[tank].g_iTankType].g_iImmunityFlags, g_esWhirlPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esWhirlPlayer[tank].g_iRangeCooldown != -1 && g_esWhirlPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esWhirlPlayer[tank].g_iCooldown != -1 && g_esWhirlPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorHanging(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esWhirlPlayer[tank].g_iAmmoCount < g_esWhirlCache[tank].g_iHumanAmmo && g_esWhirlCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esWhirlPlayer[survivor].g_bAffected)
			{
				int iCamera = CreateEntityByName("env_sprite");
				if (bIsValidEntity(iCamera))
				{
					g_esWhirlPlayer[survivor].g_bAffected = true;
					g_esWhirlPlayer[survivor].g_iOwner = tank;

					int iCooldown = -1;
					if ((flags & MT_ATTACK_RANGE) && (g_esWhirlPlayer[tank].g_iRangeCooldown == -1 || g_esWhirlPlayer[tank].g_iRangeCooldown < iTime))
					{
						if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1)
						{
							g_esWhirlPlayer[tank].g_iAmmoCount++;

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlHuman", g_esWhirlPlayer[tank].g_iAmmoCount, g_esWhirlCache[tank].g_iHumanAmmo);
						}

						iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esWhirlCache[tank].g_iWhirlRangeCooldown;
						iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1 && g_esWhirlPlayer[tank].g_iAmmoCount < g_esWhirlCache[tank].g_iHumanAmmo && g_esWhirlCache[tank].g_iHumanAmmo > 0) ? g_esWhirlCache[tank].g_iHumanRangeCooldown : iCooldown;
						g_esWhirlPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
						if (g_esWhirlPlayer[tank].g_iRangeCooldown != -1 && g_esWhirlPlayer[tank].g_iRangeCooldown > iTime)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlHuman5", (g_esWhirlPlayer[tank].g_iRangeCooldown - iTime));
						}
					}
					else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esWhirlPlayer[tank].g_iCooldown == -1 || g_esWhirlPlayer[tank].g_iCooldown < iTime))
					{
						iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esWhirlCache[tank].g_iWhirlCooldown;
						iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1) ? g_esWhirlCache[tank].g_iHumanCooldown : iCooldown;
						g_esWhirlPlayer[tank].g_iCooldown = (iTime + iCooldown);
						if (g_esWhirlPlayer[tank].g_iCooldown != -1 && g_esWhirlPlayer[tank].g_iCooldown > iTime)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlHuman5", (g_esWhirlPlayer[tank].g_iCooldown - iTime));
						}
					}

					float flEyePos[3], flAngles[3];
					GetClientEyePosition(survivor, flEyePos);
					GetClientEyeAngles(survivor, flAngles);

					SetEntityModel(iCamera, SPRITE_DOT);
					SetEntityRenderMode(iCamera, RENDER_TRANSCOLOR);
					SetEntityRenderColor(iCamera, 0, 0, 0, 0);
					TeleportEntity(iCamera, flEyePos, flAngles);
					DispatchSpawn(iCamera);

					TeleportEntity(survivor, .angles = flAngles);

					vSetEntityParent(iCamera, survivor);
					SetClientViewEntity(survivor, iCamera);

					int iAxis = -1, iAxisCount = 0, iAxes[3], iFlag = 0;
					for (int iBit = 0; iBit < (sizeof iAxes); iBit++)
					{
						iFlag = (1 << iBit);
						if (!(g_esWhirlCache[tank].g_iWhirlAxis & iFlag))
						{
							continue;
						}

						iAxes[iAxisCount] = iFlag;
						iAxisCount++;
					}

					switch (iAxes[MT_GetRandomInt(0, (iAxisCount - 1))])
					{
						case 1: iAxis = 0;
						case 2: iAxis = 1;
						case 4: iAxis = 2;
						default: iAxis = MT_GetRandomInt(0, (sizeof iAxes - 1));
					}

					DataPack dpWhirl;
					CreateDataTimer(0.1, tTimerWhirl, dpWhirl, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
					dpWhirl.WriteCell(EntIndexToEntRef(iCamera));
					dpWhirl.WriteCell(GetClientUserId(survivor));
					dpWhirl.WriteCell(GetClientUserId(tank));
					dpWhirl.WriteCell(g_esWhirlPlayer[tank].g_iTankType);
					dpWhirl.WriteCell(messages);
					dpWhirl.WriteCell(enabled);
					dpWhirl.WriteCell(pos);
					dpWhirl.WriteCell(iAxis);
					dpWhirl.WriteCell(iTime);

					vScreenEffect(survivor, tank, g_esWhirlCache[tank].g_iWhirlEffect, flags);

					if (g_esWhirlCache[tank].g_iWhirlMessage & messages)
					{
						char sTankName[33];
						MT_GetTankName(tank, sTankName);
						MT_PrintToChatAll("%s %t", MT_TAG2, "Whirl", sTankName, survivor);
						MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Whirl", LANG_SERVER, sTankName, survivor);
					}
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esWhirlPlayer[tank].g_iRangeCooldown == -1 || g_esWhirlPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1 && !g_esWhirlPlayer[tank].g_bFailed)
				{
					g_esWhirlPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esWhirlCache[tank].g_iHumanAbility == 1 && !g_esWhirlPlayer[tank].g_bNoAmmo)
		{
			g_esWhirlPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "WhirlAmmo");
		}
	}
}

void vWhirlCopyStats2(int oldTank, int newTank)
{
	g_esWhirlPlayer[newTank].g_iAmmoCount = g_esWhirlPlayer[oldTank].g_iAmmoCount;
	g_esWhirlPlayer[newTank].g_iCooldown = g_esWhirlPlayer[oldTank].g_iCooldown;
	g_esWhirlPlayer[newTank].g_iRangeCooldown = g_esWhirlPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveWhirl(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esWhirlPlayer[iSurvivor].g_bAffected && g_esWhirlPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esWhirlPlayer[iSurvivor].g_bAffected = false;
			g_esWhirlPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vWhirlReset3(tank);
}

void vWhirlReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRemoveWhirl(iPlayer);
		}
	}
}

void vWhirlReset2(int survivor, int tank, int camera, int messages)
{
	vStopWhirl(survivor, camera);

	if (g_esWhirlCache[tank].g_iWhirlMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Whirl2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Whirl2", LANG_SERVER, survivor);
	}
}

void vWhirlReset3(int tank)
{
	g_esWhirlPlayer[tank].g_bAffected = false;
	g_esWhirlPlayer[tank].g_bFailed = false;
	g_esWhirlPlayer[tank].g_bNoAmmo = false;
	g_esWhirlPlayer[tank].g_iAmmoCount = 0;
	g_esWhirlPlayer[tank].g_iCooldown = -1;
	g_esWhirlPlayer[tank].g_iRangeCooldown = -1;
}

void vStopWhirl(int survivor, int camera)
{
	g_esWhirlPlayer[survivor].g_bAffected = false;
	g_esWhirlPlayer[survivor].g_iOwner = 0;

	SetClientViewEntity(survivor, survivor);
	RemoveEntity(camera);
}

Action tTimerWhirlCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esWhirlAbility[g_esWhirlPlayer[iTank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esWhirlPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esWhirlCache[iTank].g_iWhirlAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vWhirlAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerWhirlCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esWhirlPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esWhirlAbility[g_esWhirlPlayer[iTank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esWhirlPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esWhirlCache[iTank].g_iWhirlHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esWhirlCache[iTank].g_iWhirlHitMode == 0 || g_esWhirlCache[iTank].g_iWhirlHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vWhirlHit(iSurvivor, iTank, flRandom, flChance, g_esWhirlCache[iTank].g_iWhirlHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esWhirlCache[iTank].g_iWhirlHitMode == 0 || g_esWhirlCache[iTank].g_iWhirlHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vWhirlHit(iSurvivor, iTank, flRandom, flChance, g_esWhirlCache[iTank].g_iWhirlHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerWhirl(Handle timer, DataPack pack)
{
	pack.Reset();

	int iCamera = EntRefToEntIndex(pack.ReadCell()), iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || iCamera == INVALID_ENT_REFERENCE || !bIsValidEntity(iCamera))
	{
		g_esWhirlPlayer[iSurvivor].g_bAffected = false;
		g_esWhirlPlayer[iSurvivor].g_iOwner = 0;

		if (bIsHumanSurvivor(iSurvivor))
		{
			SetClientViewEntity(iSurvivor, iSurvivor);
		}

		return Plugin_Stop;
	}

	if (!bIsHumanSurvivor(iSurvivor) || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vStopWhirl(iSurvivor, iCamera);

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esWhirlCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esWhirlCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esWhirlPlayer[iTank].g_iTankType) || (g_esWhirlCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esWhirlCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esWhirlAbility[g_esWhirlPlayer[iTank].g_iTankType].g_iAccessFlags, g_esWhirlPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esWhirlPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esWhirlPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esWhirlPlayer[iTank].g_iTankType, g_esWhirlAbility[g_esWhirlPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esWhirlPlayer[iSurvivor].g_iImmunityFlags) || !g_esWhirlPlayer[iSurvivor].g_bAffected)
	{
		vWhirlReset2(iSurvivor, iTank, iCamera, iMessage);

		return Plugin_Stop;
	}

	int iWhirlEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esWhirlCache[iTank].g_iWhirlDuration,
		iWhirlAxis = pack.ReadCell(), iTime = pack.ReadCell();
	if (iWhirlEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		vWhirlReset2(iSurvivor, iTank, iCamera, iMessage);

		return Plugin_Stop;
	}

	float flAngles[3];
	GetEntPropVector(iCamera, Prop_Data, "m_angRotation", flAngles);
	float flSpeed = (iPos != -1) ? MT_GetCombinationSetting(iTank, 16, iPos) : g_esWhirlCache[iTank].g_flWhirlSpeed;
	flAngles[iWhirlAxis] += flSpeed;
	TeleportEntity(iCamera, .angles = flAngles);

	return Plugin_Continue;
}