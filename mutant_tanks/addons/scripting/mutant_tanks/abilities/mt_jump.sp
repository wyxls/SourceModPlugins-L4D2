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

#define MT_JUMP_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_JUMP_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Jump Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank jumps periodically or sporadically and makes survivors jump uncontrollably.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Jump Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_JUMP_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_JUMP_SECTION "jumpability"
#define MT_JUMP_SECTION2 "jump ability"
#define MT_JUMP_SECTION3 "jump_ability"
#define MT_JUMP_SECTION4 "jump"

#define MT_MENU_JUMP "Jump Ability"

enum struct esJumpPlayer
{
	bool g_bActivated;
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flJumpChance;
	float g_flJumpHeight;
	float g_flJumpInterval;
	float g_flJumpRange;
	float g_flJumpRangeChance;
	float g_flJumpSporadicChance;
	float g_flJumpSporadicHeight;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iAmmoCount2;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iCooldown2;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iJumpAbility;
	int g_iJumpCooldown;
	int g_iJumpDuration;
	int g_iJumpEffect;
	int g_iJumpHit;
	int g_iJumpHitMode;
	int g_iJumpMessage;
	int g_iJumpMode;
	int g_iJumpRangeCooldown;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esJumpPlayer g_esJumpPlayer[MAXPLAYERS + 1];

enum struct esJumpAbility
{
	float g_flCloseAreasOnly;
	float g_flJumpChance;
	float g_flJumpHeight;
	float g_flJumpInterval;
	float g_flJumpRange;
	float g_flJumpRangeChance;
	float g_flJumpSporadicChance;
	float g_flJumpSporadicHeight;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iComboPosition;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iJumpAbility;
	int g_iJumpCooldown;
	int g_iJumpDuration;
	int g_iJumpEffect;
	int g_iJumpHit;
	int g_iJumpHitMode;
	int g_iJumpMessage;
	int g_iJumpMode;
	int g_iJumpRangeCooldown;
	int g_iRequiresHumans;
}

esJumpAbility g_esJumpAbility[MT_MAXTYPES + 1];

enum struct esJumpCache
{
	float g_flCloseAreasOnly;
	float g_flJumpChance;
	float g_flJumpHeight;
	float g_flJumpInterval;
	float g_flJumpRange;
	float g_flJumpRangeChance;
	float g_flJumpSporadicChance;
	float g_flJumpSporadicHeight;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanDuration;
	int g_iHumanMode;
	int g_iHumanRangeCooldown;
	int g_iJumpAbility;
	int g_iJumpCooldown;
	int g_iJumpDuration;
	int g_iJumpEffect;
	int g_iJumpHit;
	int g_iJumpHitMode;
	int g_iJumpMessage;
	int g_iJumpMode;
	int g_iJumpRangeCooldown;
	int g_iRequiresHumans;
}

esJumpCache g_esJumpCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_jump", cmdJumpInfo, "View information about the Jump ability.");

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
void vJumpMapStart()
#else
public void OnMapStart()
#endif
{
	vJumpReset();
}

#if defined MT_ABILITIES_MAIN
void vJumpClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnJumpTakeDamage);
	vJumpReset4(client);
}

#if defined MT_ABILITIES_MAIN
void vJumpClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vJumpReset4(client);
}

#if defined MT_ABILITIES_MAIN
void vJumpMapEnd()
#else
public void OnMapEnd()
#endif
{
	vJumpReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdJumpInfo(int client, int args)
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
		case false: vJumpMenu(client, MT_JUMP_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vJumpMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_JUMP_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iJumpMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Jump Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Button Mode", "Button Mode");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Duration", "Duration");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iJumpMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esJumpCache[param1].g_iJumpAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1:
				{
					MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esJumpCache[param1].g_iHumanAmmo - g_esJumpPlayer[param1].g_iAmmoCount), g_esJumpCache[param1].g_iHumanAmmo);
					MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo2", (g_esJumpCache[param1].g_iHumanAmmo - g_esJumpPlayer[param1].g_iAmmoCount2), g_esJumpCache[param1].g_iHumanAmmo);
				}
				case 2:
				{
					MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons");
					MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				}
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esJumpCache[param1].g_iHumanMode == 0) ? "AbilityButtonMode1" : "AbilityButtonMode2");
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esJumpCache[param1].g_iHumanAbility == 1) ? g_esJumpCache[param1].g_iHumanCooldown : g_esJumpCache[param1].g_iJumpCooldown));
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "JumpDetails");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration2", ((g_esJumpCache[param1].g_iHumanAbility == 1) ? g_esJumpCache[param1].g_iHumanDuration : g_esJumpCache[param1].g_iJumpDuration));
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esJumpCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 8: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esJumpCache[param1].g_iHumanAbility == 1) ? g_esJumpCache[param1].g_iHumanRangeCooldown : g_esJumpCache[param1].g_iJumpRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vJumpMenu(param1, MT_JUMP_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pJump = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "JumpMenu", param1);
			pJump.SetTitle(sMenuTitle);
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
					case 8: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN
void vJumpDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_JUMP, MT_MENU_JUMP);
}

#if defined MT_ABILITIES_MAIN
void vJumpMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_JUMP, false))
	{
		vJumpMenu(client, MT_JUMP_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_JUMP, false))
	{
		FormatEx(buffer, size, "%T", "JumpMenu2", client);
	}
}

