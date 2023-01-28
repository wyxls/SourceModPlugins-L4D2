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

#define MT_CHOKE_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_CHOKE_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Choke Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank chokes survivors in midair.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Choke Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_CHOKE_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_CHOKE_SECTION "chokeability"
#define MT_CHOKE_SECTION2 "choke ability"
#define MT_CHOKE_SECTION3 "choke_ability"
#define MT_CHOKE_SECTION4 "choke"

#define MT_MENU_CHOKE "Choke Ability"

enum struct esChokePlayer
{
	bool g_bAffected;
	bool g_bBlockFall;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flChokeChance;
	float g_flChokeDamage;
	float g_flChokeDelay;
	float g_flChokeRange;
	float g_flChokeRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iChokeAbility;
	int g_iChokeCooldown;
	int g_iChokeDuration;
	int g_iChokeEffect;
	int g_iChokeHit;
	int g_iChokeHitMode;
	int g_iChokeMessage;
	int g_iChokeRangeCooldown;
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
}

esChokePlayer g_esChokePlayer[MAXPLAYERS + 1];

enum struct esChokeAbility
{
	float g_flChokeChance;
	float g_flChokeDamage;
	float g_flChokeDelay;
	float g_flChokeRange;
	float g_flChokeRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iChokeAbility;
	int g_iChokeCooldown;
	int g_iChokeDuration;
	int g_iChokeEffect;
	int g_iChokeHit;
	int g_iChokeHitMode;
	int g_iChokeMessage;
	int g_iChokeRangeCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esChokeAbility g_esChokeAbility[MT_MAXTYPES + 1];

enum struct esChokeCache
{
	float g_flChokeChance;
	float g_flChokeDamage;
	float g_flChokeDelay;
	float g_flChokeRange;
	float g_flChokeRangeChance;
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;

	int g_iChokeAbility;
	int g_iChokeCooldown;
	int g_iChokeDuration;
	int g_iChokeEffect;
	int g_iChokeHit;
	int g_iChokeHitMode;
	int g_iChokeMessage;
	int g_iChokeRangeCooldown;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
}

esChokeCache g_esChokeCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_choke", cmdChokeInfo, "View information about the Choke ability.");

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
void vChokeMapStart()
#else
public void OnMapStart()
#endif
{
	vChokeReset();
}

#if defined MT_ABILITIES_MAIN
void vChokeClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnChokeTakeDamage);
	vChokeReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vChokeClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vChokeReset3(client);
}

#if defined MT_ABILITIES_MAIN
void vChokeMapEnd()
#else
public void OnMapEnd()
#endif
{
	vChokeReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdChokeInfo(int client, int args)
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
		case false: vChokeMenu(client, MT_CHOKE_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vChokeMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_CHOKE_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iChokeMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Choke Ability Information");
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

int iChokeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esChokeCache[param1].g_iChokeAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esChokeCache[param1].g_iHumanAmmo - g_esChokePlayer[param1].g_iAmmoCount), g_esChokeCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esChokeCache[param1].g_iHumanAbility == 1) ? g_esChokeCache[param1].g_iHumanCooldown : g_esChokeCache[param1].g_iChokeCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "ChokeDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", g_esChokeCache[param1].g_iChokeDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esChokeCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esChokeCache[param1].g_iHumanAbility == 1) ? g_esChokeCache[param1].g_iHumanRangeCooldown : g_esChokeCache[param1].g_iChokeRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vChokeMenu(param1, MT_CHOKE_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pChoke = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "ChokeMenu", param1);
			pChoke.SetTitle(sMenuTitle);
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
void vChokeDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_CHOKE, MT_MENU_CHOKE);
}

