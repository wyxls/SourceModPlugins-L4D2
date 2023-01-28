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

#define MT_QUIET_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_QUIET_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Quiet Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank silences itself around survivors.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Quiet Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_QUIET_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define MT_QUIET_SECTION "quietability"
#define MT_QUIET_SECTION2 "quiet ability"
#define MT_QUIET_SECTION3 "quiet_ability"
#define MT_QUIET_SECTION4 "quiet"

#define MT_MENU_QUIET "Quiet Ability"

char g_sFootstepsFolders[][] =
{
	"player/footsteps/infected/",
	"player/footsteps/smoker/",
	"player/footsteps/boomer/",
	"player/footsteps/hunter/",
	"player/footsteps/spitter/",
	"player/footsteps/jockey/",
	"player/footsteps/charger/",
	"player/footsteps/witch/",
	"player/footsteps/tank/"
}, g_sInfectedFolders[][] =
{
	"npc/infected/",
	"player/smoker/",
	"player/boomer/",
	"player/hunter/",
	"player/spitter/",
	"player/jockey/",
	"player/charger/",
	"npc/witch/",
	"player/tank/"
};

enum struct esQuietPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flQuietChance;
	float g_flQuietDuration;
	float g_flQuietRange;
	float g_flQuietRangeChance;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iFilter;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iQuietAbility;
	int g_iQuietCooldown;
	int g_iQuietEffect;
	int g_iQuietFilter;
	int g_iQuietHit;
	int g_iQuietHitMode;
	int g_iQuietMessage;
	int g_iQuietRangeCooldown;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esQuietPlayer g_esQuietPlayer[MAXPLAYERS + 1];

enum struct esQuietAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flQuietChance;
	float g_flQuietDuration;
	float g_flQuietRange;
	float g_flQuietRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iQuietAbility;
	int g_iQuietCooldown;
	int g_iQuietEffect;
	int g_iQuietFilter;
	int g_iQuietHit;
	int g_iQuietHitMode;
	int g_iQuietMessage;
	int g_iQuietRangeCooldown;
	int g_iRequiresHumans;
}

esQuietAbility g_esQuietAbility[MT_MAXTYPES + 1];

enum struct esQuietCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flQuietChance;
	float g_flQuietDuration;
	float g_flQuietRange;
	float g_flQuietRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iQuietAbility;
	int g_iQuietCooldown;
	int g_iQuietEffect;
	int g_iQuietFilter;
	int g_iQuietHit;
	int g_iQuietHitMode;
	int g_iQuietMessage;
	int g_iQuietRangeCooldown;
	int g_iRequiresHumans;
}

esQuietCache g_esQuietCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_quiet", cmdQuietInfo, "View information about the Quiet ability.");

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
void vQuietMapStart()
#else
public void OnMapStart()
#endif
{
	vQuietReset();

	AddNormalSoundHook(QuietSoundHook);
}

#if defined MT_ABILITIES_MAIN2
void vQuietClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnQuietTakeDamage);
	vQuietReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vQuietClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vQuietReset2(client);
}

#if defined MT_ABILITIES_MAIN2
void vQuietMapEnd()
#else
public void OnMapEnd()
#endif
{
	vQuietReset();

	RemoveNormalSoundHook(QuietSoundHook);
}

#if !defined MT_ABILITIES_MAIN2
Action cmdQuietInfo(int client, int args)
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
		case false: vQuietMenu(client, MT_QUIET_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vQuietMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_QUIET_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iQuietMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Quiet Ability Information");
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

int iQuietMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esQuietCache[param1].g_iQuietAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esQuietCache[param1].g_iHumanAmmo - g_esQuietPlayer[param1].g_iAmmoCount), g_esQuietCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esQuietCache[param1].g_iHumanAbility == 1) ? g_esQuietCache[param1].g_iHumanCooldown : g_esQuietCache[param1].g_iQuietCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "QuietDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esQuietCache[param1].g_flQuietDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esQuietCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esQuietCache[param1].g_iHumanAbility == 1) ? g_esQuietCache[param1].g_iHumanRangeCooldown : g_esQuietCache[param1].g_iQuietRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vQuietMenu(param1, MT_QUIET_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pQuiet = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "QuietMenu", param1);
			pQuiet.SetTitle(sMenuTitle);
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
void vQuietDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_QUIET, MT_MENU_QUIET);
}