Action OnJumpTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esJumpCache[attacker].g_iJumpHitMode == 0 || g_esJumpCache[attacker].g_iJumpHitMode == 1) && bIsSurvivor(victim) && g_esJumpCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esJumpAbility[g_esJumpPlayer[attacker].g_iTankType].g_iAccessFlags, g_esJumpPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esJumpPlayer[attacker].g_iTankType, g_esJumpAbility[g_esJumpPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vJumpHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esJumpCache[attacker].g_flJumpChance, g_esJumpCache[attacker].g_iJumpHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esJumpCache[victim].g_iJumpHitMode == 0 || g_esJumpCache[victim].g_iJumpHitMode == 2) && bIsSurvivor(attacker) && g_esJumpCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esJumpAbility[g_esJumpPlayer[victim].g_iTankType].g_iAccessFlags, g_esJumpPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esJumpPlayer[victim].g_iTankType, g_esJumpAbility[g_esJumpPlayer[victim].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vJumpHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esJumpCache[victim].g_flJumpChance, g_esJumpCache[victim].g_iJumpHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vJumpPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_JUMP);
}

#if defined MT_ABILITIES_MAIN
void vJumpAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_JUMP_SECTION);
	list2.PushString(MT_JUMP_SECTION2);
	list3.PushString(MT_JUMP_SECTION3);
	list4.PushString(MT_JUMP_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vJumpCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility != 2)
	{
		g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iComboPosition = -1;

		return;
	}

	g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iComboPosition = -1;

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_JUMP_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_JUMP_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_JUMP_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_JUMP_SECTION4);
	if (g_esJumpCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_JUMP_SECTION, false) || StrEqual(sSubset[iPos], MT_JUMP_SECTION2, false) || StrEqual(sSubset[iPos], MT_JUMP_SECTION3, false) || StrEqual(sSubset[iPos], MT_JUMP_SECTION4, false))
			{
				g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iComboPosition = iPos;
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esJumpCache[tank].g_iJumpAbility == 1 || g_esJumpCache[tank].g_iJumpAbility == 3)
						{
							switch (flDelay)
							{
								case 0.0: vJumpAbility(tank, true, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerJumpCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
									dpCombo.WriteCell(GetClientUserId(tank));
									dpCombo.WriteFloat(random);
									dpCombo.WriteCell(iPos);
								}
							}
						}

						if (g_esJumpCache[tank].g_iJumpAbility == 2 || g_esJumpCache[tank].g_iJumpAbility == 3)
						{
							switch (flDelay)
							{
								case 0.0: vJumpAbility(tank, false, .pos = iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerJumpCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
									dpCombo.WriteCell(GetClientUserId(tank));
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
								if ((g_esJumpCache[tank].g_iJumpHitMode == 0 || g_esJumpCache[tank].g_iJumpHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vJumpHit(survivor, tank, random, flChance, g_esJumpCache[tank].g_iJumpHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esJumpCache[tank].g_iJumpHitMode == 0 || g_esJumpCache[tank].g_iJumpHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vJumpHit(survivor, tank, random, flChance, g_esJumpCache[tank].g_iJumpHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerJumpCombo3, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vJumpConfigsLoad(int mode)
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
				g_esJumpAbility[iIndex].g_iAccessFlags = 0;
				g_esJumpAbility[iIndex].g_iImmunityFlags = 0;
				g_esJumpAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esJumpAbility[iIndex].g_iComboAbility = 0;
				g_esJumpAbility[iIndex].g_iComboPosition = -1;
				g_esJumpAbility[iIndex].g_iHumanAbility = 0;
				g_esJumpAbility[iIndex].g_iHumanAmmo = 5;
				g_esJumpAbility[iIndex].g_iHumanCooldown = 0;
				g_esJumpAbility[iIndex].g_iHumanDuration = 5;
				g_esJumpAbility[iIndex].g_iHumanMode = 1;
				g_esJumpAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esJumpAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esJumpAbility[iIndex].g_iRequiresHumans = 0;
				g_esJumpAbility[iIndex].g_iJumpAbility = 0;
				g_esJumpAbility[iIndex].g_iJumpEffect = 0;
				g_esJumpAbility[iIndex].g_iJumpMessage = 0;
				g_esJumpAbility[iIndex].g_flJumpChance = 33.3;
				g_esJumpAbility[iIndex].g_iJumpCooldown = 0;
				g_esJumpAbility[iIndex].g_iJumpDuration = 5;
				g_esJumpAbility[iIndex].g_flJumpHeight = 300.0;
				g_esJumpAbility[iIndex].g_iJumpHit = 0;
				g_esJumpAbility[iIndex].g_iJumpHitMode = 0;
				g_esJumpAbility[iIndex].g_flJumpInterval = 1.0;
				g_esJumpAbility[iIndex].g_iJumpMode = 0;
				g_esJumpAbility[iIndex].g_flJumpRange = 150.0;
				g_esJumpAbility[iIndex].g_flJumpRangeChance = 15.0;
				g_esJumpAbility[iIndex].g_iJumpRangeCooldown = 0;
				g_esJumpAbility[iIndex].g_flJumpSporadicChance = 33.3;
				g_esJumpAbility[iIndex].g_flJumpSporadicHeight = 750.0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esJumpPlayer[iPlayer].g_iAccessFlags = 0;
					g_esJumpPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esJumpPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esJumpPlayer[iPlayer].g_iComboAbility = 0;
					g_esJumpPlayer[iPlayer].g_iHumanAbility = 0;
					g_esJumpPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esJumpPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esJumpPlayer[iPlayer].g_iHumanDuration = 0;
					g_esJumpPlayer[iPlayer].g_iHumanMode = 0;
					g_esJumpPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esJumpPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esJumpPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esJumpPlayer[iPlayer].g_iJumpAbility = 0;
					g_esJumpPlayer[iPlayer].g_iJumpEffect = 0;
					g_esJumpPlayer[iPlayer].g_iJumpMessage = 0;
					g_esJumpPlayer[iPlayer].g_flJumpChance = 0.0;
					g_esJumpPlayer[iPlayer].g_iJumpCooldown = 0;
					g_esJumpPlayer[iPlayer].g_iJumpDuration = 0;
					g_esJumpPlayer[iPlayer].g_flJumpHeight = 0.0;
					g_esJumpPlayer[iPlayer].g_iJumpHit = 0;
					g_esJumpPlayer[iPlayer].g_iJumpHitMode = 0;
					g_esJumpPlayer[iPlayer].g_flJumpInterval = 0.0;
					g_esJumpPlayer[iPlayer].g_iJumpMode = 0;
					g_esJumpPlayer[iPlayer].g_flJumpRange = 0.0;
					g_esJumpPlayer[iPlayer].g_flJumpRangeChance = 0.0;
					g_esJumpPlayer[iPlayer].g_iJumpRangeCooldown = 0;
					g_esJumpPlayer[iPlayer].g_flJumpSporadicChance = 0.0;
					g_esJumpPlayer[iPlayer].g_flJumpSporadicHeight = 0.0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esJumpPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esJumpPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esJumpPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esJumpPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esJumpPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esJumpPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esJumpPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esJumpPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esJumpPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esJumpPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esJumpPlayer[admin].g_iHumanDuration = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esJumpPlayer[admin].g_iHumanDuration, value, 0, 99999);
		g_esJumpPlayer[admin].g_iHumanMode = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esJumpPlayer[admin].g_iHumanMode, value, 0, 1);
		g_esJumpPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esJumpPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esJumpPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esJumpPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esJumpPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esJumpPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esJumpPlayer[admin].g_iJumpAbility = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esJumpPlayer[admin].g_iJumpAbility, value, 0, 3);
		g_esJumpPlayer[admin].g_iJumpEffect = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esJumpPlayer[admin].g_iJumpEffect, value, 0, 7);
		g_esJumpPlayer[admin].g_iJumpMessage = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esJumpPlayer[admin].g_iJumpMessage, value, 0, 7);
		g_esJumpPlayer[admin].g_flJumpChance = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpChance", "Jump Chance", "Jump_Chance", "chance", g_esJumpPlayer[admin].g_flJumpChance, value, 0.0, 100.0);
		g_esJumpPlayer[admin].g_iJumpCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpCooldown", "Jump Cooldown", "Jump_Cooldown", "cooldown", g_esJumpPlayer[admin].g_iJumpCooldown, value, 0, 99999);
		g_esJumpPlayer[admin].g_iJumpDuration = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpDuration", "Jump Duration", "Jump_Duration", "duration", g_esJumpPlayer[admin].g_iJumpDuration, value, 0, 99999);
		g_esJumpPlayer[admin].g_flJumpHeight = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpHeight", "Jump Height", "Jump_Height", "height", g_esJumpPlayer[admin].g_flJumpHeight, value, 0.1, 99999.0);
		g_esJumpPlayer[admin].g_iJumpHit = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpHit", "Jump Hit", "Jump_Hit", "hit", g_esJumpPlayer[admin].g_iJumpHit, value, 0, 1);
		g_esJumpPlayer[admin].g_iJumpHitMode = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpHitMode", "Jump Hit Mode", "Jump_Hit_Mode", "hitmode", g_esJumpPlayer[admin].g_iJumpHitMode, value, 0, 2);
		g_esJumpPlayer[admin].g_flJumpInterval = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpInterval", "Jump Interval", "Jump_Interval", "interval", g_esJumpPlayer[admin].g_flJumpInterval, value, 0.1, 99999.0);
		g_esJumpPlayer[admin].g_iJumpMode = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpMode", "Jump Mode", "Jump_Mode", "mode", g_esJumpPlayer[admin].g_iJumpMode, value, 0, 1);
		g_esJumpPlayer[admin].g_flJumpRange = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpRange", "Jump Range", "Jump_Range", "range", g_esJumpPlayer[admin].g_flJumpRange, value, 1.0, 99999.0);
		g_esJumpPlayer[admin].g_flJumpRangeChance = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpRangeChance", "Jump Range Chance", "Jump_Range_Chance", "rangechance", g_esJumpPlayer[admin].g_flJumpRangeChance, value, 0.0, 100.0);
		g_esJumpPlayer[admin].g_iJumpRangeCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpRangeCooldown", "Jump Range Cooldown", "Jump_Range_Cooldown", "rangecooldown", g_esJumpPlayer[admin].g_iJumpRangeCooldown, value, 0, 99999);
		g_esJumpPlayer[admin].g_flJumpSporadicChance = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpSporadicChance", "Jump Sporadic Chance", "Jump_Sporadic_Chance", "sporadicchance", g_esJumpPlayer[admin].g_flJumpSporadicChance, value, 0.0, 100.0);
		g_esJumpPlayer[admin].g_flJumpSporadicHeight = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpSporadicHeight", "Jump Sporadic Height", "Jump_Sporadic_Height", "sporadicheight", g_esJumpPlayer[admin].g_flJumpSporadicHeight, value, 0.1, 99999.0);
		g_esJumpPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esJumpPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esJumpAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esJumpAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esJumpAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esJumpAbility[type].g_iComboAbility, value, 0, 1);
		g_esJumpAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esJumpAbility[type].g_iHumanAbility, value, 0, 2);
		g_esJumpAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esJumpAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esJumpAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esJumpAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esJumpAbility[type].g_iHumanDuration = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanDuration", "Human Duration", "Human_Duration", "hduration", g_esJumpAbility[type].g_iHumanDuration, value, 0, 99999);
		g_esJumpAbility[type].g_iHumanMode = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanMode", "Human Mode", "Human_Mode", "hmode", g_esJumpAbility[type].g_iHumanMode, value, 0, 1);
		g_esJumpAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esJumpAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esJumpAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esJumpAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esJumpAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esJumpAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esJumpAbility[type].g_iJumpAbility = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esJumpAbility[type].g_iJumpAbility, value, 0, 3);
		g_esJumpAbility[type].g_iJumpEffect = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esJumpAbility[type].g_iJumpEffect, value, 0, 7);
		g_esJumpAbility[type].g_iJumpMessage = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esJumpAbility[type].g_iJumpMessage, value, 0, 7);
		g_esJumpAbility[type].g_flJumpChance = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpChance", "Jump Chance", "Jump_Chance", "chance", g_esJumpAbility[type].g_flJumpChance, value, 0.0, 100.0);
		g_esJumpAbility[type].g_iJumpCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpCooldown", "Jump Cooldown", "Jump_Cooldown", "cooldown", g_esJumpAbility[type].g_iJumpCooldown, value, 0, 99999);
		g_esJumpAbility[type].g_iJumpDuration = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpDuration", "Jump Duration", "Jump_Duration", "duration", g_esJumpAbility[type].g_iJumpDuration, value, 0, 99999);
		g_esJumpAbility[type].g_flJumpHeight = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpHeight", "Jump Height", "Jump_Height", "height", g_esJumpAbility[type].g_flJumpHeight, value, 0.1, 99999.0);
		g_esJumpAbility[type].g_iJumpHit = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpHit", "Jump Hit", "Jump_Hit", "hit", g_esJumpAbility[type].g_iJumpHit, value, 0, 1);
		g_esJumpAbility[type].g_iJumpHitMode = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpHitMode", "Jump Hit Mode", "Jump_Hit_Mode", "hitmode", g_esJumpAbility[type].g_iJumpHitMode, value, 0, 2);
		g_esJumpAbility[type].g_flJumpInterval = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpInterval", "Jump Interval", "Jump_Interval", "interval", g_esJumpAbility[type].g_flJumpInterval, value, 0.1, 99999.0);
		g_esJumpAbility[type].g_iJumpMode = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpMode", "Jump Mode", "Jump_Mode", "mode", g_esJumpAbility[type].g_iJumpMode, value, 0, 1);
		g_esJumpAbility[type].g_flJumpRange = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpRange", "Jump Range", "Jump_Range", "range", g_esJumpAbility[type].g_flJumpRange, value, 1.0, 99999.0);
		g_esJumpAbility[type].g_flJumpRangeChance = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpRangeChance", "Jump Range Chance", "Jump_Range_Chance", "rangechance", g_esJumpAbility[type].g_flJumpRangeChance, value, 0.0, 100.0);
		g_esJumpAbility[type].g_iJumpRangeCooldown = iGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpRangeCooldown", "Jump Range Cooldown", "Jump_Range_Cooldown", "rangecooldown", g_esJumpAbility[type].g_iJumpRangeCooldown, value, 0, 99999);
		g_esJumpAbility[type].g_flJumpSporadicChance = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpSporadicChance", "Jump Sporadic Chance", "Jump_Sporadic_Chance", "sporadicchance", g_esJumpAbility[type].g_flJumpSporadicChance, value, 0.0, 100.0);
		g_esJumpAbility[type].g_flJumpSporadicHeight = flGetKeyValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "JumpSporadicHeight", "Jump Sporadic Height", "Jump_Sporadic_Height", "sporadicheight", g_esJumpAbility[type].g_flJumpSporadicHeight, value, 0.1, 99999.0);
		g_esJumpAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esJumpAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_JUMP_SECTION, MT_JUMP_SECTION2, MT_JUMP_SECTION3, MT_JUMP_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esJumpCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flCloseAreasOnly, g_esJumpAbility[type].g_flCloseAreasOnly);
	g_esJumpCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iComboAbility, g_esJumpAbility[type].g_iComboAbility);
	g_esJumpCache[tank].g_flJumpChance = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpChance, g_esJumpAbility[type].g_flJumpChance);
	g_esJumpCache[tank].g_flJumpHeight = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpHeight, g_esJumpAbility[type].g_flJumpHeight);
	g_esJumpCache[tank].g_flJumpInterval = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpInterval, g_esJumpAbility[type].g_flJumpInterval);
	g_esJumpCache[tank].g_flJumpRange = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpRange, g_esJumpAbility[type].g_flJumpRange);
	g_esJumpCache[tank].g_flJumpRangeChance = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpRangeChance, g_esJumpAbility[type].g_flJumpRangeChance);
	g_esJumpCache[tank].g_flJumpSporadicChance = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpSporadicChance, g_esJumpAbility[type].g_flJumpSporadicChance);
	g_esJumpCache[tank].g_flJumpSporadicHeight = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flJumpSporadicHeight, g_esJumpAbility[type].g_flJumpSporadicHeight);
	g_esJumpCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iHumanAbility, g_esJumpAbility[type].g_iHumanAbility);
	g_esJumpCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iHumanAmmo, g_esJumpAbility[type].g_iHumanAmmo);
	g_esJumpCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iHumanCooldown, g_esJumpAbility[type].g_iHumanCooldown);
	g_esJumpCache[tank].g_iHumanDuration = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iHumanDuration, g_esJumpAbility[type].g_iHumanDuration);
	g_esJumpCache[tank].g_iHumanMode = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iHumanMode, g_esJumpAbility[type].g_iHumanMode);
	g_esJumpCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iHumanRangeCooldown, g_esJumpAbility[type].g_iHumanRangeCooldown);
	g_esJumpCache[tank].g_iJumpAbility = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpAbility, g_esJumpAbility[type].g_iJumpAbility);
	g_esJumpCache[tank].g_iJumpCooldown = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpCooldown, g_esJumpAbility[type].g_iJumpCooldown);
	g_esJumpCache[tank].g_iJumpDuration = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpDuration, g_esJumpAbility[type].g_iJumpDuration);
	g_esJumpCache[tank].g_iJumpEffect = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpEffect, g_esJumpAbility[type].g_iJumpEffect);
	g_esJumpCache[tank].g_iJumpHit = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpHit, g_esJumpAbility[type].g_iJumpHit);
	g_esJumpCache[tank].g_iJumpHitMode = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpHitMode, g_esJumpAbility[type].g_iJumpHitMode);
	g_esJumpCache[tank].g_iJumpMessage = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpMessage, g_esJumpAbility[type].g_iJumpMessage);
	g_esJumpCache[tank].g_iJumpMode = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iJumpMode, g_esJumpAbility[type].g_iJumpMode);
	g_esJumpCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_flOpenAreasOnly, g_esJumpAbility[type].g_flOpenAreasOnly);
	g_esJumpCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esJumpPlayer[tank].g_iRequiresHumans, g_esJumpAbility[type].g_iRequiresHumans);
	g_esJumpPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vJumpCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vJumpCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveJump(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vJumpEventFired(Event event, const char[] name)
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
			vJumpCopyStats2(iBot, iTank);
			vRemoveJump(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vJumpCopyStats2(iTank, iBot);
			vRemoveJump(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveJump(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vJumpReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[tank].g_iAccessFlags)) || g_esJumpCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esJumpCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esJumpCache[tank].g_iJumpAbility > 0 && g_esJumpCache[tank].g_iComboAbility == 0)
	{
		vJumpAbility(tank, false);
		vJumpAbility(tank, true, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esJumpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esJumpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[tank].g_iTankType) || (g_esJumpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		int iTime = GetTime();
		if ((button & MT_MAIN_KEY) && (g_esJumpCache[tank].g_iJumpAbility == 2 || g_esJumpCache[tank].g_iJumpAbility == 3) && g_esJumpCache[tank].g_iHumanAbility == 1)
		{
			bool bRecharging = g_esJumpPlayer[tank].g_iCooldown2 != -1 && g_esJumpPlayer[tank].g_iCooldown2 > iTime;

			switch (g_esJumpCache[tank].g_iHumanMode)
			{
				case 0:
				{
					if (!g_esJumpPlayer[tank].g_bActivated && !bRecharging)
					{
						vJumpAbility(tank, false);
					}
					else if (g_esJumpPlayer[tank].g_bActivated)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman4");
					}
					else if (bRecharging)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman5", (g_esJumpPlayer[tank].g_iCooldown2 - iTime));
					}
				}
				case 1:
				{
					if (g_esJumpPlayer[tank].g_iAmmoCount < g_esJumpCache[tank].g_iHumanAmmo && g_esJumpCache[tank].g_iHumanAmmo > 0)
					{
						if (!g_esJumpPlayer[tank].g_bActivated && !bRecharging)
						{
							g_esJumpPlayer[tank].g_bActivated = true;
							g_esJumpPlayer[tank].g_iAmmoCount++;

							vJump2(tank);
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman", g_esJumpPlayer[tank].g_iAmmoCount, g_esJumpCache[tank].g_iHumanAmmo);
						}
						else if (g_esJumpPlayer[tank].g_bActivated)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman4");
						}
						else if (bRecharging)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman5", (g_esJumpPlayer[tank].g_iCooldown2 - iTime));
						}
					}
					else
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpAmmo");
					}
				}
			}
		}

		if ((button & MT_SUB_KEY) && (g_esJumpCache[tank].g_iJumpAbility == 1 || g_esJumpCache[tank].g_iJumpAbility == 3) && g_esJumpCache[tank].g_iHumanAbility == 1)
		{
			switch (g_esJumpPlayer[tank].g_iRangeCooldown == -1 || g_esJumpPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vJumpAbility(tank, true, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman6", (g_esJumpPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpButtonReleased(int tank, int button)
#else
public void MT_OnButtonReleased(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1)
	{
		if ((button & MT_MAIN_KEY) && g_esJumpCache[tank].g_iHumanMode == 1 && g_esJumpPlayer[tank].g_bActivated && (g_esJumpPlayer[tank].g_iCooldown2 == -1 || g_esJumpPlayer[tank].g_iCooldown2 < GetTime()))
		{
			vJumpReset3(tank);
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vJumpChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveJump(tank);
}

void vJump(int survivor, int tank)
{
	if (bIsAreaNarrow(tank, g_esJumpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esJumpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[tank].g_iTankType) || (g_esJumpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esJumpPlayer[tank].g_iTankType, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	float flVelocity[3];
	GetEntPropVector(survivor, Prop_Data, "m_vecVelocity", flVelocity);
	flVelocity[2] += g_esJumpCache[tank].g_flJumpHeight;
	TeleportEntity(survivor, .velocity = flVelocity);
}

void vJump2(int tank, int pos = -1)
{
	int iTime = GetTime();
	if ((g_esJumpPlayer[tank].g_iCooldown2 != -1 && g_esJumpPlayer[tank].g_iCooldown2 > iTime) || bIsAreaNarrow(tank, g_esJumpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esJumpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[tank].g_iTankType) || (g_esJumpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	switch (g_esJumpCache[tank].g_iJumpMode)
	{
		case 0:
		{
			float flInterval = (pos != -1) ? MT_GetCombinationSetting(tank, 6, pos) : g_esJumpCache[tank].g_flJumpInterval;
			DataPack dpJump;
			CreateDataTimer(flInterval, tTimerJump, dpJump, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			dpJump.WriteCell(GetClientUserId(tank));
			dpJump.WriteCell(g_esJumpPlayer[tank].g_iTankType);
			dpJump.WriteCell(iTime);
			dpJump.WriteCell(pos);
		}
		case 1:
		{
			DataPack dpJump2;
			CreateDataTimer(1.0, tTimerJump2, dpJump2, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			dpJump2.WriteCell(GetClientUserId(tank));
			dpJump2.WriteCell(g_esJumpPlayer[tank].g_iTankType);
			dpJump2.WriteCell(iTime);
			dpJump2.WriteCell(pos);
		}
	}
}

void vJumpAbility(int tank, bool main, float random = 0.0, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esJumpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esJumpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[tank].g_iTankType) || (g_esJumpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	switch (main)
	{
		case true:
		{
			if (g_esJumpCache[tank].g_iJumpAbility == 1 || g_esJumpCache[tank].g_iJumpAbility == 3)
			{
				if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esJumpPlayer[tank].g_iAmmoCount2 < g_esJumpCache[tank].g_iHumanAmmo && g_esJumpCache[tank].g_iHumanAmmo > 0))
				{
					g_esJumpPlayer[tank].g_bFailed = false;
					g_esJumpPlayer[tank].g_bNoAmmo = false;

					float flTankPos[3];
					GetClientAbsOrigin(tank, flTankPos);

					float flSurvivorPos[3],
						flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esJumpCache[tank].g_flJumpRange,
						flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esJumpCache[tank].g_flJumpRangeChance;
					int iSurvivorCount = 0;
					for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
					{
						if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esJumpPlayer[tank].g_iTankType, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[iSurvivor].g_iImmunityFlags))
						{
							GetClientAbsOrigin(iSurvivor, flSurvivorPos);
							if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
							{
								vJumpHit(iSurvivor, tank, random, flChance, g_esJumpCache[tank].g_iJumpAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

								iSurvivorCount++;
							}
						}
					}

					if (iSurvivorCount == 0)
					{
						if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman7");
						}
					}
				}
				else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1)
				{
					MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpAmmo");
				}
			}
		}
		case false:
		{
			if (g_esJumpPlayer[tank].g_iCooldown2 != -1 && g_esJumpPlayer[tank].g_iCooldown2 > GetTime())
			{
				return;
			}

			if ((g_esJumpCache[tank].g_iJumpAbility == 2 || g_esJumpCache[tank].g_iJumpAbility == 3) && !g_esJumpPlayer[tank].g_bActivated)
			{
				if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esJumpPlayer[tank].g_iAmmoCount < g_esJumpCache[tank].g_iHumanAmmo && g_esJumpCache[tank].g_iHumanAmmo > 0))
				{
					g_esJumpPlayer[tank].g_bActivated = true;

					vJump2(tank, pos);

					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1)
					{
						g_esJumpPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman", g_esJumpPlayer[tank].g_iAmmoCount, g_esJumpCache[tank].g_iHumanAmmo);
					}

					if (g_esJumpCache[tank].g_iJumpMessage & MT_MESSAGE_SPECIAL)
					{
						char sTankName[33];
						MT_GetTankName(tank, sTankName);
						MT_PrintToChatAll("%s %t", MT_TAG2, "Jump3", sTankName);
						MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Jump3", LANG_SERVER, sTankName);
					}
				}
				else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1)
				{
					MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpAmmo");
				}
			}
		}
	}
}

void vJumpHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esJumpCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esJumpCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[tank].g_iTankType) || (g_esJumpCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esJumpPlayer[tank].g_iTankType, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esJumpPlayer[tank].g_iRangeCooldown != -1 && g_esJumpPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esJumpPlayer[tank].g_iCooldown != -1 && g_esJumpPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if ((enabled == 1 || enabled == 3) && bIsSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esJumpPlayer[tank].g_iAmmoCount2 < g_esJumpCache[tank].g_iHumanAmmo && g_esJumpCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esJumpPlayer[survivor].g_bAffected)
			{
				g_esJumpPlayer[survivor].g_bAffected = true;
				g_esJumpPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esJumpPlayer[tank].g_iRangeCooldown == -1 || g_esJumpPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1)
					{
						g_esJumpPlayer[tank].g_iAmmoCount2++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman2", g_esJumpPlayer[tank].g_iAmmoCount2, g_esJumpCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esJumpCache[tank].g_iJumpRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1 && g_esJumpPlayer[tank].g_iAmmoCount2 < g_esJumpCache[tank].g_iHumanAmmo && g_esJumpCache[tank].g_iHumanAmmo > 0) ? g_esJumpCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esJumpPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esJumpPlayer[tank].g_iRangeCooldown != -1 && g_esJumpPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman9", (g_esJumpPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esJumpPlayer[tank].g_iCooldown == -1 || g_esJumpPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esJumpCache[tank].g_iJumpCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1) ? g_esJumpCache[tank].g_iHumanCooldown : iCooldown;
					g_esJumpPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esJumpPlayer[tank].g_iCooldown != -1 && g_esJumpPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman9", (g_esJumpPlayer[tank].g_iCooldown - iTime));
					}
				}

				DataPack dpJump3;
				CreateDataTimer(0.25, tTimerJump3, dpJump3, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
				dpJump3.WriteCell(GetClientUserId(survivor));
				dpJump3.WriteCell(GetClientUserId(tank));
				dpJump3.WriteCell(g_esJumpPlayer[tank].g_iTankType);
				dpJump3.WriteCell(messages);
				dpJump3.WriteCell(enabled);
				dpJump3.WriteCell(iTime);
				dpJump3.WriteCell(pos);

				vScreenEffect(survivor, tank, g_esJumpCache[tank].g_iJumpEffect, flags);

				if (g_esJumpCache[tank].g_iJumpMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Jump", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Jump", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esJumpPlayer[tank].g_iRangeCooldown == -1 || g_esJumpPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1 && !g_esJumpPlayer[tank].g_bFailed)
				{
					g_esJumpPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman3");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1 && !g_esJumpPlayer[tank].g_bNoAmmo)
		{
			g_esJumpPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpAmmo2");
		}
	}
}