#if defined MT_ABILITIES_MAIN
void vChokeMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_CHOKE, false))
	{
		vChokeMenu(client, MT_CHOKE_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_CHOKE, false))
	{
		FormatEx(buffer, size, "%T", "ChokeMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN
Action aChokePlayerRunCmd(int client, int &buttons)
#else
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
#endif
{
	if (!MT_IsCorePluginEnabled())
	{
		return Plugin_Continue;
	}

	if (g_esChokePlayer[client].g_bAffected && ((buttons & IN_ATTACK) || (buttons & IN_ATTACK2) || (buttons & IN_USE)))
	{
		int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (iWeapon > MaxClients)
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", 99999.0);
			SetEntPropFloat(client, Prop_Send, "m_flNextAttack", 99999.0);
		}

		buttons &= IN_ATTACK;
		buttons &= IN_ATTACK2;
		buttons &= IN_USE;

		return Plugin_Changed;
	}

	return Plugin_Continue;
}

Action OnChokeTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		if (bIsSurvivor(victim) && (damagetype & DMG_FALL) && g_esChokePlayer[victim].g_bBlockFall)
		{
			g_esChokePlayer[victim].g_bBlockFall = false;

			return Plugin_Handled;
		}
		else if (bIsValidEntity(inflictor))
		{
			char sClassname[32];
			GetEntityClassname(inflictor, sClassname, sizeof sClassname);
			if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esChokeCache[attacker].g_iChokeHitMode == 0 || g_esChokeCache[attacker].g_iChokeHitMode == 1) && bIsSurvivor(victim) && g_esChokeCache[attacker].g_iComboAbility == 0)
			{
				if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esChokeAbility[g_esChokePlayer[attacker].g_iTankType].g_iAccessFlags, g_esChokePlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esChokePlayer[attacker].g_iTankType, g_esChokeAbility[g_esChokePlayer[attacker].g_iTankType].g_iImmunityFlags, g_esChokePlayer[victim].g_iImmunityFlags))
				{
					return Plugin_Continue;
				}

				if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
				{
					vChokeHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esChokeCache[attacker].g_flChokeChance, g_esChokeCache[attacker].g_iChokeHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
				}
			}
			else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esChokeCache[victim].g_iChokeHitMode == 0 || g_esChokeCache[victim].g_iChokeHitMode == 2) && bIsSurvivor(attacker) && g_esChokeCache[victim].g_iComboAbility == 0)
			{
				if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esChokeAbility[g_esChokePlayer[victim].g_iTankType].g_iAccessFlags, g_esChokePlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esChokePlayer[victim].g_iTankType, g_esChokeAbility[g_esChokePlayer[victim].g_iTankType].g_iImmunityFlags, g_esChokePlayer[attacker].g_iImmunityFlags))
				{
					return Plugin_Continue;
				}

				if (StrEqual(sClassname[7], "melee"))
				{
					vChokeHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esChokeCache[victim].g_flChokeChance, g_esChokeCache[victim].g_iChokeHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
				}
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vChokePluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_CHOKE);
}

