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

#define MT_ROCKET_COMPILE_METHOD 0 // 0: packaged, 1: standalone

#if !defined MT_ABILITIES_MAIN2
	#if MT_ROCKET_COMPILE_METHOD == 1
		#include <sourcemod>
		#include <mutant_tanks>
	#else
		#error This file must be inside "scripting/mutant_tanks/abilities2" while compiling "mt_abilities2.sp" to include its content.
	#endif
public Plugin myinfo =
{
	name = "[MT] Rocket Ability",
	author = MT_AUTHOR,
	description = "The Mutant Tank sends survivors into space.",
	version = MT_VERSION,
	url = MT_URL
};

bool g_bDedicated, g_bLateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion evEngine = GetEngineVersion();
	if (evEngine != Engine_Left4Dead && evEngine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "\"[MT] Rocket Ability\" only supports Left 4 Dead 1 & 2.");

		return APLRes_SilentFailure;
	}

	g_bDedicated = IsDedicatedServer();
	g_bLateLoad = late;

	return APLRes_Success;
}
#else
	#if MT_ROCKET_COMPILE_METHOD == 1
		#error This file must be compiled as a standalone plugin.
	#endif
#endif

#define SOUND_EXPLOSION "ambient/explosions/explode_2.wav"
#define SOUND_FIRE "weapons/molotov/fire_ignite_1.wav"
#define SOUND_LAUNCH "player/boomer/explode/explo_medium_14.wav"

#define SPRITE_FIRE "sprites/sprite_fire01.vmt"

#define MT_ROCKET_SECTION "rocketability"
#define MT_ROCKET_SECTION2 "rocket ability"
#define MT_ROCKET_SECTION3 "rocket_ability"
#define MT_ROCKET_SECTION4 "rocket"

#define MT_MENU_ROCKET "Rocket Ability"

enum struct esRocketPlayer
{
	bool g_bAffected;
	bool g_bFailed;
	bool g_bNoAmmo;

	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRocketChance;
	float g_flRocketDelay;
	float g_flRocketRange;
	float g_flRocketRangeChance;

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
	int g_iRocketAbility;
	int g_iRocketBody;
	int g_iRocketCooldown;
	int g_iRocketEffect;
	int g_iRocketHit;
	int g_iRocketHitMode;
	int g_iRocketMessage;
	int g_iRocketRangeCooldown;
	int g_iTankType;
}

esRocketPlayer g_esRocketPlayer[MAXPLAYERS + 1];

enum struct esRocketAbility
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRocketChance;
	float g_flRocketDelay;
	float g_flRocketRange;
	float g_flRocketRangeChance;

	int g_iAccessFlags;
	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iImmunityFlags;
	int g_iRequiresHumans;
	int g_iRocketAbility;
	int g_iRocketBody;
	int g_iRocketCooldown;
	int g_iRocketEffect;
	int g_iRocketHit;
	int g_iRocketHitMode;
	int g_iRocketMessage;
	int g_iRocketRangeCooldown;
}

esRocketAbility g_esRocketAbility[MT_MAXTYPES + 1];

enum struct esRocketCache
{
	float g_flCloseAreasOnly;
	float g_flOpenAreasOnly;
	float g_flRocketChance;
	float g_flRocketDelay;
	float g_flRocketRange;
	float g_flRocketRangeChance;

	int g_iComboAbility;
	int g_iHumanAbility;
	int g_iHumanAmmo;
	int g_iHumanCooldown;
	int g_iHumanRangeCooldown;
	int g_iRequiresHumans;
	int g_iRocketAbility;
	int g_iRocketBody;
	int g_iRocketCooldown;
	int g_iRocketEffect;
	int g_iRocketHit;
	int g_iRocketHitMode;
	int g_iRocketMessage;
	int g_iRocketRangeCooldown;
}

esRocketCache g_esRocketCache[MAXPLAYERS + 1];

int g_iRocketDeathModelOwner = 0, g_iRocketSprite = -1;

#if !defined MT_ABILITIES_MAIN2
public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("mutant_tanks.phrases");
	LoadTranslations("mutant_tanks_names.phrases");

	RegConsoleCmd("sm_mt_rocket", cmdRocketInfo, "View information about the Rocket ability.");

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
void vRocketMapStart()
#else
public void OnMapStart()
#endif
{
	g_iRocketSprite = PrecacheModel(SPRITE_FIRE, true);

	PrecacheSound(SOUND_EXPLOSION, true);
	PrecacheSound(SOUND_FIRE, true);
	PrecacheSound(SOUND_LAUNCH, true);

	vRocketReset();
}

#if defined MT_ABILITIES_MAIN2
void vRocketClientPutInServer(int client)
#else
public void OnClientPutInServer(int client)
#endif
{
	SDKHook(client, SDKHook_OnTakeDamage, OnRocketTakeDamage);
	vRocketReset3(client);
}

#if defined MT_ABILITIES_MAIN2
void vRocketClientDisconnect_Post(int client)
#else
public void OnClientDisconnect_Post(int client)
#endif
{
	vRocketReset3(client);
}

#if defined MT_ABILITIES_MAIN2
void vRocketMapEnd()
#else
public void OnMapEnd()
#endif
{
	vRocketReset();
}

#if !defined MT_ABILITIES_MAIN2
Action cmdRocketInfo(int client, int args)
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
		case false: vRocketMenu(client, MT_ROCKET_SECTION4, 0);
	}

	return Plugin_Handled;
}
#endif

