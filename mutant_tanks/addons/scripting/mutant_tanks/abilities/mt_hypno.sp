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

#define MT_HYPNO_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN
	#if MT_HYPNO_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities" while compiling "mt_abilities.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Hypno Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank hypnotizes survivors to damage themselves or their teammates.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Hypno Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_HYPNO_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_METAL "physics/metal/metal_solid_impact_hard5.wav"

#define MT_HYPNO_SECTION "hypnoability"
#define MT_HYPNO_SECTION2 "hypno ability"
#define MT_HYPNO_SECTION3 "hypno_ability"
#define MT_HYPNO_SECTION4 "hypno"

#define MT_MENU_HYPNO "Hypno Ability"

enum struct esHypnoPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flHypnoBulletDivisor;
	float g_flHypnoChance;
	float g_flHypnoDuration;
	float g_flHypnoExplosiveDivisor;
	float g_flHypnoFireDivisor;
	float g_flHypnoHittableDivisor;
	float g_flHypnoMeleeDivisor;
	float g_flHypnoRange;
	float g_flHypnoRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iAmmoCount;
	int g_iComboAbility;
	int g_iCooldown;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHypnoAbility;
	int g_iHypnoCooldown;
	int g_iHypnoEffect;
	int g_iHypnoHit;
	int g_iHypnoHitMode;
	int g_iHypnoMessage;
	int g_iHypnoMode;
	int g_iHypnoRangeCooldown;
	int g_iImmunityFlags;
	int g_iOwner;
	int g_iRangeCooldown;
	int g_iRequiresHumans;
	int g_iTankType;
}

esHypnoPlayer g_esHypnoPlayer[MAXPLAYERS + 1];

enum struct esHypnoAbility
{
	float g_flCloseAreasOnly;
	float g_flHypnoBulletDivisor;
	float g_flHypnoChance;
	float g_flHypnoDuration;
	float g_flHypnoExplosiveDivisor;
	float g_flHypnoFireDivisor;
	float g_flHypnoHittableDivisor;
	float g_flHypnoMeleeDivisor;
	float g_flHypnoRange;
	float g_flHypnoRangeChance;
	float g_flOpenAreasOnly;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHypnoAbility;
	int g_iHypnoCooldown;
	int g_iHypnoEffect;
	int g_iHypnoHit;
	int g_iHypnoHitMode;
	int g_iHypnoMessage;
	int g_iHypnoMode;
	int g_iHypnoRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
}

esHypnoAbility g_esHypnoAbility[MT_MAXTYPES + 1];

enum struct esHypnoCache
{
	float g_flCloseAreasOnly;
	float g_flHypnoBulletDivisor;
	float g_flHypnoChance;
	float g_flHypnoDuration;
	float g_flHypnoExplosiveDivisor;
	float g_flHypnoFireDivisor;
	float g_flHypnoHittableDivisor;
	float g_flHypnoMeleeDivisor;
	float g_flHypnoRange;
	float g_flHypnoRangeChance;
	float g_flOpenAreasOnly;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iHypnoAbility;
	int g_iHypnoCooldown;
	int g_iHypnoEffect;
	int g_iHypnoHit;
	int g_iHypnoHitMode;
	int g_iHypnoMessage;
	int g_iHypnoMode;
	int g_iHypnoRangeCooldown;
	int g_iRequiresHumans;
}

esHypnoCache g_esHypnoCache[MAXPLAYERS + 1];

#if !defined MT_ABILITIES_MAIN
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_hypno", cmdHypnoInfo, "View information about the Hypno ability.");

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
void vHypnoMapStart()
#else
public void OnMapStart()
#endif
{
	vHypnoReset();
}

#if defined MT_ABILITIES_MAIN
void vHypnoClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnHypnoTakeDamage);
	vHypnoReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vHypnoClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vHypnoReset2(client);
}

#if defined MT_ABILITIES_MAIN
void vHypnoMapEnd()
#else
public void OnMapEnd()
#endif
{
	vHypnoReset();
}

#if !defined MT_ABILITIES_MAIN
Action cmdHypnoInfo(int client, int args)
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
		case false: vHypnoMenu(client, MT_HYPNO_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vHypnoMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_HYPNO_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iHypnoMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Hypno Ability Information");
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

int iHypnoMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esHypnoCache[param1].g_iHypnoAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esHypnoCache[param1].g_iHumanAmmo - g_esHypnoPlayer[param1].g_iAmmoCount), g_esHypnoCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esHypnoCache[param1].g_iHumanAbility == 1) ? g_esHypnoCache[param1].g_iHumanCooldown : g_esHypnoCache[param1].g_iHypnoCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "HypnoDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityDuration", g_esHypnoCache[param1].g_flHypnoDuration);
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esHypnoCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 7: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esHypnoCache[param1].g_iHumanAbility == 1) ? g_esHypnoCache[param1].g_iHumanRangeCooldown : g_esHypnoCache[param1].g_iHypnoRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vHypnoMenu(param1, MT_HYPNO_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pHypno = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "HypnoMenu", param1);
			pHypno.SetTitle(sMenuTitle);
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
void vHypnoDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_HYPNO, MT_MENU_HYPNO);
}