#if defined MT_ABILITIES_MAIN
void vChokeAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_CHOKE_SECTION);
	list2.PushString(MT_CHOKE_SECTION2);
	list3.PushString(MT_CHOKE_SECTION3);
	list4.PushString(MT_CHOKE_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vChokeCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_CHOKE_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_CHOKE_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_CHOKE_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_CHOKE_SECTION4);
	if (g_esChokeCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_CHOKE_SECTION, false) || StrEqual(sSubset[iPos], MT_CHOKE_SECTION2, false) || StrEqual(sSubset[iPos], MT_CHOKE_SECTION3, false) || StrEqual(sSubset[iPos], MT_CHOKE_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esChokeCache[tank].g_iChokeAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vChokeAbility(tank, random);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerChokeCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esChokeCache[tank].g_iChokeHitMode == 0 || g_esChokeCache[tank].g_iChokeHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vChokeHit(survivor, tank, random, flChance, g_esChokeCache[tank].g_iChokeHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
								}
								else if ((g_esChokeCache[tank].g_iChokeHitMode == 0 || g_esChokeCache[tank].g_iChokeHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vChokeHit(survivor, tank, random, flChance, g_esChokeCache[tank].g_iChokeHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerChokeCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vChokeConfigsLoad(int mode)
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
				g_esChokeAbility[iIndex].g_iAccessFlags = 0;
				g_esChokeAbility[iIndex].g_iImmunityFlags = 0;
				g_esChokeAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esChokeAbility[iIndex].g_iComboAbility = 0;
				g_esChokeAbility[iIndex].g_iHumanAbility = 0;
				g_esChokeAbility[iIndex].g_iHumanAmmo = 5;
				g_esChokeAbility[iIndex].g_iHumanCooldown = 0;
				g_esChokeAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esChokeAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esChokeAbility[iIndex].g_iRequiresHumans = 0;
				g_esChokeAbility[iIndex].g_iChokeAbility = 0;
				g_esChokeAbility[iIndex].g_iChokeEffect = 0;
				g_esChokeAbility[iIndex].g_iChokeMessage = 0;
				g_esChokeAbility[iIndex].g_flChokeChance = 33.3;
				g_esChokeAbility[iIndex].g_iChokeCooldown = 0;
				g_esChokeAbility[iIndex].g_flChokeDamage = 5.0;
				g_esChokeAbility[iIndex].g_flChokeDelay = 1.0;
				g_esChokeAbility[iIndex].g_iChokeDuration = 5;
				g_esChokeAbility[iIndex].g_iChokeHit = 0;
				g_esChokeAbility[iIndex].g_iChokeHitMode = 0;
				g_esChokeAbility[iIndex].g_flChokeRange = 150.0;
				g_esChokeAbility[iIndex].g_flChokeRangeChance = 15.0;
				g_esChokeAbility[iIndex].g_iChokeRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esChokePlayer[iPlayer].g_iAccessFlags = 0;
					g_esChokePlayer[iPlayer].g_iImmunityFlags = 0;
					g_esChokePlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esChokePlayer[iPlayer].g_iComboAbility = 0;
					g_esChokePlayer[iPlayer].g_iHumanAbility = 0;
					g_esChokePlayer[iPlayer].g_iHumanAmmo = 0;
					g_esChokePlayer[iPlayer].g_iHumanCooldown = 0;
					g_esChokePlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esChokePlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esChokePlayer[iPlayer].g_iRequiresHumans = 0;
					g_esChokePlayer[iPlayer].g_iChokeAbility = 0;
					g_esChokePlayer[iPlayer].g_iChokeEffect = 0;
					g_esChokePlayer[iPlayer].g_iChokeMessage = 0;
					g_esChokePlayer[iPlayer].g_flChokeChance = 0.0;
					g_esChokePlayer[iPlayer].g_iChokeCooldown = 0;
					g_esChokePlayer[iPlayer].g_flChokeDamage = 0.0;
					g_esChokePlayer[iPlayer].g_flChokeDelay = 0.0;
					g_esChokePlayer[iPlayer].g_iChokeDuration = 0;
					g_esChokePlayer[iPlayer].g_iChokeHit = 0;
					g_esChokePlayer[iPlayer].g_iChokeHitMode = 0;
					g_esChokePlayer[iPlayer].g_flChokeRange = 0.0;
					g_esChokePlayer[iPlayer].g_flChokeRangeChance = 0.0;
					g_esChokePlayer[iPlayer].g_iChokeRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esChokePlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esChokePlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esChokePlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esChokePlayer[admin].g_iComboAbility, value, 0, 1);
		g_esChokePlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esChokePlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esChokePlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esChokePlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esChokePlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esChokePlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esChokePlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esChokePlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esChokePlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esChokePlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esChokePlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esChokePlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esChokePlayer[admin].g_iChokeAbility = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esChokePlayer[admin].g_iChokeAbility, value, 0, 1);
		g_esChokePlayer[admin].g_iChokeEffect = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esChokePlayer[admin].g_iChokeEffect, value, 0, 7);
		g_esChokePlayer[admin].g_iChokeMessage = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esChokePlayer[admin].g_iChokeMessage, value, 0, 3);
		g_esChokePlayer[admin].g_flChokeChance = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeChance", "Choke Chance", "Choke_Chance", "chance", g_esChokePlayer[admin].g_flChokeChance, value, 0.0, 100.0);
		g_esChokePlayer[admin].g_iChokeCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeCooldown", "Choke Cooldown", "Choke_Cooldown", "cooldown", g_esChokePlayer[admin].g_iChokeCooldown, value, 0, 99999);
		g_esChokePlayer[admin].g_flChokeDamage = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeDamage", "Choke Damage", "Choke_Damage", "damage", g_esChokePlayer[admin].g_flChokeDamage, value, 0.0, 99999.0);
		g_esChokePlayer[admin].g_flChokeDelay = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeDelay", "Choke Delay", "Choke_Delay", "delay", g_esChokePlayer[admin].g_flChokeDelay, value, 0.1, 99999.0);
		g_esChokePlayer[admin].g_iChokeDuration = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeDuration", "Choke Duration", "Choke_Duration", "duration", g_esChokePlayer[admin].g_iChokeDuration, value, 1, 99999);
		g_esChokePlayer[admin].g_iChokeHit = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeHit", "Choke Hit", "Choke_Hit", "hit", g_esChokePlayer[admin].g_iChokeHit, value, 0, 1);
		g_esChokePlayer[admin].g_iChokeHitMode = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeHitMode", "Choke Hit Mode", "Choke_Hit_Mode", "hitmode", g_esChokePlayer[admin].g_iChokeHitMode, value, 0, 2);
		g_esChokePlayer[admin].g_flChokeRange = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeRange", "Choke Range", "Choke_Range", "range", g_esChokePlayer[admin].g_flChokeRange, value, 1.0, 99999.0);
		g_esChokePlayer[admin].g_flChokeRangeChance = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeRangeChance", "Choke Range Chance", "Choke_Range_Chance", "rangechance", g_esChokePlayer[admin].g_flChokeRangeChance, value, 0.0, 100.0);
		g_esChokePlayer[admin].g_iChokeRangeCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeRangeCooldown", "Choke Range Cooldown", "Choke_Range_Cooldown", "rangecooldown", g_esChokePlayer[admin].g_iChokeRangeCooldown, value, 0, 99999);
		g_esChokePlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esChokePlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esChokeAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esChokeAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esChokeAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esChokeAbility[type].g_iComboAbility, value, 0, 1);
		g_esChokeAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esChokeAbility[type].g_iHumanAbility, value, 0, 2);
		g_esChokeAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esChokeAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esChokeAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esChokeAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esChokeAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esChokeAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esChokeAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esChokeAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esChokeAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esChokeAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esChokeAbility[type].g_iChokeAbility = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esChokeAbility[type].g_iChokeAbility, value, 0, 1);
		g_esChokeAbility[type].g_iChokeEffect = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esChokeAbility[type].g_iChokeEffect, value, 0, 7);
		g_esChokeAbility[type].g_iChokeMessage = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esChokeAbility[type].g_iChokeMessage, value, 0, 3);
		g_esChokeAbility[type].g_flChokeChance = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeChance", "Choke Chance", "Choke_Chance", "chance", g_esChokeAbility[type].g_flChokeChance, value, 0.0, 100.0);
		g_esChokeAbility[type].g_iChokeCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeCooldown", "Choke Cooldown", "Choke_Cooldown", "cooldown", g_esChokeAbility[type].g_iChokeCooldown, value, 0, 99999);
		g_esChokeAbility[type].g_flChokeDamage = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeDamage", "Choke Damage", "Choke_Damage", "damage", g_esChokeAbility[type].g_flChokeDamage, value, 0.0, 99999.0);
		g_esChokeAbility[type].g_flChokeDelay = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeDelay", "Choke Delay", "Choke_Delay", "delay", g_esChokeAbility[type].g_flChokeDelay, value, 0.1, 99999.0);
		g_esChokeAbility[type].g_iChokeDuration = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeDuration", "Choke Duration", "Choke_Duration", "duration", g_esChokeAbility[type].g_iChokeDuration, value, 1, 99999);
		g_esChokeAbility[type].g_iChokeHit = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeHit", "Choke Hit", "Choke_Hit", "hit", g_esChokeAbility[type].g_iChokeHit, value, 0, 1);
		g_esChokeAbility[type].g_iChokeHitMode = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeHitMode", "Choke Hit Mode", "Choke_Hit_Mode", "hitmode", g_esChokeAbility[type].g_iChokeHitMode, value, 0, 2);
		g_esChokeAbility[type].g_flChokeRange = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeRange", "Choke Range", "Choke_Range", "range", g_esChokeAbility[type].g_flChokeRange, value, 1.0, 99999.0);
		g_esChokeAbility[type].g_flChokeRangeChance = flGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeRangeChance", "Choke Range Chance", "Choke_Range_Chance", "rangechance", g_esChokeAbility[type].g_flChokeRangeChance, value, 0.0, 100.0);
		g_esChokeAbility[type].g_iChokeRangeCooldown = iGetKeyValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ChokeRangeCooldown", "Choke Range Cooldown", "Choke_Range_Cooldown", "rangecooldown", g_esChokeAbility[type].g_iChokeRangeCooldown, value, 0, 99999);
		g_esChokeAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esChokeAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_CHOKE_SECTION, MT_CHOKE_SECTION2, MT_CHOKE_SECTION3, MT_CHOKE_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esChokeCache[tank].g_flChokeChance = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flChokeChance, g_esChokeAbility[type].g_flChokeChance);
	g_esChokeCache[tank].g_flChokeDamage = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flChokeDamage, g_esChokeAbility[type].g_flChokeDamage);
	g_esChokeCache[tank].g_flChokeDelay = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flChokeDelay, g_esChokeAbility[type].g_flChokeDelay);
	g_esChokeCache[tank].g_flChokeRange = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flChokeRange, g_esChokeAbility[type].g_flChokeRange);
	g_esChokeCache[tank].g_flChokeRangeChance = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flChokeRangeChance, g_esChokeAbility[type].g_flChokeRangeChance);
	g_esChokeCache[tank].g_iChokeAbility = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeAbility, g_esChokeAbility[type].g_iChokeAbility);
	g_esChokeCache[tank].g_iChokeCooldown = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeCooldown, g_esChokeAbility[type].g_iChokeCooldown);
	g_esChokeCache[tank].g_iChokeDuration = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeDuration, g_esChokeAbility[type].g_iChokeDuration);
	g_esChokeCache[tank].g_iChokeEffect = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeEffect, g_esChokeAbility[type].g_iChokeEffect);
	g_esChokeCache[tank].g_iChokeHit = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeHit, g_esChokeAbility[type].g_iChokeHit);
	g_esChokeCache[tank].g_iChokeHitMode = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeHitMode, g_esChokeAbility[type].g_iChokeHitMode);
	g_esChokeCache[tank].g_iChokeMessage = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeMessage, g_esChokeAbility[type].g_iChokeMessage);
	g_esChokeCache[tank].g_iChokeRangeCooldown = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iChokeRangeCooldown, g_esChokeAbility[type].g_iChokeRangeCooldown);
	g_esChokeCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flCloseAreasOnly, g_esChokeAbility[type].g_flCloseAreasOnly);
	g_esChokeCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iComboAbility, g_esChokeAbility[type].g_iComboAbility);
	g_esChokeCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iHumanAbility, g_esChokeAbility[type].g_iHumanAbility);
	g_esChokeCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iHumanAmmo, g_esChokeAbility[type].g_iHumanAmmo);
	g_esChokeCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iHumanCooldown, g_esChokeAbility[type].g_iHumanCooldown);
	g_esChokeCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iHumanRangeCooldown, g_esChokeAbility[type].g_iHumanRangeCooldown);
	g_esChokeCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_flOpenAreasOnly, g_esChokeAbility[type].g_flOpenAreasOnly);
	g_esChokeCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esChokePlayer[tank].g_iRequiresHumans, g_esChokeAbility[type].g_iRequiresHumans);
	g_esChokePlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vChokeCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vChokeCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveChoke(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vChokePluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esChokePlayer[iSurvivor].g_bAffected)
		{
			SetEntityMoveType(iSurvivor, MOVETYPE_WALK);
			SetEntityGravity(iSurvivor, 1.0);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeEventFired(Event event, const char[] name)
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
			vChokeCopyStats2(iBot, iTank);
			vRemoveChoke(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vChokeCopyStats2(iTank, iBot);
			vRemoveChoke(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveChoke(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vChokeReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeFatalFalling(int survivor)
#else
public Action MT_OnFatalFalling(int survivor)
#endif
{
	if (bIsSurvivor(survivor) && g_esChokePlayer[survivor].g_bBlockFall)
	{
		g_esChokePlayer[survivor].g_bBlockFall = false;
	}
#if !defined MT_ABILITIES_MAIN
	return Plugin_Continue;
#endif
}

#if defined MT_ABILITIES_MAIN
void vChokeAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esChokeAbility[g_esChokePlayer[tank].g_iTankType].g_iAccessFlags, g_esChokePlayer[tank].g_iAccessFlags)) || g_esChokeCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esChokeCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esChokeCache[tank].g_iChokeAbility == 1 && g_esChokeCache[tank].g_iComboAbility == 0)
	{
		vChokeAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esChokeCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esChokeCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esChokePlayer[tank].g_iTankType) || (g_esChokeCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esChokeCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esChokeAbility[g_esChokePlayer[tank].g_iTankType].g_iAccessFlags, g_esChokePlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esChokeCache[tank].g_iChokeAbility == 1 && g_esChokeCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esChokePlayer[tank].g_iRangeCooldown == -1 || g_esChokePlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vChokeAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeHuman3", (g_esChokePlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vChokeChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveChoke(tank);
}

void vChokeAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esChokeCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esChokeCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esChokePlayer[tank].g_iTankType) || (g_esChokeCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esChokeCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esChokeAbility[g_esChokePlayer[tank].g_iTankType].g_iAccessFlags, g_esChokePlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esChokePlayer[tank].g_iAmmoCount < g_esChokeCache[tank].g_iHumanAmmo && g_esChokeCache[tank].g_iHumanAmmo > 0))
	{
		g_esChokePlayer[tank].g_bFailed = false;
		g_esChokePlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esChokeCache[tank].g_flChokeRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esChokeCache[tank].g_flChokeRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esChokePlayer[tank].g_iTankType, g_esChokeAbility[g_esChokePlayer[tank].g_iTankType].g_iImmunityFlags, g_esChokePlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vChokeHit(iSurvivor, tank, random, flChance, g_esChokeCache[tank].g_iChokeAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeAmmo");
	}
}

void vChokeHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esChokeCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esChokeCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esChokePlayer[tank].g_iTankType) || (g_esChokeCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esChokeCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esChokeAbility[g_esChokePlayer[tank].g_iTankType].g_iAccessFlags, g_esChokePlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esChokePlayer[tank].g_iTankType, g_esChokeAbility[g_esChokePlayer[tank].g_iTankType].g_iImmunityFlags, g_esChokePlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esChokePlayer[tank].g_iRangeCooldown != -1 && g_esChokePlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esChokePlayer[tank].g_iCooldown != -1 && g_esChokePlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorDisabled(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esChokePlayer[tank].g_iAmmoCount < g_esChokeCache[tank].g_iHumanAmmo && g_esChokeCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esChokePlayer[survivor].g_bAffected)
			{
				g_esChokePlayer[survivor].g_bAffected = true;
				g_esChokePlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esChokePlayer[tank].g_iRangeCooldown == -1 || g_esChokePlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1)
					{
						g_esChokePlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeHuman", g_esChokePlayer[tank].g_iAmmoCount, g_esChokeCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esChokeCache[tank].g_iChokeRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1 && g_esChokePlayer[tank].g_iAmmoCount < g_esChokeCache[tank].g_iHumanAmmo && g_esChokeCache[tank].g_iHumanAmmo > 0) ? g_esChokeCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esChokePlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esChokePlayer[tank].g_iRangeCooldown != -1 && g_esChokePlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeHuman5", (g_esChokePlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esChokePlayer[tank].g_iCooldown == -1 || g_esChokePlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esChokeCache[tank].g_iChokeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1) ? g_esChokeCache[tank].g_iHumanCooldown : iCooldown;
					g_esChokePlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esChokePlayer[tank].g_iCooldown != -1 && g_esChokePlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeHuman5", (g_esChokePlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDelay = (pos != -1) ? 0.1 : g_esChokeCache[tank].g_flChokeDelay;
				DataPack dpChokeLaunch;
				CreateDataTimer(flDelay, tTimerChokeLaunch, dpChokeLaunch, TIMER_FLAG_NO_MAPCHANGE);
				dpChokeLaunch.WriteCell(GetClientUserId(survivor));
				dpChokeLaunch.WriteCell(GetClientUserId(tank));
				dpChokeLaunch.WriteCell(g_esChokePlayer[tank].g_iTankType);
				dpChokeLaunch.WriteCell(enabled);
				dpChokeLaunch.WriteCell(messages);
				dpChokeLaunch.WriteCell(pos);

				vScreenEffect(survivor, tank, g_esChokeCache[tank].g_iChokeEffect, flags);

				if (g_esChokeCache[tank].g_iChokeMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Choke", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Choke", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esChokePlayer[tank].g_iRangeCooldown == -1 || g_esChokePlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1 && !g_esChokePlayer[tank].g_bFailed)
				{
					g_esChokePlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esChokeCache[tank].g_iHumanAbility == 1 && !g_esChokePlayer[tank].g_bNoAmmo)
		{
			g_esChokePlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "ChokeAmmo");
		}
	}
}