void vRocketMenu(int client, const char[] name, int item)
{
	if (StrContains(MT_ROCKET_SECTION4, name, false) == -1)
	{
		return;
	}

	Menu mAbilityMenu = new Menu(iRocketMenuHandler, MENU_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	mAbilityMenu.SetTitle("Rocket Ability Information");
	mAbilityMenu.AddItem("Status", "Status");
	mAbilityMenu.AddItem("Ammunition", "Ammunition");
	mAbilityMenu.AddItem("Buttons", "Buttons");
	mAbilityMenu.AddItem("Cooldown", "Cooldown");
	mAbilityMenu.AddItem("Details", "Details");
	mAbilityMenu.AddItem("Human Support", "Human Support");
	mAbilityMenu.AddItem("Range Cooldown", "Range Cooldown");
	mAbilityMenu.DisplayAt(client, item, MENU_TIME_FOREVER);
}

int iRocketMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: delete menu;
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 0: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRocketCache[param1].g_iRocketAbility == 0) ? "AbilityStatus1" : "AbilityStatus2");
				case 1: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityAmmo", (g_esRocketCache[param1].g_iHumanAmmo - g_esRocketPlayer[param1].g_iAmmoCount), g_esRocketCache[param1].g_iHumanAmmo);
				case 2: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityButtons2");
				case 3: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityCooldown", ((g_esRocketCache[param1].g_iHumanAbility == 1) ? g_esRocketCache[param1].g_iHumanCooldown : g_esRocketCache[param1].g_iRocketCooldown));
				case 4: MT_PrintToChat(param1, "%s %t", MT_TAG3, "RocketDetails");
				case 5: MT_PrintToChat(param1, "%s %t", MT_TAG3, (g_esRocketCache[param1].g_iHumanAbility == 0) ? "AbilityHumanSupport1" : "AbilityHumanSupport2");
				case 6: MT_PrintToChat(param1, "%s %t", MT_TAG3, "AbilityRangeCooldown", ((g_esRocketCache[param1].g_iHumanAbility == 1) ? g_esRocketCache[param1].g_iHumanRangeCooldown : g_esRocketCache[param1].g_iRocketRangeCooldown));
			}

			if (bIsValidClient(param1, MT_CHECK_INGAME))
			{
				vRocketMenu(param1, MT_ROCKET_SECTION4, menu.Selection);
			}
		}
		case MenuAction_Display:
		{
			char sMenuTitle[PLATFORM_MAX_PATH];
			Panel pRocket = view_as<Panel>(param2);
			FormatEx(sMenuTitle, sizeof sMenuTitle, "%T", "RocketMenu", param1);
			pRocket.SetTitle(sMenuTitle);
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
					case 5: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "HumanSupport", param1);
					case 6: FormatEx(sMenuOption, sizeof sMenuOption, "%T", "RangeCooldown", param1);
				}

				return RedrawMenuItem(sMenuOption);
			}
		}
	}

	return 0;
}

#if defined MT_ABILITIES_MAIN2
void vRocketDisplayMenu(Menu menu)
#else
public void MT_OnDisplayMenu(Menu menu)
#endif
{
	menu.AddItem(MT_MENU_ROCKET, MT_MENU_ROCKET);
}