#if defined MT_ABILITIES_MAIN
void vHypnoMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_HYPNO, false))
	{
		vHypnoMenu(client, MT_HYPNO_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN
void vHypnoMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_HYPNO, false))
	{
		FormatEx(buffer, size, "%T", "HypnoMenu2", client);
	}
}

Action OnHypnoTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && damage > 0.0)
	{
		char sClassname[32];
		if (bIsValidEntity(inflictor))
		{
			GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		}

		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esHypnoCache[attacker].g_iHypnoHitMode == 0 || g_esHypnoCache[attacker].g_iHypnoHitMode == 1) && bIsSurvivor(victim) && g_esHypnoCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esHypnoAbility[g_esHypnoPlayer[attacker].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esHypnoPlayer[attacker].g_iTankType, g_esHypnoAbility[g_esHypnoPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esHypnoPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vHypnoHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esHypnoCache[attacker].g_flHypnoChance, g_esHypnoCache[attacker].g_iHypnoHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && bIsSurvivor(attacker))
		{
			if ((g_esHypnoCache[victim].g_iHypnoHitMode == 0 || g_esHypnoCache[victim].g_iHypnoHitMode == 2) && StrEqual(sClassname[7], "melee") && g_esHypnoCache[victim].g_iComboAbility == 0)
			{
				if ((MT_HasAdminAccess(victim) || bHasAdminAccess(victim, g_esHypnoAbility[g_esHypnoPlayer[victim].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[victim].g_iAccessFlags)) && !MT_IsAdminImmune(attacker, victim) && !bIsAdminImmune(attacker, g_esHypnoPlayer[victim].g_iTankType, g_esHypnoAbility[g_esHypnoPlayer[victim].g_iTankType].g_iImmunityFlags, g_esHypnoPlayer[attacker].g_iImmunityFlags))
				{
					vHypnoHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esHypnoCache[victim].g_flHypnoChance, g_esHypnoCache[victim].g_iHypnoHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
				}
			}

			if (!bIsPlayerIncapacitated(victim) && g_esHypnoPlayer[attacker].g_bAffected)
			{
				bool bChanged = false;
				if (g_esHypnoCache[victim].g_flHypnoBulletDivisor > 1.0 && (damagetype & DMG_BULLET))
				{
					bChanged = true;
					damage /= g_esHypnoCache[victim].g_flHypnoBulletDivisor;
				}
				else if (g_esHypnoCache[victim].g_flHypnoExplosiveDivisor > 1.0 && ((damagetype & DMG_BLAST) || (damagetype & DMG_BLAST_SURFACE) || (damagetype & DMG_AIRBOAT) || (damagetype & DMG_PLASMA)))
				{
					bChanged = true;
					damage /= g_esHypnoCache[victim].g_flHypnoExplosiveDivisor;
				}
				else if (g_esHypnoCache[victim].g_flHypnoFireDivisor > 1.0 && ((damagetype & DMG_BURN) || (damagetype & DMG_DIRECT)))
				{
					bChanged = true;
					damage /= g_esHypnoCache[victim].g_flHypnoFireDivisor;
				}
				else if (g_esHypnoCache[victim].g_flHypnoHittableDivisor > 1.0 && (damagetype & DMG_CRUSH) && bIsValidEntity(inflictor) && HasEntProp(inflictor, Prop_Send, "m_isCarryable"))
				{
					bChanged = true;
					damage /= g_esHypnoCache[victim].g_flHypnoHittableDivisor;
				}
				else if (g_esHypnoCache[victim].g_flHypnoMeleeDivisor > 1.0 && ((damagetype & DMG_SLASH) || (damagetype & DMG_CLUB)))
				{
					bChanged = true;
					damage /= g_esHypnoCache[victim].g_flHypnoMeleeDivisor;

					float flTankPos[3];
					GetClientAbsOrigin(victim, flTankPos);

					switch (MT_DoesSurvivorHaveRewardType(attacker, MT_REWARD_GODMODE))
					{
						case true: vPushNearbyEntities(victim, flTankPos, 300.0, 100.0);
						case false: vPushNearbyEntities(victim, flTankPos);
					}
				}

				if (bChanged)
				{
					if (damage < 1.0)
					{
						damage = 1.0;
					}

					int iTarget = (g_esHypnoCache[victim].g_iHypnoMode == 1) ? iGetRandomSurvivor(victim) : attacker;
					if (iTarget > 0)
					{
						char sDamageType[32];
						IntToString(damagetype, sDamageType, sizeof sDamageType);
						vDamagePlayer(iTarget, victim, damage, sDamageType);
						EmitSoundToAll(SOUND_METAL, victim);
					}
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN
void vHypnoPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_HYPNO);
}

#if defined MT_ABILITIES_MAIN
void vHypnoAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_HYPNO_SECTION);
	list2.PushString(MT_HYPNO_SECTION2);
	list3.PushString(MT_HYPNO_SECTION3);
	list4.PushString(MT_HYPNO_SECTION4);
}

#if defined MT_ABILITIES_MAIN
void vHypnoCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_HYPNO_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_HYPNO_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_HYPNO_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_HYPNO_SECTION4);
	if (g_esHypnoCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_HYPNO_SECTION, false) || StrEqual(sSubset[iPos], MT_HYPNO_SECTION2, false) || StrEqual(sSubset[iPos], MT_HYPNO_SECTION3, false) || StrEqual(sSubset[iPos], MT_HYPNO_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esHypnoCache[tank].g_iHypnoAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vHypnoAbility(tank, random, iPos);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerHypnoCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esHypnoCache[tank].g_iHypnoHitMode == 0 || g_esHypnoCache[tank].g_iHypnoHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vHypnoHit(survivor, tank, random, flChance, g_esHypnoCache[tank].g_iHypnoHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esHypnoCache[tank].g_iHypnoHitMode == 0 || g_esHypnoCache[tank].g_iHypnoHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vHypnoHit(survivor, tank, random, flChance, g_esHypnoCache[tank].g_iHypnoHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerHypnoCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vHypnoConfigsLoad(int mode)
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
				g_esHypnoAbility[iIndex].g_iAccessFlags = 0;
				g_esHypnoAbility[iIndex].g_iImmunityFlags = 0;
				g_esHypnoAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esHypnoAbility[iIndex].g_iComboAbility = 0;
				g_esHypnoAbility[iIndex].g_iHumanAbility = 0;
				g_esHypnoAbility[iIndex].g_iHumanAmmo = 5;
				g_esHypnoAbility[iIndex].g_iHumanCooldown = 0;
				g_esHypnoAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esHypnoAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esHypnoAbility[iIndex].g_iRequiresHumans = 0;
				g_esHypnoAbility[iIndex].g_iHypnoAbility = 0;
				g_esHypnoAbility[iIndex].g_iHypnoEffect = 0;
				g_esHypnoAbility[iIndex].g_iHypnoMessage = 0;
				g_esHypnoAbility[iIndex].g_flHypnoBulletDivisor = 20.0;
				g_esHypnoAbility[iIndex].g_flHypnoChance = 33.3;
				g_esHypnoAbility[iIndex].g_iHypnoCooldown = 0;
				g_esHypnoAbility[iIndex].g_flHypnoDuration = 5.0;
				g_esHypnoAbility[iIndex].g_flHypnoExplosiveDivisor = 20.0;
				g_esHypnoAbility[iIndex].g_flHypnoFireDivisor = 200.0;
				g_esHypnoAbility[iIndex].g_iHypnoHit = 0;
				g_esHypnoAbility[iIndex].g_iHypnoHitMode = 0;
				g_esHypnoAbility[iIndex].g_flHypnoHittableDivisor = 20.0;
				g_esHypnoAbility[iIndex].g_flHypnoMeleeDivisor = 200.0;
				g_esHypnoAbility[iIndex].g_iHypnoMode = 0;
				g_esHypnoAbility[iIndex].g_flHypnoRange = 150.0;
				g_esHypnoAbility[iIndex].g_flHypnoRangeChance = 15.0;
				g_esHypnoAbility[iIndex].g_iHypnoRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esHypnoPlayer[iPlayer].g_iAccessFlags = 0;
					g_esHypnoPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esHypnoPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esHypnoPlayer[iPlayer].g_iComboAbility = 0;
					g_esHypnoPlayer[iPlayer].g_iHumanAbility = 0;
					g_esHypnoPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esHypnoPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esHypnoPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esHypnoPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esHypnoPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esHypnoPlayer[iPlayer].g_iHypnoAbility = 0;
					g_esHypnoPlayer[iPlayer].g_iHypnoEffect = 0;
					g_esHypnoPlayer[iPlayer].g_iHypnoMessage = 0;
					g_esHypnoPlayer[iPlayer].g_flHypnoBulletDivisor = 0.0;
					g_esHypnoPlayer[iPlayer].g_flHypnoChance = 0.0;
					g_esHypnoPlayer[iPlayer].g_iHypnoCooldown = 0;
					g_esHypnoPlayer[iPlayer].g_flHypnoDuration = 0.0;
					g_esHypnoPlayer[iPlayer].g_flHypnoExplosiveDivisor = 0.0;
					g_esHypnoPlayer[iPlayer].g_flHypnoFireDivisor = 0.0;
					g_esHypnoPlayer[iPlayer].g_iHypnoHit = 0;
					g_esHypnoPlayer[iPlayer].g_iHypnoHitMode = 0;
					g_esHypnoPlayer[iPlayer].g_flHypnoHittableDivisor = 0.0;
					g_esHypnoPlayer[iPlayer].g_flHypnoMeleeDivisor = 0.0;
					g_esHypnoPlayer[iPlayer].g_iHypnoMode = 0;
					g_esHypnoPlayer[iPlayer].g_flHypnoRange = 0.0;
					g_esHypnoPlayer[iPlayer].g_flHypnoRangeChance = 0.0;
					g_esHypnoPlayer[iPlayer].g_iHypnoRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vHypnoConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esHypnoPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esHypnoPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esHypnoPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esHypnoPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esHypnoPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esHypnoPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esHypnoPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esHypnoPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esHypnoPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esHypnoPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esHypnoPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esHypnoPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esHypnoPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esHypnoPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esHypnoPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esHypnoPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esHypnoPlayer[admin].g_iHypnoAbility = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esHypnoPlayer[admin].g_iHypnoAbility, value, 0, 1);
		g_esHypnoPlayer[admin].g_iHypnoEffect = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esHypnoPlayer[admin].g_iHypnoEffect, value, 0, 7);
		g_esHypnoPlayer[admin].g_iHypnoMessage = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esHypnoPlayer[admin].g_iHypnoMessage, value, 0, 3);
		g_esHypnoPlayer[admin].g_flHypnoBulletDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoBulletDivisor", "Hypno Bullet Divisor", "Hypno_Bullet_Divisor", "bullet", g_esHypnoPlayer[admin].g_flHypnoBulletDivisor, value, 1.0, 99999.0);
		g_esHypnoPlayer[admin].g_flHypnoChance = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoChance", "Hypno Chance", "Hypno_Chance", "chance", g_esHypnoPlayer[admin].g_flHypnoChance, value, 0.0, 100.0);
		g_esHypnoPlayer[admin].g_iHypnoCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoCooldown", "Hypno Cooldown", "Hypno_Cooldown", "cooldown", g_esHypnoPlayer[admin].g_iHypnoCooldown, value, 0, 99999);
		g_esHypnoPlayer[admin].g_flHypnoDuration = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoDuration", "Hypno Duration", "Hypno_Duration", "duration", g_esHypnoPlayer[admin].g_flHypnoDuration, value, 0.1, 99999.0);
		g_esHypnoPlayer[admin].g_flHypnoExplosiveDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoExplosiveDivisor", "Hypno Explosive Divisor", "Hypno_Explosive_Divisor", "explosive", g_esHypnoPlayer[admin].g_flHypnoExplosiveDivisor, value, 1.0, 99999.0);
		g_esHypnoPlayer[admin].g_flHypnoFireDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoFireDivisor", "Hypno Fire Divisor", "Hypno_Fire_Divisor", "fire", g_esHypnoPlayer[admin].g_flHypnoFireDivisor, value, 1.0, 99999.0);
		g_esHypnoPlayer[admin].g_iHypnoHit = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoHit", "Hypno Hit", "Hypno_Hit", "hit", g_esHypnoPlayer[admin].g_iHypnoHit, value, 0, 1);
		g_esHypnoPlayer[admin].g_iHypnoHitMode = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoHitMode", "Hypno Hit Mode", "Hypno_Hit_Mode", "hitmode", g_esHypnoPlayer[admin].g_iHypnoHitMode, value, 0, 2);
		g_esHypnoPlayer[admin].g_flHypnoHittableDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoHittableDivisor", "Hypno Hittable Divisor", "Hypno_Hittable_Divisor", "hittable", g_esHypnoPlayer[admin].g_flHypnoHittableDivisor, value, 1.0, 99999.0);
		g_esHypnoPlayer[admin].g_flHypnoMeleeDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoMeleeDivisor", "Hypno Melee Divisor", "Hypno_Melee_Divisor", "melee", g_esHypnoPlayer[admin].g_flHypnoMeleeDivisor, value, 1.0, 99999.0);
		g_esHypnoPlayer[admin].g_iHypnoMode = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoMode", "Hypno Mode", "Hypno_Mode", "mode", g_esHypnoPlayer[admin].g_iHypnoMode, value, 0, 1);
		g_esHypnoPlayer[admin].g_flHypnoRange = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoRange", "Hypno Range", "Hypno_Range", "range", g_esHypnoPlayer[admin].g_flHypnoRange, value, 1.0, 99999.0);
		g_esHypnoPlayer[admin].g_flHypnoRangeChance = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoRangeChance", "Hypno Range Chance", "Hypno_Range_Chance", "rangechance", g_esHypnoPlayer[admin].g_flHypnoRangeChance, value, 0.0, 100.0);
		g_esHypnoPlayer[admin].g_iHypnoRangeCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoRangeCooldown", "Hypno Range Cooldown", "Hypno_Range_Cooldown", "rangecooldown", g_esHypnoPlayer[admin].g_iHypnoRangeCooldown, value, 0, 99999);
		g_esHypnoPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esHypnoPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esHypnoAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esHypnoAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esHypnoAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esHypnoAbility[type].g_iComboAbility, value, 0, 1);
		g_esHypnoAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esHypnoAbility[type].g_iHumanAbility, value, 0, 2);
		g_esHypnoAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esHypnoAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esHypnoAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esHypnoAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esHypnoAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esHypnoAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esHypnoAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esHypnoAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esHypnoAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esHypnoAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esHypnoAbility[type].g_iHypnoAbility = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esHypnoAbility[type].g_iHypnoAbility, value, 0, 1);
		g_esHypnoAbility[type].g_iHypnoEffect = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esHypnoAbility[type].g_iHypnoEffect, value, 0, 7);
		g_esHypnoAbility[type].g_iHypnoMessage = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esHypnoAbility[type].g_iHypnoMessage, value, 0, 3);
		g_esHypnoAbility[type].g_flHypnoBulletDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoBulletDivisor", "Hypno Bullet Divisor", "Hypno_Bullet_Divisor", "bullet", g_esHypnoAbility[type].g_flHypnoBulletDivisor, value, 1.0, 99999.0);
		g_esHypnoAbility[type].g_flHypnoChance = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoChance", "Hypno Chance", "Hypno_Chance", "chance", g_esHypnoAbility[type].g_flHypnoChance, value, 0.0, 100.0);
		g_esHypnoAbility[type].g_iHypnoCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoCooldown", "Hypno Cooldown", "Hypno_Cooldown", "cooldown", g_esHypnoAbility[type].g_iHypnoCooldown, value, 0, 99999);
		g_esHypnoAbility[type].g_flHypnoDuration = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoDuration", "Hypno Duration", "Hypno_Duration", "duration", g_esHypnoAbility[type].g_flHypnoDuration, value, 0.1, 99999.0);
		g_esHypnoAbility[type].g_flHypnoExplosiveDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoExplosiveDivisor", "Hypno Explosive Divisor", "Hypno_Explosive_Divisor", "explosive", g_esHypnoAbility[type].g_flHypnoExplosiveDivisor, value, 1.0, 99999.0);
		g_esHypnoAbility[type].g_flHypnoFireDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoFireDivisor", "Hypno Fire Divisor", "Hypno_Fire_Divisor", "fire", g_esHypnoAbility[type].g_flHypnoFireDivisor, value, 1.0, 99999.0);
		g_esHypnoAbility[type].g_iHypnoHit = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoHit", "Hypno Hit", "Hypno_Hit", "hit", g_esHypnoAbility[type].g_iHypnoHit, value, 0, 1);
		g_esHypnoAbility[type].g_iHypnoHitMode = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoHitMode", "Hypno Hit Mode", "Hypno_Hit_Mode", "hitmode", g_esHypnoAbility[type].g_iHypnoHitMode, value, 0, 2);
		g_esHypnoAbility[type].g_flHypnoHittableDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoHittableDivisor", "Hypno Hittable Divisor", "Hypno_Hittable_Divisor", "hittable", g_esHypnoAbility[type].g_flHypnoHittableDivisor, value, 1.0, 99999.0);
		g_esHypnoAbility[type].g_flHypnoMeleeDivisor = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoMeleeDivisor", "Hypno Melee Divisor", "Hypno_Melee_Divisor", "melee", g_esHypnoAbility[type].g_flHypnoMeleeDivisor, value, 1.0, 99999.0);
		g_esHypnoAbility[type].g_iHypnoMode = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoMode", "Hypno Mode", "Hypno_Mode", "mode", g_esHypnoAbility[type].g_iHypnoMode, value, 0, 1);
		g_esHypnoAbility[type].g_flHypnoRange = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoRange", "Hypno Range", "Hypno_Range", "range", g_esHypnoAbility[type].g_flHypnoRange, value, 1.0, 99999.0);
		g_esHypnoAbility[type].g_flHypnoRangeChance = flGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoRangeChance", "Hypno Range Chance", "Hypno_Range_Chance", "rangechance", g_esHypnoAbility[type].g_flHypnoRangeChance, value, 0.0, 100.0);
		g_esHypnoAbility[type].g_iHypnoRangeCooldown = iGetKeyValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "HypnoRangeCooldown", "Hypno Range Cooldown", "Hypno_Range_Cooldown", "rangecooldown", g_esHypnoAbility[type].g_iHypnoRangeCooldown, value, 0, 99999);
		g_esHypnoAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esHypnoAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_HYPNO_SECTION, MT_HYPNO_SECTION2, MT_HYPNO_SECTION3, MT_HYPNO_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN
void vHypnoSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esHypnoCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flCloseAreasOnly, g_esHypnoAbility[type].g_flCloseAreasOnly);
	g_esHypnoCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iComboAbility, g_esHypnoAbility[type].g_iComboAbility);
	g_esHypnoCache[tank].g_flHypnoBulletDivisor = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoBulletDivisor, g_esHypnoAbility[type].g_flHypnoBulletDivisor);
	g_esHypnoCache[tank].g_flHypnoChance = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoChance, g_esHypnoAbility[type].g_flHypnoChance);
	g_esHypnoCache[tank].g_iHypnoCooldown = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoCooldown, g_esHypnoAbility[type].g_iHypnoCooldown);
	g_esHypnoCache[tank].g_flHypnoDuration = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoDuration, g_esHypnoAbility[type].g_flHypnoDuration);
	g_esHypnoCache[tank].g_flHypnoExplosiveDivisor = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoExplosiveDivisor, g_esHypnoAbility[type].g_flHypnoExplosiveDivisor);
	g_esHypnoCache[tank].g_flHypnoFireDivisor = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoFireDivisor, g_esHypnoAbility[type].g_flHypnoFireDivisor);
	g_esHypnoCache[tank].g_flHypnoHittableDivisor = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoHittableDivisor, g_esHypnoAbility[type].g_flHypnoHittableDivisor);
	g_esHypnoCache[tank].g_flHypnoMeleeDivisor = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoMeleeDivisor, g_esHypnoAbility[type].g_flHypnoMeleeDivisor);
	g_esHypnoCache[tank].g_flHypnoRange = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoRange, g_esHypnoAbility[type].g_flHypnoRange);
	g_esHypnoCache[tank].g_flHypnoRangeChance = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flHypnoRangeChance, g_esHypnoAbility[type].g_flHypnoRangeChance);
	g_esHypnoCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHumanAbility, g_esHypnoAbility[type].g_iHumanAbility);
	g_esHypnoCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHumanAmmo, g_esHypnoAbility[type].g_iHumanAmmo);
	g_esHypnoCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHumanCooldown, g_esHypnoAbility[type].g_iHumanCooldown);
	g_esHypnoCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHumanRangeCooldown, g_esHypnoAbility[type].g_iHumanRangeCooldown);
	g_esHypnoCache[tank].g_iHypnoAbility = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoAbility, g_esHypnoAbility[type].g_iHypnoAbility);
	g_esHypnoCache[tank].g_iHypnoEffect = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoEffect, g_esHypnoAbility[type].g_iHypnoEffect);
	g_esHypnoCache[tank].g_iHypnoHit = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoHit, g_esHypnoAbility[type].g_iHypnoHit);
	g_esHypnoCache[tank].g_iHypnoHitMode = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoHitMode, g_esHypnoAbility[type].g_iHypnoHitMode);
	g_esHypnoCache[tank].g_iHypnoMessage = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoMessage, g_esHypnoAbility[type].g_iHypnoMessage);
	g_esHypnoCache[tank].g_iHypnoMode = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoMode, g_esHypnoAbility[type].g_iHypnoMode);
	g_esHypnoCache[tank].g_iHypnoRangeCooldown = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iHypnoRangeCooldown, g_esHypnoAbility[type].g_iHypnoRangeCooldown);
	g_esHypnoCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_flOpenAreasOnly, g_esHypnoAbility[type].g_flOpenAreasOnly);
	g_esHypnoCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esHypnoPlayer[tank].g_iRequiresHumans, g_esHypnoAbility[type].g_iRequiresHumans);
	g_esHypnoPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN
void vHypnoCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vHypnoCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveHypno(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN
void vHypnoEventFired(Event event, const char[] name)
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
			vHypnoCopyStats2(iBot, iTank);
			vRemoveHypno(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vHypnoCopyStats2(iTank, iBot);
			vRemoveHypno(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveHypno(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vHypnoReset();
	}
}

#if defined MT_ABILITIES_MAIN
void vHypnoAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esHypnoAbility[g_esHypnoPlayer[tank].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[tank].g_iAccessFlags)) || g_esHypnoCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esHypnoCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esHypnoCache[tank].g_iHypnoAbility == 1 && g_esHypnoCache[tank].g_iComboAbility == 0)
	{
		vHypnoAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN
void vHypnoButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esHypnoCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esHypnoCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esHypnoPlayer[tank].g_iTankType) || (g_esHypnoCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esHypnoCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esHypnoAbility[g_esHypnoPlayer[tank].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esHypnoCache[tank].g_iHypnoAbility == 1 && g_esHypnoCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esHypnoPlayer[tank].g_iRangeCooldown == -1 || g_esHypnoPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vHypnoAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoHuman3", (g_esHypnoPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN
void vHypnoChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveHypno(tank);
}

void vHypnoAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esHypnoCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esHypnoCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esHypnoPlayer[tank].g_iTankType) || (g_esHypnoCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esHypnoCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esHypnoAbility[g_esHypnoPlayer[tank].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esHypnoPlayer[tank].g_iAmmoCount < g_esHypnoCache[tank].g_iHumanAmmo && g_esHypnoCache[tank].g_iHumanAmmo > 0))
	{
		g_esHypnoPlayer[tank].g_bFailed = false;
		g_esHypnoPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esHypnoCache[tank].g_flHypnoRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esHypnoCache[tank].g_flHypnoRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esHypnoPlayer[tank].g_iTankType, g_esHypnoAbility[g_esHypnoPlayer[tank].g_iTankType].g_iImmunityFlags, g_esHypnoPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vHypnoHit(iSurvivor, tank, random, flChance, g_esHypnoCache[tank].g_iHypnoAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoAmmo");
	}
}

void vHypnoHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esHypnoCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esHypnoCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esHypnoPlayer[tank].g_iTankType) || (g_esHypnoCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esHypnoCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esHypnoAbility[g_esHypnoPlayer[tank].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esHypnoPlayer[tank].g_iTankType, g_esHypnoAbility[g_esHypnoPlayer[tank].g_iTankType].g_iImmunityFlags, g_esHypnoPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esHypnoPlayer[tank].g_iRangeCooldown != -1 && g_esHypnoPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esHypnoPlayer[tank].g_iCooldown != -1 && g_esHypnoPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !bIsSurvivorDisabled(survivor))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esHypnoPlayer[tank].g_iAmmoCount < g_esHypnoCache[tank].g_iHumanAmmo && g_esHypnoCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esHypnoPlayer[survivor].g_bAffected)
			{
				g_esHypnoPlayer[survivor].g_bAffected = true;
				g_esHypnoPlayer[survivor].g_iOwner = tank;

				int iCooldown = -1;
				if ((flags & MT_ATTACK_RANGE) && (g_esHypnoPlayer[tank].g_iRangeCooldown == -1 || g_esHypnoPlayer[tank].g_iRangeCooldown < iTime))
				{
					if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1)
					{
						g_esHypnoPlayer[tank].g_iAmmoCount++;

						MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoHuman", g_esHypnoPlayer[tank].g_iAmmoCount, g_esHypnoCache[tank].g_iHumanAmmo);
					}

					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esHypnoCache[tank].g_iHypnoRangeCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1 && g_esHypnoPlayer[tank].g_iAmmoCount < g_esHypnoCache[tank].g_iHumanAmmo && g_esHypnoCache[tank].g_iHumanAmmo > 0) ? g_esHypnoCache[tank].g_iHumanRangeCooldown : iCooldown;
					g_esHypnoPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
					if (g_esHypnoPlayer[tank].g_iRangeCooldown != -1 && g_esHypnoPlayer[tank].g_iRangeCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoHuman5", (g_esHypnoPlayer[tank].g_iRangeCooldown - iTime));
					}
				}
				else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esHypnoPlayer[tank].g_iCooldown == -1 || g_esHypnoPlayer[tank].g_iCooldown < iTime))
				{
					iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esHypnoCache[tank].g_iHypnoCooldown;
					iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1) ? g_esHypnoCache[tank].g_iHumanCooldown : iCooldown;
					g_esHypnoPlayer[tank].g_iCooldown = (iTime + iCooldown);
					if (g_esHypnoPlayer[tank].g_iCooldown != -1 && g_esHypnoPlayer[tank].g_iCooldown > iTime)
					{
						MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoHuman5", (g_esHypnoPlayer[tank].g_iCooldown - iTime));
					}
				}

				float flDuration = (pos != -1) ? MT_GetCombinationSetting(tank, 5, pos) : g_esHypnoCache[tank].g_flHypnoDuration;
				DataPack dpStopHypno;
				CreateDataTimer(flDuration, tTimerStopHypno, dpStopHypno, TIMER_FLAG_NO_MAPCHANGE);
				dpStopHypno.WriteCell(GetClientUserId(survivor));
				dpStopHypno.WriteCell(GetClientUserId(tank));
				dpStopHypno.WriteCell(messages);

				vScreenEffect(survivor, tank, g_esHypnoCache[tank].g_iHypnoEffect, flags);

				if (g_esHypnoCache[tank].g_iHypnoMessage & messages)
				{
					char sTankName[33];
					MT_GetTankName(tank, sTankName);
					MT_PrintToChatAll("%s %t", MT_TAG2, "Hypno", sTankName, survivor);
					MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Hypno", LANG_SERVER, sTankName, survivor);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esHypnoPlayer[tank].g_iRangeCooldown == -1 || g_esHypnoPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1 && !g_esHypnoPlayer[tank].g_bFailed)
				{
					g_esHypnoPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esHypnoCache[tank].g_iHumanAbility == 1 && !g_esHypnoPlayer[tank].g_bNoAmmo)
		{
			g_esHypnoPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "HypnoAmmo");
		}
	}
}