#if defined MT_ABILITIES_MAIN2
void vQuietMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_QUIET, false))
	{
		vQuietMenu(client, MT_QUIET_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vQuietMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_QUIET, false))
	{
		FormatEx(buffer, size, "%T", "QuietMenu2", client);
	}
}

Action OnQuietTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esQuietCache[attacker].g_iQuietHitMode == 0 || g_esQuietCache[attacker].g_iQuietHitMode == 1) && bIsHumanSurvivor(victim) && g_esQuietCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esQuietAbility[g_esQuietPlayer[attacker].g_iTankType].g_iAccessFlags, g_esQuietPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esQuietPlayer[attacker].g_iTankType, g_esQuietAbility[g_esQuietPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esQuietPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vQuietHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esQuietCache[attacker].g_flQuietChance, g_esQuietCache[attacker].g_iQuietHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esQuietCache[victim].g_iQuietHitMode == 0 || g_esQuietCache[victim].g_iQuietHitMode == 2) && bIsHumanSurvivor(attacker) && g_esQuietCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esQuietAbility[g_esQuietPlayer[victim].g_iTankType].g_iAccessFlags, g_esQuietPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esQuietPlayer[victim].g_iTankType, g_esQuietAbility[g_esQuietPlayer[victim].g_iTankType].g_iImmunityFlags, g_esQuietPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vQuietHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esQuietCache[victim].g_flQuietChance, g_esQuietCache[victim].g_iQuietHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

Action QuietSoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (MT_IsCorePluginEnabled())
	{
		bool bChanged = false;
		for (int iPos = 0; iPos < (sizeof g_sInfectedFolders); iPos++)
		{
			for (int iSurvivor = 0; iSurvivor < numClients; iSurvivor++)
			{
				if (bIsHumanSurvivor(clients[iSurvivor]) && g_esQuietPlayer[clients[iSurvivor]].g_bAffected && (StrContains(sample, g_sFootstepsFolders[iPos], false) != -1 || StrContains(sample, g_sInfectedFolders[iPos], false) != -1) && (g_esQuietPlayer[clients[iSurvivor]].g_iFilter == 0 || (g_esQuietPlayer[clients[iSurvivor]].g_iFilter & (1 << iPos))))
				{
					for (int iPlayer = iSurvivor; iPlayer < (numClients - 1); iPlayer++)
					{
						clients[iPlayer] = clients[iPlayer + 1];
					}

					bChanged = true;
					numClients--;
					iSurvivor--;
				}
			}
		}

		return (bChanged || numClients > 0) ? Plugin_Changed : Plugin_Stop;
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vQuietPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_QUIET);
}