#if defined MT_ABILITIES_MAIN2
void vRocketMenuItemSelected(int client, const char[] info)
#else
public void MT_OnMenuItemSelected(int client, const char[] info)
#endif
{
	if (StrEqual(info, MT_MENU_ROCKET, false))
	{
		vRocketMenu(client, MT_ROCKET_SECTION4, 0);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#else
public void MT_OnMenuItemDisplayed(int client, const char[] info, char[] buffer, int size)
#endif
{
	if (StrEqual(info, MT_MENU_ROCKET, false))
	{
		FormatEx(buffer, size, "%T", "RocketMenu2", client);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketEntityCreated(int entity, const char[] classname)
#else
public void OnEntityCreated(int entity, const char[] classname)
#endif
{
	if (bIsValidEntity(entity) && StrEqual(classname, "survivor_death_model"))
	{
		int iOwner = GetClientOfUserId(g_iRocketDeathModelOwner);
		if (bIsValidClient(iOwner))
		{
			SDKHook(entity, SDKHook_SpawnPost, OnRocketModelSpawnPost);
		}

		g_iRocketDeathModelOwner = 0;
	}
}

void OnRocketModelSpawnPost(int model)
{
	g_iRocketDeathModelOwner = 0;

	SDKUnhook(model, SDKHook_SpawnPost, OnRocketModelSpawnPost);

	if (!bIsValidEntity(model))
	{
		return;
	}

	RemoveEntity(model);
}

Action OnRocketTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (MT_IsCorePluginEnabled() && bIsValidClient(victim, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE) && bIsValidEntity(inflictor) && damage > 0.0)
	{
		char sClassname[32];
		GetEntityClassname(inflictor, sClassname, sizeof sClassname);
		if (MT_IsTankSupported(attacker) && MT_IsCustomTankSupported(attacker) && (g_esRocketCache[attacker].g_iRocketHitMode == 0 || g_esRocketCache[attacker].g_iRocketHitMode == 1) && bIsSurvivor(victim) && g_esRocketCache[attacker].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(attacker) && !bHasAdminAccess(attacker, g_esRocketAbility[g_esRocketPlayer[attacker].g_iTankType].g_iAccessFlags, g_esRocketPlayer[attacker].g_iAccessFlags)) || MT_IsAdminImmune(victim, attacker) || bIsAdminImmune(victim, g_esRocketPlayer[attacker].g_iTankType, g_esRocketAbility[g_esRocketPlayer[attacker].g_iTankType].g_iImmunityFlags, g_esRocketPlayer[victim].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock"))
			{
				vRocketHit(victim, attacker, MT_GetRandomFloat(0.1, 100.0), g_esRocketCache[attacker].g_flRocketChance, g_esRocketCache[attacker].g_iRocketHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW);
			}
		}
		else if (MT_IsTankSupported(victim) && MT_IsCustomTankSupported(victim) && (g_esRocketCache[victim].g_iRocketHitMode == 0 || g_esRocketCache[victim].g_iRocketHitMode == 2) && bIsSurvivor(attacker) && g_esRocketCache[victim].g_iComboAbility == 0)
		{
			if ((!MT_HasAdminAccess(victim) && !bHasAdminAccess(victim, g_esRocketAbility[g_esRocketPlayer[victim].g_iTankType].g_iAccessFlags, g_esRocketPlayer[victim].g_iAccessFlags)) || MT_IsAdminImmune(attacker, victim) || bIsAdminImmune(attacker, g_esRocketPlayer[victim].g_iTankType, g_esRocketAbility[g_esRocketPlayer[victim].g_iTankType].g_iImmunityFlags, g_esRocketPlayer[attacker].g_iImmunityFlags))
			{
				return Plugin_Continue;
			}

			if (StrEqual(sClassname[7], "melee"))
			{
				vRocketHit(attacker, victim, MT_GetRandomFloat(0.1, 100.0), g_esRocketCache[victim].g_flRocketChance, g_esRocketCache[victim].g_iRocketHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE);
			}
		}
	}

	return Plugin_Continue;
}

#if defined MT_ABILITIES_MAIN2
void vRocketPluginCheck(ArrayList list)
#else
public void MT_OnPluginCheck(ArrayList list)
#endif
{
	list.PushString(MT_MENU_ROCKET);
}

#if defined MT_ABILITIES_MAIN2
void vRocketAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#else
public void MT_OnAbilityCheck(ArrayList list, ArrayList list2, ArrayList list3, ArrayList list4)
#endif
{
	list.PushString(MT_ROCKET_SECTION);
	list2.PushString(MT_ROCKET_SECTION2);
	list3.PushString(MT_ROCKET_SECTION3);
	list4.PushString(MT_ROCKET_SECTION4);
}

#if defined MT_ABILITIES_MAIN2
void vRocketCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, const char[] classname)
#else
public void MT_OnCombineAbilities(int tank, int type, const float random, const char[] combo, int survivor, int weapon, const char[] classname)
#endif
{
	if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility != 2)
	{
		return;
	}

	char sCombo[320], sSet[4][32];
	FormatEx(sCombo, sizeof sCombo, ",%s,", combo);
	FormatEx(sSet[0], sizeof sSet[], ",%s,", MT_ROCKET_SECTION);
	FormatEx(sSet[1], sizeof sSet[], ",%s,", MT_ROCKET_SECTION2);
	FormatEx(sSet[2], sizeof sSet[], ",%s,", MT_ROCKET_SECTION3);
	FormatEx(sSet[3], sizeof sSet[], ",%s,", MT_ROCKET_SECTION4);
	if (g_esRocketCache[tank].g_iComboAbility == 1 && (StrContains(sCombo, sSet[0], false) != -1 || StrContains(sCombo, sSet[1], false) != -1 || StrContains(sCombo, sSet[2], false) != -1 || StrContains(sCombo, sSet[3], false) != -1))
	{
		char sAbilities[320], sSubset[10][32];
		strcopy(sAbilities, sizeof sAbilities, combo);
		ExplodeString(sAbilities, ",", sSubset, sizeof sSubset, sizeof sSubset[]);

		float flChance = 0.0, flDelay = 0.0;
		for (int iPos = 0; iPos < (sizeof sSubset); iPos++)
		{
			if (StrEqual(sSubset[iPos], MT_ROCKET_SECTION, false) || StrEqual(sSubset[iPos], MT_ROCKET_SECTION2, false) || StrEqual(sSubset[iPos], MT_ROCKET_SECTION3, false) || StrEqual(sSubset[iPos], MT_ROCKET_SECTION4, false))
			{
				flDelay = MT_GetCombinationSetting(tank, 4, iPos);

				switch (type)
				{
					case MT_COMBO_MAINRANGE:
					{
						if (g_esRocketCache[tank].g_iRocketAbility == 1)
						{
							switch (flDelay)
							{
								case 0.0: vRocketAbility(tank, random);
								default:
								{
									DataPack dpCombo;
									CreateDataTimer(flDelay, tTimerRocketCombo, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
								if ((g_esRocketCache[tank].g_iRocketHitMode == 0 || g_esRocketCache[tank].g_iRocketHitMode == 1) && (StrEqual(classname[7], "tank_claw") || StrEqual(classname, "tank_rock")))
								{
									vRocketHit(survivor, tank, random, flChance, g_esRocketCache[tank].g_iRocketHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
								}
								else if ((g_esRocketCache[tank].g_iRocketHitMode == 0 || g_esRocketCache[tank].g_iRocketHitMode == 2) && StrEqual(classname[7], "melee"))
								{
									vRocketHit(survivor, tank, random, flChance, g_esRocketCache[tank].g_iRocketHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
								}
							}
							default:
							{
								DataPack dpCombo;
								CreateDataTimer(flDelay, tTimerRocketCombo2, dpCombo, TIMER_FLAG_NO_MAPCHANGE);
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
void vRocketConfigsLoad(int mode)
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
				g_esRocketAbility[iIndex].g_iAccessFlags = 0;
				g_esRocketAbility[iIndex].g_iImmunityFlags = 0;
				g_esRocketAbility[iIndex].g_flCloseAreasOnly = 0.0;
				g_esRocketAbility[iIndex].g_iComboAbility = 0;
				g_esRocketAbility[iIndex].g_iHumanAbility = 0;
				g_esRocketAbility[iIndex].g_iHumanAmmo = 5;
				g_esRocketAbility[iIndex].g_iHumanCooldown = 0;
				g_esRocketAbility[iIndex].g_iHumanRangeCooldown = 0;
				g_esRocketAbility[iIndex].g_flOpenAreasOnly = 0.0;
				g_esRocketAbility[iIndex].g_iRequiresHumans = 0;
				g_esRocketAbility[iIndex].g_iRocketAbility = 0;
				g_esRocketAbility[iIndex].g_iRocketEffect = 0;
				g_esRocketAbility[iIndex].g_iRocketMessage = 0;
				g_esRocketAbility[iIndex].g_iRocketBody = 1;
				g_esRocketAbility[iIndex].g_flRocketChance = 33.3;
				g_esRocketAbility[iIndex].g_iRocketCooldown = 0;
				g_esRocketAbility[iIndex].g_flRocketDelay = 1.0;
				g_esRocketAbility[iIndex].g_iRocketHit = 0;
				g_esRocketAbility[iIndex].g_iRocketHitMode = 0;
				g_esRocketAbility[iIndex].g_flRocketRange = 150.0;
				g_esRocketAbility[iIndex].g_flRocketRangeChance = 15.0;
				g_esRocketAbility[iIndex].g_iRocketRangeCooldown = 0;
			}
		}
		case 3:
		{
			for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
			{
				if (bIsValidClient(iPlayer))
				{
					g_esRocketPlayer[iPlayer].g_iAccessFlags = 0;
					g_esRocketPlayer[iPlayer].g_iImmunityFlags = 0;
					g_esRocketPlayer[iPlayer].g_flCloseAreasOnly = 0.0;
					g_esRocketPlayer[iPlayer].g_iComboAbility = 0;
					g_esRocketPlayer[iPlayer].g_iHumanAbility = 0;
					g_esRocketPlayer[iPlayer].g_iHumanAmmo = 0;
					g_esRocketPlayer[iPlayer].g_iHumanCooldown = 0;
					g_esRocketPlayer[iPlayer].g_iHumanRangeCooldown = 0;
					g_esRocketPlayer[iPlayer].g_flOpenAreasOnly = 0.0;
					g_esRocketPlayer[iPlayer].g_iRequiresHumans = 0;
					g_esRocketPlayer[iPlayer].g_iRocketAbility = 0;
					g_esRocketPlayer[iPlayer].g_iRocketEffect = 0;
					g_esRocketPlayer[iPlayer].g_iRocketMessage = 0;
					g_esRocketPlayer[iPlayer].g_iRocketBody = 0;
					g_esRocketPlayer[iPlayer].g_flRocketChance = 0.0;
					g_esRocketPlayer[iPlayer].g_iRocketCooldown = 0;
					g_esRocketPlayer[iPlayer].g_flRocketDelay = 0.0;
					g_esRocketPlayer[iPlayer].g_iRocketHit = 0;
					g_esRocketPlayer[iPlayer].g_iRocketHitMode = 0;
					g_esRocketPlayer[iPlayer].g_flRocketRange = 0.0;
					g_esRocketPlayer[iPlayer].g_flRocketRangeChance = 0.0;
					g_esRocketPlayer[iPlayer].g_iRocketRangeCooldown = 0;
				}
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#else
public void MT_OnConfigsLoaded(const char[] subsection, const char[] key, const char[] value, int type, int admin, int mode)
#endif
{
	if (mode == 3 && bIsValidClient(admin))
	{
		g_esRocketPlayer[admin].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esRocketPlayer[admin].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esRocketPlayer[admin].g_iComboAbility = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esRocketPlayer[admin].g_iComboAbility, value, 0, 1);
		g_esRocketPlayer[admin].g_iHumanAbility = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esRocketPlayer[admin].g_iHumanAbility, value, 0, 2);
		g_esRocketPlayer[admin].g_iHumanAmmo = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esRocketPlayer[admin].g_iHumanAmmo, value, 0, 99999);
		g_esRocketPlayer[admin].g_iHumanCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esRocketPlayer[admin].g_iHumanCooldown, value, 0, 99999);
		g_esRocketPlayer[admin].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esRocketPlayer[admin].g_iHumanRangeCooldown, value, 0, 99999);
		g_esRocketPlayer[admin].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esRocketPlayer[admin].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esRocketPlayer[admin].g_iRequiresHumans = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esRocketPlayer[admin].g_iRequiresHumans, value, 0, 32);
		g_esRocketPlayer[admin].g_iRocketAbility = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esRocketPlayer[admin].g_iRocketAbility, value, 0, 1);
		g_esRocketPlayer[admin].g_iRocketEffect = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esRocketPlayer[admin].g_iRocketEffect, value, 0, 7);
		g_esRocketPlayer[admin].g_iRocketMessage = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esRocketPlayer[admin].g_iRocketMessage, value, 0, 3);
		g_esRocketPlayer[admin].g_iRocketBody = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketBody", "Rocket Body", "Rocket_Body", "body", g_esRocketPlayer[admin].g_iRocketBody, value, 0, 1);
		g_esRocketPlayer[admin].g_flRocketChance = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketChance", "Rocket Chance", "Rocket_Chance", "chance", g_esRocketPlayer[admin].g_flRocketChance, value, 0.0, 100.0);
		g_esRocketPlayer[admin].g_iRocketCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketCooldown", "Rocket Cooldown", "Rocket_Cooldown", "cooldown", g_esRocketPlayer[admin].g_iRocketCooldown, value, 0, 99999);
		g_esRocketPlayer[admin].g_flRocketDelay = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketDelay", "Rocket Delay", "Rocket_Delay", "delay", g_esRocketPlayer[admin].g_flRocketDelay, value, 0.1, 99999.0);
		g_esRocketPlayer[admin].g_iRocketHit = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketHit", "Rocket Hit", "Rocket_Hit", "hit", g_esRocketPlayer[admin].g_iRocketHit, value, 0, 1);
		g_esRocketPlayer[admin].g_iRocketHitMode = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketHitMode", "Rocket Hit Mode", "Rocket_Hit_Mode", "hitmode", g_esRocketPlayer[admin].g_iRocketHitMode, value, 0, 2);
		g_esRocketPlayer[admin].g_flRocketRange = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketRange", "Rocket Range", "Rocket_Range", "range", g_esRocketPlayer[admin].g_flRocketRange, value, 1.0, 99999.0);
		g_esRocketPlayer[admin].g_flRocketRangeChance = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketRangeChance", "Rocket Range Chance", "Rocket_Range_Chance", "rangechance", g_esRocketPlayer[admin].g_flRocketRangeChance, value, 0.0, 100.0);
		g_esRocketPlayer[admin].g_iRocketRangeCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketRangeCooldown", "Rocket Range Cooldown", "Rocket_Range_Cooldown", "rangecooldown", g_esRocketPlayer[admin].g_iRocketRangeCooldown, value, 0, 99999);
		g_esRocketPlayer[admin].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esRocketPlayer[admin].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}

	if (mode < 3 && type > 0)
	{
		g_esRocketAbility[type].g_flCloseAreasOnly = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "CloseAreasOnly", "Close Areas Only", "Close_Areas_Only", "closeareas", g_esRocketAbility[type].g_flCloseAreasOnly, value, 0.0, 99999.0);
		g_esRocketAbility[type].g_iComboAbility = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "ComboAbility", "Combo Ability", "Combo_Ability", "combo", g_esRocketAbility[type].g_iComboAbility, value, 0, 1);
		g_esRocketAbility[type].g_iHumanAbility = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanAbility", "Human Ability", "Human_Ability", "human", g_esRocketAbility[type].g_iHumanAbility, value, 0, 2);
		g_esRocketAbility[type].g_iHumanAmmo = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanAmmo", "Human Ammo", "Human_Ammo", "hammo", g_esRocketAbility[type].g_iHumanAmmo, value, 0, 99999);
		g_esRocketAbility[type].g_iHumanCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanCooldown", "Human Cooldown", "Human_Cooldown", "hcooldown", g_esRocketAbility[type].g_iHumanCooldown, value, 0, 99999);
		g_esRocketAbility[type].g_iHumanRangeCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "HumanRangeCooldown", "Human Range Cooldown", "Human_Range_Cooldown", "hrangecooldown", g_esRocketAbility[type].g_iHumanRangeCooldown, value, 0, 99999);
		g_esRocketAbility[type].g_flOpenAreasOnly = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "OpenAreasOnly", "Open Areas Only", "Open_Areas_Only", "openareas", g_esRocketAbility[type].g_flOpenAreasOnly, value, 0.0, 99999.0);
		g_esRocketAbility[type].g_iRequiresHumans = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RequiresHumans", "Requires Humans", "Requires_Humans", "hrequire", g_esRocketAbility[type].g_iRequiresHumans, value, 0, 32);
		g_esRocketAbility[type].g_iRocketAbility = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AbilityEnabled", "Ability Enabled", "Ability_Enabled", "aenabled", g_esRocketAbility[type].g_iRocketAbility, value, 0, 1);
		g_esRocketAbility[type].g_iRocketEffect = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AbilityEffect", "Ability Effect", "Ability_Effect", "effect", g_esRocketAbility[type].g_iRocketEffect, value, 0, 7);
		g_esRocketAbility[type].g_iRocketMessage = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AbilityMessage", "Ability Message", "Ability_Message", "message", g_esRocketAbility[type].g_iRocketMessage, value, 0, 3);
		g_esRocketAbility[type].g_iRocketBody = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketBody", "Rocket Body", "Rocket_Body", "body", g_esRocketAbility[type].g_iRocketBody, value, 0, 1);
		g_esRocketAbility[type].g_flRocketChance = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketChance", "Rocket Chance", "Rocket_Chance", "chance", g_esRocketAbility[type].g_flRocketChance, value, 0.0, 100.0);
		g_esRocketAbility[type].g_iRocketCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketCooldown", "Rocket Cooldown", "Rocket_Cooldown", "cooldown", g_esRocketAbility[type].g_iRocketCooldown, value, 0, 99999);
		g_esRocketAbility[type].g_flRocketDelay = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketDelay", "Rocket Delay", "Rocket_Delay", "delay", g_esRocketAbility[type].g_flRocketDelay, value, 0.1, 99999.0);
		g_esRocketAbility[type].g_iRocketHit = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketHit", "Rocket Hit", "Rocket_Hit", "hit", g_esRocketAbility[type].g_iRocketHit, value, 0, 1);
		g_esRocketAbility[type].g_iRocketHitMode = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketHitMode", "Rocket Hit Mode", "Rocket_Hit_Mode", "hitmode", g_esRocketAbility[type].g_iRocketHitMode, value, 0, 2);
		g_esRocketAbility[type].g_flRocketRange = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketRange", "Rocket Range", "Rocket_Range", "range", g_esRocketAbility[type].g_flRocketRange, value, 1.0, 99999.0);
		g_esRocketAbility[type].g_flRocketRangeChance = flGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketRangeChance", "Rocket Range Chance", "Rocket_Range_Chance", "rangechance", g_esRocketAbility[type].g_flRocketRangeChance, value, 0.0, 100.0);
		g_esRocketAbility[type].g_iRocketRangeCooldown = iGetKeyValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "RocketRangeCooldown", "Rocket Range Cooldown", "Rocket_Range_Cooldown", "rangecooldown", g_esRocketAbility[type].g_iRocketRangeCooldown, value, 0, 99999);
		g_esRocketAbility[type].g_iAccessFlags = iGetAdminFlagsValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "AccessFlags", "Access Flags", "Access_Flags", "access", value);
		g_esRocketAbility[type].g_iImmunityFlags = iGetAdminFlagsValue(subsection, MT_ROCKET_SECTION, MT_ROCKET_SECTION2, MT_ROCKET_SECTION3, MT_ROCKET_SECTION4, key, "ImmunityFlags", "Immunity Flags", "Immunity_Flags", "immunity", value);
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketSettingsCached(int tank, bool apply, int type)
#else
public void MT_OnSettingsCached(int tank, bool apply, int type)
#endif
{
	bool bHuman = bIsTank(tank, MT_CHECK_FAKECLIENT);
	g_esRocketCache[tank].g_flCloseAreasOnly = flGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_flCloseAreasOnly, g_esRocketAbility[type].g_flCloseAreasOnly);
	g_esRocketCache[tank].g_iComboAbility = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iComboAbility, g_esRocketAbility[type].g_iComboAbility);
	g_esRocketCache[tank].g_flRocketChance = flGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_flRocketChance, g_esRocketAbility[type].g_flRocketChance);
	g_esRocketCache[tank].g_flRocketDelay = flGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_flRocketDelay, g_esRocketAbility[type].g_flRocketDelay);
	g_esRocketCache[tank].g_flRocketRange = flGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_flRocketRange, g_esRocketAbility[type].g_flRocketRange);
	g_esRocketCache[tank].g_flRocketRangeChance = flGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_flRocketRangeChance, g_esRocketAbility[type].g_flRocketRangeChance);
	g_esRocketCache[tank].g_iHumanAbility = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iHumanAbility, g_esRocketAbility[type].g_iHumanAbility);
	g_esRocketCache[tank].g_iHumanAmmo = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iHumanAmmo, g_esRocketAbility[type].g_iHumanAmmo);
	g_esRocketCache[tank].g_iHumanCooldown = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iHumanCooldown, g_esRocketAbility[type].g_iHumanCooldown);
	g_esRocketCache[tank].g_iHumanRangeCooldown = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iHumanRangeCooldown, g_esRocketAbility[type].g_iHumanRangeCooldown);
	g_esRocketCache[tank].g_flOpenAreasOnly = flGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_flOpenAreasOnly, g_esRocketAbility[type].g_flOpenAreasOnly);
	g_esRocketCache[tank].g_iRequiresHumans = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRequiresHumans, g_esRocketAbility[type].g_iRequiresHumans);
	g_esRocketCache[tank].g_iRocketAbility = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketAbility, g_esRocketAbility[type].g_iRocketAbility);
	g_esRocketCache[tank].g_iRocketBody = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketBody, g_esRocketAbility[type].g_iRocketBody);
	g_esRocketCache[tank].g_iRocketCooldown = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketCooldown, g_esRocketAbility[type].g_iRocketCooldown);
	g_esRocketCache[tank].g_iRocketEffect = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketEffect, g_esRocketAbility[type].g_iRocketEffect);
	g_esRocketCache[tank].g_iRocketHit = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketHit, g_esRocketAbility[type].g_iRocketHit);
	g_esRocketCache[tank].g_iRocketHitMode = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketHitMode, g_esRocketAbility[type].g_iRocketHitMode);
	g_esRocketCache[tank].g_iRocketMessage = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketMessage, g_esRocketAbility[type].g_iRocketMessage);
	g_esRocketCache[tank].g_iRocketRangeCooldown = iGetSettingValue(apply, bHuman, g_esRocketPlayer[tank].g_iRocketRangeCooldown, g_esRocketAbility[type].g_iRocketRangeCooldown);
	g_esRocketPlayer[tank].g_iTankType = apply ? type : 0;
}