void vJumpCopyStats2(int oldTank, int newTank)
{
	g_esJumpPlayer[newTank].g_iAmmoCount = g_esJumpPlayer[oldTank].g_iAmmoCount;
	g_esJumpPlayer[newTank].g_iAmmoCount2 = g_esJumpPlayer[oldTank].g_iAmmoCount2;
	g_esJumpPlayer[newTank].g_iCooldown = g_esJumpPlayer[oldTank].g_iCooldown;
	g_esJumpPlayer[newTank].g_iCooldown2 = g_esJumpPlayer[oldTank].g_iCooldown2;
	g_esJumpPlayer[newTank].g_iRangeCooldown = g_esJumpPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveJump(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esJumpPlayer[iSurvivor].g_bAffected && g_esJumpPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esJumpPlayer[iSurvivor].g_bAffected = false;
			g_esJumpPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vJumpReset4(tank);
}

void vJumpReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vJumpReset4(iPlayer);
		}
	}
}

void vJumpReset2(int survivor, int tank, int messages)
{
	g_esJumpPlayer[survivor].g_bAffected = false;
	g_esJumpPlayer[survivor].g_iOwner = 0;

	if (g_esJumpCache[tank].g_iJumpMessage & messages)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Jump2", survivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Jump2", LANG_SERVER, survivor);
	}
}

