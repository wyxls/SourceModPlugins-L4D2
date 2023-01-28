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

#define MT_ICE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_ICE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Ice Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank freezes survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Ice Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_ICE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_BULLET "physics/glass/glass_impact_bullet4.wav"

#define MT_ICE_SECTION "iceability"
#define MT_ICE_SECTION2 "ice ability"
#define MT_ICE_SECTION3 "ice_ability"
#define MT_ICE_SECTION4 "ice"

#define MT_MENU_ICE "Ice Ability"

enum struct esIcePlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flIceChance;
	float g_flIceDuration;
	float g_flIceRange;
	float g_flIceRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iIceAbility;
	int g_iIceCooldown;
	int g_iIceEffect;
	int g_iIceHit;
	int g_iIceHitMode;
	int g_iIceMessage;
	int g_iIceRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esIcePlayer g_esIcePlayer[MAXPLAYERS + 1];

enum struct esIceAbility
{
	float g_flCloseAreasOnly;
	float g_flIceChance;
	float g_flIceDuration;
	float g_flIceRange;
	float g_flIceRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iIceAbility;
	int g_iIceCooldown;
	int g_iIceEffect;
	int g_iIceHit;
	int g_iIceHitMode;
	int g_iIceMessage;
	int g_iIceRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esIceAbility g_esIceAbility[MT_MAXTYPES + 1];

enum struct esIceCache
{
	float g_flCloseAreasOnly;
	float g_flIceChance;
	float g_flIceDuration;
	float g_flIceRange;
	float g_flIceRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iIceAbility;
	int g_iIceCooldown;
	int g_iIceEffect;
	int g_iIceHit;
	int g_iIceHitMode;
	int g_iIceMessage;
	int g_iIceRangeCooldown;
	int g_iRequiresHumans;
}

esIceCache g_esIceCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_ice", cmdIceInfo, "View information about the Ice ability.");

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
void vIceMapStart()
#else
public void OnMapStart()
#endif
{
	PrecacheSound(SOUND_BULLET, true);

	vIceReset();
}

#if defined MT_ABILITIES_MAIN
void vIceClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnIceTakeDamage);
	vIceReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vIceClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vIceReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vIceMapEnd()
#else
public void OnMapEnd()
#endif
{
	vIceReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdIceInfo(int client, int args)
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
		case false: vIceMenu(client, MT_ICE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vIceMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ICE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iIceMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Ice Ability Information");
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

int iIceMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esIceCache[param1].g_iIceAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esIceCache[param1].g_iHumanAmmo - g_esIcePlayer[param1].g_iAmmoCount), g_esIceCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esIceCache[param1].g_iHumanAbility == 1) ? g_esIceCache[param1].g_iHumanCooldown : g_esIceCache[param1].g_iIceCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "IceDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esIceCache[param1].g_flIceDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esIceCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esIceCache[param1].g_iHumanAbility == 1) ? g_esIceCache[param1].g_iHumanRangeCooldown : g_esIceCache[param1].g_iIceRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vIceMenu(param1, MT_ICE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pIce = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "IceMenu", param1);
			pIce.SetTitle(sMenuTitle);
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

#if defined MT_ABILITIES_MAIN
void vIceDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ICE, MT_MENU_ICE);
}

#if defined MT_ABILITIES_MAIN
void vIceMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ICE, false))
	{
		vIceMenu(client, MT_ICE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vIceMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ICE, false))
	{
		FormatEx(buffer, size, "%T", "IceMenu2", client);
	}
}

Action OnIceTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esIceCache[attacker].g_iIceHitMode == 0 || g_esIceCache[attacker].g_iIceHitMode == 1) && bIsSurvivor(victim) && g_esIceCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esIceAbility[g_esIcePlayer[attacker].g_iTankType].g_iAccessFlags, g_esIcePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esIcePlayer[attacker].g_iTankType, g_esIceAbility[g_esIcePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esIcePlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vIceHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esIceCache[attacker].g_flIceChance, g_esIceCache[attacker].g_iIceHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esIceCache[victim].g_iIceHitMode == 0 || g_esIceCache[victim].g_iIceHitMode == 2) && bIsSurvivor(attacker) && g_esIceCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esIceAbility[g_esIcePlayer[victim].g_iTankType].g_iAccessFlags, g_esIcePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esIcePlayer[victim].g_iTankType, g_esIceAbility[g_esIcePlayer[victim].g_iTankType].g_iImmunityFlags, g_esIcePlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vIceHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esIceCache[victim].g_flIceChance, g_esIceCache[victim].g_iIceHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vIcePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ICE);
}