#if defined MT_ABILITIES_MAIN2
void vQuietAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_QUIET_SECTION);
	list2.PushString(MT_QUIET_SECTION2);
	list3.PushString(MT_QUIET_SECTION3);
	list4.PushString(MT_QUIET_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vQuietCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_QUIET_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_QUIET_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_QUIET_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_QUIET_SECTION4);
	if (g_esQuietCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_QUIET_SECTION, false) || StrEqual(sSubset[iPos], MT_QUIET_SECTION2, false) || StrEqual(sSubset[iPos], MT_QUIET_SECTION3, false) || StrEqual(sSubset[iPos], MT_QUIET_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esQuietCache[tank].g_iQuietAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vQuietAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerQuietCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esQuietCache[tank].g_iQuietHitMode == 0 || g_esQuietCache[tank].g_iQuietHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vQuietHit(survivor, tank, random, flChance, g_esQuietCache[tank].g_iQuietHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esQuietCache[tank].g_iQuietHitMode == 0 || g_esQuietCache[tank].g_iQuietHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vQuietHit(survivor, tank, random, flChance, g_esQuietCache[tank].g_iQuietHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerQuietCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vQuietConfigsLoad(int mode)
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
				g_esQuietAbility[iIndex].g_iAccessFlags = 0;
				g_esQuietAbility[iIndex].g_iImmunityFlags = 0;
				g_esQuietAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esQuietAbility[iIndex].g_iComboAbility = 0;
				g_esQuietAbility[iIndex].g_iHumanAbility = 0;
				g_esQuietAbility[iIndex].g_iHumanAmmo = 5;
				g_esQuietAbility[iIndex].g_iHumanCooldown = 0;
				g_esQuietAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esQuietAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esQuietAbility[iIndex].g_iRequiresHumans = 1;
				g_esQuietAbility[iIndex].g_iQuietAbility = 0;
				g_esQuietAbility[iIndex].g_iQuietEffect = 0;
				g_esQuietAbility[iIndex].g_iQuietMessage = 0;
				g_esQuietAbility[iIndex].g_flQuietChance = 33.3;
				g_esQuietAbility[iIndex].g_iQuietCooldown = 0;
				g_esQuietAbility[iIndex].g_flQuietDuration = 5.0;
				g_esQuietAbility[iIndex].g_iQuietFilter = 0;
				g_esQuietAbility[iIndex].g_iQuietHit = 0;
				g_esQuietAbility[iIndex].g_iQuietHitMode = 0;
				g_esQuietAbility[iIndex].g_flQuietRange = 150.0;
				g_esQuietAbility[iIndex].g_flQuietRangeChance = 15.0;
				g_esQuietAbility[iIndex].g_iQuietRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esQuietPlayer[iPlayer].g_iAccessFlags = 0;
					g_esQuietPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esQuietPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esQuietPlayer[iPlayer].g_iComboAbility = 0;
					g_esQuietPlayer[iPlayer].g_iHumanAbility = 0;
					g_esQuietPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esQuietPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esQuietPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esQuietPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esQuietPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esQuietPlayer[iPlayer].g_iQuietAbility = 0;
					g_esQuietPlayer[iPlayer].g_iQuietEffect = 0;
					g_esQuietPlayer[iPlayer].g_iQuietMessage = 0;
					g_esQuietPlayer[iPlayer].g_flQuietChance = 0.0;
					g_esQuietPlayer[iPlayer].g_iQuietCooldown = 0;
					g_esQuietPlayer[iPlayer].g_flQuietDuration = 0.0;
					g_esQuietPlayer[iPlayer].g_iQuietFilter = 0;
					g_esQuietPlayer[iPlayer].g_iQuietHit = 0;
					g_esQuietPlayer[iPlayer].g_iQuietHitMode = 0;
					g_esQuietPlayer[iPlayer].g_flQuietRange = 0.0;
					g_esQuietPlayer[iPlayer].g_flQuietRangeChance = 0.0;
					g_esQuietPlayer[iPlayer].g_iQuietRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vQuietConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esQuietPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esQuietPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esQuietPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esQuietPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esQuietPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esQuietPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esQuietPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esQuietPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esQuietPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esQuietPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esQuietPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esQuietPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esQuietPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esQuietPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esQuietPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esQuietPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esQuietPlayer[admin].g_iQuietAbility = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esQuietPlayer[admin].g_iQuietAbility, value, 0, 1);
		g_esQuietPlayer[admin].g_iQuietEffect = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esQuietPlayer[admin].g_iQuietEffect, value, 0, 7);
		g_esQuietPlayer[admin].g_iQuietMessage = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esQuietPlayer[admin].g_iQuietMessage, value, 0, 3);
		g_esQuietPlayer[admin].g_flQuietChance = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietChance", "Quiet Chance", "Quiet_Chance", "chance", g_esQuietPlayer[admin].g_flQuietChance, value, 0.0, 100.0);
		g_esQuietPlayer[admin].g_iQuietCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietCooldown", "Quiet Cooldown", "Quiet_Cooldown", "cooldown", g_esQuietPlayer[admin].g_iQuietCooldown, value, 0, 99999);
		g_esQuietPlayer[admin].g_flQuietDuration = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietDuration", "Quiet Duration", "Quiet_Duration", "duration", g_esQuietPlayer[admin].g_flQuietDuration, value, 0.1, 99999.0);
		g_esQuietPlayer[admin].g_iQuietFilter = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietFilter", "Quiet Filter", "Quiet_Filter", "filter", g_esQuietPlayer[admin].g_iQuietFilter, value, 0, 511);
		g_esQuietPlayer[admin].g_iQuietHit = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietHit", "Quiet Hit", "Quiet_Hit", "hit", g_esQuietPlayer[admin].g_iQuietHit, value, 0, 1);
		g_esQuietPlayer[admin].g_iQuietHitMode = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietHitMode", "Quiet Hit Mode", "Quiet_Hit_Mode", "hitmode", g_esQuietPlayer[admin].g_iQuietHitMode, value, 0, 2);
		g_esQuietPlayer[admin].g_flQuietRange = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietRange", "Quiet Range", "Quiet_Range", "range", g_esQuietPlayer[admin].g_flQuietRange, value, 1.0, 99999.0);
		g_esQuietPlayer[admin].g_flQuietRangeChance = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietRangeChance", "Quiet Range Chance", "Quiet_Range_Chance", "rangechance", g_esQuietPlayer[admin].g_flQuietRangeChance, value, 0.0, 100.0);
		g_esQuietPlayer[admin].g_iQuietRangeCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietRangeCooldown", "Quiet Range Cooldown", "Quiet_Range_Cooldown", "rangecooldown", g_esQuietPlayer[admin].g_iQuietRangeCooldown, value, 0, 99999);
		g_esQuietPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esQuietPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esQuietAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esQuietAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esQuietAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esQuietAbility[type].g_iComboAbility, value, 0, 1);
		g_esQuietAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esQuietAbility[type].g_iHumanAbility, value, 0, 2);
		g_esQuietAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esQuietAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esQuietAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esQuietAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esQuietAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esQuietAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esQuietAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esQuietAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esQuietAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esQuietAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esQuietAbility[type].g_iQuietAbility = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esQuietAbility[type].g_iQuietAbility, value, 0, 1);
		g_esQuietAbility[type].g_iQuietEffect = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esQuietAbility[type].g_iQuietEffect, value, 0, 7);
		g_esQuietAbility[type].g_iQuietMessage = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esQuietAbility[type].g_iQuietMessage, value, 0, 3);
		g_esQuietAbility[type].g_flQuietChance = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietChance", "Quiet Chance", "Quiet_Chance", "chance", g_esQuietAbility[type].g_flQuietChance, value, 0.0, 100.0);
		g_esQuietAbility[type].g_iQuietCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietCooldown", "Quiet Cooldown", "Quiet_Cooldown", "cooldown", g_esQuietAbility[type].g_iQuietCooldown, value, 0, 99999);
		g_esQuietAbility[type].g_flQuietDuration = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietDuration", "Quiet Duration", "Quiet_Duration", "duration", g_esQuietAbility[type].g_flQuietDuration, value, 0.1, 99999.0);
		g_esQuietAbility[type].g_iQuietFilter = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietFilter", "Quiet Filter", "Quiet_Filter", "filter", g_esQuietAbility[type].g_iQuietFilter, value, 0, 511);
		g_esQuietAbility[type].g_iQuietHit = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietHit", "Quiet Hit", "Quiet_Hit", "hit", g_esQuietAbility[type].g_iQuietHit, value, 0, 1);
		g_esQuietAbility[type].g_iQuietHitMode = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietHitMode", "Quiet Hit Mode", "Quiet_Hit_Mode", "hitmode", g_esQuietAbility[type].g_iQuietHitMode, value, 0, 2);
		g_esQuietAbility[type].g_flQuietRange = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietRange", "Quiet Range", "Quiet_Range", "range", g_esQuietAbility[type].g_flQuietRange, value, 1.0, 99999.0);
		g_esQuietAbility[type].g_flQuietRangeChance = flGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietRangeChance", "Quiet Range Chance", "Quiet_Range_Chance", "rangechance", g_esQuietAbility[type].g_flQuietRangeChance, value, 0.0, 100.0);
		g_esQuietAbility[type].g_iQuietRangeCooldown = iGetKeyValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "QuietRangeCooldown", "Quiet Range Cooldown", "Quiet_Range_Cooldown", "rangecooldown", g_esQuietAbility[type].g_iQuietRangeCooldown, value, 0, 99999);
		g_esQuietAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esQuietAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_QUIET_SECTION, MT_QUIET_SECTION2, MT_QUIET_SECTION3, MT_QUIET_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vQuietSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esQuietCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_flCloseAreasOnly, g_esQuietAbility[type].g_flCloseAreasOnly);
	g_esQuietCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iComboAbility, g_esQuietAbility[type].g_iComboAbility);
	g_esQuietCache[tank].g_flQuietChance = flGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_flQuietChance, g_esQuietAbility[type].g_flQuietChance);
	g_esQuietCache[tank].g_flQuietDuration = flGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_flQuietDuration, g_esQuietAbility[type].g_flQuietDuration);
	g_esQuietCache[tank].g_flQuietRange = flGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_flQuietRange, g_esQuietAbility[type].g_flQuietRange);
	g_esQuietCache[tank].g_flQuietRangeChance = flGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_flQuietRangeChance, g_esQuietAbility[type].g_flQuietRangeChance);
	g_esQuietCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iHumanAbility, g_esQuietAbility[type].g_iHumanAbility);
	g_esQuietCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iHumanAmmo, g_esQuietAbility[type].g_iHumanAmmo);
	g_esQuietCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iHumanCooldown, g_esQuietAbility[type].g_iHumanCooldown);
	g_esQuietCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iHumanRangeCooldown, g_esQuietAbility[type].g_iHumanRangeCooldown);
	g_esQuietCache[tank].g_iQuietAbility = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietAbility, g_esQuietAbility[type].g_iQuietAbility);
	g_esQuietCache[tank].g_iQuietCooldown = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietCooldown, g_esQuietAbility[type].g_iQuietCooldown);
	g_esQuietCache[tank].g_iQuietEffect = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietEffect, g_esQuietAbility[type].g_iQuietEffect);
	g_esQuietCache[tank].g_iQuietFilter = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietFilter, g_esQuietAbility[type].g_iQuietFilter);
	g_esQuietCache[tank].g_iQuietHit = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietHit, g_esQuietAbility[type].g_iQuietHit);
	g_esQuietCache[tank].g_iQuietHitMode = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietHitMode, g_esQuietAbility[type].g_iQuietHitMode);
	g_esQuietCache[tank].g_iQuietMessage = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietMessage, g_esQuietAbility[type].g_iQuietMessage);
	g_esQuietCache[tank].g_iQuietRangeCooldown = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iQuietRangeCooldown, g_esQuietAbility[type].g_iQuietRangeCooldown);
	g_esQuietCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_flOpenAreasOnly, g_esQuietAbility[type].g_flOpenAreasOnly);
	g_esQuietCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esQuietPlayer[tank].g_iRequiresHumans, g_esQuietAbility[type].g_iRequiresHumans);
	g_esQuietPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vQuietCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vQuietCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveQuiet(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vQuietEventFired(Event event, const char[] name)
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
			vQuietCopyStats2(iBot, iTank);
			vRemoveQuiet(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vQuietCopyStats2(iTank, iBot);
			vRemoveQuiet(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveQuiet(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vQuietReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vQuietAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esQuietAbility[g_esQuietPlayer[tank].g_iTankType].g_iAccessFlags, g_esQuietPlayer[tank].g_iAccessFlags)) || g_esQuietCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esQuietCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esQuietCache[tank].g_iQuietAbility == 1 && g_esQuietCache[tank].g_iComboAbility == 0)
	{
		vQuietAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vQuietButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esQuietCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esQuietCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esQuietPlayer[tank].g_iTankType) || (g_esQuietCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esQuietCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esQuietAbility[g_esQuietPlayer[tank].g_iTankType].g_iAccessFlags, g_esQuietPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esQuietCache[tank].g_iQuietAbility == 1 && g_esQuietCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esQuietPlayer[tank].g_iRangeCooldown == -1 || g_esQuietPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vQuietAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietHuman3", (g_esQuietPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vQuietChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveQuiet(tank);
}

void vQuietAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esQuietCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esQuietCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esQuietPlayer[tank].g_iTankType) || (g_esQuietCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esQuietCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esQuietAbility[g_esQuietPlayer[tank].g_iTankType].g_iAccessFlags, g_esQuietPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esQuietPlayer[tank].g_iAmmoCount < g_esQuietCache[tank].g_iHumanAmmo && g_esQuietCache[tank].g_iHumanAmmo > 0))
	{
		g_esQuietPlayer[tank].g_bFailed = false;
		g_esQuietPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esQuietCache[tank].g_flQuietRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esQuietCache[tank].g_flQuietRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esQuietPlayer[tank].g_iTankType, g_esQuietAbility[g_esQuietPlayer[tank].g_iTankType].g_iImmunityFlags, g_esQuietPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vQuietHit(iSurvivor, tank, random, flChance, g_esQuietCache[tank].g_iQuietAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietAmmo");
	}
}

void vQuietHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esQuietCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esQuietCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esQuietPlayer[tank].g_iTankType) || (g_esQuietCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esQuietCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esQuietAbility[g_esQuietPlayer[tank].g_iTankType].g_iAccessFlags, g_esQuietPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esQuietPlayer[tank].g_iTankType, g_esQuietAbility[g_esQuietPlayer[tank].g_iTankType].g_iImmunityFlags, g_esQuietPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esQuietPlayer[tank].g_iRangeCooldown != -1 && g_esQuietPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esQuietPlayer[tank].g_iCooldown != -1 && g_esQuietPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsHumanSurvivor(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esQuietPlayer[tank].g_iAmmoCount < g_esQuietCache[tank].g_iHumanAmmo && g_esQuietCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esQuietPlayer[survivor].g_bAffected)
			{
				g_esQuietPlayer[survivor].g_bAffected = true;
				g_esQuietPlayer[survivor].g_iFilter = g_esQuietCache[tank].g_iQuietFilter;
				g_esQuietPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esQuietPlayer[tank].g_iRangeCooldown == -1 || g_esQuietPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1)
					{
						g_esQuietPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietHuman", g_esQuietPlayer[tank].g_iAmmoCount, g_esQuietCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esQuietCache[tank].g_iQuietRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1 && g_esQuietPlayer[tank].g_iAmmoCount < g_esQuietCache[tank].g_iHumanAmmo && g_esQuietCache[tank].g_iHumanAmmo > 0) ? g_esQuietCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esQuietPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esQuietPlayer[tank].g_iRangeCooldown != -1 && g_esQuietPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietHuman5", (g_esQuietPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esQuietPlayer[tank].g_iCooldown == -1 || g_esQuietPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esQuietCache[tank].g_iQuietCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1) ? g_esQuietCache[tank].g_iHumanCooldown : iCooldown;
					g_esQuietPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esQuietPlayer[tank].g_iCooldown != -1 && g_esQuietPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietHuman5", (g_esQuietPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esQuietCache[tank].g_flQuietDuration;
				DataPack dpStopQuiet;
				CreateDataTimer(flDuration, tTimerStopQuiet, dpStopQuiet, TIMER_FLAG_NO_MAPCHANGE);
				dpStopQuiet.WriteCell(GetClientUserId(survivor));
				dpStopQuiet.WriteCell(GetClientUserId(tank));
				dpStopQuiet.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esQuietCache[tank].g_iQuietEffect, flags);

				if (g_esQuietCache[tank].g_iQuietMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Quiet", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Quiet", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esQuietPlayer[tank].g_iRangeCooldown == -1 || g_esQuietPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1 && !g_esQuietPlayer[tank].g_bFailed)
				{
					g_esQuietPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esQuietCache[tank].g_iHumanAbility == 1 && !g_esQuietPlayer[tank].g_bNoAmmo)
		{
			g_esQuietPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "QuietAmmo");
		}
	}
}