#if defined MT_ABILITIES_MAIN2
void vRocketCopyStats(int oldTank, int newTank)
#else
public void MT_OnCopyStats(int oldTank, int newTank)
#endif
{
	vRocketCopyStats2(oldTank, newTank);

	if (oldTank != newTank)
	{
		vRemoveRocket(oldTank);
	}
}

#if !defined MT_ABILITIES_MAIN2
public void MT_OnPluginUpdate()
{
	MT_ReloadPlugin(null);
}
#endif

#if defined MT_ABILITIES_MAIN2
void vRocketPluginEnd()
#else
public void MT_OnPluginEnd()
#endif
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esRocketPlayer[iSurvivor].g_bAffected)
		{
			SetEntityGravity(iSurvivor, 1.0);
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketEventFired(Event event, const char[] name)
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
			vRocketCopyStats2(iBot, iTank);
			vRemoveRocket(iBot);
		}
	}
	else if (StrEqual(name, "player_bot_replace"))
	{
		int iTankId = event.GetInt("player"), iTank = GetClientOfUserId(iTankId),
			iBotId = event.GetInt("bot"), iBot = GetClientOfUserId(iBotId);
		if (bIsValidClient(iTank) && bIsTank(iBot))
		{
			vRocketCopyStats2(iTank, iBot);
			vRemoveRocket(iTank);
		}
	}
	else if (StrEqual(name, "player_death") || StrEqual(name, "player_spawn"))
	{
		int iTankId = event.GetInt("userid"), iTank = GetClientOfUserId(iTankId);
		if (MT_IsTankSupported(iTank, MT_CHECK_INDEX|MT_CHECK_INGAME))
		{
			vRemoveRocket(iTank);
		}
	}
	else if (StrEqual(name, "mission_lost") || StrEqual(name, "round_start") || StrEqual(name, "round_end"))
	{
		vRocketReset();
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketAbilityActivated(int tank)
#else
public void MT_OnAbilityActivated(int tank)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_FAKECLIENT) && ((!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRocketAbility[g_esRocketPlayer[tank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[tank].g_iAccessFlags)) || g_esRocketCache[tank].g_iHumanAbility == 0))
	{
		return;
	}

	if (MT_IsTankSupported(tank) && (!bIsTank(tank, MT_CHECK_FAKECLIENT) || g_esRocketCache[tank].g_iHumanAbility != 1) && MT_IsCustomTankSupported(tank) && g_esRocketCache[tank].g_iRocketAbility == 1 && g_esRocketCache[tank].g_iComboAbility == 0)
	{
		vRocketAbility(tank, MT_GetRandomFloat(0.1, 100.0));
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketButtonPressed(int tank, int button)
#else
public void MT_OnButtonPressed(int tank, int button)
#endif
{
	if (MT_IsTankSupported(tank, MT_CHECK_INDEX|MT_CHECK_INGAME|MT_CHECK_ALIVE|MT_CHECK_FAKECLIENT) && MT_IsCustomTankSupported(tank))
	{
		if (bIsAreaNarrow(tank, g_esRocketCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRocketCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRocketPlayer[tank].g_iTankType) || (g_esRocketCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRocketCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRocketAbility[g_esRocketPlayer[tank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[tank].g_iAccessFlags)))
		{
			return;
		}

		if ((button & MT_SUB_KEY) && g_esRocketCache[tank].g_iRocketAbility == 1 && g_esRocketCache[tank].g_iHumanAbility == 1)
		{
			int iTime = GetTime();

			switch (g_esRocketPlayer[tank].g_iRangeCooldown == -1 || g_esRocketPlayer[tank].g_iRangeCooldown < iTime)
			{
				case true: vRocketAbility(tank, MT_GetRandomFloat(0.1, 100.0));
				case false: MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketHuman3", (g_esRocketPlayer[tank].g_iRangeCooldown - iTime));
			}
		}
	}
}

#if defined MT_ABILITIES_MAIN2
void vRocketChangeType(int tank, int oldType)
#else
public void MT_OnChangeType(int tank, int oldType, int newType, bool revert)
#endif
{
	if (oldType <= 0)
	{
		return;
	}

	vRemoveRocket(tank);
}

void vRocketAbility(int tank, float random, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esRocketCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRocketCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRocketPlayer[tank].g_iTankType) || (g_esRocketCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRocketCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRocketAbility[g_esRocketPlayer[tank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[tank].g_iAccessFlags)))
	{
		return;
	}

	if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (g_esRocketPlayer[tank].g_iAmmoCount < g_esRocketCache[tank].g_iHumanAmmo && g_esRocketCache[tank].g_iHumanAmmo > 0))
	{
		g_esRocketPlayer[tank].g_bFailed = false;
		g_esRocketPlayer[tank].g_bNoAmmo = false;

		float flTankPos[3], flSurvivorPos[3];
		GetClientAbsOrigin(tank, flTankPos);
		float flRange = (pos != -1) ? MT_GetCombinationSetting(tank, 9, pos) : g_esRocketCache[tank].g_flRocketRange,
			flChance = (pos != -1) ? MT_GetCombinationSetting(tank, 10, pos) : g_esRocketCache[tank].g_flRocketRangeChance;
		int iSurvivorCount = 0;
		for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
		{
			if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && !MT_IsAdminImmune(iSurvivor, tank) && !bIsAdminImmune(iSurvivor, g_esRocketPlayer[tank].g_iTankType, g_esRocketAbility[g_esRocketPlayer[tank].g_iTankType].g_iImmunityFlags, g_esRocketPlayer[iSurvivor].g_iImmunityFlags))
			{
				GetClientAbsOrigin(iSurvivor, flSurvivorPos);
				if (GetVectorDistance(flTankPos, flSurvivorPos) <= flRange)
				{
					vRocketHit(iSurvivor, tank, random, flChance, g_esRocketCache[tank].g_iRocketAbility, MT_MESSAGE_RANGE, MT_ATTACK_RANGE, pos);

					iSurvivorCount++;
				}
			}
		}

		if (iSurvivorCount == 0)
		{
			if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1)
			{
				MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketHuman4");
			}
		}
	}
	else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1)
	{
		MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketAmmo");
	}
}