void vJumpReset3(int tank)
{
	g_esJumpPlayer[tank].g_bActivated = false;

	int iTime = GetTime(), iPos = g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iComboPosition, iCooldown = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, iPos)) : g_esJumpCache[tank].g_iJumpCooldown;
	iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esJumpCache[tank].g_iHumanAbility == 1 && g_esJumpCache[tank].g_iHumanMode == 0 && g_esJumpPlayer[tank].g_iAmmoCount < g_esJumpCache[tank].g_iHumanAmmo && g_esJumpCache[tank].g_iHumanAmmo > 0) ? g_esJumpCache[tank].g_iHumanCooldown : iCooldown;
	g_esJumpPlayer[tank].g_iCooldown2 = (iTime + iCooldown);
	if (g_esJumpPlayer[tank].g_iCooldown2 != -1 && g_esJumpPlayer[tank].g_iCooldown2 > iTime)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "JumpHuman8", (g_esJumpPlayer[tank].g_iCooldown2 - iTime));
	}
}

void vJumpReset4(int tank)
{
	g_esJumpPlayer[tank].g_bActivated = false;
	g_esJumpPlayer[tank].g_bAffected = false;
	g_esJumpPlayer[tank].g_bFailed = false;
	g_esJumpPlayer[tank].g_bNoAmmo = false;
	g_esJumpPlayer[tank].g_iAmmoCount = 0;
	g_esJumpPlayer[tank].g_iAmmoCount2 = 0;
	g_esJumpPlayer[tank].g_iCooldown = -1;
	g_esJumpPlayer[tank].g_iCooldown2 = -1;
	g_esJumpPlayer[tank].g_iRangeCooldown = -1;
}