#if defined MT_ABILITIES_MAIN
void vIceAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ICE_SECTION);
	list2.PushString(MT_ICE_SECTION2);
	list3.PushString(MT_ICE_SECTION3);
	list4.PushString(MT_ICE_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vIceCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ICE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ICE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ICE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ICE_SECTION4);
	if (g_esIceCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_ICE_SECTION, false) || StrEqual(sSubset[iPos], MT_ICE_SECTION2, false) || StrEqual(sSubset[iPos], MT_ICE_SECTION3, false) || StrEqual(sSubset[iPos], MT_ICE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esIceCache[tank].g_iIceAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vIceAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerIceCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esIceCache[tank].g_iIceHitMode == 0 || g_esIceCache[tank].g_iIceHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vIceHit(survivor, tank, random, flChance, g_esIceCache[tank].g_iIceHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esIceCache[tank].g_iIceHitMode == 0 || g_esIceCache[tank].g_iIceHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vIceHit(survivor, tank, random, flChance, g_esIceCache[tank].g_iIceHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerIceCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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

#if defined MT_ABILITIES_MAIN
void vIceConfigsLoad(int mode)
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
				g_esIceAbility[iIndex].g_iAccessFlags = 0;
				g_esIceAbility[iIndex].g_iImmunityFlags = 0;
				g_esIceAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esIceAbility[iIndex].g_iComboAbility = 0;
				g_esIceAbility[iIndex].g_iHumanAbility = 0;
				g_esIceAbility[iIndex].g_iHumanAmmo = 5;
				g_esIceAbility[iIndex].g_iHumanCooldown = 0;
				g_esIceAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esIceAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esIceAbility[iIndex].g_iRequiresHumans = 0;
				g_esIceAbility[iIndex].g_iIceAbility = 0;
				g_esIceAbility[iIndex].g_iIceEffect = 0;
				g_esIceAbility[iIndex].g_iIceMessage = 0;
				g_esIceAbility[iIndex].g_flIceChance = 33.3;
				g_esIceAbility[iIndex].g_iIceCooldown = 0;
				g_esIceAbility[iIndex].g_flIceDuration = 5.0;
				g_esIceAbility[iIndex].g_iIceHit = 0;
				g_esIceAbility[iIndex].g_iIceHitMode = 0;
				g_esIceAbility[iIndex].g_flIceRange = 150.0;
				g_esIceAbility[iIndex].g_flIceRangeChance = 15.0;
				g_esIceAbility[iIndex].g_iIceRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esIcePlayer[iPlayer].g_iAccessFlags = 0;
					g_esIcePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esIcePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esIcePlayer[iPlayer].g_iComboAbility = 0;
					g_esIcePlayer[iPlayer].g_iHumanAbility = 0;
					g_esIcePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esIcePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esIcePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esIcePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esIcePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esIcePlayer[iPlayer].g_iIceAbility = 0;
					g_esIcePlayer[iPlayer].g_iIceEffect = 0;
					g_esIcePlayer[iPlayer].g_iIceMessage = 0;
					g_esIcePlayer[iPlayer].g_flIceChance = 0.0;
					g_esIcePlayer[iPlayer].g_iIceCooldown = 0;
					g_esIcePlayer[iPlayer].g_flIceDuration = 0.0;
					g_esIcePlayer[iPlayer].g_iIceHit = 0;
					g_esIcePlayer[iPlayer].g_iIceHitMode = 0;
					g_esIcePlayer[iPlayer].g_flIceRange = 0.0;
					g_esIcePlayer[iPlayer].g_flIceRangeChance = 0.0;
					g_esIcePlayer[iPlayer].g_iIceRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vIceConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esIcePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esIcePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esIcePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esIcePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esIcePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esIcePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esIcePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esIcePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esIcePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esIcePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esIcePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esIcePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esIcePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esIcePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esIcePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esIcePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esIcePlayer[admin].g_iIceAbility = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esIcePlayer[admin].g_iIceAbility, value, 0, 1);
		g_esIcePlayer[admin].g_iIceEffect = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esIcePlayer[admin].g_iIceEffect, value, 0, 7);
		g_esIcePlayer[admin].g_iIceMessage = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esIcePlayer[admin].g_iIceMessage, value, 0, 3);
		g_esIcePlayer[admin].g_flIceChance = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceChance", "Ice Chance", "Ice_Chance", "chance", g_esIcePlayer[admin].g_flIceChance, value, 0.0, 100.0);
		g_esIcePlayer[admin].g_iIceCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceCooldown", "Ice Cooldown", "Ice_Cooldown", "cooldown", g_esIcePlayer[admin].g_iIceCooldown, value, 0, 99999);
		g_esIcePlayer[admin].g_flIceDuration = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceDuration", "Ice Duration", "Ice_Duration", "duration", g_esIcePlayer[admin].g_flIceDuration, value, 0.1, 99999.0);
		g_esIcePlayer[admin].g_iIceHit = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceHit", "Ice Hit", "Ice_Hit", "hit", g_esIcePlayer[admin].g_iIceHit, value, 0, 1);
		g_esIcePlayer[admin].g_iIceHitMode = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceHitMode", "Ice Hit Mode", "Ice_Hit_Mode", "hitmode", g_esIcePlayer[admin].g_iIceHitMode, value, 0, 2);
		g_esIcePlayer[admin].g_flIceRange = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceRange", "Ice Range", "Ice_Range", "range", g_esIcePlayer[admin].g_flIceRange, value, 1.0, 99999.0);
		g_esIcePlayer[admin].g_flIceRangeChance = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceRangeChance", "Ice Range Chance", "Ice_Range_Chance", "rangechance", g_esIcePlayer[admin].g_flIceRangeChance, value, 0.0, 100.0);
		g_esIcePlayer[admin].g_iIceRangeCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceRangeCooldown", "Ice Range Cooldown", "Ice_Range_Cooldown", "rangecooldown", g_esIcePlayer[admin].g_iIceRangeCooldown, value, 0, 99999);
		g_esIcePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esIcePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esIceAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esIceAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esIceAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esIceAbility[type].g_iComboAbility, value, 0, 1);
		g_esIceAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esIceAbility[type].g_iHumanAbility, value, 0, 2);
		g_esIceAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esIceAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esIceAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esIceAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esIceAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esIceAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esIceAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esIceAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esIceAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esIceAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esIceAbility[type].g_iIceAbility = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esIceAbility[type].g_iIceAbility, value, 0, 1);
		g_esIceAbility[type].g_iIceEffect = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esIceAbility[type].g_iIceEffect, value, 0, 7);
		g_esIceAbility[type].g_iIceMessage = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esIceAbility[type].g_iIceMessage, value, 0, 3);
		g_esIceAbility[type].g_flIceChance = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceChance", "Ice Chance", "Ice_Chance", "chance", g_esIceAbility[type].g_flIceChance, value, 0.0, 100.0);
		g_esIceAbility[type].g_iIceCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceCooldown", "Ice Cooldown", "Ice_Cooldown", "cooldown", g_esIceAbility[type].g_iIceCooldown, value, 0, 99999);
		g_esIceAbility[type].g_flIceDuration = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceDuration", "Ice Duration", "Ice_Duration", "duration", g_esIceAbility[type].g_flIceDuration, value, 0.1, 99999.0);
		g_esIceAbility[type].g_iIceHit = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceHit", "Ice Hit", "Ice_Hit", "hit", g_esIceAbility[type].g_iIceHit, value, 0, 1);
		g_esIceAbility[type].g_iIceHitMode = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceHitMode", "Ice Hit Mode", "Ice_Hit_Mode", "hitmode", g_esIceAbility[type].g_iIceHitMode, value, 0, 2);
		g_esIceAbility[type].g_flIceRange = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceRange", "Ice Range", "Ice_Range", "range", g_esIceAbility[type].g_flIceRange, value, 1.0, 99999.0);
		g_esIceAbility[type].g_flIceRangeChance = flGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceRangeChance", "Ice Range Chance", "Ice_Range_Chance", "rangechance", g_esIceAbility[type].g_flIceRangeChance, value, 0.0, 100.0);
		g_esIceAbility[type].g_iIceRangeCooldown = iGetKeyValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "IceRangeCooldown", "Ice Range Cooldown", "Ice_Range_Cooldown", "rangecooldown", g_esIceAbility[type].g_iIceRangeCooldown, value, 0, 99999);
		g_esIceAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esIceAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ICE_SECTION, MT_ICE_SECTION2, MT_ICE_SECTION3, MT_ICE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vIceSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esIceCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_flCloseAreasOnly, g_esIceAbility[type].g_flCloseAreasOnly);
	g_esIceCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iComboAbility, g_esIceAbility[type].g_iComboAbility);
	g_esIceCache[tank].g_flIceChance = flGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_flIceChance, g_esIceAbility[type].g_flIceChance);
	g_esIceCache[tank].g_flIceDuration = flGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_flIceDuration, g_esIceAbility[type].g_flIceDuration);
	g_esIceCache[tank].g_flIceRange = flGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_flIceRange, g_esIceAbility[type].g_flIceRange);
	g_esIceCache[tank].g_flIceRangeChance = flGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_flIceRangeChance, g_esIceAbility[type].g_flIceRangeChance);
	g_esIceCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iHumanAbility, g_esIceAbility[type].g_iHumanAbility);
	g_esIceCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iHumanAmmo, g_esIceAbility[type].g_iHumanAmmo);
	g_esIceCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iHumanCooldown, g_esIceAbility[type].g_iHumanCooldown);
	g_esIceCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iHumanRangeCooldown, g_esIceAbility[type].g_iHumanRangeCooldown);
	g_esIceCache[tank].g_iIceAbility = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceAbility, g_esIceAbility[type].g_iIceAbility);
	g_esIceCache[tank].g_iIceCooldown = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceCooldown, g_esIceAbility[type].g_iIceCooldown);
	g_esIceCache[tank].g_iIceEffect = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceEffect, g_esIceAbility[type].g_iIceEffect);
	g_esIceCache[tank].g_iIceHit = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceHit, g_esIceAbility[type].g_iIceHit);
	g_esIceCache[tank].g_iIceHitMode = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceHitMode, g_esIceAbility[type].g_iIceHitMode);
	g_esIceCache[tank].g_iIceMessage = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceMessage, g_esIceAbility[type].g_iIceMessage);
	g_esIceCache[tank].g_iIceRangeCooldown = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iIceRangeCooldown, g_esIceAbility[type].g_iIceRangeCooldown);
	g_esIceCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_flOpenAreasOnly, g_esIceAbility[type].g_flOpenAreasOnly);
	g_esIceCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esIcePlayer[tank].g_iRequiresHumans, g_esIceAbility[type].g_iRequiresHumans);
	g_esIcePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vIceCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vIceCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveIce(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vIcePluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iTank = 1; iTank <= MaxClients; iTank++)
	{
		if (bIsTank(iTank, MT_CHECK_INGAME|MT_CHECK_ALIVE))
		{
			vRemoveIce(iTank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vIceEventFired(Event event, const char[] name)
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
			vIceCopyStats2(iBot, iTank);
			vRemoveIce(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vIceCopyStats2(iTank, iBot);
			vRemoveIce(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iPlayerId = event.GetInt("userid"), iPlayer = GetClientOfUserId(iPlayerId);
		if (MT_IsTankSupported(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveIce(iPlayer);
		}
		else if (bIsSurvivor(iPlayer, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vStopIce(iPlayer, false);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vIceReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vIceAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIceAbility[g_esIcePlayer[tank].g_iTankType].g_iAccessFlags, g_esIcePlayer[tank].g_iAccessFlags)) || g_esIceCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esIceCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esIceCache[tank].g_iIceAbility == 1 && g_esIceCache[tank].g_iComboAbility == 0)
	{
		vIceAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vIceButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esIceCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esIceCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esIcePlayer[tank].g_iTankType) || (g_esIceCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esIceCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIceAbility[g_esIcePlayer[tank].g_iTankType].g_iAccessFlags, g_esIcePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esIceCache[tank].g_iIceAbility == 1 && g_esIceCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esIcePlayer[tank].g_iRangeCooldown == -1 || g_esIcePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vIceAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceHuman3", (g_esIcePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vIceChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveIce(tank);
}

void vIceAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esIceCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esIceCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esIcePlayer[tank].g_iTankType) || (g_esIceCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esIceCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIceAbility[g_esIcePlayer[tank].g_iTankType].g_iAccessFlags, g_esIcePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esIcePlayer[tank].g_iAmmoCount < g_esIceCache[tank].g_iHumanAmmo && g_esIceCache[tank].g_iHumanAmmo > 0))
	{
		g_esIcePlayer[tank].g_bFailed = false;
		g_esIcePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esIceCache[tank].g_flIceRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esIceCache[tank].g_flIceRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esIcePlayer[tank].g_iTankType, g_esIceAbility[g_esIcePlayer[tank].g_iTankType].g_iImmunityFlags, g_esIcePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vIceHit(iSurvivor, tank, random, flChance, g_esIceCache[tank].g_iIceAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceAmmo");
	}
}

void vIceHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esIceCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esIceCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esIcePlayer[tank].g_iTankType) || (g_esIceCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esIceCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esIceAbility[g_esIcePlayer[tank].g_iTankType].g_iAccessFlags, g_esIcePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esIcePlayer[tank].g_iTankType, g_esIceAbility[g_esIcePlayer[tank].g_iTankType].g_iImmunityFlags, g_esIcePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esIcePlayer[tank].g_iRangeCooldown != -1 && g_esIcePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esIcePlayer[tank].g_iCooldown != -1 && g_esIcePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorHanging(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esIcePlayer[tank].g_iAmmoCount < g_esIceCache[tank].g_iHumanAmmo && g_esIceCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esIcePlayer[survivor].g_bAffected)
			{
				g_esIcePlayer[survivor].g_bAffected = true;
				g_esIcePlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esIcePlayer[tank].g_iRangeCooldown == -1 || g_esIcePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1)
					{
						g_esIcePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceHuman", g_esIcePlayer[tank].g_iAmmoCount, g_esIceCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esIceCache[tank].g_iIceRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1 && g_esIcePlayer[tank].g_iAmmoCount < g_esIceCache[tank].g_iHumanAmmo && g_esIceCache[tank].g_iHumanAmmo > 0) ? g_esIceCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esIcePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esIcePlayer[tank].g_iRangeCooldown != -1 && g_esIcePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceHuman5", (g_esIcePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esIcePlayer[tank].g_iCooldown == -1 || g_esIcePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esIceCache[tank].g_iIceCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1) ? g_esIceCache[tank].g_iHumanCooldown : iCooldown;
					g_esIcePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esIcePlayer[tank].g_iCooldown != -1 && g_esIcePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceHuman5", (g_esIcePlayer[tank].g_iCooldown - iTime));
					}
				}

				float flPos[3];
				GetClientEyePosition(survivor, flPos);

				if (GetEntityMoveType(survivor) != MOVETYPE_NONE)
				{
					SetEntityMoveType(survivor, MOVETYPE_NONE);
				}

				SetEntityRenderColor(survivor, 0, 130, 255, 190);
				EmitAmbientSound(SOUND_BULLET, flPos, survivor, SNDLEVEL_RAIDSIREN);

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esIceCache[tank].g_flIceDuration;
				DataPack dpStopIce;
				CreateDataTimer(flDuration, tTimerStopIce, dpStopIce, TIMER_FLAG_NO_MAPCHANGE);
				dpStopIce.WriteCell(GetClientUserId(survivor));
				dpStopIce.WriteCell(GetClientUserId(tank));
				dpStopIce.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esIceCache[tank].g_iIceEffect, flags);

				if (g_esIceCache[tank].g_iIceMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Ice", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Ice", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esIcePlayer[tank].g_iRangeCooldown == -1 || g_esIcePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1 && !g_esIcePlayer[tank].g_bFailed)
				{
					g_esIcePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esIceCache[tank].g_iHumanAbility == 1 && !g_esIcePlayer[tank].g_bNoAmmo)
		{
			g_esIcePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "IceAmmo");
		}
	}
}