void vChokeCopyStats2(int oldTank, int newTank)
{
	g_esChokePlayer[newTank].g_iAmmoCount = g_esChokePlayer[oldTank].g_iAmmoCount;
	g_esChokePlayer[newTank].g_iCooldown = g_esChokePlayer[oldTank].g_iCooldown;
	g_esChokePlayer[newTank].g_iRangeCooldown = g_esChokePlayer[oldTank].g_iRangeCooldown;
}

void vRemoveChoke(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esChokePlayer[iSurvivor].g_bAffected && g_esChokePlayer[iSurvivor].g_iOwner == tank)
		{
			g_esChokePlayer[iSurvivor].g_bAffected = false;
			g_esChokePlayer[iSurvivor].g_bBlockFall = false;
			g_esChokePlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vChokeReset3(tank);
}

void vChokeReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vChokeReset3(iPlayer);

			g_esChokePlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vChokeReset2(int survivor, int tank, int messages)
{
	g_esChokePlayer[survivor].g_bAffected = false;
	g_esChokePlayer[survivor].g_bBlockFall = true;
	g_esChokePlayer[survivor].g_iOwner = 0;

	SetEntityMoveType(survivor, MOVETYPE_WALK);
	SetEntityGravity(survivor, 1.0);

	int iWeapon = 0;
	for (int iSlot = 0; iSlot < 5; iSlot++)
	{
		iWeapon = GetPlayerWeaponSlot(survivor, iSlot);
		if (iWeapon > MaxClients)
		{
			SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", 1.0);
		}
	}

	SetEntPropFloat(survivor, Prop_Send, "m_flNextAttack", 1.0);

	if (g_esChokeCache[tank].g_iChokeMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Choke2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Choke2", LANG_SERVER, survivor);
	}
}