void vQuietCopyStats2(int oldTank, int newTank)
{
	g_esQuietPlayer[newTank].g_iAmmoCount = g_esQuietPlayer[oldTank].g_iAmmoCount;
	g_esQuietPlayer[newTank].g_iCooldown = g_esQuietPlayer[oldTank].g_iCooldown;
	g_esQuietPlayer[newTank].g_iRangeCooldown = g_esQuietPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveQuiet(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsHumanSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esQuietPlayer[iSurvivor].g_bAffected && g_esQuietPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esQuietPlayer[iSurvivor].g_bAffected = false;
			g_esQuietPlayer[iSurvivor].g_iFilter = 0;
			g_esQuietPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vQuietReset2(tank);
}

void vQuietReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vQuietReset2(iPlayer);

			g_esQuietPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vQuietReset2(int tank)
{
	g_esQuietPlayer[tank].g_bAffected = false;
	g_esQuietPlayer[tank].g_bFailed = false;
	g_esQuietPlayer[tank].g_bNoAmmo = false;
	g_esQuietPlayer[tank].g_iAmmoCount = 0;
	g_esQuietPlayer[tank].g_iCooldown = -1;
	g_esQuietPlayer[tank].g_iFilter = 0;
	g_esQuietPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerQuietCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esQuietAbility[g_esQuietPlayer[iTank].g_iTankType].g_iAccessFlags, g_esQuietPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esQuietPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esQuietCache[iTank].g_iQuietAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vQuietAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerQuietCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsHumanSurvivor(iSurvivor) || g_esQuietPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esQuietAbility[g_esQuietPlayer[iTank].g_iTankType].g_iAccessFlags, g_esQuietPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esQuietPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esQuietCache[iTank].g_iQuietHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esQuietCache[iTank].g_iQuietHitMode == 0 || g_esQuietCache[iTank].g_iQuietHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vQuietHit(iSurvivor, iTank, flRandom, flChance, g_esQuietCache[iTank].g_iQuietHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esQuietCache[iTank].g_iQuietHitMode == 0 || g_esQuietCache[iTank].g_iQuietHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vQuietHit(iSurvivor, iTank, flRandom, flChance, g_esQuietCache[iTank].g_iQuietHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopQuiet(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsHumanSurvivor(iSurvivor) || !g_esQuietPlayer[iSurvivor].g_bAffected)
	{
		g_esQuietPlayer[iSurvivor].g_bAffected = false;
		g_esQuietPlayer[iSurvivor].g_iFilter = 0;
		g_esQuietPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		g_esQuietPlayer[iSurvivor].g_bAffected = false;
		g_esQuietPlayer[iSurvivor].g_iFilter = 0;
		g_esQuietPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esQuietPlayer[iSurvivor].g_bAffected = false;
	g_esQuietPlayer[iSurvivor].g_iFilter = 0;
	g_esQuietPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esQuietCache[iTank].g_iQuietMessage & iMessage)
	{
		char sTankName[33];
		MT_GetTankName(iTank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Quiet2", sTankName, iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Quiet2", LANG_SERVER, sTankName, iSurvivor);
	}

	return Plugin_Continue;
}