void vIceCopyStats2(int oldTank, int newTank)
{
	g_esIcePlayer[newTank].g_iAmmoCount = g_esIcePlayer[oldTank].g_iAmmoCount;
	g_esIcePlayer[newTank].g_iCooldown = g_esIcePlayer[oldTank].g_iCooldown;
	g_esIcePlayer[newTank].g_iRangeCooldown = g_esIcePlayer[oldTank].g_iRangeCooldown;
}

void vRemoveIce(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esIcePlayer[iSurvivor].g_bAffected && g_esIcePlayer[iSurvivor].g_iOwner == tank)
		{
			vStopIce(iSurvivor);
		}
	}

	vIceReset2(tank);
}

void vIceReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vIceReset2(iPlayer);

			g_esIcePlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vIceReset2(int tank)
{
	g_esIcePlayer[tank].g_bAffected = false;
	g_esIcePlayer[tank].g_bFailed = false;
	g_esIcePlayer[tank].g_bNoAmmo = false;
	g_esIcePlayer[tank].g_iAmmoCount = 0;
	g_esIcePlayer[tank].g_iCooldown = -1;
	g_esIcePlayer[tank].g_iRangeCooldown = -1;
}

void vStopIce(int survivor, bool all = true)
{
	g_esIcePlayer[survivor].g_bAffected = false;
	g_esIcePlayer[survivor].g_iOwner = 0;

	float flPos[3];
	GetClientEyePosition(survivor, flPos);

	if (GetEntityMoveType(survivor) == MOVETYPE_NONE)
	{
		SetEntityMoveType(survivor, MOVETYPE_WALK);
	}

	SetEntityRenderColor(survivor, 255, 255, 255, 255);

	if (all)
	{
		TeleportEntity(survivor, .velocity = view_as<float>({0.0, 0.0, 0.0}));
		EmitAmbientSound(SOUND_BULLET, flPos, survivor, SNDLEVEL_RAIDSIREN);
	}
}

Action tTimerIceCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esIceAbility[g_esIcePlayer[iTank].g_iTankType].g_iAccessFlags, g_esIcePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esIcePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esIceCache[iTank].g_iIceAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vIceAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerIceCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esIcePlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esIceAbility[g_esIcePlayer[iTank].g_iTankType].g_iAccessFlags, g_esIcePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esIcePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esIceCache[iTank].g_iIceHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esIceCache[iTank].g_iIceHitMode == 0 || g_esIceCache[iTank].g_iIceHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vIceHit(iSurvivor, iTank, flRandom, flChance, g_esIceCache[iTank].g_iIceHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esIceCache[iTank].g_iIceHitMode == 0 || g_esIceCache[iTank].g_iIceHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vIceHit(iSurvivor, iTank, flRandom, flChance, g_esIceCache[iTank].g_iIceHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopIce(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		g_esIcePlayer[iSurvivor].g_bAffected = false;
		g_esIcePlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank) || !g_esIcePlayer[iSurvivor].g_bAffected)
	{
		vStopIce(iSurvivor);

		return Plugin_Stop;
	}

	vStopIce(iSurvivor);

	int iMessage = pack.ReadCell();
	if (g_esIceCache[iTank].g_iIceMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Ice2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Ice2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}