float flGetNearestSurvivor(int tank)
{
	if (bIsTank(tank))
	{
		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esJumpPlayer[tank].g_iTankType, g_esJumpAbility[g_esJumpPlayer[tank].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);

				return GetVectorDistance(flTankPos, flSurvivorPos);
			}
		}
	}

	return 0.0;
}

Action tTimerJumpCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esJumpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esJumpCache[iTank].g_iJumpAbility == 0 || g_esJumpCache[iTank].g_iJumpAbility == 2)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vJumpAbility(iTank, true, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerJumpCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esJumpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esJumpCache[iTank].g_iJumpAbility == 0 || g_esJumpCache[iTank].g_iJumpAbility == 1)
	{
		return Plugin_Stop;
	}

	int iPos = pack.ReadCell();
	vJumpAbility(iTank, false, .pos = iPos);

	return Plugin_Continue;
}

Action tTimerJumpCombo3(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esJumpPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esJumpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esJumpCache[iTank].g_iJumpHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esJumpCache[iTank].g_iJumpHitMode == 0 || g_esJumpCache[iTank].g_iJumpHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vJumpHit(iSurvivor, iTank, flRandom, flChance, g_esJumpCache[iTank].g_iJumpHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esJumpCache[iTank].g_iJumpHitMode == 0 || g_esJumpCache[iTank].g_iJumpHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vJumpHit(iSurvivor, iTank, flRandom, flChance, g_esJumpCache[iTank].g_iJumpHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerJump(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esJumpCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esJumpCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[iTank].g_iTankType) || (g_esJumpCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esJumpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esJumpPlayer[iTank].g_iTankType || (g_esJumpCache[iTank].g_iJumpAbility != 2 && g_esJumpCache[iTank].g_iJumpAbility != 3) || !g_esJumpPlayer[iTank].g_bActivated)
	{
		g_esJumpPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esJumpCache[iTank].g_iJumpDuration;
	iDuration = (bHuman && g_esJumpCache[iTank].g_iHumanAbility == 1) ? g_esJumpCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esJumpCache[iTank].g_iHumanAbility == 1 && g_esJumpCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esJumpPlayer[iTank].g_iCooldown2 == -1 || g_esJumpPlayer[iTank].g_iCooldown2 < iCurrentTime))
	{
		vJumpReset3(iTank);

		return Plugin_Stop;
	}

	if (!bIsEntityGrounded(iTank))
	{
		return Plugin_Continue;
	}

	vJump(iTank, iTank);

	return Plugin_Continue;
}

Action tTimerJump2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell();
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esJumpCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esJumpCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[iTank].g_iTankType) || (g_esJumpCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esJumpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esJumpPlayer[iTank].g_iTankType || (g_esJumpCache[iTank].g_iJumpAbility != 2 && g_esJumpCache[iTank].g_iJumpAbility != 3) || !g_esJumpPlayer[iTank].g_bActivated)
	{
		g_esJumpPlayer[iTank].g_bActivated = false;

		return Plugin_Stop;
	}

	bool bHuman = bIsTank(iTank, MT_CHECK_FAKECLIENT);
	int iTime = pack.ReadCell(), iCurrentTime = GetTime(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esJumpCache[iTank].g_iJumpDuration;
	iDuration = (bHuman && g_esJumpCache[iTank].g_iHumanAbility == 1) ? g_esJumpCache[iTank].g_iHumanDuration : iDuration;
	if (iDuration > 0 && (!bHuman || (bHuman && g_esJumpCache[iTank].g_iHumanAbility == 1 && g_esJumpCache[iTank].g_iHumanMode == 0)) && (iTime + iDuration) < iCurrentTime && (g_esJumpPlayer[iTank].g_iCooldown2 == -1 || g_esJumpPlayer[iTank].g_iCooldown2 < iCurrentTime))
	{
		vJumpReset3(iTank);

		return Plugin_Stop;
	}

	if (MT_GetRandomFloat(0.1, 100.0) > g_esJumpCache[iTank].g_flJumpSporadicChance)
	{
		return Plugin_Continue;
	}

	float flNearestSurvivor = flGetNearestSurvivor(iTank);
	if (flNearestSurvivor > 100.0 && flNearestSurvivor < 1000.0)
	{
		float flVelocity[3];
		GetEntPropVector(iTank, Prop_Data, "m_vecVelocity", flVelocity);

		if (flVelocity[0] > 0.0 && flVelocity[0] < 500.0)
		{
			flVelocity[0] += 500.0;
		}
		else if (flVelocity[0] < 0.0 && flVelocity[0] > -500.0)
		{
			flVelocity[0] += -500.0;
		}
		if (flVelocity[1] > 0.0 && flVelocity[1] < 500.0)
		{
			flVelocity[1] += 500.0;
		}
		else if (flVelocity[1] < 0.0 && flVelocity[1] > -500.0)
		{
			flVelocity[1] += -500.0;
		}

		flVelocity[2] += g_esJumpCache[iTank].g_flJumpSporadicHeight;
		TeleportEntity(iTank, .velocity = flVelocity);
	}

	return Plugin_Continue;
}