void vHypnoCopyStats2(int oldTank, int newTank)
{
	g_esHypnoPlayer[newTank].g_iAmmoCount = g_esHypnoPlayer[oldTank].g_iAmmoCount;
	g_esHypnoPlayer[newTank].g_iCooldown = g_esHypnoPlayer[oldTank].g_iCooldown;
	g_esHypnoPlayer[newTank].g_iRangeCooldown = g_esHypnoPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveHypno(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME) && g_esHypnoPlayer[iSurvivor].g_bAffected && g_esHypnoPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esHypnoPlayer[iSurvivor].g_bAffected = false;
			g_esHypnoPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vHypnoReset2(tank);
}

void vHypnoReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vHypnoReset2(iPlayer);

			g_esHypnoPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vHypnoReset2(int tank)
{
	g_esHypnoPlayer[tank].g_bAffected = false;
	g_esHypnoPlayer[tank].g_bFailed = false;
	g_esHypnoPlayer[tank].g_bNoAmmo = false;
	g_esHypnoPlayer[tank].g_iAmmoCount = 0;
	g_esHypnoPlayer[tank].g_iCooldown = -1;
	g_esHypnoPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerHypnoCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esHypnoAbility[g_esHypnoPlayer[iTank].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esHypnoPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esHypnoCache[iTank].g_iHypnoAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vHypnoAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerHypnoCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || g_esHypnoPlayer[iSurvivor].g_bAffected)
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esHypnoAbility[g_esHypnoPlayer[iTank].g_iTankType].g_iAccessFlags, g_esHypnoPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esHypnoPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esHypnoCache[iTank].g_iHypnoHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esHypnoCache[iTank].g_iHypnoHitMode == 0 || g_esHypnoCache[iTank].g_iHypnoHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vHypnoHit(iSurvivor, iTank, flRandom, flChance, g_esHypnoCache[iTank].g_iHypnoHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esHypnoCache[iTank].g_iHypnoHitMode == 0 || g_esHypnoCache[iTank].g_iHypnoHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vHypnoHit(iSurvivor, iTank, flRandom, flChance, g_esHypnoCache[iTank].g_iHypnoHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerStopHypno(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor) || !g_esHypnoPlayer[iSurvivor].g_bAffected)
	{
		g_esHypnoPlayer[iSurvivor].g_bAffected = false;
		g_esHypnoPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsTankSupported(iTank) || !MT_IsCustomTankSupported(iTank))
	{
		g_esHypnoPlayer[iSurvivor].g_bAffected = false;
		g_esHypnoPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	g_esHypnoPlayer[iSurvivor].g_bAffected = false;
	g_esHypnoPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esHypnoCache[iTank].g_iHypnoMessage & iMessage)
	{
		MT_PrintToChatAll("%s %t", MT_TAG2, "Hypno2", iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Hypno2", LANG_SERVER, iSurvivor);
	}

	return Plugin_Continue;
}