void vRocketHit(int survivor, int tank, float random, float chance, int enabled, int messages, int flags, int pos = -1)
{
	if (bIsAreaNarrow(tank, g_esRocketCache[tank].g_flOpenAreasOnly) || bIsAreaWide(tank, g_esRocketCache[tank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRocketPlayer[tank].g_iTankType) || (g_esRocketCache[tank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRocketCache[tank].g_iRequiresHumans) || (!MT_HasAdminAccess(tank) && !bHasAdminAccess(tank, g_esRocketAbility[g_esRocketPlayer[tank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[tank].g_iAccessFlags)) || MT_IsAdminImmune(survivor, tank) || bIsAdminImmune(survivor, g_esRocketPlayer[tank].g_iTankType, g_esRocketAbility[g_esRocketPlayer[tank].g_iTankType].g_iImmunityFlags, g_esRocketPlayer[survivor].g_iImmunityFlags))
	{
		return;
	}

	int iTime = GetTime();
	if (((flags & MT_ATTACK_RANGE) && g_esRocketPlayer[tank].g_iRangeCooldown != -1 && g_esRocketPlayer[tank].g_iRangeCooldown > iTime) || (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && g_esRocketPlayer[tank].g_iCooldown != -1 && g_esRocketPlayer[tank].g_iCooldown > iTime))
	{
		return;
	}

	if (enabled == 1 && bIsSurvivor(survivor) && !MT_DoesSurvivorHaveRewardType(survivor, MT_REWARD_GODMODE))
	{
		if (!bIsTank(tank, MT_CHECK_FAKECLIENT) || (flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE) || (g_esRocketPlayer[tank].g_iAmmoCount < g_esRocketCache[tank].g_iHumanAmmo && g_esRocketCache[tank].g_iHumanAmmo > 0))
		{
			if (random <= chance && !g_esRocketPlayer[survivor].g_bAffected)
			{
				int iFlame = CreateEntityByName("env_steam");
				if (bIsValidEntity(iFlame))
				{
					g_esRocketPlayer[survivor].g_bAffected = true;
					g_esRocketPlayer[survivor].g_iOwner = tank;

					int iCooldown = -1;
					if ((flags & MT_ATTACK_RANGE) && (g_esRocketPlayer[tank].g_iRangeCooldown == -1 || g_esRocketPlayer[tank].g_iRangeCooldown < iTime))
					{
						if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1)
						{
							g_esRocketPlayer[tank].g_iAmmoCount++;

							MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketHuman", g_esRocketPlayer[tank].g_iAmmoCount, g_esRocketCache[tank].g_iHumanAmmo);
						}

						iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 11, pos)) : g_esRocketCache[tank].g_iRocketRangeCooldown;
						iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1 && g_esRocketPlayer[tank].g_iAmmoCount < g_esRocketCache[tank].g_iHumanAmmo && g_esRocketCache[tank].g_iHumanAmmo > 0) ? g_esRocketCache[tank].g_iHumanRangeCooldown : iCooldown;
						g_esRocketPlayer[tank].g_iRangeCooldown = (iTime + iCooldown);
						if (g_esRocketPlayer[tank].g_iRangeCooldown != -1 && g_esRocketPlayer[tank].g_iRangeCooldown > iTime)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketHuman5", (g_esRocketPlayer[tank].g_iRangeCooldown - iTime));
						}
					}
					else if (((flags & MT_ATTACK_CLAW) || (flags & MT_ATTACK_MELEE)) && (g_esRocketPlayer[tank].g_iCooldown == -1 || g_esRocketPlayer[tank].g_iCooldown < iTime))
					{
						iCooldown = (pos != -1) ? RoundToNearest(MT_GetCombinationSetting(tank, 2, pos)) : g_esRocketCache[tank].g_iRocketCooldown;
						iCooldown = (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1) ? g_esRocketCache[tank].g_iHumanCooldown : iCooldown;
						g_esRocketPlayer[tank].g_iCooldown = (iTime + iCooldown);
						if (g_esRocketPlayer[tank].g_iCooldown != -1 && g_esRocketPlayer[tank].g_iCooldown > iTime)
						{
							MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketHuman5", (g_esRocketPlayer[tank].g_iCooldown - iTime));
						}
					}

					float flPos[3], flAngles[3];
					GetEntPropVector(survivor, Prop_Data, "m_vecOrigin", flPos);
					flPos[2] += 30.0;
					flAngles[0] = 90.0;
					flAngles[1] = 0.0;
					flAngles[2] = 0.0;

					DispatchKeyValueInt(iFlame, "spawnflags", 1);
					DispatchKeyValueInt(iFlame, "Type", 0);
					DispatchKeyValueInt(iFlame, "InitialState", 1);
					DispatchKeyValueInt(iFlame, "Spreadspeed", 10);
					DispatchKeyValueInt(iFlame, "Speed", 800);
					DispatchKeyValueInt(iFlame, "Startsize", 10);
					DispatchKeyValueInt(iFlame, "EndSize", 250);
					DispatchKeyValueInt(iFlame, "Rate", 15);
					DispatchKeyValueInt(iFlame, "JetLength", 400);

					SetEntityRenderColor(iFlame, 180, 70, 10, 180);
					TeleportEntity(iFlame, flPos, flAngles);
					DispatchSpawn(iFlame);
					vSetEntityParent(iFlame, survivor);

					iFlame = EntIndexToEntRef(iFlame);
					vDeleteEntity(iFlame, 3.0);

					vScreenEffect(survivor, tank, g_esRocketCache[tank].g_iRocketEffect, flags);
					EmitSoundToAll(SOUND_FIRE, survivor);

					float flDelay = (pos != -1) ? 0.1 : g_esRocketCache[tank].g_flRocketDelay;
					DataPack dpRocketLaunch;
					CreateDataTimer(flDelay, tTimerRocketLaunch, dpRocketLaunch, TIMER_FLAG_NO_MAPCHANGE);
					dpRocketLaunch.WriteCell(GetClientUserId(survivor));
					dpRocketLaunch.WriteCell(GetClientUserId(tank));
					dpRocketLaunch.WriteCell(g_esRocketPlayer[tank].g_iTankType);
					dpRocketLaunch.WriteCell(enabled);

					DataPack dpRocketDetonate;
					CreateDataTimer((flDelay + 1.5), tTimerRocketDetonate, dpRocketDetonate, TIMER_FLAG_NO_MAPCHANGE);
					dpRocketDetonate.WriteCell(GetClientUserId(survivor));
					dpRocketDetonate.WriteCell(GetClientUserId(tank));
					dpRocketDetonate.WriteCell(g_esRocketPlayer[tank].g_iTankType);
					dpRocketDetonate.WriteCell(enabled);
					dpRocketDetonate.WriteCell(messages);
				}
			}
			else if ((flags & MT_ATTACK_RANGE) && (g_esRocketPlayer[tank].g_iRangeCooldown == -1 || g_esRocketPlayer[tank].g_iRangeCooldown < iTime))
			{
				if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1 && !g_esRocketPlayer[tank].g_bFailed)
				{
					g_esRocketPlayer[tank].g_bFailed = true;

					MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketHuman2");
				}
			}
		}
		else if (bIsTank(tank, MT_CHECK_FAKECLIENT) && g_esRocketCache[tank].g_iHumanAbility == 1 && !g_esRocketPlayer[tank].g_bNoAmmo)
		{
			g_esRocketPlayer[tank].g_bNoAmmo = true;

			MT_PrintToChat(tank, "%s %t", MT_TAG3, "RocketAmmo");
		}
	}
}