Action tTimerJump3(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esJumpPlayer[iSurvivor].g_bAffected = false;
		g_esJumpPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iMessage = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esJumpCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esJumpCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esJumpPlayer[iTank].g_iTankType) || (g_esJumpCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esJumpCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iAccessFlags, g_esJumpPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esJumpPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esJumpPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esJumpPlayer[iTank].g_iTankType, g_esJumpAbility[g_esJumpPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esJumpPlayer[iSurvivor].g_iImmunityFlags) || !g_esJumpPlayer[iSurvivor].g_bAffected)
	{
		vJumpReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	int iJumpEnabled = pack.ReadCell(), iTime = pack.ReadCell(), iPos = pack.ReadCell(),
		iDuration = (iPos != -1) ? RoundToNearest(MT_GetCombinationSetting(iTank, 5, iPos)) : g_esJumpCache[iTank].g_iJumpDuration;
	iDuration = (bIsTank(iTank, MT_CHECK_FAKECLIENT) && g_esJumpCache[iTank].g_iHumanAbility == 1) ? g_esJumpCache[iTank].g_iHumanDuration : iDuration;
	if ((iJumpEnabled != 1 && iJumpEnabled != 3) || (iTime + iDuration) < GetTime())
	{
		vJumpReset2(iSurvivor, iTank, iMessage);

		return Plugin_Stop;
	}

	if (!bIsEntityGrounded(iSurvivor))
	{
		return Plugin_Continue;
	}

	vJump(iSurvivor, iTank);

	return Plugin_Continue;
}