void vChokeReset3(int tank)
{
	g_esChokePlayer[tank].g_bAffected = false;
	g_esChokePlayer[tank].g_bBlockFall = false;
	g_esChokePlayer[tank].g_bFailed = false;
	g_esChokePlayer[tank].g_bNoAmmo = false;
	g_esChokePlayer[tank].g_iAmmoCount = 0;
	g_esChokePlayer[tank].g_iCooldown = -1;
	g_esChokePlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerChokeLaunch(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor) || bIsSurvivorDisabled(iSurvivor) || !g_esChokePlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		g_esChokePlayer[iSurvivor].g_bAffected = false;
		g_esChokePlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iChokeEnabled = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esChokeAbility[g_esChokePlayer[iTank].g_iTankType].g_iAccessFlags, g_esChokePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esChokePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esChokePlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esChokePlayer[iTank].g_iTankType, g_esChokeAbility[g_esChokePlayer[iTank].g_iTankType].g_iImmunityFlags, g_esChokePlayer[iSurvivor].g_iImmunityFlags) || iChokeEnabled == 0)
	{
		g_esChokePlayer[iSurvivor].g_bAffected = false;
		g_esChokePlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esChokePlayer[iSurvivor].g_bBlockFall = true;

	TeleportEntity(iSurvivor, .velocity = view_as<float>({0.0, 0.0, 0.0}));
	TeleportEntity(iSurvivor, .velocity = view_as<float>({0.0, 0.0, 300.0}));
	SetEntityGravity(iSurvivor, 0.1);

	int iMessage = pack.ReadCell(), iPos = pack.ReadCell();
	DataPack dpChokeDamage;
	CreateDataTimer(1.0, tTimerChokeDamage, dpChokeDamage, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	dpChokeDamage.WriteCell(GetClientUserId(iSurvivor));
	dpChokeDamage.WriteCell(GetClientUserId(iTank));
	dpChokeDamage.WriteCell(g_esChokePlayer[iTank].g_iTankType);
	dpChokeDamage.WriteCell(iMessage);
	dpChokeDamage.WriteCell(iChokeEnabled);
	dpChokeDamage.WriteCell(iPos);
	dpChokeDamage.WriteCell(GetTime());

	return Plugin_Continue;
}

Action tTimerChokeDamage(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esChokePlayer[iSurvivor].g_bAffected = false;
		g_esChokePlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esChokeAbility[g_esChokePlayer[iTank].g_iTankType].g_iAccessFlags, g_esChokePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esChokePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esChokePlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esChokePlayer[iTank].g_iTankType, g_esChokeAbility[g_esChokePlayer[iTank].g_iTankType].g_iImmunityFlags, g_esChokePlayer[iSurvivor].g_iImmunityFlags) || bIsSurvivorDisabled(iSurvivor) || !g_esChokePlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vChokeReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iChokeEnabled = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esChokeCache[iTank].g_iChokeDuration,
		iTime = pack.ReadCell();
	if (iChokeEnabled == 0 || (iTime + iDuration) < GetTime())
	{
		vChokeReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	TeleportEntity(iSurvivor, .velocity = view_as<float>({0.0, 0.0, 0.0}));
	SetEntityMoveType(iSurvivor, MOVETYPE_NONE);
	SetEntityGravity(iSurvivor, 1.0);

	float flDamage = (iPos != -1) ? MT_GetCombinationSetting(iTank, 3, iPos) : g_esChokeCache[iTank].g_flChokeDamage;
	if (flDamage > 0.0)
	{
		vDamagePlayer(iSurvivor, iTank, MT_GetScaledDamage(flDamage), "16384");
	}

	return Plugin_Continue;
}

Action tTimerChokeCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esChokeAbility[g_esChokePlayer[iTank].g_iTankType].g_iAccessFlags, g_esChokePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esChokePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esChokeCache[iTank].g_iChokeAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vChokeAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerChokeCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsHumanSurvivor(iSurvivor) || g_esChokePlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esChokeAbility[g_esChokePlayer[iTank].g_iTankType].g_iAccessFlags, g_esChokePlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esChokePlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esChokeCache[iTank].g_iChokeHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esChokeCache[iTank].g_iChokeHitMode == 0 || g_esChokeCache[iTank].g_iChokeHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vChokeHit(iSurvivor, iTank, flRandom, flChance, g_esChokeCache[iTank].g_iChokeHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esChokeCache[iTank].g_iChokeHitMode == 0 || g_esChokeCache[iTank].g_iChokeHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vChokeHit(iSurvivor, iTank, flRandom, flChance, g_esChokeCache[iTank].g_iChokeHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}