void vRocketCopyStats2(int oldTank, int newTank)
{
	g_esRocketPlayer[newTank].g_iAmmoCount = g_esRocketPlayer[oldTank].g_iAmmoCount;
	g_esRocketPlayer[newTank].g_iCooldown = g_esRocketPlayer[oldTank].g_iCooldown;
	g_esRocketPlayer[newTank].g_iRangeCooldown = g_esRocketPlayer[oldTank].g_iRangeCooldown;
}

void vRemoveRocket(int tank)
{
	for (int iSurvivor = 1; iSurvivor <= MaxClients; iSurvivor++)
	{
		if (bIsSurvivor(iSurvivor, MT_CHECK_INGAME|MT_CHECK_ALIVE) && g_esRocketPlayer[iSurvivor].g_bAffected && g_esRocketPlayer[iSurvivor].g_iOwner == tank)
		{
			g_esRocketPlayer[iSurvivor].g_bAffected = false;
			g_esRocketPlayer[iSurvivor].g_iOwner = 0;
		}
	}

	vRocketReset3(tank);
}

void vRocketReset()
{
	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer++)
	{
		if (bIsValidClient(iPlayer, MT_CHECK_INGAME))
		{
			vRocketReset3(iPlayer);

			g_esRocketPlayer[iPlayer].g_iOwner = 0;
		}
	}
}

void vRocketReset2(int survivor)
{
	g_esRocketPlayer[survivor].g_bAffected = false;
	g_esRocketPlayer[survivor].g_iOwner = 0;

	SetEntityGravity(survivor, 1.0);
}

void vRocketReset3(int tank)
{
	g_esRocketPlayer[tank].g_bAffected = false;
	g_esRocketPlayer[tank].g_bFailed = false;
	g_esRocketPlayer[tank].g_bNoAmmo = false;
	g_esRocketPlayer[tank].g_iAmmoCount = 0;
	g_esRocketPlayer[tank].g_iCooldown = -1;
	g_esRocketPlayer[tank].g_iRangeCooldown = -1;
}

Action tTimerRocketCombo(Handle timer, DataPack pack)
{
	pack.Reset();

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRocketAbility[g_esRocketPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRocketPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esRocketCache[iTank].g_iRocketAbility == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat();
	int iPos = pack.ReadCell();
	vRocketAbility(iTank, flRandom, iPos);

	return Plugin_Continue;
}

Action tTimerRocketCombo2(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!bIsSurvivor(iSurvivor))
	{
		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !MT_IsTankSupported(iTank) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRocketAbility[g_esRocketPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRocketPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || g_esRocketCache[iTank].g_iRocketHit == 0)
	{
		return Plugin_Stop;
	}

	float flRandom = pack.ReadFloat(), flChance = pack.ReadFloat();
	int iPos = pack.ReadCell();
	char sClassname[32];
	pack.ReadString(sClassname, sizeof sClassname);
	if ((g_esRocketCache[iTank].g_iRocketHitMode == 0 || g_esRocketCache[iTank].g_iRocketHitMode == 1) && (StrEqual(sClassname[7], "tank_claw") || StrEqual(sClassname, "tank_rock")))
	{
		vRocketHit(iSurvivor, iTank, flRandom, flChance, g_esRocketCache[iTank].g_iRocketHit, MT_MESSAGE_MELEE, MT_ATTACK_CLAW, iPos);
	}
	else if ((g_esRocketCache[iTank].g_iRocketHitMode == 0 || g_esRocketCache[iTank].g_iRocketHitMode == 2) && StrEqual(sClassname[7], "melee"))
	{
		vRocketHit(iSurvivor, iTank, flRandom, flChance, g_esRocketCache[iTank].g_iRocketHit, MT_MESSAGE_MELEE, MT_ATTACK_MELEE, iPos);
	}

	return Plugin_Continue;
}

Action tTimerRocketLaunch(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esRocketPlayer[iSurvivor].g_bAffected = false;
		g_esRocketPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iRocketEnabled = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esRocketCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esRocketCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRocketPlayer[iTank].g_iTankType) || (g_esRocketCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRocketCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRocketAbility[g_esRocketPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRocketPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esRocketPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esRocketPlayer[iTank].g_iTankType, g_esRocketAbility[g_esRocketPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esRocketPlayer[iSurvivor].g_iImmunityFlags) || iRocketEnabled == 0 || !g_esRocketPlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vRocketReset2(iSurvivor);

		return Plugin_Stop;
	}

	float flVelocity[3];
	flVelocity[0] = 0.0;
	flVelocity[1] = 0.0;
	flVelocity[2] = 800.0;

	EmitSoundToAll(SOUND_EXPLOSION, iSurvivor);
	EmitSoundToAll(SOUND_LAUNCH, iSurvivor);

	TeleportEntity(iSurvivor, .velocity = flVelocity);
	SetEntityGravity(iSurvivor, 0.1);

	return Plugin_Continue;
}

Action tTimerRocketDetonate(Handle timer, DataPack pack)
{
	pack.Reset();

	int iSurvivor = GetClientOfUserId(pack.ReadCell());
	if (!MT_IsCorePluginEnabled() || !bIsSurvivor(iSurvivor))
	{
		g_esRocketPlayer[iSurvivor].g_bAffected = false;
		g_esRocketPlayer[iSurvivor].g_iOwner = 0;

		return Plugin_Stop;
	}

	int iTank = GetClientOfUserId(pack.ReadCell()), iType = pack.ReadCell(), iRocketEnabled = pack.ReadCell();
	if (!MT_IsTankSupported(iTank) || bIsAreaNarrow(iTank, g_esRocketCache[iTank].g_flOpenAreasOnly) || bIsAreaWide(iTank, g_esRocketCache[iTank].g_flCloseAreasOnly) || MT_DoesTypeRequireHumans(g_esRocketPlayer[iTank].g_iTankType) || (g_esRocketCache[iTank].g_iRequiresHumans > 0 && iGetHumanCount() < g_esRocketCache[iTank].g_iRequiresHumans) || (!MT_HasAdminAccess(iTank) && !bHasAdminAccess(iTank, g_esRocketAbility[g_esRocketPlayer[iTank].g_iTankType].g_iAccessFlags, g_esRocketPlayer[iTank].g_iAccessFlags)) || !MT_IsTypeEnabled(g_esRocketPlayer[iTank].g_iTankType) || !MT_IsCustomTankSupported(iTank) || iType != g_esRocketPlayer[iTank].g_iTankType || MT_IsAdminImmune(iSurvivor, iTank) || bIsAdminImmune(iSurvivor, g_esRocketPlayer[iTank].g_iTankType, g_esRocketAbility[g_esRocketPlayer[iTank].g_iTankType].g_iImmunityFlags, g_esRocketPlayer[iSurvivor].g_iImmunityFlags) || iRocketEnabled == 0 || !g_esRocketPlayer[iSurvivor].g_bAffected || MT_DoesSurvivorHaveRewardType(iSurvivor, MT_REWARD_GODMODE))
	{
		vRocketReset2(iSurvivor);

		return Plugin_Stop;
	}

	if (g_esRocketCache[iTank].g_iRocketBody == 1)
	{
		g_iRocketDeathModelOwner = GetClientUserId(iSurvivor);
	}

	float flPos[3];
	GetClientAbsOrigin(iSurvivor, flPos);

	TE_SetupExplosion(flPos, g_iRocketSprite, 10.0, 1, 0, 600, 5000);
	TE_SendToAll();

	SetEntityGravity(iSurvivor, 1.0);
	ForcePlayerSuicide(iSurvivor);

	g_esRocketPlayer[iSurvivor].g_bAffected = false;
	g_esRocketPlayer[iSurvivor].g_iOwner = 0;

	int iMessage = pack.ReadCell();
	if (g_esRocketCache[iTank].g_iRocketMessage & iMessage)
	{
		char sTankName[33];
		MT_GetTankName(iTank, sTankName);
		MT_PrintToChatAll("%s %t", MT_TAG2, "Rocket", sTankName, iSurvivor);
		MT_LogMessage(MT_LOG_ABILITY, "%s %T", MT_TAG, "Rocket", LANG_SERVER, sTankName, iSurvivor);
	}

	return Plugin_Continue;
}